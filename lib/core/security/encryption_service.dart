import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  /// Derives a 256-bit AES key from user's secret vault master passphrase
  static enc.Key deriveKey(String masterPassword, String salt) {
    final keyBytes = utf8.encode(masterPassword + salt);
    final digest = sha256.convert(keyBytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// Encrypts bytes using AES-256 in GCM or CBC mode with random IV
  static Uint8List encryptFileBytes(Uint8List fileBytes, enc.Key key) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
    
    // Prepend the 16-byte IV to the ciphertext
    final result = BytesBuilder();
    result.add(iv.bytes);
    result.add(encrypted.bytes);
    return result.toBytes();
  }

  /// Decrypts bytes using AES-256 with prepended IV
  static Uint8List decryptFileBytes(Uint8List encryptedData, enc.Key key) {
    if (encryptedData.length < 16) {
      throw Exception("Invalid encrypted file format");
    }
    final ivBytes = encryptedData.sublist(0, 16);
    final cipherBytes = encryptedData.sublist(16);
    
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }
}
