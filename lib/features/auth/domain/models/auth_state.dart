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
  final String? lastName;
  final String? username;
  final String? telegramUserId;

  const AuthState({
    this.status = AuthStatus.initial,
    this.phoneNumber,
    this.phoneCodeHash,
    this.errorMessage,
    this.vaultChannelId,
    this.userName,
    this.lastName,
    this.username,
    this.telegramUserId,
  });

  bool get isLoading =>
      status == AuthStatus.codeSending ||
      status == AuthStatus.verifyingCode ||
      status == AuthStatus.verifying2FA;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  String get displayName {
    final first = userName ?? "";
    final last = lastName ?? "";
    final full = "$first $last".trim();
    if (full.isNotEmpty) return full;
    if (username != null && username!.isNotEmpty) return "@$username";
    if (phoneNumber != null && phoneNumber!.isNotEmpty) return phoneNumber!;
    return "Telegram User";
  }

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    String? phoneCodeHash,
    String? errorMessage,
    int? vaultChannelId,
    String? userName,
    String? lastName,
    String? username,
    String? telegramUserId,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneCodeHash: phoneCodeHash ?? this.phoneCodeHash,
      errorMessage: errorMessage ?? this.errorMessage,
      vaultChannelId: vaultChannelId ?? this.vaultChannelId,
      userName: userName ?? this.userName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      telegramUserId: telegramUserId ?? this.telegramUserId,
    );
  }
}
