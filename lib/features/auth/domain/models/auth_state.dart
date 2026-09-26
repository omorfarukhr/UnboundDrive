enum AuthStatus {
  initial,
  codeSending,
  codeSent,
  verifyingCode,
  waitingFor2FA,
  verifying2FA,
  authenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? phoneNumber;
  final String? phoneCodeHash;
  final String? errorMessage;
  final int? vaultChannelId;
  final String? userName;

  const AuthState({
    this.status = AuthStatus.initial,
    this.phoneNumber,
    this.phoneCodeHash,
    this.errorMessage,
    this.vaultChannelId,
    this.userName,
  });

  bool get isLoading =>
      status == AuthStatus.codeSending ||
      status == AuthStatus.verifyingCode ||
      status == AuthStatus.verifying2FA;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    String? phoneCodeHash,
    String? errorMessage,
    int? vaultChannelId,
    String? userName,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneCodeHash: phoneCodeHash ?? this.phoneCodeHash,
      errorMessage: errorMessage ?? this.errorMessage,
      vaultChannelId: vaultChannelId ?? this.vaultChannelId,
      userName: userName ?? this.userName,
    );
  }
}
