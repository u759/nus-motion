import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/distance_formatter.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/widgets/pickup_points_list.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/core/widgets/selectable_card.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/core/utils/animations.dart';
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
    final shuttles = ref.watch(shuttlesProvider(stop.stopName));

    // Get first 2 arrivals with valid times (not '-' or empty)
    final arrivals = shuttles.maybeWhen(
      skipLoadingOnReload: true,
      data: (result) {
        return result.shuttles
            .where((s) => s.arrivalTime.isNotEmpty && s.arrivalTime != '-')
            .take(2)
            .toList();
      },
      orElse: () => <Shuttle>[],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bookmark-style location button — full height, flush left
            GestureDetector(
              onTap: onLocate,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
                child: const Center(
                  child: Icon(
                    Icons.my_location,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
            // Rest of card — tap to open detail view
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
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
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DistanceFormatter.format(stop.distanceMeters)} • ${stop.walkingMinutes} min walk',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      // Arrivals row — now inside the tappable GestureDetector
                      if (arrivals.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _ArrivalsRow(arrivals: arrivals),
                      ],
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
    return Row(
      children: [
        ...arrivals.asMap().entries.expand((entry) {
          final i = entry.key;
          final shuttle = entry.value;
          final eta = EtaFormatter.format(shuttle.arrivalTime);
          return [
            if (i > 0) const SizedBox(width: 12),
            RouteBadge(routeCode: shuttle.name, fontSize: 10),
            const SizedBox(width: 4),
            Text(
              eta,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ];
        }),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: AppColors.primary,
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DistanceFormatter.format(widget.stop.distanceMeters)} • ${widget.stop.walkingMinutes} min walk',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedFavoriteIcon(
                isFavorite: isFavorite,
                color: isFavorite ? AppColors.primary : AppColors.textMuted,
                onTap: () => ref
                    .read(favoriteStopsProvider.notifier)
                    .toggle(widget.stop.stopName),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
        // Shuttle arrivals
        Expanded(
          child: shuttles.when(
            skipLoadingOnReload: true,
            data: (result) {
              if (result.shuttles.isEmpty) {
                return const Center(
                  child: Text(
                    'No services at this time',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const Center(
              child: Text(
                'Failed to load arrivals',
                style: TextStyle(fontSize: 14, color: AppColors.error),
              ),
            ),
          ),
        ),
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
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                  if (nextEta != 'N/A') ...[
                    const SizedBox(width: 8),
                    Text(
                      '• $nextEta',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (shuttle.towards != null)
                    Flexible(
                      child: Text(
                        shuttle.towards!,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.textMuted,
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
    final pickupPoints = ref.watch(pickupPointsProvider(routeCode));
    final allBuses = ref.watch(allActiveBusesProvider);

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: pickupPoints.when(
        data: (points) {
          if (points.isEmpty) {
            return const Text(
              'No stop information available',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
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
        error: (_, __) => const Text(
          'Failed to load stops',
          style: TextStyle(fontSize: 13, color: AppColors.error),
        ),
      ),
    );
  }
}
