import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (!isExpanded) {
      return _buildCollapsed();
    }
    return _buildExpanded(ref);
  }

  Widget _buildCollapsed() {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0x80182A34), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0x80182A34),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.transparent),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF64748B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.stopDisplayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stop.walkingMinutes.round()} min walk • ${stop.distanceMeters.round()}m away',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more, color: Color(0xFF475569)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(WidgetRef ref) {
    final shuttlesAsync = ref.watch(shuttlesProvider(stop.stopName));

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 40,
                  width: 40,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.stopDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF1F5F9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stop.walkingMinutes.round()} min walk • ${stop.distanceMeters.round()}m away',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.expand_less, color: AppTheme.primary),
              ],
            ),
            // Bus lines
            const SizedBox(height: 16),
            shuttlesAsync.when(
              data: (result) => _buildShuttleList(result, ref),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Could not load shuttles',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShuttleList(ShuttleServiceResult result, WidgetRef ref) {
    if (result.shuttles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          'No active shuttles',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      );
    }

    // Build a map of plate → LoadInfo from ActiveBus data for each route
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
        // First shuttle is expanded
        for (int i = 0; i < result.shuttles.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < result.shuttles.length - 1 ? 12 : 0,
            ),
            child: BusLineTile(
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
    // Try to match the arriving bus plate to active bus load info
    if (shuttle.arrivalTimeVehPlate.isNotEmpty) {
      final info = plateLoadInfo[shuttle.arrivalTimeVehPlate];
      if (info != null) return info;
    }
    return null;
  }
}
