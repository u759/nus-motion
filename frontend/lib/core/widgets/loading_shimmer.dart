import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:frontend/app/theme.dart';

class LoadingShimmer extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const LoadingShimmer({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return Shimmer.fromColors(
      baseColor: colors.border,
      highlightColor: colors.surfaceMuted,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerList({super.key, this.itemCount = 4, this.itemHeight = 80});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Handle unconstrained height (e.g., inside a Column without bounds)
        final totalItemHeight = itemHeight + 12; // item + padding
        int visibleItems;

        if (constraints.maxHeight.isFinite) {
          final maxItems = (constraints.maxHeight / totalItemHeight).floor();
          visibleItems = maxItems.clamp(1, itemCount);
        } else {
          // Infinite constraint — just use the requested item count
          visibleItems = itemCount;
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            visibleItems,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Opacity(
                opacity: 1.0 - (i * 0.12).clamp(0.0, 0.4),
                child: LoadingShimmer(height: itemHeight),
              ),
            ),
          ),
        );
      },
    );
  }
}
