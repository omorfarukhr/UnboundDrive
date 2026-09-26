import 'package:flutter/material.dart';

class FileUtils {
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return "Just now";
        return "${diff.inMinutes}m ago";
      }
      return "${diff.inHours}h ago";
    } else if (diff.inDays < 7) {
      return "${diff.inDays}d ago";
    }
    return "${date.day}/${date.month}/${date.year}";
  }

  static IconData getFileIcon(String extension) {
    switch (extension.toLowerCase().replaceAll('.', '')) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
        return Icons.image_rounded;
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'avi':
        return Icons.videocam_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'm4a':
        return Icons.music_note_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
        return Icons.description_rounded;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
        return Icons.folder_zip_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color getFileColor(String extension) {
    switch (extension.toLowerCase().replaceAll('.', '')) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
        return Colors.cyan;
      case 'mp4':
      case 'mov':
      case 'mkv':
        return Colors.purpleAccent;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Colors.amber;
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
      case 'txt':
        return Colors.blueAccent;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.orangeAccent;
      default:
        return Colors.grey;
    }
  }
}
