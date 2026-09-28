import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import '../../features/drive/domain/models/drive_item.dart';
import '../transfers/resumable_transfer_manager.dart';
import 'zero_knowledge_crypto.dart';

/// SecureVaultManifest
/// ----------------------------------------------------
/// Zero-Central-Database Architecture
///
/// Principle: "Don't Store What You Cannot Protect"
/// There is NO central server database storing user files, folder trees, or filenames.
///
/// The entire state of the drive is compiled into an Encrypted Vault Manifest (.ubd)
/// which is stored exclusively on the user's device (Sandboxed) and mirrored in
/// the user's private Telegram channel.
class SecureVaultManifest {
  final int version;
  final DateTime lastUpdated;
  final int channelId;
  final List<DriveItem> items;

  const SecureVaultManifest({
    this.version = 1,
    required this.lastUpdated,
    required this.channelId,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        "version": version,
        "lastUpdated": lastUpdated.toIso8601String(),
        "channelId": channelId,
        "items": items.map((i) => {
              "id": i.id,
              "name": i.name,
              "size": i.size,
              "extension": i.extension,
              "uploadDate": i.uploadDate.toIso8601String(),
              "isFolder": i.isFolder,
              "isEncrypted": i.isEncrypted,
              "telegramMessageId": i.telegramMessageId,
              "directShareUrl": i.directShareUrl,
              "privacy": i.privacy.name,
              "isLinkActive": i.isLinkActive,
              "downloadCount": i.downloadCount,
              "parentFolderId": i.parentFolderId,
              "sha256Checksum": i.sha256Checksum,
              "previewText": i.previewText,
              "thumbnailBase64": i.thumbnailBytes != null ? base64Encode(i.thumbnailBytes!) : null,
              "chunks": i.chunks?.map((c) => c.toJson()).toList(),
            }).toList(),
      };

  factory SecureVaultManifest.fromJson(Map<String, dynamic> data) {
    final itemsRaw = (data["items"] as List<dynamic>?) ?? [];
    final parsedItems = itemsRaw.map((m) {
      final map = m as Map<String, dynamic>;
      final privacyStr = map["privacy"] as String? ?? "privateOnly";
      final privacy = privacyStr == "publicWithLink"
          ? FilePrivacy.publicWithLink
          : FilePrivacy.privateOnly;

      final chunksRaw = (map["chunks"] as List<dynamic>?) ?? [];
      final parsedChunks = chunksRaw.map((c) => ChunkRecord.fromJson(c as Map<String, dynamic>)).toList();
      final thumbB64 = map["thumbnailBase64"] as String?;

      return DriveItem(
        id: map["id"] as String,
        name: map["name"] as String,
        size: map["size"] as int,
        extension: map["extension"] as String,
        uploadDate: DateTime.parse(map["uploadDate"] as String),
        isFolder: map["isFolder"] as bool? ?? false,
        isEncrypted: map["isEncrypted"] as bool? ?? true,
        telegramMessageId: map["telegramMessageId"] as int?,
        directShareUrl: map["directShareUrl"] as String?,
        privacy: privacy,
        isLinkActive: map["isLinkActive"] as bool? ?? false,
        downloadCount: map["downloadCount"] as int? ?? 0,
        parentFolderId: map["parentFolderId"] as String?,
        sha256Checksum: map["sha256Checksum"] as String?,
        previewText: map["previewText"] as String?,
        thumbnailBytes: thumbB64 != null ? base64Decode(thumbB64) : null,
        chunks: parsedChunks.isEmpty ? null : parsedChunks,
      );
    }).toList();

    return SecureVaultManifest(
      version: data["version"] as int? ?? 1,
      lastUpdated: DateTime.parse(data["lastUpdated"] as String),
      channelId: data["channelId"] as int,
      items: parsedItems,
    );
  }

  /// Serializes the entire vault ledger into an encrypted binary envelope (.ubd)
  Uint8List exportEncryptedManifest(enc.Key masterKey) {
    final rawJson = jsonEncode(toJson());
    final rawBytes = Uint8List.fromList(utf8.encode(rawJson));
    return ZeroKnowledgeCrypto.sealEnvelope(payload: rawBytes, key: masterKey);
  }

  /// Deserializes and verifies an encrypted manifest envelope
  static SecureVaultManifest importEncryptedManifest({
    required Uint8List envelopeBytes,
    required enc.Key masterKey,
  }) {
    final decryptedBytes = ZeroKnowledgeCrypto.openEnvelope(
      envelopeBytes: envelopeBytes,
      key: masterKey,
    );

    final rawJson = utf8.decode(decryptedBytes);
    final data = jsonDecode(rawJson) as Map<String, dynamic>;
    return SecureVaultManifest.fromJson(data);
  }
}
