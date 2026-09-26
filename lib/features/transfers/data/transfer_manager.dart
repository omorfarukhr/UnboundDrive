import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/transfer_item.dart';

final transferManagerProvider = StateNotifierProvider<TransferManager, List<TransferItem>>((ref) {
  return TransferManager();
});

class TransferManager extends StateNotifier<List<TransferItem>> {
  TransferManager() : super([]);

  void addTransfer(TransferItem item) {
    state = [item, ...state];
  }

  void updateProgress({
    required String id,
    required int bytesTransferred,
    required double progress,
    required String speed,
  }) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(
          bytesTransferred: bytesTransferred,
          progress: progress,
          speed: speed,
          status: progress >= 1.0 ? TransferStatus.completed : TransferStatus.inProgress,
        );
      }
      return item;
    }).toList();
  }

  void completeTransfer(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(
          progress: 1.0,
          status: TransferStatus.completed,
          speed: "Done",
        );
      }
      return item;
    }).toList();
  }

  void failTransfer(String id, String error) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(
          status: TransferStatus.failed,
          errorMessage: error,
          speed: "0 KB/s",
        );
      }
      return item;
    }).toList();
  }

  void clearCompleted() {
    state = state.where((item) => item.status != TransferStatus.completed).toList();
  }
}
