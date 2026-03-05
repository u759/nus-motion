import 'package:flutter/material.dart';

import 'package:frontend/app/theme.dart';

/// Whether the suggestion comes from search history, a bus stop, or a building.
enum SuggestionType { recent, stop, building }

class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
    super.key,
    required this.name,
    this.subtitle,
    this.type = SuggestionType.stop,
    this.onTap,
  });

  final String name;
  final String? subtitle;
  final SuggestionType type;
  final VoidCallback? onTap;

  IconData get _icon => switch (type) {
    SuggestionType.recent => Icons.history,
    _ => Icons.location_on,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing8,
        ),
        child: Row(
          children: [
            Icon(_icon, color: AppTheme.textMuted, size: 22),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            const Icon(Icons.north_west, color: AppTheme.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}
