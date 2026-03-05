import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/route_plan_result.dart';

class RouteSummaryCard extends StatelessWidget {
  final RoutePlanResult route;
  final bool isSelected;
  final VoidCallback? onTap;

  const RouteSummaryCard({
    super.key,
    required this.route,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final busLegs = route.legs.where((l) => l.mode == 'BUS').toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.infoBg : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${route.totalMinutes} min',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FASTEST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Route badges
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (route.walkingMinutes > 0)
                  const Icon(
                    Icons.directions_walk,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                for (int i = 0; i < busLegs.length; i++) ...[
                  if (i > 0 || route.walkingMinutes > 0)
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  RouteBadge(routeCode: busLegs[i].routeCode ?? 'BUS'),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${route.transfers} transfer${route.transfers != 1 ? 's' : ''} • ${route.walkingMinutes} min walk',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
