// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

class FileDownloadHelperImpl {
  static Future<void> downloadBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..style.display = "none";

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }
}
