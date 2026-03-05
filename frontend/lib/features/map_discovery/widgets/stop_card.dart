import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/active_bus.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/data/models/shuttle_service_result.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/map_discovery/widgets/bus_line_tile.dart';

class StopCard extends ConsumerWidget {
  final NearbyStopResult stop;
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String routeCode)? onRouteTap;

  const StopCard({
    super.key,
    required this.stop,
    required this.isExpanded,
    required this.onToggle,
    this.onRouteTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: AppTheme.durationMedium,
      curve: AppTheme.curve,
      decoration: BoxDecoration(
        color: isExpanded
            ? AppTheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(isExpanded ? AppTheme.radiusLg : 0),
        border: Border.all(
          color: isExpanded
              ? AppTheme.primary.withValues(alpha: 0.25)
              : AppTheme.borderDark.withValues(alpha: 0.5),
          width: isExpanded ? 1.0 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(
            isExpanded ? AppTheme.radiusLg : 0,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                if (isExpanded) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  _buildShuttles(ref, context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: AppTheme.durationMedium,
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: isExpanded
                ? AppTheme.primary.withValues(alpha: 0.2)
                : AppTheme.surfaceVariant.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.location_on,
            color: isExpanded ? AppTheme.primary : AppTheme.textMuted,
            size: 20,
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.stopDisplayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isExpanded
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${stop.walkingMinutes.round()} min walk · ${stop.distanceMeters.round()}m away',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: AppTheme.durationMedium,
          curve: AppTheme.curve,
          child: Icon(
            Icons.expand_more,
            color: isExpanded ? AppTheme.primary : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildShuttles(WidgetRef ref, BuildContext context) {
    final shuttlesAsync = ref.watch(shuttlesProvider(stop.stopName));

    return shuttlesAsync.when(
      data: (result) => _buildShuttleList(result, ref, context),
      loading: () => Shimmer.fromColors(
        baseColor: AppTheme.surfaceVariant,
        highlightColor: AppTheme.neutralDark,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Column(
            children: List.generate(
              2,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacing8),
        child: Text(
          'Could not load shuttles',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildShuttleList(
    ShuttleServiceResult result,
    WidgetRef ref,
    BuildContext context,
  ) {
    if (result.shuttles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing8),
        child: Text(
          'No active shuttles',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final Map<String, LoadInfo> plateLoadInfo = {};
    final routeNames = result.shuttles.map((s) => s.name).toSet();
    for (final route in routeNames) {
      final activeBusesAsync = ref.watch(activeBusesProvider(route));
      activeBusesAsync.whenData((buses) {
        for (final bus in buses) {
          if (bus.loadInfo != null) {
            plateLoadInfo[bus.vehplate] = bus.loadInfo!;
          }
        }
      });
    }

    return Column(
      children: [
        for (int i = 0; i < result.shuttles.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < result.shuttles.length - 1 ? AppTheme.spacing12 : 0,
            ),
            child: BusLineTile(
              key: ValueKey('${stop.stopName}_${result.shuttles[i].name}_$i'),
              shuttle: result.shuttles[i],
              routeName: result.name,
              expanded: i == 0,
              loadInfo: _findLoadInfo(result.shuttles[i], plateLoadInfo),
              onRouteTap: onRouteTap != null
                  ? () => onRouteTap!(result.name)
                  : null,
            ),
          ),
      ],
    );
  }

  LoadInfo? _findLoadInfo(
    Shuttle shuttle,
    Map<String, LoadInfo> plateLoadInfo,
  ) {
    if (shuttle.arrivalTimeVehPlate.isNotEmpty) {
      final info = plateLoadInfo[shuttle.arrivalTimeVehPlate];
      if (info != null) return info;
    }
    return null;
  }
}
