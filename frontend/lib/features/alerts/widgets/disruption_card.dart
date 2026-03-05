import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:frontend/app/theme.dart';

class DisruptionCard extends StatelessWidget {
  final String badge;
  final String meta;
  final String title;
  final String description;
  final String priority;
  final VoidCallback? onCheckRoute;
  final VoidCallback? onDismiss;

  const DisruptionCard({
    super.key,
    required this.badge,
    required this.meta,
    required this.title,
    required this.description,
    this.priority = 'normal',
    this.onCheckRoute,
    this.onDismiss,
  });

  bool get _isHighPriority =>
      priority.toLowerCase() == 'high' || priority.toLowerCase() == 'urgent';

  Color get _accentColor =>
      _isHighPriority ? AppTheme.warning : AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: _isHighPriority
              ? AppTheme.warning.withValues(alpha: 0.3)
              : AppTheme.surfaceVariant,
        ),
      ),
      child: Stack(
        children: [
          if (_isHighPriority)
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              child: Container(width: 4, color: AppTheme.warning),
            ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: BorderRadius.circular(AppTheme.spacing4),
                      ),
                      child: Text(
                        badge.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          color: _isHighPriority
                              ? AppTheme.backgroundDark
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        meta,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (_isHighPriority)
                      const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: AppTheme.textMuted,
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (_isHighPriority) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  Row(
                    children: [
                      _ActionButton(
                        label: 'Check Route',
                        color: AppTheme.warning,
                        onTap: onCheckRoute,
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      _ActionButton(
                        label: 'Dismiss',
                        color: AppTheme.textSecondary,
                        bgColor: AppTheme.surfaceVariant,
                        onTap: onDismiss,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color? bgColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor ?? color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing8,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
