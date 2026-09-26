enum TransferType { upload, download }

enum TransferStatus { queued, inProgress, paused, completed, failed }

class TransferItem {
  final String id;
  final String fileName;
  final int totalBytes;
  final int bytesTransferred;
  final TransferType type;
  final TransferStatus status;
  final double progress;
  final String speed;
  final bool isEncrypted;
  final String? errorMessage;
  final DateTime createdAt;

  const TransferItem({
    required this.id,
    required this.fileName,
    required this.totalBytes,
    this.bytesTransferred = 0,
    required this.type,
    this.status = TransferStatus.queued,
    this.progress = 0.0,
    this.speed = "0 KB/s",
    this.isEncrypted = true,
    this.errorMessage,
    required this.createdAt,
  });

  TransferItem copyWith({
    String? id,
    String? fileName,
    int? totalBytes,
    int? bytesTransferred,
    TransferType? type,
    TransferStatus? status,
    double? progress,
    String? speed,
    bool? isEncrypted,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return TransferItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      type: type ?? this.type,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
