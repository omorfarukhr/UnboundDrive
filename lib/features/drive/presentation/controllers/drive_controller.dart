import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/sample_vault_data.dart';
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
      : super(SampleVaultData.getInitialRealDriveItems());

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
          thumbnailBytes = await ThumbnailHelper.generateVideoThumbnail(bytes, ext);
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
    final picker = ImagePicker();
    final media = await picker.pickImage(source: ImageSource.gallery);
    if (media == null) return;

    final bytes = await media.readAsBytes();
    final fileName = media.name;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    _uploadNotifier.startUpload(fileName: fileName, totalBytes: bytes.length);

    Uint8List? thumbnailBytes;
    final isVideo = ['mp4', 'webm', 'mov', 'mkv', 'avi', 'm4v'].contains(ext);
    final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'].contains(ext);

    if (isVideo) {
      try {
        thumbnailBytes = await ThumbnailHelper.generateVideoThumbnail(bytes, ext);
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
  }

  /// Deletes an item from the drive
  void deleteItem(String id) {
    state = state.where((item) => item.id != id).toList();
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
  }

  Future<void> _persistCurrentState(enc.Key masterKey) async {
    try {
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
