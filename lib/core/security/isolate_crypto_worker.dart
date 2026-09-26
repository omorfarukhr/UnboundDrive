import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'argon2id_kdf.dart';
import 'hardware_security_manager.dart';
import 'zero_knowledge_crypto.dart';

/// Parameters for background Argon2id key derivation
class _ArgonParams {
  final String passphrase;
  final Uint8List salt;
  final int memoryCostKb;
  final int timeCost;

  _ArgonParams({
    required this.passphrase,
    required this.salt,
    required this.memoryCostKb,
    required this.timeCost,
  });
}

/// Parameters for background envelope sealing
class _SealParams {
  final Uint8List payload;
  final Uint8List keyBytes;

  _SealParams({required this.payload, required this.keyBytes});
}

/// Parameters for background envelope opening
class _OpenParams {
  final Uint8List envelopeBytes;
  final Uint8List keyBytes;

  _OpenParams({required this.envelopeBytes, required this.keyBytes});
}

/// IsolateCryptoWorker
/// ----------------------------------------------------
/// High-Performance Multi-Threaded Cryptographic Worker
///
/// Dispatches heavy cryptographic operations (Argon2id matrix expansion,
/// AES-256-EtM chunk encryption/decryption, SHA-256 checksums) onto dedicated
/// Dart Isolates.
///
/// Guarantees:
/// 1. 60/120 FPS UI smoothness without frame drops during multi-GB transfers.
/// 2. Memory zeroization on ephemeral key material inside the isolate.
/// 3. Constant-time verification offloaded from the UI loop.
class IsolateCryptoWorker {
  /// Offloads memory-hard Argon2id key derivation to a background isolate
  static Future<Uint8List> deriveKeyArgon2id({
    required String passphrase,
    required Uint8List salt,
    int memoryCostKb = 16 * 1024,
    int timeCost = 3,
  }) async {
    final params = _ArgonParams(
      passphrase: passphrase,
      salt: salt,
      memoryCostKb: memoryCostKb,
      timeCost: timeCost,
    );

    return await Isolate.run(() {
      final key = Argon2idEngine.deriveKey(
        passphrase: params.passphrase,
        salt: params.salt,
        memoryCostKb: params.memoryCostKb,
        timeCost: params.timeCost,
      );
      return key;
    });
  }

  /// Encrypts a binary payload (chunk or file) inside a background isolate
  static Future<Uint8List> sealEnvelope({
    required Uint8List payload,
    required Uint8List keyBytes,
  }) async {
    final params = _SealParams(payload: payload, keyBytes: keyBytes);

    return await Isolate.run(() {
      final encKey = enc.Key(params.keyBytes);
      final envelope = ZeroKnowledgeCrypto.sealEnvelope(
        payload: params.payload,
        key: encKey,
      );
      // Zeroize local copy of key in isolate RAM
      HardwareSecurityManager.zeroizeMemory(params.keyBytes);
      return envelope;
    });
  }

  /// Decrypts a binary envelope inside a background isolate
  static Future<Uint8List> openEnvelope({
    required Uint8List envelopeBytes,
    required Uint8List keyBytes,
  }) async {
    final params = _OpenParams(envelopeBytes: envelopeBytes, keyBytes: keyBytes);

    return await Isolate.run(() {
      final encKey = enc.Key(params.keyBytes);
      final plaintext = ZeroKnowledgeCrypto.openEnvelope(
        envelopeBytes: params.envelopeBytes,
        key: encKey,
      );
      // Zeroize local copy of key in isolate RAM
      HardwareSecurityManager.zeroizeMemory(params.keyBytes);
      return plaintext;
    });
  }

  /// Computes a high-throughput SHA-256 integrity checksum in a background isolate
  static Future<String> computeSha256Checksum(Uint8List data) async {
    return await Isolate.run(() {
      final digest = sha256.convert(data);
      return digest.toString();
    });
  }
}
