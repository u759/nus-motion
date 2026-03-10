import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/distance_formatter.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/widgets/error_card.dart';
import 'package:frontend/core/widgets/pickup_points_list.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/core/widgets/selectable_card.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/features/map_discovery/models/navigation_state.dart';
import 'package:frontend/state/providers.dart';

class StopsTab extends ConsumerStatefulWidget {
  final List<NearbyStopResult> stops;
  final String? selectedStop;
  final String? selectedRoute;
  final ValueChanged<String> onStopSelected;
  final ValueChanged<String> onStopLocate;
  final ValueChanged<String> onRouteSelected;
  final void Function(double lat, double lng, String stopCode)? onCenterMap;
  final void Function(String route, String plate)? onBusSelected;

  const StopsTab({
    super.key,
    required this.stops,
    this.selectedStop,
    this.selectedRoute,
    required this.onStopSelected,
    required this.onStopLocate,
    required this.onRouteSelected,
    this.onCenterMap,
    this.onBusSelected,
  });

  @override
  ConsumerState<StopsTab> createState() => _StopsTabState();
}

class _StopsTabState extends ConsumerState<StopsTab> {
  @override
  Widget build(BuildContext context) {
    if (widget.stops.isEmpty) {
      return const EmptyState(
        icon: Icons.location_off,
        title: 'No stops nearby',
        subtitle: 'Try moving closer to the NUS campus',
      );
    }

    final selectedStopData = widget.selectedStop != null
        ? widget.stops.cast<NearbyStopResult?>().firstWhere(
            (s) => s!.stopName == widget.selectedStop,
            orElse: () => null,
          )
        : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final isDetail = child.key == ValueKey('detail_${widget.selectedStop}');
        final offset = isDetail
            ? Tween(begin: const Offset(0, 0.15), end: Offset.zero)
            : Tween(begin: const Offset(0, -0.05), end: Offset.zero);
        return SlideTransition(
          position: offset.animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: selectedStopData != null
          ? _StopDetailView(
              key: ValueKey('detail_${widget.selectedStop}'),
              stop: selectedStopData,
              selectedRoute: widget.selectedRoute,
              onRouteSelected: widget.onRouteSelected,
              onBack: () => widget.onStopSelected(selectedStopData.stopName),
              onCenterMap: widget.onCenterMap,
              onBusSelected: widget.onBusSelected,
            )
          : _StopListView(
              key: const ValueKey('stop_list'),
              stops: widget.stops,
              onStopSelected: widget.onStopSelected,
              onStopLocate: widget.onStopLocate,
            ),
    );
  }
}

// ─── Stop List View ───────────────────────────────────────────

class _StopListView extends StatelessWidget {
  final List<NearbyStopResult> stops;
  final ValueChanged<String> onStopSelected;
  final ValueChanged<String> onStopLocate;

  const _StopListView({
    super.key,
    required this.stops,
    required this.onStopSelected,
    required this.onStopLocate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const PageStorageKey('stops_tab_list'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        return FadeSlideIn(
          key: ValueKey('fade_${stop.stopName}'),
          delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
          child: _StopCard(
            stop: stop,
            onTap: () => onStopSelected(stop.stopName),
            onLocate: () => onStopLocate(stop.stopName),
          ),
        );
      },
    );
  }
}

// ─── Stop Card (list item, non-expanding) ─────────────────────

class _StopCard extends ConsumerWidget {
  final NearbyStopResult stop;
  final VoidCallback onTap;
  final VoidCallback onLocate;

  const _StopCard({
    required this.stop,
    required this.onTap,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nusColors;
    final shuttles = ref.watch(shuttlesProvider(stop.stopName));

    // Get first 3 arrivals with valid times (not '-' or empty)
    final arrivals = shuttles.maybeWhen(
      skipLoadingOnReload: true,
      data: (result) {
        return result.shuttles
            .where((s) => s.arrivalTime.isNotEmpty && s.arrivalTime != '-')
            .take(3)
            .toList();
      },
      orElse: () => <Shuttle>[],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left column: locate + directions with full primary fill
            Container(
              width: 44,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onLocate,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Icon(
                          Icons.my_location,
                          color: colors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    color: colors.primary.withValues(alpha: 0.3),
                  ),
                  Expanded(child: _DirectionsButton(stop: stop)),
                ],
              ),
            ),
            // Right content — tappable to open detail
            Expanded(
              child: PressableScale(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop.stopDisplayName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DistanceFormatter.format(stop.distanceMeters)} • ${stop.walkingMinutes} min walk',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: colors.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      arrivals.isNotEmpty
                          ? _ArrivalsRow(arrivals: arrivals)
                          : Text(
                              'No service at this time',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Arrivals Row (compact preview on stop card) ──────────────

class _ArrivalsRow extends StatelessWidget {
  final List<Shuttle> arrivals;

  const _ArrivalsRow({required this.arrivals});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < arrivals.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            _ArrivalChip(
              routeCode: arrivals[i].name,
              eta: EtaFormatter.format(arrivals[i].arrivalTime),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArrivalChip extends StatelessWidget {
  final String routeCode;
  final String eta;

  const _ArrivalChip({required this.routeCode, required this.eta});

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RouteBadge(routeCode: routeCode, fontSize: 10),
        const SizedBox(width: 4),
        Text(
          eta,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Directions Button ────────────────────────────────────────

class _DirectionsButton extends ConsumerWidget {
  final NearbyStopResult stop;

  const _DirectionsButton({required this.stop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nusColors;
    return GestureDetector(
      onTap: () {
        final building = Building(
          elementId: stop.stopName,
          name: stop.stopDisplayName,
          address: '',
          postal: '',
          latitude: stop.latitude,
          longitude: stop.longitude,
        );
        ref.read(navigationStateProvider.notifier).selectDestination(building);
      },
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Icon(Icons.directions, size: 20, color: colors.primary),
      ),
    );
  }
}

// ─── Stop Detail View (full panel) ────────────────────────────

class _StopDetailView extends ConsumerStatefulWidget {
  final NearbyStopResult stop;
  final String? selectedRoute;
  final ValueChanged<String> onRouteSelected;
  final VoidCallback onBack;
  final void Function(double lat, double lng, String stopCode)? onCenterMap;
  final void Function(String route, String plate)? onBusSelected;

  const _StopDetailView({
    super.key,
    required this.stop,
    this.selectedRoute,
    required this.onRouteSelected,
    required this.onBack,
    this.onCenterMap,
    this.onBusSelected,
  });

  @override
  ConsumerState<_StopDetailView> createState() => _StopDetailViewState();
}

class _StopDetailViewState extends ConsumerState<_StopDetailView> {
  String? _expandedShuttleKey; // unique key: busstopcode_routeName
  String? _lastHighlightedPlate;

  /// Creates a unique key for a shuttle entry (busstopcode may be shared)
  String _shuttleKey(Shuttle s) => '${s.busstopcode}_${s.name}';

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    final shuttles = ref.watch(shuttlesProvider(widget.stop.stopName));

    // Auto-update highlighted bus when arrival data changes
    if (_expandedShuttleKey != null && widget.onBusSelected != null) {
      shuttles.whenData((result) {
        final shuttle = result.shuttles
            .where((s) => _shuttleKey(s) == _expandedShuttleKey)
            .firstOrNull;
        if (shuttle != null && shuttle.arrivalTimeVehPlate.isNotEmpty) {
          final newPlate = shuttle.arrivalTimeVehPlate;
          if (newPlate != _lastHighlightedPlate) {
            _lastHighlightedPlate = newPlate;
            // Schedule the callback to avoid calling during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onBusSelected!(shuttle.name, newPlate);
            });
          }
        }
      });
    }

    final isFavorite = ref
        .watch(favoriteStopsProvider)
        .contains(widget.stop.stopName);

    final contentSlivers = shuttles.when(
      skipLoadingOnReload: true,
      data: (result) {
        if (result.shuttles.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No services at this time',
                  style: TextStyle(fontSize: 14, color: colors.textMuted),
                ),
              ),
            ),
          ];
        }
        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList.builder(
              itemCount: result.shuttles.length,
              itemBuilder: (context, index) {
                final s = result.shuttles[index];
                final key = _shuttleKey(s);
                return _ShuttleArrivalRow(
                  key: ValueKey(key),
                  shuttle: s,
                  isExpanded: _expandedShuttleKey == key,
                  currentStopCode: widget.stop.stopName,
                  onCenterMap: widget.onCenterMap,
                  onTap: () {
                    final wasExpanded = _expandedShuttleKey == key;
                    setState(() {
                      _expandedShuttleKey = wasExpanded ? null : key;
                      if (wasExpanded) _lastHighlightedPlate = null;
                    });
                    widget.onRouteSelected(s.name);

                    // Highlight the next-arriving bus when expanding (not collapsing)
                    if (!wasExpanded && widget.onBusSelected != null) {
                      final allBuses = ref
                          .read(allActiveBusesProvider)
                          .valueOrNull;
                      final routeBuses = allBuses?[s.name] ?? [];
                      if (routeBuses.isNotEmpty) {
                        // Use the vehicle plate from shuttle arrival data (the next bus)
                        final nextPlate = s.arrivalTimeVehPlate;
                        final matchingBus = nextPlate.isNotEmpty
                            ? routeBuses.firstWhere(
                                (b) => b.vehPlate == nextPlate,
                                orElse: () => routeBuses.first,
                              )
                            : routeBuses.first;
                        _lastHighlightedPlate = matchingBus.vehPlate;
                        widget.onBusSelected!(s.name, matchingBus.vehPlate);
                      }
                    }
                  },
                );
              },
            ),
          ),
        ];
      },
      loading: () => <Widget>[
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ],
      error: (_, __) => <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorCard(
                message: 'Failed to load arrivals',
                onRetry: () => ref.invalidate(shuttlesProvider),
              ),
            ),
          ),
        ),
      ],
    );

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stop.stopDisplayName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DistanceFormatter.format(widget.stop.distanceMeters)} • ${widget.stop.walkingMinutes} min walk',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Directions button
                GestureDetector(
                  onTap: () {
                    final building = Building(
                      elementId: widget.stop.stopName,
                      name: widget.stop.stopDisplayName,
                      address: '',
                      postal: '',
                      latitude: widget.stop.latitude,
                      longitude: widget.stop.longitude,
                    );
                    ref
                        .read(navigationStateProvider.notifier)
                        .selectDestination(building);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions,
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedFavoriteIcon(
                  isFavorite: isFavorite,
                  color: isFavorite ? colors.primary : colors.textMuted,
                  onTap: () => ref
                      .read(favoriteStopsProvider.notifier)
                      .toggle(widget.stop.stopName),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Divider(height: 1, color: colors.borderLight),
          ),
        ),
        // Shuttle arrivals
        ...contentSlivers,
      ],
    );
  }
}

// ─── Shuttle Arrival Row (detail view) ────────────────────────

class _ShuttleArrivalRow extends ConsumerWidget {
  final Shuttle shuttle;
  final bool isExpanded;
  final String? currentStopCode;
  final void Function(double lat, double lng, String stopCode)? onCenterMap;
  final VoidCallback onTap;

  const _ShuttleArrivalRow({
    super.key,
    required this.shuttle,
    this.isExpanded = false,
    this.currentStopCode,
    this.onCenterMap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nusColors;
    final eta = EtaFormatter.format(shuttle.arrivalTime);
    final nextEta = EtaFormatter.format(shuttle.nextArrivalTime);
    final routeColor = RouteBadge.colorForRoute(shuttle.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PressableScale(
            onTap: onTap,
            child: SelectableCard(
              isSelected: isExpanded,
              accentColor: routeColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  RouteBadge(routeCode: shuttle.name),
                  const SizedBox(width: 12),
                  Text(
                    eta,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: eta == 'Arriving'
                          ? colors.success
                          : colors.primary,
                    ),
                  ),
                  if (nextEta != 'N/A') ...[
                    const SizedBox(width: 8),
                    Text(
                      '• $nextEta',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (shuttle.towards != null)
                    Flexible(
                      child: Text(
                        shuttle.towards!,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded stops section
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? _ExpandedStopsSection(
                    routeCode: shuttle.name,
                    routeColor: routeColor,
                    selectedStopCode: currentStopCode,
                    onCenterMap: onCenterMap,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── Expanded Stops Section ───────────────────────────────────

class _ExpandedStopsSection extends ConsumerWidget {
  final String routeCode;
  final Color routeColor;
  final String? selectedStopCode;
  final void Function(double lat, double lng, String stopCode)? onCenterMap;

  const _ExpandedStopsSection({
    required this.routeCode,
    required this.routeColor,
    this.selectedStopCode,
    this.onCenterMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nusColors;
    final pickupPoints = ref.watch(pickupPointsProvider(routeCode));
    final allBuses = ref.watch(allActiveBusesProvider);

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: pickupPoints.when(
        data: (points) {
          if (points.isEmpty) {
            return Text(
              'No stop information available',
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pin_drop, size: 14, color: routeColor),
                  const SizedBox(width: 6),
                  Text(
                    'Stops',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: routeColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PickupPointsList(
                points: points,
                routeCode: routeCode,
                selectedStopCode: selectedStopCode,
                activeBuses: allBuses.valueOrNull?[routeCode],
                onStopTapped: onCenterMap != null
                    ? (stop) =>
                          onCenterMap!(stop.lat, stop.lng, stop.busstopcode)
                    : null,
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) => ErrorCard(
          message: 'Failed to load stops',
          onRetry: () => ref.invalidate(pickupPointsProvider(routeCode)),
        ),
      ),
    );
  }
}
