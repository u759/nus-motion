import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/features/search_routing/widgets/route_step_tile.dart';

class RouteDetailCard extends StatelessWidget {
  final RoutePlanResult route;

  const RouteDetailCard({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                '${route.totalMinutes} min',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (route.walkingMinutes > 0) ...[
                    const Icon(
                      Icons.directions_walk,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 2),
                  ],
                  if (route.transfers > 0) ...[
                    const Icon(
                      Icons.directions_bus,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 2),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${route.transfers} transfer${route.transfers != 1 ? "s" : ""} • ${route.walkingMinutes} min walk',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          // Steps timeline
          for (int i = 0; i < route.legs.length; i++)
            RouteStepTile(
              leg: route.legs[i],
              isLast: i == route.legs.length - 1,
            ),
        ],
      ),
    );
  }
}
