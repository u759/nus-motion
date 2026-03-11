import 'dart:async';

import 'package:flutter/material.dart';

/// Fades in + slides up on first build. Used for staggered list item appearance.
/// Tracks which keys have already animated so rebuilds don't replay.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 300),
    this.offset = 20,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  /// Track keys that have already animated so rebuilds skip the animation.
  static final _animated = <Key>{};

  /// Reset tracking (e.g. on full page navigation).
  static void reset() => _animated.clear();

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  Timer? _delayTimer;
  bool _skip = false;

  @override
  void initState() {
    super.initState();
    final key = widget.key;
    if (key != null && FadeSlideIn._animated.contains(key)) {
      _skip = true;
    }

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    if (_skip) {
      _controller.value = 1.0; // already seen → show immediately
    } else {
      if (key != null) {
        FadeSlideIn._animated.add(key);
        // Prevent unbounded growth: trim oldest half when exceeding 500.
        if (FadeSlideIn._animated.length > 500) {
          final toRemove = FadeSlideIn._animated
              .take(FadeSlideIn._animated.length ~/ 2)
              .toList();
          FadeSlideIn._animated.removeAll(toRemove);
        }
      }
      if (widget.delay == Duration.zero) {
        _controller.forward();
      } else {
        _delayTimer = Timer(widget.delay, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, widget.offset * (1 - _curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Pre-configured [AnimatedSwitcher] with a consistent fade + scale transition.
class AnimatedSwitcherDefaults extends StatelessWidget {
  const AnimatedSwitcherDefaults({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        final scale = Tween<double>(begin: 0.95, end: 1.0).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}

/// GestureDetector wrapper that scales down on press for tactile feedback.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (mounted) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (mounted) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (mounted) setState(() => _pressed = false);
      },
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Bouncing bookmark icon for the favorite toggle.
class AnimatedFavoriteIcon extends StatefulWidget {
  const AnimatedFavoriteIcon({
    super.key,
    required this.isFavorite,
    this.onTap,
    required this.color,
  });

  final bool isFavorite;
  final VoidCallback? onTap;
  final Color color;

  @override
  State<AnimatedFavoriteIcon> createState() => _AnimatedFavoriteIconState();
}

class _AnimatedFavoriteIconState extends State<AnimatedFavoriteIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 60),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(AnimatedFavoriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite != oldWidget.isFavorite) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Icon(
          widget.isFavorite ? Icons.bookmark : Icons.bookmark_border,
          color: widget.color,
        ),
      ),
    );
  }
}

/// Animated panel that slides in from a direction with opacity.
class SlideReveal extends StatelessWidget {
  const SlideReveal({
    super.key,
    required this.child,
    required this.visible,
    this.direction = AxisDirection.up,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final bool visible;
  final AxisDirection direction;
  final Duration duration;

  Offset get _hiddenOffset {
    switch (direction) {
      case AxisDirection.up:
        return const Offset(0, 1);
      case AxisDirection.down:
        return const Offset(0, -1);
      case AxisDirection.left:
        return const Offset(1, 0);
      case AxisDirection.right:
        return const Offset(-1, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : _hiddenOffset,
      duration: duration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}
