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
import '../../../../core/constants/sample_vault_data.dart';
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

  DriveController(this._storageService, this._uploadNotifier)
      : super(SampleVaultData.getInitialRealDriveItems()) {
    _loadPersistedItems();
  }

  Future<void> reloadPersistedItems([String? phone]) async {
    await _loadPersistedItems(phone);
    await syncFromTelegram(phone);
  }

  Future<void> _loadPersistedItems([String? phone]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedJsonStr;
      if (phone != null && phone.isNotEmpty) {
        savedJsonStr = prefs.getString("ubd_cached_vault_ledger_$phone");
      }
      savedJsonStr ??= prefs.getString("ubd_cached_vault_ledger");

      if (savedJsonStr != null && savedJsonStr.isNotEmpty) {
        final data = jsonDecode(savedJsonStr) as Map<String, dynamic>;
        final manifest = SecureVaultManifest.fromJson(data);
        if (manifest.items.isNotEmpty) {
          state = manifest.items;
        }
      }
    } catch (_) {}
  }

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

      // Automatically persist to sandboxed encrypted vault ledger
      await _persistCurrentState(masterKey);
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
    await _persistCurrentState(masterKey);
  }

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

  Future<void> _persistLedgerCache([String? phone]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final manifest = SecureVaultManifest(
        lastUpdated: DateTime.now(),
        channelId: -100982736412,
        items: state,
      );
      final jsonStr = jsonEncode(manifest.toJson());
      await prefs.setString("ubd_cached_vault_ledger", jsonStr);
      if (phone != null && phone.isNotEmpty) {
        await prefs.setString("ubd_cached_vault_ledger_$phone", jsonStr);
      }
    } catch (_) {}
  }

  Future<void> clearCache() async {
    state = const [];
  }

  /// Syncs files uploaded directly to Telegram Cloud channel/Saved Messages
  Future<void> syncFromTelegram([String? phone]) async {
    try {
      final uri = Uri.parse("${NetworkConfig.driveUrl}/sync");
      final headers = <String, String>{};
      if (phone != null && phone.isNotEmpty) {
        headers["X-Phone"] = phone;
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
          final existingMap = {for (var i in state) i.name: i};
          for (final item in syncedItems) {
            existingMap[item.name] = item;
          }
          state = existingMap.values.toList();
          await _persistLedgerCache(phone);
        }
      }
    } catch (_) {}
  }

  Future<void> _persistCurrentState(enc.Key masterKey) async {
    try {
      await _persistLedgerCache();
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
}
