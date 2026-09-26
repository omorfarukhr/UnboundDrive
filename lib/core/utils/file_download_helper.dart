import 'dart:typed_data';

import 'file_download_helper_io.dart'
    if (dart.library.html) 'file_download_helper_web.dart';

class FileDownloadHelper {
  /// Saves and triggers download of raw bytes to device or web browser
  static Future<void> downloadFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await FileDownloadHelperImpl.downloadBytes(
      bytes: bytes,
      fileName: fileName,
    );
  }
}
