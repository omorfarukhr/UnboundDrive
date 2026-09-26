import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/models/drive_item.dart';

class SharePrivacyDialog extends StatefulWidget {
  final DriveItem item;
  final Function(FilePrivacy privacy) onPrivacyChanged;

  const SharePrivacyDialog({
    super.key,
    required this.item,
    required this.onPrivacyChanged,
  });

  @override
  State<SharePrivacyDialog> createState() => _SharePrivacyDialogState();
}

class _SharePrivacyDialogState extends State<SharePrivacyDialog> {
  late FilePrivacy _currentPrivacy;

  @override
  void initState() {
    super.initState();
    _currentPrivacy = widget.item.privacy;
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = _currentPrivacy == FilePrivacy.publicWithLink;
    final shareUrl = widget.item.directShareUrl ?? "https://dl.unbounddrive.app/f/${widget.item.id.replaceAll('file_', '')}";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // File Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FileUtils.getFileColor(widget.item.extension).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.item.isFolder ? Icons.folder_rounded : FileUtils.getFileIcon(widget.item.extension),
                  color: FileUtils.getFileColor(widget.item.extension),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      FileUtils.formatBytes(widget.item.size),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            "GENERAL ACCESS & PRIVACY",
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Option 1: Private (Only You)
          InkWell(
            onTap: () {
              setState(() => _currentPrivacy = FilePrivacy.privateOnly);
              widget.onPrivacyChanged(FilePrivacy.privateOnly);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !isPublic ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !isPublic ? AppColors.primary : AppColors.darkBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Restricted / Private (Only You)",
                          style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Only you can access this file in your vault. All public links are disabled.",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: !isPublic ? AppColors.accent : AppColors.textMuted,
                        width: 2,
                      ),
                    ),
                    child: !isPublic
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Option 2: Anyone with the link (Public)
          InkWell(
            onTap: () {
              setState(() => _currentPrivacy = FilePrivacy.publicWithLink);
              widget.onPrivacyChanged(FilePrivacy.publicWithLink);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPublic ? AppColors.success.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPublic ? AppColors.success : AppColors.darkBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.public_rounded, color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Anyone with the link (Public)",
                          style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Anyone with the link can 1-click download via Chrome or IDM without login.",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPublic ? AppColors.success : AppColors.textMuted,
                        width: 2,
                      ),
                    ),
                    child: isPublic
                        ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // Link Display & Copy Button (When Public)
          if (isPublic) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shareUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.accent, size: 20),
                    tooltip: "Copy Link",
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Public link copied to clipboard!")),
                      );
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.accent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "This file is 100% private. Only your authenticated session can decrypt it.",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Done", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
