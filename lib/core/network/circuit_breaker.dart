import 'dart:async';
import 'dart:math';

enum CircuitState { closed, open, halfOpen }

/// CircuitBreaker
/// ----------------------------------------------------
/// Enterprise Fault Tolerance & Resilience Circuit Breaker
///
/// Prevents cascade failures, Telegram flood bans (420 FLOOD_WAIT),
/// and excessive network battering during network dropouts.
class CircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;
  final String serviceName;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _floodWaitExpiry;
  final Random _random = Random();

  CircuitBreaker({
    required this.serviceName,
    this.failureThreshold = 3,
    this.resetTimeout = const Duration(seconds: 15),
  });

  CircuitState get state => _state;
  bool get isOpen => _state == CircuitState.open;

  /// Executes an asynchronous operation through the circuit breaker
  Future<T> execute<T>(Future<T> Function() action) async {
    _evaluateState();

    if (_state == CircuitState.open) {
      final waitRemaining = _floodWaitExpiry != null
          ? _floodWaitExpiry!.difference(DateTime.now()).inSeconds
          : (_lastFailureTime != null
              ? resetTimeout.inSeconds - DateTime.now().difference(_lastFailureTime!).inSeconds
              : 0);

      throw CircuitBreakerOpenException(
        "Circuit for '$serviceName' is OPEN. Cooling down. Retry in ${waitRemaining > 0 ? waitRemaining : 1}s.",
      );
    }

    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (error) {
      _onFailure(error);
      rethrow;
    }
  }

  void _evaluateState() {
    final now = DateTime.now();

    // Check if Telegram flood wait active
    if (_floodWaitExpiry != null) {
      if (now.isBefore(_floodWaitExpiry!)) {
        _state = CircuitState.open;
        return;
      } else {
        _floodWaitExpiry = null;
      }
    }

    if (_state == CircuitState.open) {
      if (_lastFailureTime != null && now.difference(_lastFailureTime!) > resetTimeout) {
        _state = CircuitState.halfOpen;
      }
    }
  }

  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitState.closed;
  }

  void _onFailure(dynamic error) {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    // Detect Telegram FloodWait error (e.g. "Wait 45 seconds")
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains("wait") && errorStr.contains("second")) {
      final match = RegExp(r'(\d+)\s*second').firstMatch(errorStr);
      if (match != null) {
        final waitSec = int.tryParse(match.group(1) ?? "10") ?? 10;
        // Apply jitter (+ 20% random delay) to prevent thundering herd
        final jitter = _random.nextInt(3) + 1;
        _floodWaitExpiry = DateTime.now().add(Duration(seconds: waitSec + jitter));
        _state = CircuitState.open;
        return;
      }
    }

    if (_failureCount >= failureThreshold) {
      _state = CircuitState.open;
    }
  }

  /// Calculates exponential backoff with randomized jitter
  static Duration calculateExponentialBackoff(
    int attempt, {
    Duration initialDelay = const Duration(milliseconds: 500),
    Duration maxDelay = const Duration(seconds: 30),
  }) {
    final expMs = initialDelay.inMilliseconds * pow(2, attempt).toInt();
    final cappedMs = min(expMs, maxDelay.inMilliseconds);
    final jitterMs = Random().nextInt(300); // 0-300ms jitter
    return Duration(milliseconds: cappedMs + jitterMs);
  }

  /// Manually reset circuit breaker
  void reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _floodWaitExpiry = null;
  }
}

class CircuitBreakerOpenException implements Exception {
  final String message;
  CircuitBreakerOpenException(this.message);

  @override
  String toString() => "CircuitBreakerOpenException: $message";
}
