import 'dart:typed_data';

class FileChunk {
  final int index;
  final int totalChunks;
  final Uint8List bytes;
  final int size;

  const FileChunk({
    required this.index,
    required this.totalChunks,
    required this.bytes,
    required this.size,
  });
}

class FileChunker {
  /// Default chunk size: 500 MB (safely below Telegram's 2GB free user limit)
  static const int defaultChunkSize = 500 * 1024 * 1024;

  /// Splits a file into manageable binary chunks for parallel/resumable upload
  static List<FileChunk> chunkBytes(Uint8List fileBytes, [int chunkSize = defaultChunkSize]) {
    final totalBytes = fileBytes.length;
    if (totalBytes <= chunkSize) {
      return [
        FileChunk(
          index: 0,
          totalChunks: 1,
          bytes: fileBytes,
          size: totalBytes,
        ),
      ];
    }

    final totalChunks = (totalBytes / chunkSize).ceil();
    final chunks = <FileChunk>[];

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize > totalBytes) ? totalBytes : start + chunkSize;
      final subBytes = fileBytes.sublist(start, end);

      chunks.add(
        FileChunk(
          index: i,
          totalChunks: totalChunks,
          bytes: subBytes,
          size: subBytes.length,
        ),
      );
    }

    return chunks;
  }

  /// Reassembles decrypted chunks in sequential order into a single continuous file
  static Uint8List mergeChunks(List<Uint8List> decryptedChunks) {
    final builder = BytesBuilder(copy: false);
    for (final chunk in decryptedChunks) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  /// Calculates number of chunks required for a given file size
  static int calculateChunkCount(int totalBytes, [int chunkSize = defaultChunkSize]) {
    if (totalBytes <= 0) return 1;
    return (totalBytes / chunkSize).ceil();
  }
}
