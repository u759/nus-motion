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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.route, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$from → $to',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: const Icon(
                  Icons.bookmark,
                  color: AppColors.primary,
                  size: 20,
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
