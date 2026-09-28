import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/active_upload_state.dart';

final activeUploadProvider = StateNotifierProvider<ActiveUploadNotifier, ActiveUploadState>((ref) {
  return ActiveUploadNotifier();
});

class ActiveUploadNotifier extends StateNotifier<ActiveUploadState> {
  ActiveUploadNotifier() : super(const ActiveUploadState());

  void startUpload({required String fileName, required int totalBytes}) {
    state = ActiveUploadState(
      isUploading: true,
      fileName: fileName,
      totalBytes: totalBytes,
      bytesTransferred: 0,
      progress: 0.05,
      speed: "0 KB/s",
      stage: "🔐 Zero-Knowledge AES-256 Encryption...",
      isSuccess: false,
      error: null,
    );
  }

  void updateProgress({
    required double progress,
    required int bytesTransferred,
    required String speed,
    required String stage,
  }) {
    state = state.copyWith(
      isUploading: progress < 1.0,
      progress: progress.clamp(0.0, 1.0),
      bytesTransferred: bytesTransferred,
      speed: speed,
      stage: stage,
    );
  }

  void completeUpload() {
    state = state.copyWith(
      isUploading: false,
      progress: 1.0,
      bytesTransferred: state.totalBytes,
      speed: "Completed",
      stage: "✅ Secured in Telegram Cloud Vault!",
      isSuccess: true,
    );

    // Auto-dismiss success indicator after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (state.isSuccess) {
        state = const ActiveUploadState();
      }
    });
  }

  void failUpload(String errorMessage) {
    state = state.copyWith(
      isUploading: false,
      error: errorMessage,
      stage: "Upload Failed",
    );
  }

  void dismiss() {
    state = const ActiveUploadState();
  }
}
