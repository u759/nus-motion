import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/data/models/route_leg.dart';
import 'package:frontend/core/widgets/route_badge.dart';

class RouteDetailScreen extends ConsumerWidget {
  final Map<String, dynamic>? routeData;

  const RouteDetailScreen({super.key, this.routeData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = routeData?['route'] as RoutePlanResult?;
    final origin = routeData?['origin'] as String? ?? '';
    final destination = routeData?['destination'] as String? ?? '';

    if (route == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('No route data')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route to $destination',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Leave now from $origin',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune, color: AppColors.textSecondary),
                onPressed: () {},
              ),
            ],
          ),

          // Route summary bar
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text(
                    '${route.totalMinutes} min',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sensors, size: 12, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Real-time',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Mode icons
                  ...route.legs
                      .where((l) => l.mode == 'BUS')
                      .map(
                        (l) => Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: RouteBadge(
                            routeCode: l.routeCode ?? 'BUS',
                            fontSize: 10,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),

          // Step timeline
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < route.legs.length; i++)
                    _StepTile(
                      leg: route.legs[i],
                      isLast: i == route.legs.length - 1,
                    ),
                  // Final arrival
                  _StepTile(
                    leg: RouteLeg(
                      mode: 'ARRIVE',
                      instruction: 'Arrive at $destination',
                    ),
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),

          // Start navigation button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/search/active', extra: routeData);
                  },
                  icon: const Icon(Icons.navigation, size: 20),
                  label: const Text('START NAVIGATION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final RouteLeg leg;
  final bool isLast;

  const _StepTile({required this.leg, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color dotColor;
    final bool filled;

    switch (leg.mode) {
      case 'WALK':
        icon = Icons.directions_walk;
        dotColor = AppColors.textMuted;
        filled = true;
      case 'WAIT':
        icon = Icons.schedule;
        dotColor = AppColors.warning;
        filled = true;
      case 'BUS':
        icon = Icons.directions_bus;
        dotColor = AppColors.primary;
        filled = true;
      case 'ARRIVE':
        icon = Icons.location_on;
        dotColor = AppColors.primary;
        filled = false;
      default:
        icon = Icons.circle;
        dotColor = AppColors.textMuted;
        filled = true;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: filled ? dotColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: filled
                        ? null
                        : Border.all(color: dotColor, width: 2),
                  ),
                  child: Icon(
                    icon,
                    size: 14,
                    color: filled ? Colors.white : dotColor,
                  ),
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
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leg.instruction,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (leg.minutes != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${leg.minutes} min',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (leg.mode == 'BUS' && leg.routeCode != null) ...[
                          const SizedBox(width: 8),
                          RouteBadge(routeCode: leg.routeCode!, fontSize: 9),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
