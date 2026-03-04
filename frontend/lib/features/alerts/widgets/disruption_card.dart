import 'package:flutter/material.dart';

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
      _isHighPriority ? const Color(0xFFFFBF00) : AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isHighPriority
              ? const Color(0xFFFFBF00).withValues(alpha: 0.3)
              : const Color(0xFF1E293B),
        ),
      ),
      child: Stack(
        children: [
          // Left accent bar (only for high priority)
          if (_isHighPriority)
            Positioned(
              top: 0,
              left: 0,
              bottom: 0,
              child: Container(width: 4, color: const Color(0xFFFFBF00)),
            ),
          // Content
          Padding(
            padding: EdgeInsets.only(
              left: _isHighPriority ? 16 : 16,
              right: 16,
              top: 16,
              bottom: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          color: _isHighPriority
                              ? AppTheme.backgroundDark
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        meta,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textMuted,
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
                const SizedBox(height: 8),
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Description
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                // Action buttons (only for high priority)
                if (_isHighPriority) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ActionButton(
                        label: 'Check Route',
                        color: const Color(0xFFFFBF00),
                        onTap: onCheckRoute,
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(
                        label: 'Dismiss',
                        color: AppTheme.textSecondary,
                        bgColor: const Color(0xFF1E293B),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor ?? color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
