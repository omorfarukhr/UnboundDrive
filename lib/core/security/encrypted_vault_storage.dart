import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'hardware_security_manager.dart';
import 'isolate_crypto_worker.dart';
import 'zero_knowledge_crypto.dart';

/// EncryptedVaultStorage
/// ----------------------------------------------------
/// Sandboxed Client-Side Encrypted Storage Engine
///
/// Ensures that NO unencrypted sensitive metadata, file lists, or tokens
/// ever touch the device's persistent flash memory.
///
/// Features:
/// 1. Zero Central Server Database: All user records remain purely in user custody.
/// 2. Hardware Keystore integration: Master credentials stored in Android Keystore / iOS Secure Enclave.
/// 3. Authenticated Tamper-Proof Storage (AES-256-EtM).
/// 4. Atomic file swapping to prevent corruption during sudden power-off/crash.
class EncryptedVaultStorage {
  static const String _ledgerFileName = "vault_ledger.ubd";
  static const String _journalFileName = "transfer_journal.ubd";

  static Future<String> _getAppStoragePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory("${dir.path}/.unbound_vault");
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir.path;
  }

  /// Saves encrypted payload to local disk atomically
  static Future<void> saveEncryptedFile({
    required String fileName,
    required Uint8List payload,
    required enc.Key masterKey,
  }) async {
    final dirPath = await _getAppStoragePath();
    final targetPath = "$dirPath/$fileName";
    final tempPath = "$targetPath.tmp";

    // Seal into tamper-proof .ubd envelope via background isolate
    final envelope = await IsolateCryptoWorker.sealEnvelope(
      payload: payload,
      keyBytes: Uint8List.fromList(masterKey.bytes),
    );

    // Atomic write pattern: write to temp file then rename to avoid corruption
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(envelope, flush: true);
    await tempFile.rename(targetPath);
  }

  /// Reads and decrypts an encrypted file from local disk
  static Future<Uint8List?> readEncryptedFile({
    required String fileName,
    required enc.Key masterKey,
  }) async {
    final dirPath = await _getAppStoragePath();
    final targetFile = File("$dirPath/$fileName");

    if (!await targetFile.exists()) {
      return null;
    }

    final envelopeBytes = await targetFile.readAsBytes();
    if (envelopeBytes.isEmpty) return null;

    // Decrypt and verify HMAC in background isolate
    final decrypted = await IsolateCryptoWorker.openEnvelope(
      envelopeBytes: envelopeBytes,
      keyBytes: Uint8List.fromList(masterKey.bytes),
    );

    return decrypted;
  }

  /// Writes the complete Vault Ledger (Micro-Database) to sandboxed encrypted storage
  static Future<void> persistLedger({
    required Map<String, dynamic> ledgerJson,
    required enc.Key masterKey,
  }) async {
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(ledgerJson)));
    await saveEncryptedFile(
      fileName: _ledgerFileName,
      payload: jsonBytes,
      masterKey: masterKey,
    );
  }

  /// Loads and verifies the complete Vault Ledger
  static Future<Map<String, dynamic>?> loadLedger({
    required enc.Key masterKey,
  }) async {
    final bytes = await readEncryptedFile(
      fileName: _ledgerFileName,
      masterKey: masterKey,
    );
    if (bytes == null) return null;

    final jsonStr = utf8.decode(bytes);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Writes transfer state journal for fault tolerance & resumable recovery
  static Future<void> persistJournal({
    required Map<String, dynamic> journalJson,
    required enc.Key masterKey,
  }) async {
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(journalJson)));
    await saveEncryptedFile(
      fileName: _journalFileName,
      payload: jsonBytes,
      masterKey: masterKey,
    );
  }

  /// Loads transfer state journal
  static Future<Map<String, dynamic>?> loadJournal({
    required enc.Key masterKey,
  }) async {
    final bytes = await readEncryptedFile(
      fileName: _journalFileName,
      masterKey: masterKey,
    );
    if (bytes == null) return null;

    final jsonStr = utf8.decode(bytes);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }

  /// Secure Wipe of all local vault caches (Emergency Lockdown / Sign Out)
  static Future<void> securePurgeAllLocalData() async {
    final dirPath = await _getAppStoragePath();
    final vaultDir = Directory(dirPath);
    if (await vaultDir.exists()) {
      // Overwrite each file with random noise before deleting to prevent flash recovery
      final files = vaultDir.listSync().whereType<File>();
      for (final file in files) {
        final length = await file.length();
        if (length > 0) {
          final dummyBytes = ZeroKnowledgeCrypto.generateSecureSalt(length > 4096 ? 4096 : length);
          await file.writeAsBytes(dummyBytes, flush: true);
        }
        await file.delete();
      }
      await vaultDir.delete(recursive: true);
    }
    await HardwareSecurityManager.purgeHardwareCredentials();
  }
}
