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
    );
  }
}
