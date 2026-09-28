import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/file_utils.dart';
import '../../data/active_upload_notifier.dart';

class ActiveUploadHUD extends ConsumerWidget {
  const ActiveUploadHUD({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(activeUploadProvider);

    if (!uploadState.isUploading && !uploadState.isSuccess && uploadState.error == null) {
      return const SizedBox.shrink();
    }

    final isDone = uploadState.isSuccess;
    final isError = uploadState.error != null;
    final progressPct = (uploadState.progress * 100).toInt().clamp(0, 100);

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isError
                  ? Colors.redAccent.withValues(alpha: 0.6)
                  : isDone
                      ? Colors.greenAccent.withValues(alpha: 0.6)
                      : AppColors.primaryLight.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isError
                        ? Colors.redAccent
                        : isDone
                            ? Colors.greenAccent
                            : AppColors.primary)
                    .withValues(alpha: 0.25),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: Icon, File Name & Percentage / Close
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isError
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : isDone
                              ? Colors.green.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isError
                          ? Icons.error_outline_rounded
                          : isDone
                              ? Icons.check_circle_rounded
                              : Icons.cloud_upload_rounded,
                      color: isError
                          ? Colors.redAccent
                          : isDone
                              ? Colors.greenAccent
                              : AppColors.primaryLight,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uploadState.fileName.isNotEmpty
                              ? uploadState.fileName
                              : "Uploading File...",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          uploadState.stage,
                          style: TextStyle(
                            color: isError
                                ? Colors.redAccent.shade100
                                : isDone
                                    ? Colors.greenAccent
                                    : AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (uploadState.isUploading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "$progressPct%",
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref.read(activeUploadProvider.notifier).dismiss();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Animated Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: uploadState.progress > 0 ? uploadState.progress : null,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isError
                        ? Colors.redAccent
                        : isDone
                            ? Colors.greenAccent
                            : AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Metrics Row: Speed & Transferred MB
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, size: 14, color: Colors.amberAccent),
                      const SizedBox(width: 2),
                      Text(
                        uploadState.speed,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Text(
                      "${FileUtils.formatBytes(uploadState.bytesTransferred)} / ${FileUtils.formatBytes(uploadState.totalBytes)}",
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
