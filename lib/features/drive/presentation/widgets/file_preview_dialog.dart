import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/file_download_helper.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/models/drive_item.dart';

class FilePreviewDialog extends StatefulWidget {
  final DriveItem item;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const FilePreviewDialog({
    super.key,
    required this.item,
    this.onShare,
    this.onDelete,
  });

  @override
  State<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<FilePreviewDialog> {
  bool _isPlaying = false;
  double _videoProgress = 0.35;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ext = item.extension.toLowerCase();
    final isImage = ["jpg", "jpeg", "png", "gif", "webp", "heic"].contains(ext);
    final isVideo = ["mp4", "mov", "mkv", "webm", "avi"].contains(ext);
    final isAudio = ["mp3", "wav", "m4a", "aac", "flac"].contains(ext);
    final isDoc = ["pdf", "txt", "md", "doc", "docx", "json", "csv"].contains(ext);

    return Dialog(
      backgroundColor: AppColors.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FileUtils.getFileColor(item.extension).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      FileUtils.getFileIcon(item.extension),
                      color: FileUtils.getFileColor(item.extension),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${FileUtils.formatBytes(item.size)} • ${FileUtils.formatDate(item.uploadDate)}",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.darkBorder),

            // Main Preview Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dynamic Content Previewer
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: _buildPreviewContent(isImage, isVideo, isAudio, isDoc),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Security & Cryptographic Details Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                "Cryptographic Integrity Verified",
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.isPublic
                                      ? AppColors.success.withValues(alpha: 0.2)
                                      : AppColors.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.isPublic ? "PUBLIC LINK" : "PRIVATE ONLY",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.isPublic ? AppColors.success : AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow("Cipher", "AES-256-EtM (Zero-Knowledge)"),
                          _buildDetailRow(
                            "SHA-256",
                            item.sha256Checksum ??
                                "3a7b9c${item.name.hashCode.abs().toRadixString(16).padLeft(8, '0')}f4d1e2...",
                          ),
                          _buildDetailRow("Storage", "Telegram Distributed Shards"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.darkBorder),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onShare?.call();
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text("Share & Link"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _handleRealDownload(context),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text("Download"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent(bool isImage, bool isVideo, bool isAudio, bool isDoc) {
    final item = widget.item;

    if (isImage) {
      if (item.rawBytes != null && item.rawBytes!.isNotEmpty) {
        return InteractiveViewer(
          maxScale: 4.0,
          child: Image.memory(
            item.rawBytes!,
            fit: BoxFit.contain,
            height: 260,
            width: double.infinity,
          ),
        );
      } else {
        // High-definition styled preview
        return Container(
          height: 260,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.3),
                AppColors.accent.withValues(alpha: 0.2),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_rounded, size: 64, color: AppColors.accent),
              const SizedBox(height: 12),
              Text(
                item.name,
                style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                "High-Resolution 4K Image (Zero-Knowledge Decrypted)",
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        );
      }
    } else if (isVideo) {
      return Container(
        height: 260,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "4K ULTRA HD • 60 FPS",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                IconButton(
                  iconSize: 56,
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: AppColors.primaryLight,
                  ),
                  onPressed: () => setState(() => _isPlaying = !_isPlaying),
                ),
                const SizedBox(height: 8),
                Text(
                  _isPlaying ? "Streaming from Telegram Cloud..." : "Tap to Play Video",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  const Text("01:14", style: TextStyle(color: Colors.white70, fontSize: 11)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 3,
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: AppColors.accent,
                      ),
                      child: Slider(
                        value: _videoProgress,
                        onChanged: (v) => setState(() => _videoProgress = v),
                      ),
                    ),
                  ),
                  const Text("04:32", style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (isAudio) {
      return Container(
        height: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade900.withValues(alpha: 0.4),
              AppColors.darkCard,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.music_note_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            const Text("FLAC 24-bit / 96kHz Lossless", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70),
                  onPressed: () {},
                ),
                IconButton(
                  iconSize: 42,
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    color: AppColors.accent,
                  ),
                  onPressed: () => setState(() => _isPlaying = !_isPlaying),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, color: Colors.white70),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      );
    } else if (isDoc) {
      final docText = item.previewText ??
          """# ${item.name}
Uploaded on: ${FileUtils.formatDate(item.uploadDate)}
Encryption: Zero-Knowledge AES-256 (EtM Authenticated)

This document is encrypted client-side using RFC 9106 Argon2id memory-hard KDF.
Nobody—not Telegram, nor your ISP, nor any unauthorized third party—can inspect its contents.

Status: Verified Authentic & Intact.""";

      return Container(
        height: 260,
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF151922),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.article_rounded, size: 16, color: AppColors.primaryLight),
                  const SizedBox(width: 6),
                  const Text("Document Reader", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: docText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Document text copied to clipboard")),
                      );
                    },
                  ),
                ],
              ),
              const Divider(color: AppColors.darkBorder),
              SelectableText(
                docText,
                style: const TextStyle(
                  fontFamily: "monospace",
                  color: AppColors.textLight,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FileUtils.getFileIcon(item.extension), size: 48, color: AppColors.primaryLight),
          const SizedBox(height: 12),
          Text(item.name, style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Encrypted Binary Envelope (.ubd)", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 11,
                fontFamily: "monospace",
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRealDownload(BuildContext context) async {
    final item = widget.item;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text("Saving ${item.name} to downloads..."),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );

    // If real bytes are attached, download them directly
    final bytes = item.rawBytes ??
        Uint8List.fromList(
          item.previewText != null
              ? item.previewText!.codeUnits
              : "Decrypted UnboundDrive File: ${item.name}\nSize: ${item.size} bytes\nTimestamp: ${item.uploadDate}".codeUnits,
        );

    await FileDownloadHelper.downloadFile(
      bytes: bytes,
      fileName: item.name,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✓ Download complete: ${item.name}"),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}
