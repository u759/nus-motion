import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/core/widgets/loading_shimmer.dart';
import 'package:frontend/core/widgets/error_card.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/map_discovery/models/navigation_state.dart';

/// Panel displaying route suggestions from user's location to a destination.
/// Shown when NavigationState.status == routePreview.
class RouteSuggestionsPanel extends ConsumerStatefulWidget {
  final Building destination;
  final Position? userPosition;

  const RouteSuggestionsPanel({
    super.key,
    required this.destination,
    this.userPosition,
  });

  @override
  ConsumerState<RouteSuggestionsPanel> createState() =>
      _RouteSuggestionsPanelState();
}

class _RouteSuggestionsPanelState extends ConsumerState<RouteSuggestionsPanel> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        final from = widget.userPosition != null
            ? '${widget.userPosition!.latitude},${widget.userPosition!.longitude}'
            : 'Current Location';
        final to = widget.destination.name;
        ref.invalidate(routeProvider((from: from, to: to)));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build route query params
    final from = widget.userPosition != null
        ? '${widget.userPosition!.latitude},${widget.userPosition!.longitude}'
        : 'Current Location';
    final to = widget.destination.name;

    final routesAsync = ref.watch(routeProvider((from: from, to: to)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suggested Routes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'To ${widget.destination.name}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Refresh button
              IconButton(
                onPressed: () =>
                    ref.invalidate(routeProvider((from: from, to: to))),
                icon: const Icon(Icons.refresh, size: 20),
                color: AppColors.textMuted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),

        // Routes list
        Expanded(
          child: routesAsync.when(
            skipLoadingOnReload: true,
            data: (routes) {
              // Filter out routes with inactive bus legs
              final validRoutes = _filterActiveRoutes(routes, ref);
              if (validRoutes.isEmpty) {
                return _buildEmptyState();
              }
              return _buildRoutesList(context, ref, validRoutes);
            },
            loading: () => _buildLoadingState(),
            error: (error, _) => _buildErrorState(ref, from, to, error),
          ),
        ),
      ],
    );
  }

  /// Filters out routes that have bus legs with no active shuttles.
  /// This ensures we only show routes where buses are currently running.
  List<RoutePlanResult> _filterActiveRoutes(
    List<RoutePlanResult> routes,
    WidgetRef ref,
  ) {
    final stops = ref.read(stopsProvider).valueOrNull;
    if (stops == null) return routes;

    return routes.where((route) {
      // Check each bus leg has active shuttles
      for (final leg in route.legs.where((l) => l.isBus)) {
        final routeCode = leg.routeCode;
        if (routeCode == null) continue;

        // Find the stop code for the boarding stop
        String? stopCode;
        for (final s in stops) {
          if (s.longName == leg.fromStop ||
              s.caption == leg.fromStop ||
              s.name == leg.fromStop) {
            stopCode = s.name;
            break;
          }
        }

        if (stopCode == null) continue;

        // Check if shuttle service shows this route at this stop with active buses
        final shuttles = ref.read(shuttlesProvider(stopCode)).valueOrNull;
        if (shuttles == null) continue;

        // arrivalTime "-" means no bus is coming for that route
        final hasActiveShuttle = shuttles.shuttles.any(
          (s) => s.name == routeCode && s.arrivalTime != '-',
        );
        if (!hasActiveShuttle) {
          return false; // Route has a bus leg with no active service
        }
      }
      return true;
    }).toList();
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: ShimmerList(itemCount: 3, itemHeight: 100),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.route_outlined,
                size: 32,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No routes found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try a different destination or walk directly',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, String from, String to, Object error) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ErrorCard(
        message: 'Could not load routes. Please try again.',
        onRetry: () => ref.invalidate(routeProvider((from: from, to: to))),
      ),
    );
  }

  Widget _buildRoutesList(
    BuildContext context,
    WidgetRef ref,
    List<RoutePlanResult> routes,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: routes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final route = routes[index];
        final isFirst = index == 0;
        return _RouteCard(
          route: route,
          isFastest: isFirst,
          onTap: () {
            ref.read(navigationStateProvider.notifier).selectRoute(route);
          },
        );
      },
    );
  }
}

/// Individual route option card.
class _RouteCard extends ConsumerWidget {
  final RoutePlanResult route;
  final bool isFastest;
  final VoidCallback onTap;

  const _RouteCard({
    required this.route,
    required this.isFastest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve first bus leg for live arrival lookup
    final firstBusLeg = route.legs.where((l) => l.isBus).firstOrNull;
    String? stopCode;
    String? liveEta;

    if (firstBusLeg?.fromStop != null) {
      final stops = ref.watch(stopsProvider);
      stops.whenData((list) {
        for (final s in list) {
          if (s.longName == firstBusLeg!.fromStop ||
              s.caption == firstBusLeg.fromStop ||
              s.name == firstBusLeg.fromStop) {
            stopCode = s.name;
            break;
          }
        }
      });
    }

    // Fetch live arrivals for the first bus stop
    if (stopCode != null && firstBusLeg?.routeCode != null) {
      final shuttles = ref.watch(shuttlesProvider(stopCode!));
      shuttles.whenData((result) {
        for (final s in result.shuttles) {
          if (s.name == firstBusLeg!.routeCode) {
            liveEta = s.arrivalTime;
            break;
          }
        }
      });
    }
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isFastest
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFastest ? AppColors.primary : AppColors.border,
            width: isFastest ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: time + route badges + transfers
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time and label
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${route.totalMinutes}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'min',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (isFastest)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FASTEST',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),

                // Divider
                Container(
                  width: 1,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: AppColors.border,
                ),

                // Route badges
                Expanded(child: _buildRouteBadges()),

                // Transfers
                if (route.transfers > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${route.transfers}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Time breakdown
            _buildTimeBreakdown(liveEta: liveEta),
          ],
        ),
      ),
    );
  }

  /// Builds route badges showing each bus leg.
  Widget _buildRouteBadges() {
    final busLegs = route.legs.where((leg) => leg.isBus).toList();

    if (busLegs.isEmpty) {
      // Walking only
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_walk, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Walk',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < busLegs.length; i++) ...[
          if (i > 0)
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.textMuted,
            ),
          RouteBadge(routeCode: busLegs[i].routeCode ?? '?', fontSize: 10),
        ],
      ],
    );
  }

  /// Builds the time breakdown row (walk, wait, bus) with optional live ETA chip.
  Widget _buildTimeBreakdown({String? liveEta}) {
    return Row(
      children: [
        _buildTimeChip(
          icon: Icons.directions_walk,
          label: '${route.walkingMinutes} min walk',
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        _buildTimeChip(
          icon: Icons.schedule,
          label: '${route.waitingMinutes} min wait',
          color: AppColors.warning,
        ),
        const SizedBox(width: 12),
        _buildTimeChip(
          icon: Icons.directions_bus,
          label: '${route.busMinutes} min ride',
          color: AppColors.primary,
        ),
        if (liveEta != null && liveEta != '-') ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              liveEta.toLowerCase() == 'arr' ? 'Arriving' : '$liveEta min',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Live ETA shown as chip in _buildTimeBreakdown row
