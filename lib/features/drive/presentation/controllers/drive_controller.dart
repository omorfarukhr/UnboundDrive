import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/security/encrypted_vault_storage.dart';
import '../../../../core/security/hardware_security_manager.dart';
import '../../../../core/security/isolate_crypto_worker.dart';
import '../../../../core/security/secure_vault_manifest.dart';
import '../../../../core/security/zero_knowledge_crypto.dart';
import '../../../transfers/data/transfer_manager.dart';
import '../../data/vault_storage_service.dart';
import '../../domain/models/drive_item.dart';

final vaultStorageServiceProvider = Provider<VaultStorageService>((ref) {
  final transferManager = ref.watch(transferManagerProvider.notifier);
  return VaultStorageService(transferManager: transferManager);
});

final driveControllerProvider = StateNotifierProvider<DriveController, List<DriveItem>>((ref) {
  final service = ref.watch(vaultStorageServiceProvider);
  return DriveController(service);
});

class DriveController extends StateNotifier<List<DriveItem>> {
  final VaultStorageService _storageService;

  DriveController(this._storageService)
      : super([
          DriveItem(
            id: "1",
            name: "Camera Auto-Backup",
            size: 0,
            extension: "",
            isFolder: true,
            uploadDate: DateTime.now(),
          ),
          DriveItem(
            id: "2",
            name: "Work Documents",
            size: 0,
            extension: "",
            isFolder: true,
            uploadDate: DateTime.now(),
          ),
          DriveItem(
            id: "3",
            name: "Trip_to_California_4K.mp4",
            size: 1420000000,
            extension: "mp4",
            isEncrypted: true,
            uploadDate: DateTime.now(),
            privacy: FilePrivacy.publicWithLink,
            isLinkActive: true,
            directShareUrl: "https://dl.unbounddrive.app/f/ca4k99",
          ),
          DriveItem(
            id: "4",
            name: "Financial_Report_2026.pdf",
            size: 4500000,
            extension: "pdf",
            uploadDate: DateTime.now(),
            privacy: FilePrivacy.privateOnly,
            isLinkActive: false,
          ),
          DriveItem(
            id: "5",
            name: "Sunset_GrandCanyon.heic",
            size: 8900000,
            extension: "heic",
            uploadDate: DateTime.now(),
            privacy: FilePrivacy.publicWithLink,
            isLinkActive: true,
            directShareUrl: "https://dl.unbounddrive.app/f/sunset",
          ),
        ]);

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

  /// Picks files from device storage, encrypts via isolate, and uploads with resumable chunking
  Future<void> pickAndUploadFiles({
    required String masterPassword,
    String? userPhone,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final masterKey = await _deriveMasterKey(masterPassword);

    for (final file in result.files) {
      if (file.bytes == null && file.path == null) continue;

      final Uint8List bytes = file.bytes ?? Uint8List(0);
      final fileName = file.name;

      final newItem = await _storageService.uploadFile(
        fileName: fileName,
        fileBytes: bytes,
        masterKey: masterKey,
        channelId: -100982736412,
        userPhone: userPhone,
        enableEncryption: true,
      );

      state = [newItem, ...state];

      // Automatically persist to sandboxed encrypted vault ledger
      await _persistCurrentState(masterKey);
    }
  }

  /// Picks photos or videos from gallery and uploads with resumable chunking
  Future<void> pickAndUploadMedia({
    required String masterPassword,
    String? userPhone,
  }) async {
    final picker = ImagePicker();
    final media = await picker.pickImage(source: ImageSource.gallery);
    if (media == null) return;

    final bytes = await media.readAsBytes();
    final fileName = media.name;

    final masterKey = await _deriveMasterKey(masterPassword);

    final newItem = await _storageService.uploadFile(
      fileName: fileName,
      fileBytes: bytes,
      masterKey: masterKey,
      channelId: -100982736412,
      userPhone: userPhone,
      enableEncryption: true,
    );

    state = [newItem, ...state];
    await _persistCurrentState(masterKey);
  }

  /// Downloads an item and verifies integrity
  Future<Uint8List> downloadItem(DriveItem item, {
    required String masterPassword,
    String? userPhone,
  }) async {
    final masterKey = await _deriveMasterKey(masterPassword);
    return await _storageService.downloadFile(
      item: item,
      masterKey: masterKey,
      userPhone: userPhone,
    );
  }

  /// Creates a new virtual folder
  void createFolder(String folderName) {
    final newFolder = DriveItem(
      id: "folder_${DateTime.now().millisecondsSinceEpoch}",
      name: folderName.trim(),
      size: 0,
      extension: "",
      isFolder: true,
      uploadDate: DateTime.now(),
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
