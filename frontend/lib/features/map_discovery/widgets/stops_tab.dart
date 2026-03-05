import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/distance_formatter.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/state/providers.dart';

class StopsTab extends ConsumerStatefulWidget {
  final List<NearbyStopResult> stops;
  final String? selectedStop;
  final String? selectedRoute;
  final ValueChanged<String> onStopSelected;
  final ValueChanged<String> onRouteSelected;

  const StopsTab({
    super.key,
    required this.stops,
    this.selectedStop,
    this.selectedRoute,
    required this.onStopSelected,
    required this.onRouteSelected,
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
            )
          : _StopListView(
              key: const ValueKey('stop_list'),
              stops: widget.stops,
              onStopSelected: widget.onStopSelected,
            ),
    );
  }
}

// ─── Stop List View ───────────────────────────────────────────

class _StopListView extends StatelessWidget {
  final List<NearbyStopResult> stops;
  final ValueChanged<String> onStopSelected;

  const _StopListView({
    super.key,
    required this.stops,
    required this.onStopSelected,
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

  const _StopCard({required this.stop, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.directions_bus,
                color: AppColors.textSecondary,
                size: 18,
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
      ),
    );
  }
}

// ─── Stop Detail View (full panel) ────────────────────────────

class _StopDetailView extends ConsumerWidget {
  final NearbyStopResult stop;
  final String? selectedRoute;
  final ValueChanged<String> onRouteSelected;
  final VoidCallback onBack;

  const _StopDetailView({
    super.key,
    required this.stop,
    this.selectedRoute,
    required this.onRouteSelected,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuttles = ref.watch(shuttlesProvider(stop.stopName));
    final isFavorite = ref.watch(favoriteStopsProvider).contains(stop.stopName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
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
                      stop.stopDisplayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DistanceFormatter.format(stop.distanceMeters)} • ${stop.walkingMinutes} min walk',
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
                    .toggle(stop.stopName),
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
                  return _ShuttleArrivalRow(
                    key: ValueKey('${s.name}_$index'),
                    shuttle: s,
                    isSelected: selectedRoute == s.name,
                    onTap: () => onRouteSelected(s.name),
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

class _ShuttleArrivalRow extends StatelessWidget {
  final Shuttle shuttle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShuttleArrivalRow({
    super.key,
    required this.shuttle,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eta = EtaFormatter.format(shuttle.arrivalTime);
    final nextEta = EtaFormatter.format(shuttle.nextArrivalTime);
    final routeColor = RouteBadge.colorForRoute(shuttle.name);

    final selectedBg = Color.alphaBlend(
      routeColor.withValues(alpha: 0.06),
      AppColors.surface,
    );
    final selectedBorder = Color.alphaBlend(
      routeColor.withValues(alpha: 0.3),
      AppColors.surface,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? selectedBorder : AppColors.borderLight,
            ),
          ),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
