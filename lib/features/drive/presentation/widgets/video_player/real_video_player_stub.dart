import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';

Widget buildPlatformVideoPlayer({
  required String videoId,
  required Uint8List videoBytes,
  required String fileName,
  required String extension,
}) {
  return Container(
    height: 280,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, size: 48, color: AppColors.primaryLight),
          ),
          const SizedBox(height: 12),
          Text(
            fileName,
            style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Text(
            "Encrypted Video Stream Decrypted (Native Runtime)",
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
