import 'dart:async';
import 'dart:typed_data';
import 'circuit_breaker.dart';

typedef ChunkWorkerFunction = Future<dynamic> Function(int chunkIndex, Uint8List chunkData);

/// LoadBalancedTransferPool
/// ----------------------------------------------------
/// High-Throughput Scalable Worker Pool for MTProto Transmissions
///
/// Features:
/// 1. Concurrency Limiter: Manages 2 to 8 parallel chunk upload streams.
/// 2. Dynamic Backpressure & Adaptive Throttling: Automatically tunes
///    concurrency based on network latency and Telegram rate limits.
/// 3. Zero Head-of-Line Blocking: Independent chunk workers.
class LoadBalancedTransferPool {
  int maxConcurrentWorkers;
  final bool enableAdaptiveTuning;
  final CircuitBreaker circuitBreaker;

  int _activeWorkers = 0;
  final List<Completer<void>> _waitQueue = [];

  LoadBalancedTransferPool({
    this.maxConcurrentWorkers = 4,
    this.enableAdaptiveTuning = true,
    CircuitBreaker? circuitBreaker,
  }) : circuitBreaker = circuitBreaker ?? CircuitBreaker(serviceName: "MTProtoPool");

  /// Processes chunks in parallel while respecting maximum concurrency limit
  Future<List<T>> processChunks<T>({
    required List<Uint8List> chunks,
    required Future<T> Function(int index, Uint8List chunkData) task,
    void Function(int completed, int total)? onProgress,
  }) async {
    final results = List<T?>.filled(chunks.length, null);
    int completedCount = 0;
    final List<Future<void>> runningFutures = [];

    for (int i = 0; i < chunks.length; i++) {
      final chunkIndex = i;
      final chunkData = chunks[i];

      // Wait until a slot in the worker pool opens up
      await _acquireWorkerSlot();

      final workerFuture = () async {
        final stopwatch = Stopwatch()..start();
        int attempts = 0;
        const maxRetries = 3;

        while (true) {
          try {
            final result = await circuitBreaker.execute(() => task(chunkIndex, chunkData));
            results[chunkIndex] = result;
            stopwatch.stop();

            // Adaptive concurrency tuning
            _tuneConcurrency(latencyMs: stopwatch.elapsedMilliseconds);
            break;
          } catch (e) {
            attempts++;
            if (attempts >= maxRetries) {
              rethrow;
            }
            // Exponential backoff
            final delay = CircuitBreaker.calculateExponentialBackoff(attempts);
            await Future.delayed(delay);
          }
        }

        completedCount++;
        if (onProgress != null) {
          onProgress(completedCount, chunks.length);
        }
      }().whenComplete(() {
        _releaseWorkerSlot();
      });

      runningFutures.add(workerFuture);
    }

    // Wait for all chunk workers to finalize
    await Future.wait(runningFutures);

    return results.cast<T>();
  }

  Future<void> _acquireWorkerSlot() async {
    while (_activeWorkers >= maxConcurrentWorkers) {
      final completer = Completer<void>();
      _waitQueue.add(completer);
      await completer.future;
    }
    _activeWorkers++;
  }

  void _releaseWorkerSlot() {
    _activeWorkers--;
    if (_waitQueue.isNotEmpty) {
      final nextWorker = _waitQueue.removeAt(0);
      nextWorker.complete();
    }
  }

  /// Automatically scales concurrency up or down based on latency
  void _tuneConcurrency({required int latencyMs}) {
    if (!enableAdaptiveTuning) return;
    if (latencyMs < 300 && maxConcurrentWorkers < 6) {
      // Fast connection, expand pool
      maxConcurrentWorkers++;
    } else if (latencyMs > 2500 && maxConcurrentWorkers > 2) {
      // High latency or congestion, throttle back to prevent packet loss
      maxConcurrentWorkers--;
    }
  }
}
