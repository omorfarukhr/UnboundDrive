import 'dart:typed_data';
import '../../../../core/transfers/resumable_transfer_manager.dart';

enum FilePrivacy {
  privateOnly,
  publicWithLink,
}

class DriveItem {
  final String id;
  final String name;
  final int size; // In bytes
  final String extension;
  final DateTime uploadDate;
  final bool isFolder;
  final bool isEncrypted;
  final int? telegramMessageId;
  final String? directShareUrl;
  final String? localCachedPath;
  final FilePrivacy privacy;
  final bool isLinkActive;
  final int downloadCount;
  final List<ChunkRecord>? chunks;
  final Uint8List? rawBytes;
  final String? previewText;
  final String? parentFolderId;
  final String? sha256Checksum;
  final Uint8List? thumbnailBytes;

  const DriveItem({
    required this.id,
    required this.name,
    required this.size,
    required this.extension,
    required this.uploadDate,
    this.isFolder = false,
    this.isEncrypted = false,
    this.telegramMessageId,
    this.directShareUrl,
    this.localCachedPath,
    this.privacy = FilePrivacy.privateOnly,
    this.isLinkActive = false,
    this.downloadCount = 0,
    this.chunks,
    this.rawBytes,
    this.previewText,
    this.parentFolderId,
    this.sha256Checksum,
    this.thumbnailBytes,
  });

  bool get isPublic => privacy == FilePrivacy.publicWithLink && isLinkActive;

  DriveItem copyWith({
    String? id,
    String? name,
    int? size,
    String? extension,
    DateTime? uploadDate,
    bool? isFolder,
    bool? isEncrypted,
    int? telegramMessageId,
    String? directShareUrl,
    String? localCachedPath,
    FilePrivacy? privacy,
    bool? isLinkActive,
    int? downloadCount,
    List<ChunkRecord>? chunks,
    Uint8List? rawBytes,
    String? previewText,
    String? parentFolderId,
    String? sha256Checksum,
    Uint8List? thumbnailBytes,
  }) {
    return DriveItem(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      extension: extension ?? this.extension,
      uploadDate: uploadDate ?? this.uploadDate,
      isFolder: isFolder ?? this.isFolder,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      telegramMessageId: telegramMessageId ?? this.telegramMessageId,
      directShareUrl: directShareUrl ?? this.directShareUrl,
      localCachedPath: localCachedPath ?? this.localCachedPath,
      privacy: privacy ?? this.privacy,
      isLinkActive: isLinkActive ?? this.isLinkActive,
      downloadCount: downloadCount ?? this.downloadCount,
      chunks: chunks ?? this.chunks,
      rawBytes: rawBytes ?? this.rawBytes,
      previewText: previewText ?? this.previewText,
      parentFolderId: parentFolderId ?? this.parentFolderId,
      sha256Checksum: sha256Checksum ?? this.sha256Checksum,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
    );
  }
}
