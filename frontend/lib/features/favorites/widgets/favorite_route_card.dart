import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

class FavoriteRouteCard extends StatelessWidget {
  final String from;
  final String to;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const FavoriteRouteCard({
    super.key,
    required this.from,
    required this.to,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.route, color: colors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$from → $to',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.bookmark, color: colors.primary, size: 20),
              )
            else
              Icon(Icons.chevron_right, color: colors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
