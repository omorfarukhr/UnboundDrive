import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/file_utils.dart';
import '../../data/transfer_manager.dart';
import '../../domain/models/transfer_item.dart';

class TransferCenterScreen extends ConsumerWidget {
  const TransferCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transferManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Transfer Center",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (transfers.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(transferManagerProvider.notifier).clearCompleted(),
              child: const Text("Clear Done", style: TextStyle(color: AppColors.accent)),
            ),
        ],
      ),
      body: transfers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.swap_vert_circle_outlined,
                      size: 64,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No Active Transfers",
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Uploads and downloads will show their progress and speed here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: transfers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = transfers[index];
                return _buildTransferCard(item);
              },
            ),
    );
  }

  Widget _buildTransferCard(TransferItem item) {
    final isUpload = item.type == TransferType.upload;
    final isDone = item.status == TransferStatus.completed;
    final isFailed = item.status == TransferStatus.failed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isUpload
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUpload ? Icons.upload_rounded : Icons.download_rounded,
                  color: isUpload ? AppColors.primaryLight : AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "${FileUtils.formatBytes(item.bytesTransferred)} / ${FileUtils.formatBytes(item.totalBytes)}",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        if (item.isEncrypted) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock_rounded, size: 12, color: AppColors.accent),
                          const Text(" Encrypted", style: TextStyle(color: AppColors.accent, fontSize: 10)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isDone)
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24)
              else if (isFailed)
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 24)
              else
                Text(
                  item.speed,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF334155),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone
                    ? AppColors.success
                    : isFailed
                        ? AppColors.error
                        : AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
