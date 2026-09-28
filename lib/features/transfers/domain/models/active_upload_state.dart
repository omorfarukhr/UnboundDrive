class ActiveUploadState {
  final bool isUploading;
  final String fileName;
  final int totalBytes;
  final int bytesTransferred;
  final double progress; // 0.0 to 1.0
  final String speed; // e.g. "3.8 MB/s"
  final String stage; // e.g. "Encrypting AES-256-EtM...", "Streaming to Telegram...", "Complete"
  final String? error;
  final bool isSuccess;

  const ActiveUploadState({
    this.isUploading = false,
    this.fileName = "",
    this.totalBytes = 0,
    this.bytesTransferred = 0,
    this.progress = 0.0,
    this.speed = "0 KB/s",
    this.stage = "",
    this.error,
    this.isSuccess = false,
  });

  ActiveUploadState copyWith({
    bool? isUploading,
    String? fileName,
    int? totalBytes,
    int? bytesTransferred,
    double? progress,
    String? speed,
    String? stage,
    String? error,
    bool? isSuccess,
  }) {
    return ActiveUploadState(
      isUploading: isUploading ?? this.isUploading,
      fileName: fileName ?? this.fileName,
      totalBytes: totalBytes ?? this.totalBytes,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      stage: stage ?? this.stage,
      error: error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}
