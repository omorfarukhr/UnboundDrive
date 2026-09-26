import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/telegram_auth_service.dart';
import '../../domain/models/auth_state.dart';

final telegramAuthServiceProvider = Provider<TelegramAuthService>((ref) {
  return TelegramAuthService();
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final service = ref.watch(telegramAuthServiceProvider);
  return AuthController(service);
});

class AuthController extends StateNotifier<AuthState> {
  final TelegramAuthService _authService;

  AuthController(this._authService) : super(const AuthState());

  Future<void> sendCode({
    required String phoneNumber,
    String apiId = "2040", // Fallback default official test client ID
    String apiHash = "b18441a1ff607e10a989891a5462e627",
  }) async {
    state = state.copyWith(status: AuthStatus.codeSending, errorMessage: null);
    final result = await _authService.sendVerificationCode(
      phoneNumber: phoneNumber,
      apiId: apiId,
      apiHash: apiHash,
    );
    state = result;
  }

  Future<void> verifyCode(String code) async {
    if (state.phoneNumber == null || state.phoneCodeHash == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: "Session expired. Please re-enter your phone number.",
      );
      return;
    }

    state = state.copyWith(status: AuthStatus.verifyingCode, errorMessage: null);
    final result = await _authService.verifyCode(
      phoneNumber: state.phoneNumber!,
      phoneCodeHash: state.phoneCodeHash!,
      code: code,
    );
    state = result;
  }

  Future<void> verify2FA(String password) async {
    if (state.phoneNumber == null) return;

    state = state.copyWith(status: AuthStatus.verifying2FA, errorMessage: null);
    final result = await _authService.verify2FA(
      phoneNumber: state.phoneNumber!,
      password: password,
    );
    state = result;
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState();
  }

  void resetError() {
    state = state.copyWith(errorMessage: null);
  }
}
