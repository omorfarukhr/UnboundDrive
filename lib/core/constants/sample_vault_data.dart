import 'dart:convert';
import 'dart:typed_data';
import '../../features/drive/domain/models/drive_item.dart';
import 'sample_thumbnail.dart';

class SampleVaultData {
  static const String _kLogoBase64 = "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";

  /// Real high-entropy byte buffer representing UnboundDrive brand badge
  static Uint8List get sampleImageBytes {
    try {
      final clean = _kLogoBase64.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(clean);
    } catch (_) {
      return Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x60, 0x60, 0x00,
        0x00, 0x00, 0x04, 0x00, 0x01, 0x27, 0x34, 0x27, 0x0A, 0x00, 0x00, 0x00,
        0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
    }
  }

  static const String sampleWhitepaperText = """# UnboundDrive Security Whitepaper (v2.4)
Date: September 2026
Classification: Public Specification

1. Zero-Central-Database Architecture
Unlike Google Drive or AWS S3, UnboundDrive maintains ZERO central databases.
Every folder structure, filename, and chunk reference exists exclusively inside
an encrypted client-side ledger (vault_ledger.ubd).

2. Key Derivation Function (RFC 9106 Argon2id)
- Memory Cost: 64 MB RAM matrix
- Time Cost: 3 iterations
- Parallelism: 4 threads
- Output: 256-bit AES master key

3. Envelope Encryption (Encrypt-then-MAC)
Every chunk is sealed with:
1. CSPRNG 16-byte IV
2. AES-256 PKCS7 Ciphertext
3. HMAC-SHA256 authenticated signature over IV + Ciphertext

4. Hardware Security
- Android: Titan M / Knox TEE Keystore
- iOS: Apple Secure Enclave Keychain
- Memory Zeroization: Immediate RAM sanitization on cleanup.

No data leaks. No central honeypot. Total privacy.""";

  static const String sampleManifestJson = """{
  "system": "UnboundDrive Decentralized Shard Core",
  "version": "2.4.0",
  "cipher": "AES-256-GCM / EtM",
  "kdf": "Argon2id-RFC9106",
  "datacenters": ["DC1-MIA", "DC2-AMS", "DC3-MIA", "DC4-AMS", "DC5-SIN"],
  "concurrency_limit": 8,
  "max_chunk_size_mb": 2,
  "resumable_journal_status": "ACTIVE",
  "integrity_algorithm": "SHA-256",
  "tamper_detection": true
}""";

  /// Returns real, fully interactive files ready for preview and downloading
  static List<DriveItem> getInitialRealDriveItems() {
    final imageBytes = sampleImageBytes;
    final whitepaperBytes = Uint8List.fromList(utf8.encode(sampleWhitepaperText));
    final manifestBytes = Uint8List.fromList(utf8.encode(sampleManifestJson));

    return [
      DriveItem(
        id: "folder_camera",
        name: "Camera Auto-Backup",
        size: 0,
        extension: "",
        isFolder: true,
        uploadDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      DriveItem(
        id: "folder_work",
        name: "Work Documents",
        size: 0,
        extension: "",
        isFolder: true,
        uploadDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      DriveItem(
        id: "real_img_1",
        name: "Unbound_Brand_Artwork.png",
        size: imageBytes.length,
        extension: "png",
        uploadDate: DateTime.now().subtract(const Duration(hours: 3)),
        isEncrypted: true,
        privacy: FilePrivacy.publicWithLink,
        isLinkActive: true,
        directShareUrl: "https://dl.unbounddrive.app/f/badge192",
        rawBytes: imageBytes,
        sha256Checksum: "9b3c4f7281d4a0e98c76fa1234567890abcdef1234567890abcdef1234567890",
      ),
      DriveItem(
        id: "real_doc_1",
        name: "Vault_Security_Whitepaper.md",
        size: whitepaperBytes.length,
        extension: "md",
        uploadDate: DateTime.now().subtract(const Duration(hours: 6)),
        isEncrypted: true,
        privacy: FilePrivacy.privateOnly,
        isLinkActive: false,
        rawBytes: whitepaperBytes,
        previewText: sampleWhitepaperText,
        sha256Checksum: "4f7a2b91c830e4d7a28b19c402e84d728194bfa2018c72839401827461930284",
      ),
      DriveItem(
        id: "real_json_1",
        name: "System_Manifest_v1.json",
        size: manifestBytes.length,
        extension: "json",
        uploadDate: DateTime.now().subtract(const Duration(hours: 12)),
        isEncrypted: true,
        privacy: FilePrivacy.privateOnly,
        isLinkActive: false,
        rawBytes: manifestBytes,
        previewText: sampleManifestJson,
        sha256Checksum: "c183920194857261948572019485729184758291048572910485720194857201",
      ),
      DriveItem(
        id: "real_video_1",
        name: "MEDIANOVIX_Logo_Reveal_4K.mp4",
        size: 4201241,
        extension: "mp4",
        uploadDate: DateTime.now().subtract(const Duration(days: 3)),
        isEncrypted: true,
        privacy: FilePrivacy.publicWithLink,
        isLinkActive: true,
        directShareUrl: "https://dl.unbounddrive.app/f/demo_reveal",
        thumbnailBytes: SampleThumbnail.bytes,
        sha256Checksum: "d837492019485720194857291847582910485729104857201948572019485720",
      ),
    ];
  }
}
