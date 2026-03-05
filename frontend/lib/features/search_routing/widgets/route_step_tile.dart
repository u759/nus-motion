import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/route_leg.dart';

class RouteStepTile extends StatelessWidget {
  final RouteLeg leg;
  final bool isLast;

  const RouteStepTile({super.key, required this.leg, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = _resolveStyle();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isLast
                        ? Colors.transparent
                        : color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(icon, size: 13, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leg.mode == 'BUS' && leg.routeCode != null) ...[
                    RouteBadge(routeCode: leg.routeCode!),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    leg.instruction,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (leg.minutes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${leg.minutes} min',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _resolveStyle() {
    switch (leg.mode) {
      case 'WALK':
        return (Icons.directions_walk, AppColors.textSecondary);
      case 'WAIT':
        return (Icons.access_time, AppColors.warning);
      case 'BUS':
        return (Icons.directions_bus, AppColors.primary);
      default:
        return (Icons.location_on, AppColors.primary);
    }
  }
}
