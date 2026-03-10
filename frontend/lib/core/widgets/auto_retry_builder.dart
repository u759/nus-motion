import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/widgets/error_card.dart';

/// A widget that wraps an AsyncValue and provides auto-retry logic with
/// exponential backoff on error, plus a manual retry button after max attempts.
///
/// Usage:
/// ```dart
/// AutoRetryBuilder<List<Data>>(
///   asyncValue: ref.watch(myProvider),
///   onRetry: () => ref.invalidate(myProvider),
///   dataBuilder: (data) => MyDataWidget(data: data),
///   loadingBuilder: () => CircularProgressIndicator(),
/// )
/// ```
class AutoRetryBuilder<T> extends StatefulWidget {
  final AsyncValue<T> asyncValue;
  final VoidCallback onRetry;
  final Widget Function(T data) dataBuilder;
  final Widget Function()? loadingBuilder;
  final String errorMessage;
  final int maxAttempts;
  final int baseDelaySeconds;

  const AutoRetryBuilder({
    super.key,
    required this.asyncValue,
    required this.onRetry,
    required this.dataBuilder,
    this.loadingBuilder,
    this.errorMessage = 'Failed to load data',
    this.maxAttempts = 3,
    this.baseDelaySeconds = 2,
  });

  @override
  State<AutoRetryBuilder<T>> createState() => _AutoRetryBuilderState<T>();
}

class _AutoRetryBuilderState<T> extends State<AutoRetryBuilder<T>> {
  int _retryCount = 0;
  bool _isRetrying = false;
  Timer? _retryTimer;

  @override
  void didUpdateWidget(covariant AutoRetryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset retry count when data successfully loads
    if (widget.asyncValue.hasValue && !widget.asyncValue.hasError) {
      _retryCount = 0;
      _isRetrying = false;
      _retryTimer?.cancel();
    }

    // Trigger auto-retry on error if we haven't exceeded max attempts
    if (widget.asyncValue.hasError &&
        !_isRetrying &&
        _retryCount < widget.maxAttempts) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retryCount++;
    _isRetrying = true;

    final delaySeconds = math.pow(widget.baseDelaySeconds, _retryCount).toInt();

    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted) return;
      setState(() => _isRetrying = false);
      widget.onRetry();
    });

    setState(() {});
  }

  void _manualRetry() {
    _retryCount = 0;
    _isRetrying = false;
    _retryTimer?.cancel();
    widget.onRetry();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.asyncValue.when(
      skipLoadingOnReload: true,
      data: widget.dataBuilder,
      loading: () =>
          widget.loadingBuilder?.call() ??
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) {
        // Show retrying indicator during auto-retry
        if (_isRetrying && _retryCount < widget.maxAttempts) {
          return RetryingIndicator(
            attempt: _retryCount,
            maxAttempts: widget.maxAttempts,
          );
        }

        // Show error card with manual retry button after max attempts
        return ErrorCard(message: widget.errorMessage, onRetry: _manualRetry);
      },
    );
  }
}

/// A compact indicator shown during auto-retry attempts.
class RetryingIndicator extends StatelessWidget {
  final int attempt;
  final int maxAttempts;

  const RetryingIndicator({
    super.key,
    required this.attempt,
    required this.maxAttempts,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Retrying... ($attempt/$maxAttempts)',
            style: TextStyle(fontSize: 13, color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A smaller inline retry indicator for use in compact spaces.
class InlineRetryIndicator extends StatelessWidget {
  final int attempt;
  final int maxAttempts;

  const InlineRetryIndicator({
    super.key,
    required this.attempt,
    required this.maxAttempts,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Retrying ($attempt/$maxAttempts)',
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
      ],
    );
  }
}
