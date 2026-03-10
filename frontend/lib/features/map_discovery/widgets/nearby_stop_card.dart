import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/distance_formatter.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/state/providers.dart';

class NearbyStopCard extends ConsumerStatefulWidget {
  final NearbyStopResult stop;
  final String? selectedRoute;
  final ValueChanged<String>? onRouteSelected;

  const NearbyStopCard({
    super.key,
    required this.stop,
    this.selectedRoute,
    this.onRouteSelected,
  });

  @override
  ConsumerState<NearbyStopCard> createState() => _NearbyStopCardState();
}

class _NearbyStopCardState extends ConsumerState<NearbyStopCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    final shuttles = ref.watch(shuttlesProvider(widget.stop.stopName));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.infoBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stop.stopDisplayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
                  IconButton(
                    icon: Icon(
                      ref
                              .watch(favoriteStopsProvider.notifier)
                              .isFavorite(widget.stop.stopName)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color:
                          ref
                              .watch(favoriteStopsProvider.notifier)
                              .isFavorite(widget.stop.stopName)
                          ? colors.primary
                          : colors.textMuted,
                      size: 22,
                    ),
                    onPressed: () => ref
                        .read(favoriteStopsProvider.notifier)
                        .toggle(widget.stop.stopName),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: colors.textMuted,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable shuttle list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: shuttles.when(
              data: (result) {
                if (result.shuttles.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'No services at this time',
                      style: TextStyle(fontSize: 13, color: colors.textMuted),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      Divider(height: 1, color: colors.borderLight),
                      const SizedBox(height: 8),
                      ...result.shuttles
                          .take(6)
                          .map(
                            (s) => _ShuttleButton(
                              key: ValueKey(s.name + s.arrivalTimeVehPlate),
                              shuttle: s,
                              isSelected: widget.selectedRoute == s.name,
                              onTap: () => widget.onRouteSelected?.call(s.name),
                            ),
                          ),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Failed to load arrivals',
                  style: TextStyle(fontSize: 13, color: colors.error),
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class _ShuttleButton extends StatelessWidget {
  final Shuttle shuttle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShuttleButton({
    super.key,
    required this.shuttle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    final eta = EtaFormatter.format(shuttle.arrivalTime);
    final nextEta = EtaFormatter.format(shuttle.nextArrivalTime);
    final routeColor = RouteBadge.colorForRoute(shuttle.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? routeColor.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? routeColor.withValues(alpha: 0.3)
                    : colors.borderLight,
              ),
            ),
            child: Row(
              children: [
                RouteBadge(routeCode: shuttle.name),
                const SizedBox(width: 10),
                Text(
                  eta,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: eta == 'Arriving' ? colors.success : colors.primary,
                  ),
                ),
                if (nextEta != 'N/A') ...[
                  const SizedBox(width: 6),
                  Text(
                    '• $nextEta',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
                const Spacer(),
                if (shuttle.towards != null)
                  Text(
                    shuttle.towards!,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                const SizedBox(width: 8),
                Icon(
                  isSelected ? Icons.map : Icons.chevron_right,
                  size: 18,
                  color: isSelected ? routeColor : colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
