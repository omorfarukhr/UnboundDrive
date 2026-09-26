import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
            directShareUrl: "https://dl.unbounddrive.app/f/ca4k99",
          ),
          DriveItem(
            id: "4",
            name: "Financial_Report_2026.pdf",
            size: 4500000,
            extension: "pdf",
            uploadDate: DateTime.now(),
            directShareUrl: "https://dl.unbounddrive.app/f/fin2026",
          ),
          DriveItem(
            id: "5",
            name: "Sunset_GrandCanyon.heic",
            size: 8900000,
            extension: "heic",
            uploadDate: DateTime.now(),
            directShareUrl: "https://dl.unbounddrive.app/f/sunset",
          ),
        ]);

  /// Picks files from device storage and encrypts & uploads them
  Future<void> pickAndUploadFiles({required String masterPassword}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    // Derive user's 256-bit AES master key
    final salt = ZeroKnowledgeCrypto.generateSecureSalt();
    final masterKey = ZeroKnowledgeCrypto.deriveMasterKey(
      masterPassphrase: masterPassword,
      salt: salt,
    );

    for (final file in result.files) {
      if (file.bytes == null && file.path == null) continue;
      
      final Uint8List bytes = file.bytes ?? Uint8List(0);
      final fileName = file.name;

      final newItem = await _storageService.uploadFile(
        fileName: fileName,
        fileBytes: bytes,
        masterKey: masterKey,
        channelId: -100982736412,
        enableEncryption: true,
      );

      state = [newItem, ...state];
    }
  }

  /// Picks photos or videos from camera/gallery and uploads
  Future<void> pickAndUploadMedia({required String masterPassword}) async {
    final picker = ImagePicker();
    final media = await picker.pickImage(source: ImageSource.gallery);
    if (media == null) return;

    final bytes = await media.readAsBytes();
    final fileName = media.name;

    final salt = ZeroKnowledgeCrypto.generateSecureSalt();
    final masterKey = ZeroKnowledgeCrypto.deriveMasterKey(
      masterPassphrase: masterPassword,
      salt: salt,
    );

    final newItem = await _storageService.uploadFile(
      fileName: fileName,
      fileBytes: bytes,
      masterKey: masterKey,
      channelId: -100982736412,
      enableEncryption: true,
    );

    state = [newItem, ...state];
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
}
