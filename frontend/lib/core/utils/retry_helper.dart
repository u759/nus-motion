import 'dart:async';
import 'dart:math' as math;

/// Executes a function with exponential backoff retry logic.
///
/// - [fn]: The async function to execute.
/// - [maxAttempts]: Maximum number of retry attempts (default: 3).
/// - [baseDelaySeconds]: Base delay in seconds for exponential backoff (default: 2).
/// - [onRetry]: Optional callback invoked before each retry with attempt number.
///
/// Returns the result on success, or rethrows the last error after all attempts fail.
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
  int baseDelaySeconds = 2,
  void Function(int attempt)? onRetry,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn();
    } catch (e) {
      attempt++;
      if (attempt >= maxAttempts) rethrow;
      onRetry?.call(attempt);
      final delaySeconds = math.pow(baseDelaySeconds, attempt).toInt();
      await Future.delayed(Duration(seconds: delaySeconds));
    }
  }
}
