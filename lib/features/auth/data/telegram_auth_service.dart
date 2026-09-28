import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/network_config.dart';
import '../../../../core/constants/telegram_constants.dart';
import '../domain/models/auth_state.dart';

class TelegramAuthService {
  final FlutterSecureStorage _secureStorage;
  static String get bridgeBaseUrl => NetworkConfig.authUrl;

  static const String _keySessionActive = "ubd_session_active";
  static const String _keyPhone = "ubd_phone";
  static const String _keyFirstName = "ubd_first_name";
  static const String _keyLastName = "ubd_last_name";
  static const String _keyUsername = "ubd_username";
  static const String _keyTelegramUserId = "ubd_telegram_user_id";
  static const String _keyVaultChannelId = "ubd_vault_channel_id";

  TelegramAuthService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Checks if an active session exists in storage
  Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool(_keySessionActive) ?? false;
    final phone = prefs.getString(_keyPhone);
    return isActive && phone != null && phone.isNotEmpty;
  }

  /// Restores saved authentication state upon app launch
  Future<AuthState?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool(_keySessionActive) ?? false;
      final phone = prefs.getString(_keyPhone);

      if (!isActive || phone == null || phone.isEmpty) {
        return null;
      }

      final firstName = prefs.getString(_keyFirstName) ?? "";
      final lastName = prefs.getString(_keyLastName) ?? "";
      final username = prefs.getString(_keyUsername);
      final userId = prefs.getString(_keyTelegramUserId);
      final channelId = prefs.getInt(_keyVaultChannelId);

      return AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: phone,
        userName: firstName,
        lastName: lastName,
        username: username,
        telegramUserId: userId,
        vaultChannelId: channelId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sends a real Telegram verification code via MTProto Bridge
  Future<AuthState> sendVerificationCode({
    required String phoneNumber,
    required String apiId,
    required String apiHash,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    await _secureStorage.write(key: TelegramConstants.keyApiId, value: apiId);
    await _secureStorage.write(key: TelegramConstants.keyApiHash, value: apiHash);

    try {
      final response = await http.post(
        Uri.parse("$bridgeBaseUrl/send_code"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone_number": cleanPhone}),
      ).timeout(const Duration(seconds: 25));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data["status"] == "ok") {
        return AuthState(
          status: AuthStatus.codeSent,
          phoneNumber: cleanPhone,
          phoneCodeHash: data["phone_code_hash"],
        );
      } else {
        final errorMsg = data["message"] ?? "Failed to send Telegram code.";
        return AuthState(
          status: AuthStatus.error,
          errorMessage: errorMsg,
        );
      }
    } catch (e) {
      return AuthState(
        status: AuthStatus.error,
        errorMessage: "Cannot reach Telegram MTProto Bridge at ${NetworkConfig.defaultBridgeHost}:8086.\nEnsure your PC Bridge is running on the same Wi-Fi.",
      );
    }
  }

  /// Verifies the REAL OTP code received via Telegram
  Future<AuthState> verifyCode({
    required String phoneNumber,
    required String phoneCodeHash,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$bridgeBaseUrl/verify_code"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone_number": phoneNumber,
          "phone_code_hash": phoneCodeHash,
          "code": code,
        }),
      ).timeout(const Duration(seconds: 25));

      final data = jsonDecode(response.body);

      if (data["status"] == "2fa_required") {
        return AuthState(
          status: AuthStatus.waitingFor2FA,
          phoneNumber: phoneNumber,
          phoneCodeHash: phoneCodeHash,
        );
      } else if (response.statusCode == 200 && data["status"] == "authenticated") {
        final user = data["user"] ?? {};
        final firstName = user["first_name"] as String? ?? "";
        final lastName = user["last_name"] as String? ?? "";
        final username = user["username"] as String?;
        final userId = user["id"]?.toString();
        final channelId = user["vault_channel_id"] as int?;

        await _saveUserSession(
          phone: phoneNumber,
          firstName: firstName,
          lastName: lastName,
          username: username,
          telegramUserId: userId,
          vaultChannelId: channelId,
        );

        return AuthState(
          status: AuthStatus.authenticated,
          phoneNumber: phoneNumber,
          vaultChannelId: channelId,
          userName: firstName,
          lastName: lastName,
          username: username,
          telegramUserId: userId,
        );
      } else {
        return AuthState(
          status: AuthStatus.error,
          phoneNumber: phoneNumber,
          phoneCodeHash: phoneCodeHash,
          errorMessage: data["message"] ?? "Invalid verification code. Please check your Telegram app.",
        );
      }
    } catch (e) {
      return AuthState(
        status: AuthStatus.error,
        phoneNumber: phoneNumber,
        phoneCodeHash: phoneCodeHash,
        errorMessage: "Network error communicating with Telegram Bridge: $e",
      );
    }
  }

  /// Verifies 2FA Cloud Password if enabled
  Future<AuthState> verify2FA({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$bridgeBaseUrl/verify_2fa"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone_number": phoneNumber,
          "password": password,
        }),
      ).timeout(const Duration(seconds: 25));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data["status"] == "authenticated") {
        final user = data["user"] ?? {};
        final firstName = user["first_name"] as String? ?? "";
        final lastName = user["last_name"] as String? ?? "";
        final username = user["username"] as String?;
        final userId = user["id"]?.toString();
        final channelId = user["vault_channel_id"] as int?;

        await _saveUserSession(
          phone: phoneNumber,
          firstName: firstName,
          lastName: lastName,
          username: username,
          telegramUserId: userId,
          vaultChannelId: channelId,
        );

        return AuthState(
          status: AuthStatus.authenticated,
          phoneNumber: phoneNumber,
          vaultChannelId: channelId,
          userName: firstName,
          lastName: lastName,
          username: username,
          telegramUserId: userId,
        );
      } else {
        return AuthState(
          status: AuthStatus.error,
          phoneNumber: phoneNumber,
          errorMessage: data["message"] ?? "Incorrect 2FA password.",
        );
      }
    } catch (e) {
      return AuthState(
        status: AuthStatus.error,
        phoneNumber: phoneNumber,
        errorMessage: "Network error verifying 2FA: $e",
      );
    }
  }

  Future<void> _saveUserSession({
    required String phone,
    required String firstName,
    required String lastName,
    String? username,
    String? telegramUserId,
    int? vaultChannelId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySessionActive, true);
    await prefs.setString(_keyPhone, phone);
    await prefs.setString(_keyFirstName, firstName);
    await prefs.setString(_keyLastName, lastName);
    if (username != null) await prefs.setString(_keyUsername, username);
    if (telegramUserId != null) await prefs.setString(_keyTelegramUserId, telegramUserId);
    if (vaultChannelId != null) await prefs.setInt(_keyVaultChannelId, vaultChannelId);

    await _secureStorage.write(key: TelegramConstants.keySessionToken, value: "auth_token_$phone");
    if (vaultChannelId != null) {
      await _secureStorage.write(key: TelegramConstants.keyVaultChannelId, value: vaultChannelId.toString());
    }
  }

  /// Logs out and purges local session and credentials
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_keyPhone);
    try {
      if (phone != null && phone.isNotEmpty) {
        await http.post(
          Uri.parse("$bridgeBaseUrl/logout"),
          headers: {"Content-Type": "application/json", "X-Phone": phone},
          body: jsonEncode({"phone_number": phone}),
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {}

    await prefs.remove(_keySessionActive);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyFirstName);
    await prefs.remove(_keyLastName);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyTelegramUserId);
    await prefs.remove(_keyVaultChannelId);

    await _secureStorage.delete(key: TelegramConstants.keySessionToken);
    await _secureStorage.delete(key: TelegramConstants.keyVaultChannelId);
  }
}
