import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:unbounddrive/core/network/circuit_breaker.dart';
import 'package:unbounddrive/core/network/load_balanced_transfer_pool.dart';
import 'package:unbounddrive/core/security/isolate_crypto_worker.dart';
import 'package:unbounddrive/core/security/secure_vault_manifest.dart';
import 'package:unbounddrive/core/security/zero_knowledge_crypto.dart';
import 'package:unbounddrive/core/transfers/resumable_transfer_manager.dart';
import 'package:unbounddrive/features/drive/domain/models/drive_item.dart';

void main() {
  group('Security & Cryptography Engine Tests', () {
    test('Argon2id derivation produces 256-bit key', () async {
      final salt = ZeroKnowledgeCrypto.generateSecureSalt(32);
      expect(salt.length, equals(32));

      final keyBytes = await IsolateCryptoWorker.deriveKeyArgon2id(
        passphrase: "TopSecretPassword123!",
        salt: salt,
        memoryCostKb: 256, // small cost for fast test
        timeCost: 1,
      );

      expect(keyBytes.length, equals(32));
    });

    test('ZeroKnowledgeCrypto tamper detection rejects manipulated envelopes', () {
      final salt = ZeroKnowledgeCrypto.generateSecureSalt();
      final key = ZeroKnowledgeCrypto.deriveMasterKey(
        masterPassphrase: "MyVaultPassword!",
        salt: salt,
      );

      final originalData = utf8.encode("Sensitive User Document Confidential");
      final envelope = ZeroKnowledgeCrypto.sealEnvelope(
        payload: Uint8List.fromList(originalData),
        key: key,
      );

      expect(envelope.length, greaterThan(52));
      // First 4 bytes are magic 'UBD1'
      expect(utf8.decode(envelope.sublist(0, 4)), equals("UBD1"));

      // Decrypt authentic envelope -> should match original
      final decrypted = ZeroKnowledgeCrypto.openEnvelope(
        envelopeBytes: envelope,
        key: key,
      );
      expect(utf8.decode(decrypted), equals("Sensitive User Document Confidential"));

      // Tamper with 1 byte in the ciphertext
      final tampered = Uint8List.fromList(envelope);
      tampered[tampered.length - 1] ^= 0xFF;

      // Must throw SecurityException due to HMAC-SHA256 integrity check
      expect(
        () => ZeroKnowledgeCrypto.openEnvelope(envelopeBytes: tampered, key: key),
        throwsA(isA<SecurityException>()),
      );
    });

    test('SecureVaultManifest serializes and deserializes chunk records', () {
      final salt = ZeroKnowledgeCrypto.generateSecureSalt();
      final key = ZeroKnowledgeCrypto.deriveMasterKey(
        masterPassphrase: "VaultMasterKey123",
        salt: salt,
      );

      final originalManifest = SecureVaultManifest(
        lastUpdated: DateTime.now(),
        channelId: -1001234567,
        items: [
          DriveItem(
            id: "file_test_1",
            name: "database_backup.tar.gz",
            size: 104857600,
            extension: "gz",
            uploadDate: DateTime.now(),
            isEncrypted: true,
            chunks: const [
              ChunkRecord(index: 0, telegramMessageId: 101, sha256Hash: "hash_0", byteLength: 52428800),
              ChunkRecord(index: 1, telegramMessageId: 102, sha256Hash: "hash_1", byteLength: 52428800),
            ],
          )
        ],
      );

      final encryptedEnvelope = originalManifest.exportEncryptedManifest(key);
      expect(encryptedEnvelope.isNotEmpty, isTrue);

      final restored = SecureVaultManifest.importEncryptedManifest(
        envelopeBytes: encryptedEnvelope,
        masterKey: key,
      );

      expect(restored.items.length, equals(1));
      expect(restored.items.first.name, equals("database_backup.tar.gz"));
      expect(restored.items.first.chunks?.length, equals(2));
      expect(restored.items.first.chunks?.first.telegramMessageId, equals(101));
    });
  });

  group('Fault Tolerance & Circuit Breaker Tests', () {
    test('Circuit breaker trips to open after consecutive failures', () async {
      final breaker = CircuitBreaker(
        serviceName: "TestService",
        failureThreshold: 2,
        resetTimeout: const Duration(seconds: 1),
      );

      expect(breaker.state, equals(CircuitState.closed));

      // 1st failure
      try {
        await breaker.execute(() async => throw Exception("Network timeout"));
      } catch (_) {}
      expect(breaker.state, equals(CircuitState.closed));

      // 2nd failure -> trips open!
      try {
        await breaker.execute(() async => throw Exception("Connection refused"));
      } catch (_) {}
      expect(breaker.state, equals(CircuitState.open));

      // Next call fails fast without hitting network
      expect(
        () => breaker.execute(() async => "Should not run"),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('Circuit breaker parses Telegram FloodWait and applies backoff', () async {
      final breaker = CircuitBreaker(serviceName: "FloodWaitBreaker");

      try {
        await breaker.execute(() async {
          throw Exception("Telegram rate limit: Wait 5 seconds.");
        });
      } catch (_) {}

      expect(breaker.state, equals(CircuitState.open));
      expect(breaker.isOpen, isTrue);
    });
  });

  group('Scalability & Load Balancing Pool Tests', () {
    test('LoadBalancedTransferPool processes chunks with concurrency limit', () async {
      final pool = LoadBalancedTransferPool(maxConcurrentWorkers: 2, enableAdaptiveTuning: false);
      final dummyChunks = List<Uint8List>.generate(4, (i) => Uint8List.fromList([i]));

      int activeAtPeak = 0;
      int currentActive = 0;

      final results = await pool.processChunks<int>(
        chunks: dummyChunks,
        task: (index, data) async {
          currentActive++;
          if (currentActive > activeAtPeak) {
            activeAtPeak = currentActive;
          }
          await Future.delayed(const Duration(milliseconds: 30));
          currentActive--;
          return index * 10;
        },
      );

      expect(results, equals([0, 10, 20, 30]));
      expect(activeAtPeak, lessThanOrEqualTo(2));
    });

    test('TransferSessionJournal tracks progress accurately', () {
      final journal = TransferSessionJournal(
        transferId: "tx_1",
        fileName: "archive.zip",
        totalBytes: 1000,
        totalChunks: 2,
      );

      expect(journal.isComplete, isFalse);
      expect(journal.progress, equals(0.0));

      journal.completedChunks[0] = const ChunkRecord(
        index: 0,
        telegramMessageId: 50,
        sha256Hash: "hash0",
        byteLength: 500,
      );

      expect(journal.progress, equals(0.5));
      expect(journal.isComplete, isFalse);

      journal.completedChunks[1] = const ChunkRecord(
        index: 1,
        telegramMessageId: 51,
        sha256Hash: "hash1",
        byteLength: 500,
      );

      expect(journal.progress, equals(1.0));
      expect(journal.isComplete, isTrue);
    });

    test('SecureVaultManifest serializes all rich metadata (thumbnail, sha256, folder, preview)', () {
      final sampleThumb = Uint8List.fromList([1, 2, 3, 4, 5]);
      final item = DriveItem(
        id: "test_item_1",
        name: "document.pdf",
        size: 1024,
        extension: "pdf",
        uploadDate: DateTime(2026, 1, 1),
        parentFolderId: "folder_123",
        sha256Checksum: "abcd1234efgh",
        previewText: "Sample preview content",
        thumbnailBytes: sampleThumb,
      );

      final manifest = SecureVaultManifest(
        lastUpdated: DateTime(2026, 1, 1),
        channelId: -100123456789,
        items: [item],
      );

      final json = manifest.toJson();
      final restored = SecureVaultManifest.fromJson(json);

      expect(restored.items.length, equals(1));
      final rItem = restored.items.first;
      expect(rItem.id, equals("test_item_1"));
      expect(rItem.parentFolderId, equals("folder_123"));
      expect(rItem.sha256Checksum, equals("abcd1234efgh"));
      expect(rItem.previewText, equals("Sample preview content"));
      expect(rItem.thumbnailBytes, equals(sampleThumb));
    });
  });
}
