import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/models/drive_item.dart';

class FileCard extends StatelessWidget {
  final DriveItem item;
  final bool isGrid;
  final VoidCallback? onTap;
  final VoidCallback? onShareDirect;
  final VoidCallback? onDownload;

  const FileCard({
    super.key,
    required this.item,
    this.isGrid = true,
    this.onTap,
    this.onShareDirect,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final ext = item.extension.toLowerCase();
    final isImage = ["jpg", "jpeg", "png", "webp", "gif", "heic"].contains(ext);
    final hasRealImage = isImage && item.rawBytes != null && item.rawBytes!.isNotEmpty;

    if (isGrid) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isPublic
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.darkBorder,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.isFolder
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : FileUtils.getFileColor(item.extension).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.isFolder ? Icons.folder_rounded : FileUtils.getFileIcon(item.extension),
                      color: item.isFolder
                          ? AppColors.primaryLight
                          : FileUtils.getFileColor(item.extension),
                      size: 24,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                    color: AppColors.darkCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.darkBorder),
                    ),
                    onSelected: (value) {
                      if (value == 'preview') onTap?.call();
                      if (value == 'share') onShareDirect?.call();
                      if (value == 'download') onDownload?.call();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'preview',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_rounded, color: AppColors.primaryLight, size: 18),
                            SizedBox(width: 8),
                            Text("Open & Preview", style: TextStyle(color: AppColors.textLight)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(
                              item.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                              color: item.isPublic ? AppColors.success : AppColors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text("Share & Privacy", style: TextStyle(color: AppColors.textLight)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download_rounded, color: AppColors.textLight, size: 18),
                            SizedBox(width: 8),
                            Text("Download", style: TextStyle(color: AppColors.textLight)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              if (hasRealImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 52,
                    width: double.infinity,
                    color: Colors.black26,
                    child: Image.memory(
                      item.rawBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (hasRealImage) const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.isFolder ? "Folder" : FileUtils.formatBytes(item.size),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (item.isPublic)
                    const Icon(Icons.link_rounded, color: AppColors.success, size: 14)
                  else if (!item.isFolder)
                    const Icon(Icons.shield_rounded, color: AppColors.accent, size: 14),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // List View
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: item.isFolder
              ? AppColors.primary.withValues(alpha: 0.2)
              : FileUtils.getFileColor(item.extension).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          item.isFolder ? Icons.folder_rounded : FileUtils.getFileIcon(item.extension),
          color: item.isFolder ? AppColors.primaryLight : FileUtils.getFileColor(item.extension),
          size: 22,
        ),
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        item.isFolder ? "Folder" : "${FileUtils.formatBytes(item.size)} • ${FileUtils.formatDate(item.uploadDate)}",
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.isPublic)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.public_rounded, color: AppColors.success, size: 12),
                  SizedBox(width: 4),
                  Text("Public Link", style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, color: AppColors.accent, size: 12),
                  SizedBox(width: 4),
                  Text("Private", style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
            color: AppColors.darkCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.darkBorder),
            ),
            onSelected: (value) {
              if (value == 'preview') onTap?.call();
              if (value == 'share') onShareDirect?.call();
              if (value == 'download') onDownload?.call();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.visibility_rounded, color: AppColors.primaryLight, size: 18),
                    SizedBox(width: 8),
                    Text("Open & Preview", style: TextStyle(color: AppColors.textLight)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(
                      item.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                      color: item.isPublic ? AppColors.success : AppColors.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text("Share & Privacy", style: TextStyle(color: AppColors.textLight)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, color: AppColors.textLight, size: 18),
                    SizedBox(width: 8),
                    Text("Download", style: TextStyle(color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
