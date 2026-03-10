import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/active_bus.dart';
import 'package:frontend/state/providers.dart';

/// Callback with (routeCode, bus) for selecting a specific bus on the map.
typedef BusSelectedCallback = void Function(String route, ActiveBus bus);

class BusesTab extends ConsumerWidget {
  final String? selectedBusPlate;
  final BusSelectedCallback onBusSelected;

  const BusesTab({
    super.key,
    this.selectedBusPlate,
    required this.onBusSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBuses = ref.watch(allActiveBusesProvider);

    return allBuses.when(
      skipLoadingOnReload: true,
      data: (busMap) {
        final entries = <_BusEntry>[];
        for (final entry in busMap.entries) {
          for (final bus in entry.value) {
            entries.add(_BusEntry(route: entry.key, bus: bus));
          }
        }
        if (entries.isEmpty) {
          return const EmptyState(
            icon: Icons.directions_bus,
            title: 'No active buses',
            subtitle: 'No bus services are running right now',
          );
        }
        // Sort by route then plate
        entries.sort((a, b) {
          final c = a.route.compareTo(b.route);
          return c != 0 ? c : a.bus.vehPlate.compareTo(b.bus.vehPlate);
        });
        // Pin selected bus to the top of the list
        if (selectedBusPlate != null) {
          final idx = entries.indexWhere(
            (e) => e.bus.vehPlate == selectedBusPlate,
          );
          if (idx > 0) {
            final item = entries.removeAt(idx);
            entries.insert(0, item);
          }
        }

        return ListView.builder(
          key: const PageStorageKey('buses_tab_list'),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            final isSelected = selectedBusPlate == e.bus.vehPlate;
            return FadeSlideIn(
              key: ValueKey('fade_${e.bus.vehPlate}'),
              delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
              child: _BusItem(
                key: ValueKey(e.bus.vehPlate),
                entry: e,
                isSelected: isSelected,
                onTap: () => onBusSelected(e.route, e.bus),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Builder(
            builder: (context) {
              final colors = context.nusColors;
              return Text(
                'Failed to load buses',
                style: TextStyle(color: colors.textMuted),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BusEntry {
  final String route;
  final ActiveBus bus;
  const _BusEntry({required this.route, required this.bus});
}

class _BusItem extends StatelessWidget {
  final _BusEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _BusItem({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    final bus = entry.bus;
    final routeColor = RouteBadge.colorForRoute(entry.route);
    final load = bus.loadInfo;

    final occupancyPct = load != null ? (load.occupancy * 100).round() : null;
    final capacityText = load != null
        ? '${load.ridership}/${load.capacity}'
        : '—';
    final crowdText = load?.crowdLevel ?? 'Unknown';

    final selectedBg = Color.alphaBlend(
      routeColor.withValues(alpha: 0.06),
      colors.surface,
    );
    final selectedBorder = Color.alphaBlend(
      routeColor.withValues(alpha: 0.3),
      colors.surface,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedBorder : colors.borderLight,
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              RouteBadge(routeCode: entry.route, fontSize: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plate number
                    Text(
                      bus.vehPlate,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Crowd + Speed
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.speed,
                          label: '${bus.speed} km/h',
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.people_outline,
                          label: capacityText,
                        ),
                        if (occupancyPct != null) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.pie_chart_outline,
                            label: '$occupancyPct%',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedSwitcherDefaults(
                    child: Container(
                      key: ValueKey(crowdText),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _crowdColor(
                          context,
                          crowdText,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        crowdText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _crowdColor(context, crowdText),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(
                isSelected ? Icons.map : Icons.chevron_right,
                size: 18,
                color: isSelected ? routeColor : colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _crowdColor(BuildContext context, String level) {
    final colors = context.nusColors;
    switch (level.toLowerCase()) {
      case 'low':
        return colors.success;
      case 'medium':
        return colors.warning;
      case 'high':
        return colors.error;
      default:
        return colors.textMuted;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colors.textMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
      ],
    );
  }
}
