import 'dart:io';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class FileDownloadHelperImpl {
  static Future<void> downloadBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$fileName");
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }
}
