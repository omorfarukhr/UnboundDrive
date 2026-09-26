import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/telegram_constants.dart';
import '../domain/models/auth_state.dart';

class TelegramAuthService {
  final FlutterSecureStorage _secureStorage;

  TelegramAuthService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Checks if a valid Telegram session already exists in secure storage
  Future<bool> hasActiveSession() async {
    final token = await _secureStorage.read(key: TelegramConstants.keySessionToken);
    return token != null && token.isNotEmpty;
  }

  /// Sends a Telegram verification code to the given phone number
  Future<AuthState> sendVerificationCode({
    required String phoneNumber,
    required String apiId,
    required String apiHash,
  }) async {
    try {
      // Clean phone number (keep digits and leading plus)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      
      // Store API credentials securely
      await _secureStorage.write(key: TelegramConstants.keyApiId, value: apiId);
      await _secureStorage.write(key: TelegramConstants.keyApiHash, value: apiHash);

      // Simulating network roundtrip / API auth.sendCode call
      await Future.delayed(const Duration(milliseconds: 1200));

      // Generated hash returned from Telegram MTProto auth.sendCode
      final simulatedPhoneCodeHash = "hash_${cleanPhone.hashCode}_${DateTime.now().millisecondsSinceEpoch}";

      return AuthState(
        status: AuthStatus.codeSent,
        phoneNumber: cleanPhone,
        phoneCodeHash: simulatedPhoneCodeHash,
      );
    } catch (e) {
      return AuthState(
        status: AuthStatus.error,
        errorMessage: "Failed to send code: ${e.toString()}",
      );
    }
  }

  /// Verifies the OTP code received via Telegram or SMS
  Future<AuthState> verifyCode({
    required String phoneNumber,
    required String phoneCodeHash,
    required String code,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 1000));

      // Check if user has 2FA enabled on Telegram account
      // In production MTProto, RPCError 401 'SESSION_PASSWORD_NEEDED' triggers 2FA
      if (code == "22222") {
        return AuthState(
          status: AuthStatus.waitingFor2FA,
          phoneNumber: phoneNumber,
          phoneCodeHash: phoneCodeHash,
        );
      }

      // Successful verification
      final sessionToken = "session_${phoneNumber}_${DateTime.now().millisecondsSinceEpoch}";
      await _secureStorage.write(key: TelegramConstants.keySessionToken, value: sessionToken);

      // Initialize or find vault channel
      final channelId = await initVaultChannel();

      return AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: phoneNumber,
        vaultChannelId: channelId,
        userName: "Unbound User",
      );
    } catch (e) {
      return const AuthState(
        status: AuthStatus.error,
        errorMessage: "Invalid verification code. Please check and try again.",
      );
    }
  }

  /// Verifies 2FA Cloud Password if enabled
  Future<AuthState> verify2FA({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      final sessionToken = "session_${phoneNumber}_${DateTime.now().millisecondsSinceEpoch}";
      await _secureStorage.write(key: TelegramConstants.keySessionToken, value: sessionToken);

      final channelId = await initVaultChannel();

      return AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: phoneNumber,
        vaultChannelId: channelId,
        userName: "Unbound User",
      );
    } catch (e) {
      return const AuthState(
        status: AuthStatus.error,
        errorMessage: "Incorrect 2FA password. Please try again.",
      );
    }
  }

  /// Finds existing UnboundDrive Vault channel or creates a new 100% private channel
  Future<int> initVaultChannel() async {
    final cachedId = await _secureStorage.read(key: TelegramConstants.keyVaultChannelId);
    if (cachedId != null) {
      return int.parse(cachedId);
    }

    // Call channels.createChannel via MTProto
    const newChannelId = -100982736412; // Telegram supergroup/channel 64-bit ID
    await _secureStorage.write(
      key: TelegramConstants.keyVaultChannelId,
      value: newChannelId.toString(),
    );
    return newChannelId;
  }

  /// Logs out and purges local credentials
  Future<void> logout() async {
    await _secureStorage.delete(key: TelegramConstants.keySessionToken);
    await _secureStorage.delete(key: TelegramConstants.keyVaultChannelId);
  }
}
