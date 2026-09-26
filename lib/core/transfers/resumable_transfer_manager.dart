import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import '../network/circuit_breaker.dart';
import '../network/load_balanced_transfer_pool.dart';
import '../security/encrypted_vault_storage.dart';
import '../security/isolate_crypto_worker.dart';

/// Metadata for an individual uploaded chunk
class ChunkRecord {
  final int index;
  final int telegramMessageId;
  final String sha256Hash;
  final int byteLength;

  const ChunkRecord({
    required this.index,
    required this.telegramMessageId,
    required this.sha256Hash,
    required this.byteLength,
  });

  Map<String, dynamic> toJson() => {
        "index": index,
        "telegramMessageId": telegramMessageId,
        "sha256Hash": sha256Hash,
        "byteLength": byteLength,
      };

  factory ChunkRecord.fromJson(Map<String, dynamic> json) => ChunkRecord(
        index: json["index"] as int,
        telegramMessageId: json["telegramMessageId"] as int,
        sha256Hash: json["sha256Hash"] as String,
        byteLength: json["byteLength"] as int,
      );
}

/// Journal tracking in-flight and completed transfers for instant resume
class TransferSessionJournal {
  final String transferId;
  final String fileName;
  final int totalBytes;
  final int totalChunks;
  final Map<int, ChunkRecord> completedChunks;

  TransferSessionJournal({
    required this.transferId,
    required this.fileName,
    required this.totalBytes,
    required this.totalChunks,
    Map<int, ChunkRecord>? completedChunks,
  }) : completedChunks = completedChunks ?? {};

  bool get isComplete => completedChunks.length == totalChunks;
  double get progress => totalChunks == 0 ? 0.0 : completedChunks.length / totalChunks;

  Map<String, dynamic> toJson() => {
        "transferId": transferId,
        "fileName": fileName,
        "totalBytes": totalBytes,
        "totalChunks": totalChunks,
        "completedChunks": completedChunks.map((k, v) => MapEntry(k.toString(), v.toJson())),
      };

  factory TransferSessionJournal.fromJson(Map<String, dynamic> json) {
    final rawChunks = (json["completedChunks"] as Map<String, dynamic>?) ?? {};
    final parsedChunks = <int, ChunkRecord>{};
    rawChunks.forEach((key, val) {
      final idx = int.tryParse(key);
      if (idx != null) {
        parsedChunks[idx] = ChunkRecord.fromJson(val as Map<String, dynamic>);
      }
    });

    return TransferSessionJournal(
      transferId: json["transferId"] as String,
      fileName: json["fileName"] as String,
      totalBytes: json["totalBytes"] as int,
      totalChunks: json["totalChunks"] as int,
      completedChunks: parsedChunks,
    );
  }
}

/// ResumableTransferManager
/// ----------------------------------------------------
/// Military-Grade Resilient File Transmission Controller
///
/// Features:
/// 1. Resumable Byte-Offset Architecture: Never restarts dropped transfers from 0%.
/// 2. Isolated Crypto: Background isolate encryption avoids UI lag.
/// 3. SHA-256 Per-Chunk Integrity Verification (Self-Healing).
/// 4. Integrated Circuit Breaker & Adaptive Load-Balanced Pool.
class ResumableTransferManager {
  final LoadBalancedTransferPool _pool;
  final CircuitBreaker _circuitBreaker;

  ResumableTransferManager({
    LoadBalancedTransferPool? pool,
    CircuitBreaker? circuitBreaker,
  })  : _circuitBreaker = circuitBreaker ?? CircuitBreaker(serviceName: "ResumableEngine"),
        _pool = pool ?? LoadBalancedTransferPool();

  /// Executes an upload with resumable state journaling and fault tolerance
  Future<List<ChunkRecord>> executeResumableUpload({
    required String transferId,
    required String fileName,
    required List<Uint8List> rawChunks,
    required enc.Key masterKey,
    required Future<int> Function(int chunkIndex, Uint8List encryptedData, String hash) uploadFn,
    void Function(double progress, int bytesUploaded, String speed)? onProgress,
  }) async {
    final totalChunks = rawChunks.length;
    final totalBytes = rawChunks.fold<int>(0, (sum, c) => sum + c.length);

    // 1. Recover existing transfer journal if previously interrupted
    TransferSessionJournal journal = TransferSessionJournal(
      transferId: transferId,
      fileName: fileName,
      totalBytes: totalBytes,
      totalChunks: totalChunks,
    );

    try {
      final savedJournalJson = await EncryptedVaultStorage.loadJournal(masterKey: masterKey);
      if (savedJournalJson != null && savedJournalJson["transferId"] == transferId) {
        journal = TransferSessionJournal.fromJson(savedJournalJson);
      }
    } catch (_) {
      // Clean fallback if journal missing
    }

    final keyBytes = Uint8List.fromList(masterKey.bytes);
    final stopwatch = Stopwatch()..start();

    // 2. Identify missing chunks that need to be processed
    final missingIndices = <int>[];
    for (int i = 0; i < totalChunks; i++) {
      if (!journal.completedChunks.containsKey(i)) {
        missingIndices.add(i);
      }
    }

    // 3. Process remaining chunks through the load-balanced worker pool
    final missingChunks = missingIndices.map((idx) => rawChunks[idx]).toList();

    await _pool.processChunks<void>(
      chunks: missingChunks,
      task: (slotIndex, chunkBytes) async {
        final originalIndex = missingIndices[slotIndex];

        // Background isolate: Calculate SHA-256 hash & encrypt chunk
        final hash = await IsolateCryptoWorker.computeSha256Checksum(chunkBytes);
        final encryptedChunk = await IsolateCryptoWorker.sealEnvelope(
          payload: chunkBytes,
          keyBytes: keyBytes,
        );

        // Upload chunk to Telegram via network callback
        final telegramMsgId = await _circuitBreaker.execute(() => uploadFn(
              originalIndex,
              encryptedChunk,
              hash,
            ));

        // Record chunk in journal
        final record = ChunkRecord(
          index: originalIndex,
          telegramMessageId: telegramMsgId,
          sha256Hash: hash,
          byteLength: chunkBytes.length,
        );

        journal.completedChunks[originalIndex] = record;

        // Persist journal state atomically to encrypted local storage
        await EncryptedVaultStorage.persistJournal(
          journalJson: journal.toJson(),
          masterKey: masterKey,
        );

        // Compute real-time upload speed and progress
        if (onProgress != null) {
          final completedBytes = journal.completedChunks.values.fold<int>(
            0,
            (sum, item) => sum + item.byteLength,
          );
          final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
          final speedMb = elapsedSec > 0 ? (completedBytes / (1024 * 1024)) / elapsedSec : 0.0;

          onProgress(
            journal.progress,
            completedBytes,
            "${speedMb.toStringAsFixed(1)} MB/s",
          );
        }
      },
    );

    // 4. Return ordered list of all chunks
    final result = <ChunkRecord>[];
    for (int i = 0; i < totalChunks; i++) {
      final chunk = journal.completedChunks[i];
      if (chunk == null) {
        throw StateError("Upload failed: Missing chunk index $i after completion.");
      }
      result.add(chunk);
    }

    return result;
  }

  /// Downloads chunks with self-healing verification: corrupt chunks are automatically re-fetched
  Future<Uint8List> executeResumableDownload({
    required List<ChunkRecord> chunkRecords,
    required enc.Key masterKey,
    required Future<Uint8List> Function(int messageId) downloadFn,
    void Function(double progress, String speed)? onProgress,
  }) async {
    final totalChunks = chunkRecords.length;
    final decryptedChunks = List<Uint8List?>.filled(totalChunks, null);
    final keyBytes = Uint8List.fromList(masterKey.bytes);
    final stopwatch = Stopwatch()..start();
    int completedCount = 0;

    // Parallel fetch with LoadBalancedTransferPool
    final dummyChunks = List<Uint8List>.generate(totalChunks, (_) => Uint8List(0));

    await _pool.processChunks<void>(
      chunks: dummyChunks,
      task: (index, _) async {
        final record = chunkRecords[index];
        int retries = 0;
        const maxRetries = 3;

        while (true) {
          try {
            // Fetch chunk from Telegram
            final encryptedBytes = await _circuitBreaker.execute(() => downloadFn(record.telegramMessageId));

            // Decrypt in background isolate
            final plaintext = await IsolateCryptoWorker.openEnvelope(
              envelopeBytes: encryptedBytes,
              keyBytes: keyBytes,
            );

            // Verify integrity checksum
            final calculatedHash = await IsolateCryptoWorker.computeSha256Checksum(plaintext);
            if (calculatedHash != record.sha256Hash) {
              throw StateError("Chunk $index checksum mismatch! Corrupted in transit.");
            }

            decryptedChunks[index] = plaintext;
            completedCount++;

            if (onProgress != null) {
              final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
              final speedMb = elapsedSec > 0 ? (completedCount * 2.0) / elapsedSec : 0.0;
              onProgress(completedCount / totalChunks, "${speedMb.toStringAsFixed(1)} MB/s");
            }
            break;
          } catch (e) {
            retries++;
            if (retries >= maxRetries) {
              rethrow;
            }
            await Future.delayed(CircuitBreaker.calculateExponentialBackoff(retries));
          }
        }
      },
    );

    // Reassemble full file
    final builder = BytesBuilder(copy: false);
    for (int i = 0; i < totalChunks; i++) {
      final chunk = decryptedChunks[i];
      if (chunk == null) {
        throw StateError("Download failed: Missing chunk index $i");
      }
      builder.add(chunk);
    }

    return builder.toBytes();
  }
}
