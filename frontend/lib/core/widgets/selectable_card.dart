import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

/// Animated card that transitions between normal and selected states.
/// Uses route-colored tint for the selected state.
class SelectableCard extends StatelessWidget {
  final bool isSelected;
  final Color accentColor;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const SelectableCard({
    super.key,
    required this.isSelected,
    required this.accentColor,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? Color.alphaBlend(
            accentColor.withValues(alpha: 0.06),
            AppColors.surface,
          )
        : AppColors.surface;
    final borderColor = isSelected
        ? Color.alphaBlend(
            accentColor.withValues(alpha: 0.3),
            AppColors.surface,
          )
        : AppColors.borderLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor),
        ),
        child: child,
      ),
    );
  }
}
