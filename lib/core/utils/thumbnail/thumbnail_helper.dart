import 'dart:typed_data';

import 'thumbnail_helper_stub.dart'
    if (dart.library.html) 'thumbnail_helper_web.dart' as impl;

class ThumbnailHelper {
  /// Generates a real visual frame thumbnail from video binary bytes
  static Future<Uint8List?> generateVideoThumbnail(Uint8List videoBytes, String extension, {String? filePath}) async {
    return impl.generateVideoThumbnailPlatform(videoBytes, extension, filePath: filePath);
  }
}
