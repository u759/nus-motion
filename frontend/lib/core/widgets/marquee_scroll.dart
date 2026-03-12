import 'package:flutter/material.dart';

/// Auto-scrolling marquee wrapper.
///
/// If [child] overflows horizontally, it waits 2 s, scrolls to the end,
/// pauses, fades out, resets, fades in, and repeats. If the content fits,
/// nothing happens.
class MarqueeScroll extends StatefulWidget {
  final Widget child;
  const MarqueeScroll({super.key, required this.child});

  @override
  State<MarqueeScroll> createState() => _MarqueeScrollState();
}

class _MarqueeScrollState extends State<MarqueeScroll>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final AnimationController _fadeController;
  bool _overflows = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0 && !_overflows) {
      _overflows = true;
      _runCycle();
    }
  }

  Future<void> _runCycle() async {
    while (mounted && _overflows) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final ms = (maxScroll * 12).toInt().clamp(800, 4000);
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: ms),
        curve: Curves.linear,
      );
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      await _fadeController.animateTo(0);
      if (!mounted) return;

      _scrollController.jumpTo(0);

      await _fadeController.animateTo(1);
      if (!mounted) return;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}
