import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/network_config.dart';
import '../../../../core/transfers/resumable_transfer_manager.dart';
import '../../../../core/security/encrypted_vault_storage.dart';
import '../../../../core/security/hardware_security_manager.dart';
import '../../../../core/security/isolate_crypto_worker.dart';
import '../../../../core/security/secure_vault_manifest.dart';
import '../../../../core/security/zero_knowledge_crypto.dart';
import '../../../../core/utils/thumbnail/thumbnail_helper.dart';
import '../../../transfers/data/active_upload_notifier.dart';
import '../../../transfers/data/transfer_manager.dart';
import '../../data/vault_storage_service.dart';
import '../../domain/models/drive_item.dart';

final vaultStorageServiceProvider = Provider<VaultStorageService>((ref) {
  final transferManager = ref.watch(transferManagerProvider.notifier);
  return VaultStorageService(transferManager: transferManager);
});

final driveControllerProvider = StateNotifierProvider<DriveController, List<DriveItem>>((ref) {
  final service = ref.watch(vaultStorageServiceProvider);
  final uploadNotifier = ref.watch(activeUploadProvider.notifier);
  return DriveController(service, uploadNotifier);
});

class DriveController extends StateNotifier<List<DriveItem>> {
  final VaultStorageService _storageService;
  final ActiveUploadNotifier _uploadNotifier;

  /// The phone number of the currently logged-in user. Used as the namespace
  /// key for all persistence operations so that different accounts never
  /// leak files into each other.
  String? _currentPhone;

  DriveController(this._storageService, this._uploadNotifier)
      : super(const []);

  // ---------------------------------------------------------------------------
  // Account lifecycle
  // ---------------------------------------------------------------------------

  /// Called when a user logs in (or the app restores a session). Sets the
  /// phone-scoped namespace and loads ONLY that user's persisted files, then
  /// syncs from Telegram.
  Future<void> loadAccountFiles(String? phone) async {
    _currentPhone = phone;

    // Always start fresh for this account – never carry over another user's
    // in-memory state.
    state = const [];

    // Load from phone-specific cache only
    await _loadPersistedItemsForPhone(phone);

    // Sync from Telegram to pick up any files uploaded from other devices
    await syncFromTelegram(phone);
  }

  /// Called on pull-to-refresh or manual sync tap. Does NOT wipe state; instead
  /// merges Telegram cloud state into the existing in-memory items.
  Future<void> reloadPersistedItems([String? phone]) async {
    final effectivePhone = phone ?? _currentPhone;
    await syncFromTelegram(effectivePhone);
  }

  /// Called when the user logs out. Wipes in-memory state but does NOT touch
  /// the phone-specific persisted cache (so files survive re-login).
  Future<void> clearCache() async {
    _currentPhone = null;
    state = const [];
  }

  // ---------------------------------------------------------------------------
  // Persistence (phone-scoped)
  // ---------------------------------------------------------------------------

  /// Loads items from SharedPreferences using the phone-specific key ONLY.
  /// Never falls back to the generic key – that was the source of cross-account
  /// file leakage.
  Future<void> _loadPersistedItemsForPhone(String? phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedJsonStr;
      if (phone != null && phone.isNotEmpty) {
        savedJsonStr = prefs.getString("ubd_cached_vault_ledger_$phone");
      }
      // NOTE: We intentionally do NOT fall back to the generic key
      // "ubd_cached_vault_ledger" because that key is shared across all
      // accounts and causes cross-account file leakage.

      if (savedJsonStr != null && savedJsonStr.isNotEmpty) {
        final data = jsonDecode(savedJsonStr) as Map<String, dynamic>;
        final manifest = SecureVaultManifest.fromJson(data);
        if (manifest.items.isNotEmpty) {
          state = manifest.items;
        }
      }
    } catch (_) {}
  }

  /// Persists the current state to the phone-specific SharedPreferences key.
  Future<void> _persistLedgerCache([String? phone]) async {
    final effectivePhone = phone ?? _currentPhone;
    if (effectivePhone == null || effectivePhone.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final manifest = SecureVaultManifest(
        lastUpdated: DateTime.now(),
        channelId: -100982736412,
        items: state,
      );
      final jsonStr = jsonEncode(manifest.toJson());
      // Save ONLY under the phone-specific key
      await prefs.setString("ubd_cached_vault_ledger_$effectivePhone", jsonStr);
    } catch (_) {}
  }

  Future<void> _persistCurrentState(enc.Key masterKey, [String? phone]) async {
    final effectivePhone = phone ?? _currentPhone;
    try {
      await _persistLedgerCache(effectivePhone);
      final manifest = SecureVaultManifest(
        lastUpdated: DateTime.now(),
        channelId: -100982736412,
        items: state,
      );
      await EncryptedVaultStorage.persistLedger(
        ledgerJson: manifest.toJson(),
        masterKey: masterKey,
      );
    } catch (_) {
      // Non-blocking persistence
    }
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  /// Derives master key using hardware salt and Argon2id in a background isolate
  Future<enc.Key> _deriveMasterKey(String masterPassword) async {
    final hexSalt = await HardwareSecurityManager.getHardwareSalt();
    Uint8List salt;
    if (hexSalt != null && hexSalt.isNotEmpty) {
      salt = Uint8List.fromList([
        for (int i = 0; i < hexSalt.length; i += 2)
          int.parse(hexSalt.substring(i, i + 2), radix: 16)
      ]);
    } else {
      salt = ZeroKnowledgeCrypto.generateSecureSalt(32);
      await HardwareSecurityManager.storeHardwareSalt(salt);
    }

    final keyBytes = await IsolateCryptoWorker.deriveKeyArgon2id(
      passphrase: masterPassword,
      salt: salt,
      memoryCostKb: 16 * 1024,
      timeCost: 3,
    );

    return enc.Key(keyBytes);
  }

  /// Picks files from device storage, encrypts via isolate/web, and uploads with resumable chunking
  Future<void> pickAndUploadFiles({
    required String masterPassword,
    String? userPhone,
    String? targetFolderId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final masterKey = await _deriveMasterKey(masterPassword);

    for (final file in result.files) {
      Uint8List bytes = file.bytes ?? Uint8List(0);

      // On web/streaming or desktop if bytes were not directly attached:
      if (bytes.isEmpty && file.readStream != null) {
        try {
          final builder = BytesBuilder();
          await for (final chunk in file.readStream!) {
            builder.add(chunk);
          }
          bytes = builder.toBytes();
        } catch (_) {}
      }

      if (!kIsWeb && bytes.isEmpty && file.path != null) {
        try {
          bytes = io.File(file.path!).readAsBytesSync();
        } catch (_) {}
      }

      if (bytes.isEmpty) continue;

      final fileName = file.name;
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

      _uploadNotifier.startUpload(fileName: fileName, totalBytes: bytes.length);

      // Extract real video thumbnail if it's a video file
      Uint8List? thumbnailBytes;
      final isVideo = ['mp4', 'webm', 'mov', 'mkv', 'avi', 'm4v'].contains(ext);
      final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'].contains(ext);

      if (isVideo) {
        _uploadNotifier.updateProgress(
          progress: 0.15,
          bytesTransferred: 0,
          speed: "Generating...",
          stage: "🎬 Extracting Real Video Thumbnail...",
        );
        try {
          thumbnailBytes = await ThumbnailHelper.generateVideoThumbnail(bytes, ext, filePath: file.path);
        } catch (_) {}
      } else if (isImage) {
        thumbnailBytes = bytes;
      }

      final fileHash = await IsolateCryptoWorker.computeSha256Checksum(bytes);

      String? previewText;
      if (['txt', 'md', 'json', 'csv', 'dart', 'py', 'html', 'js', 'xml', 'log'].contains(ext) && bytes.isNotEmpty) {
        try {
          previewText = utf8.decode(bytes);
        } catch (_) {}
      }

      final uploadedItem = await _storageService.uploadFile(
        fileName: fileName,
        fileBytes: bytes,
        masterKey: masterKey,
        channelId: -100982736412,
        userPhone: userPhone,
        enableEncryption: true,
        onProgress: (progress, bytesUploaded, speed, stage) {
          _uploadNotifier.updateProgress(
            progress: progress,
            bytesTransferred: bytesUploaded,
            speed: speed,
            stage: stage,
          );
        },
      );

      final newItem = uploadedItem.copyWith(
        rawBytes: bytes,
        previewText: previewText,
        sha256Checksum: fileHash,
        parentFolderId: targetFolderId,
        thumbnailBytes: thumbnailBytes,
      );

      state = [newItem, ...state];
      _uploadNotifier.completeUpload();

      // Persist immediately under the current user's phone key
      await _persistCurrentState(masterKey, userPhone);
    }
  }

  /// Picks photos or videos from gallery and uploads with resumable chunking
  Future<void> pickAndUploadMedia({
    required String masterPassword,
    String? userPhone,
    String? targetFolderId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    Uint8List bytes = file.bytes ?? Uint8List(0);
    if (!kIsWeb && bytes.isEmpty && file.path != null) {
      try {
        bytes = io.File(file.path!).readAsBytesSync();
      } catch (_) {}
    }
    if (bytes.isEmpty) return;
    final fileName = file.name;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    _uploadNotifier.startUpload(fileName: fileName, totalBytes: bytes.length);

    Uint8List? thumbnailBytes;
    final isVideo = ['mp4', 'webm', 'mov', 'mkv', 'avi', 'm4v'].contains(ext);
    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'].contains(ext);

    if (isVideo) {
      try {
        thumbnailBytes = await ThumbnailHelper.generateVideoThumbnail(bytes, ext, filePath: file.path);
      } catch (_) {}
    } else if (isImage) {
      thumbnailBytes = bytes;
    }

    final fileHash = await IsolateCryptoWorker.computeSha256Checksum(bytes);
    final masterKey = await _deriveMasterKey(masterPassword);

    final uploadedItem = await _storageService.uploadFile(
      fileName: fileName,
      fileBytes: bytes,
      masterKey: masterKey,
      channelId: -100982736412,
      userPhone: userPhone,
      enableEncryption: true,
      onProgress: (progress, bytesUploaded, speed, stage) {
        _uploadNotifier.updateProgress(
          progress: progress,
          bytesTransferred: bytesUploaded,
          speed: speed,
          stage: stage,
        );
      },
    );

    final newItem = uploadedItem.copyWith(
      rawBytes: bytes,
      sha256Checksum: fileHash,
      parentFolderId: targetFolderId,
      thumbnailBytes: thumbnailBytes,
    );

    state = [newItem, ...state];
    _uploadNotifier.completeUpload();
    await _persistCurrentState(masterKey, userPhone);
  }

  // ---------------------------------------------------------------------------
  // Download
  // ---------------------------------------------------------------------------

  /// Downloads an item and verifies integrity
  Future<Uint8List> downloadItem(DriveItem item, {
    required String masterPassword,
    String? userPhone,
  }) async {
    if (item.rawBytes != null && item.rawBytes!.isNotEmpty) {
      return item.rawBytes!;
    }

    final masterKey = await _deriveMasterKey(masterPassword);
    return await _storageService.downloadFile(
      item: item,
      masterKey: masterKey,
      userPhone: userPhone,
    );
  }

  // ---------------------------------------------------------------------------
  // Folder / item management
  // ---------------------------------------------------------------------------

  /// Creates a new virtual folder
  void createFolder(String folderName, {String? parentFolderId}) {
    final newFolder = DriveItem(
      id: "folder_${DateTime.now().millisecondsSinceEpoch}",
      name: folderName.trim(),
      size: 0,
      extension: "",
      isFolder: true,
      uploadDate: DateTime.now(),
      parentFolderId: parentFolderId,
    );
    state = [newFolder, ...state];
    _persistLedgerCache();
  }

  /// Deletes an item from the drive
  void deleteItem(String id) {
    state = state.where((item) => item.id != id).toList();
    _persistLedgerCache();
  }

  /// Sets privacy for a file (PrivateOnly or PublicWithLink)
  void setPrivacy(String id, FilePrivacy privacy) {
    state = state.map((item) {
      if (item.id == id) {
        final isPublic = privacy == FilePrivacy.publicWithLink;
        final shareUrl = item.directShareUrl ?? "https://dl.unbounddrive.app/f/${item.id.replaceAll('file_', '')}";
        return item.copyWith(
          privacy: privacy,
          isLinkActive: isPublic,
          directShareUrl: shareUrl,
        );
      }
      return item;
    }).toList();
    _persistLedgerCache();
  }

  // ---------------------------------------------------------------------------
  // Telegram sync
  // ---------------------------------------------------------------------------

  /// Syncs files uploaded directly to Telegram Cloud channel/Saved Messages
  Future<void> syncFromTelegram([String? phone]) async {
    final effectivePhone = phone ?? _currentPhone;
    try {
      final queryParams = <String, String>{};
      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        queryParams["phone"] = effectivePhone;
      }
      final uri = Uri.parse("${NetworkConfig.driveUrl}/sync").replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final headers = <String, String>{};
      if (effectivePhone != null && effectivePhone.isNotEmpty) {
        headers["X-Phone"] = effectivePhone;
      }
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawItems = (data["items"] as List<dynamic>?) ?? [];
        final syncedItems = <DriveItem>[];
        for (final r in rawItems) {
          if (r is! Map<String, dynamic>) continue;
          final map = r;
          final rawChunks = (map["chunks"] as List<dynamic>?) ?? [];
          final parsedChunks = <ChunkRecord>[];
          for (final c in rawChunks) {
            try {
              if (c is Map<String, dynamic>) {
                parsedChunks.add(ChunkRecord.fromJson(c));
              }
            } catch (_) {}
          }
          final msgId = (map["telegramMessageId"] as num?)?.toInt() ??
              (map["telegram_message_id"] as num?)?.toInt();
          final size = (map["size"] as num?)?.toInt() ?? 0;

          if (parsedChunks.isEmpty && msgId != null) {
            parsedChunks.add(
              ChunkRecord(
                index: 0,
                telegramMessageId: msgId,
                sha256Hash: "tg_verified",
                byteLength: size,
              ),
            );
          }

          syncedItems.add(
            DriveItem(
              id: map["id"]?.toString() ?? "tg_file_$msgId",
              name: map["name"]?.toString() ?? "Telegram File",
              size: size,
              extension: map["extension"]?.toString() ?? "",
              isFolder: map["isFolder"] as bool? ?? false,
              isEncrypted: map["isEncrypted"] as bool? ?? true,
              uploadDate: DateTime.tryParse(map["uploadDate"]?.toString() ?? "") ?? DateTime.now(),
              telegramMessageId: msgId,
              directShareUrl: map["directShareUrl"]?.toString(),
              chunks: parsedChunks.isEmpty ? null : parsedChunks,
            ),
          );
        }
        if (syncedItems.isNotEmpty) {
          // Build map from current state, preserving in-memory rawBytes/thumbnails
          final existingMap = {for (var i in state) i.name: i};
          for (final item in syncedItems) {
            final existing = existingMap[item.name];
            if (existing != null) {
              // Keep the in-memory data (rawBytes, thumbnailBytes, previewText)
              existingMap[item.name] = existing.copyWith(
                size: item.size > 0 ? item.size : existing.size,
                telegramMessageId: item.telegramMessageId ?? existing.telegramMessageId,
                chunks: item.chunks ?? existing.chunks,
                directShareUrl: item.directShareUrl ?? existing.directShareUrl,
                uploadDate: item.uploadDate,
              );
            } else {
              existingMap[item.name] = item;
            }
          }
          state = existingMap.values.toList();
          await _persistLedgerCache(effectivePhone);
        }
      }
    } catch (_) {}
  }
}
