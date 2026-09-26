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
  });

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
    );
  }
}
