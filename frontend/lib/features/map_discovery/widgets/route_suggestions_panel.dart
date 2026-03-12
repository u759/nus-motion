import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/core/widgets/loading_shimmer.dart';
import 'package:frontend/core/widgets/error_card.dart';
import 'package:frontend/core/widgets/pulsing_dot.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/route_leg.dart';
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

class _RouteSuggestionsPanelState extends ConsumerState<RouteSuggestionsPanel>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startRefreshTimer();
  }

  String _resolveFrom() {
    final navState = ref.read(navigationStateProvider);
    if (navState.origin != null) {
      return navState.origin!.name;
    }
    return widget.userPosition != null
        ? '${widget.userPosition!.latitude},${widget.userPosition!.longitude}'
        : 'Current Location';
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        final from = _resolveFrom();
        final to = widget.destination.name;
        ref.invalidate(routeProvider((from: from, to: to)));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;

    // Build route query params
    final from = _resolveFrom();
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
                    Text(
                      'Suggested Routes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'To ${widget.destination.name}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
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
                color: colors.textMuted,
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
                return _buildEmptyState(colors);
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

  Widget _buildEmptyState(NusColorsData colors) {
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
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.route_outlined,
                size: 32,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No routes found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different destination or walk directly',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
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

/// Individual route option card with a visual journey strip.
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
    final colors = context.nusColors;

    // When origin is a custom building (not GPS), skip the first walk leg
    final navState = ref.watch(navigationStateProvider);
    final skipFirstWalk =
        navState.origin != null &&
        route.legs.isNotEmpty &&
        route.legs.first.isWalk;
    final firstWalkMinutes = skipFirstWalk
        ? (route.legs.first.minutes ?? 0)
        : 0;
    final displayTotalMinutes = route.totalMinutes - firstWalkMinutes;
    final displayWalkingMinutes = route.walkingMinutes - firstWalkMinutes;
    final displayLegs = skipFirstWalk ? route.legs.sublist(1) : route.legs;

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

    // Capture for null promotion inside builder
    final eta = liveEta;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isFastest
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.primary.withValues(alpha: 0.06),
                    colors.primary.withValues(alpha: 0.02),
                  ],
                )
              : null,
          color: isFastest ? null : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFastest ? colors.primary : colors.border,
            width: isFastest ? 2 : 0.5,
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
            // Row 1: Total time + Fastest pill + Live ETA
            Row(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$displayTotalMinutes',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'min',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (isFastest) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Fastest',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (eta != null && eta != '-')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PulsingDot(color: colors.success),
                        const SizedBox(width: 4),
                        Text(
                          eta.toLowerCase() == 'arr' ? 'Arriving' : '$eta min',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 2: Journey strip
            _buildJourneyStrip(colors, displayLegs),

            const SizedBox(height: 10),

            // Row 3: De-emphasized time breakdown footer
            _buildFooter(colors, displayWalkingMinutes),
          ],
        ),
      ),
    );
  }

  /// Horizontal journey strip with proportional segments for each leg.
  Widget _buildJourneyStrip(NusColorsData colors, List<RouteLeg> legs) {
    final displayLegs = legs
        .where((l) => (l.isWalk || l.isBus) && (l.minutes ?? 0) > 0)
        .toList();

    if (displayLegs.isEmpty) {
      final isDark = colors.background.computeLuminance() < 0.2;
      return Container(
        height: 28,
        decoration: BoxDecoration(
          color: colors.textMuted.withValues(alpha: isDark ? 0.25 : 0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_walk, size: 13, color: colors.textMuted),
            const SizedBox(width: 4),
            Text(
              'Walk only',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            for (int i = 0; i < displayLegs.length; i++)
              Expanded(
                flex: (displayLegs[i].minutes ?? 1).clamp(1, 999),
                child: _buildSegment(displayLegs[i], colors),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(RouteLeg leg, NusColorsData colors) {
    if (leg.isBus) {
      final routeColor = RouteBadge.colorForRoute(leg.routeCode ?? '');
      return Container(
        color: routeColor.withValues(alpha: 0.85),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_bus, size: 11, color: Colors.white),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                leg.routeCode ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Walk segment — darker in light mode, lighter in dark mode for visibility
    final isDark = colors.background.computeLuminance() < 0.2;
    return Container(
      color: colors.textMuted.withValues(alpha: isDark ? 0.25 : 0.18),
      alignment: Alignment.center,
      child: Icon(
        Icons.directions_walk,
        size: 13,
        color: colors.textMuted.withValues(alpha: isDark ? 0.8 : 0.5),
      ),
    );
  }

  /// Subtle footer row: walk, wait, ride breakdown + transfer count.
  Widget _buildFooter(NusColorsData colors, int walkingMinutes) {
    return Row(
      children: [
        Icon(Icons.directions_walk, size: 12, color: colors.textMuted),
        const SizedBox(width: 3),
        Text(
          '${walkingMinutes}m',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.schedule, size: 12, color: colors.textMuted),
        const SizedBox(width: 3),
        Text(
          '${route.waitingMinutes}m wait',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.directions_bus, size: 12, color: colors.textMuted),
        const SizedBox(width: 3),
        Text(
          '${route.busMinutes}m ride',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
          ),
        ),
        if (route.transfers > 0) ...[
          const SizedBox(width: 12),
          Icon(Icons.swap_horiz, size: 12, color: colors.textMuted),
          const SizedBox(width: 3),
          Text(
            '${route.transfers} transfer${route.transfers > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
