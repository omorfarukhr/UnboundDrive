import 'dart:typed_data';
import 'package:flutter/services.dart';

const _channel = MethodChannel('app.unbounddrive/video_thumbnail');

Future<Uint8List?> generateVideoThumbnailPlatform(Uint8List videoBytes, String extension, {String? filePath}) async {
  try {
    final result = await _channel.invokeMethod<Uint8List>('getVideoThumbnail', {
      'filePath': filePath,
      'fileBytes': videoBytes.isNotEmpty ? videoBytes : null,
    });
    return result;
  } catch (_) {
    return null;
  }
}
