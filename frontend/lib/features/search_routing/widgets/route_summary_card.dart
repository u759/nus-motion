import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/state/providers.dart';

class RouteSummaryCard extends ConsumerWidget {
  final RoutePlanResult route;
  final bool isSelected;
  final VoidCallback? onTap;

  const RouteSummaryCard({
    super.key,
    required this.route,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busLegs = route.legs.where((l) => l.mode == 'BUS').toList();
    final walkLegs = route.legs.where((l) => l.mode == 'WALK').toList();

    // Resolve the first bus leg's stop code for live arrival lookup
    final firstBusLeg = busLegs.isNotEmpty ? busLegs.first : null;
    String? stopCode;
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
    String? liveEta;
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.infoBg : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: total time + live ETA + badge
            Row(
              children: [
                Text(
                  '${route.totalMinutes} min',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (liveEta != null) ...[
                  const SizedBox(width: 10),
                  _LiveEtaChip(
                    eta: liveEta!,
                    routeCode: firstBusLeg?.routeCode ?? '',
                  ),
                ],
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'FASTEST',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Route visual: walk → bus → transfer → bus → walk
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (walkLegs.isNotEmpty && route.legs.first.mode == 'WALK')
                  _LegChip(
                    icon: Icons.directions_walk,
                    label: '${route.legs.first.minutes} min',
                  ),
                for (int i = 0; i < busLegs.length; i++) ...[
                  if (i > 0 ||
                      (walkLegs.isNotEmpty && route.legs.first.mode == 'WALK'))
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                  RouteBadge(routeCode: busLegs[i].routeCode ?? 'BUS'),
                  Text(
                    ' ${busLegs[i].minutes ?? 0} min',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (walkLegs.isNotEmpty && route.legs.last.mode == 'WALK') ...[
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  _LegChip(
                    icon: Icons.directions_walk,
                    label: '${route.legs.last.minutes} min',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Leg-by-leg summary
            for (final leg in busLegs)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      size: 14,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        leg.instruction,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.swap_horiz,
                  label:
                      '${route.transfers} transfer${route.transfers != 1 ? 's' : ''}',
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.directions_walk,
                  label: '${route.walkingMinutes} min walk',
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.schedule,
                  label: '${route.waitingMinutes} min wait',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveEtaChip extends StatelessWidget {
  final String eta;
  final String routeCode;

  const _LiveEtaChip({required this.eta, required this.routeCode});

  @override
  Widget build(BuildContext context) {
    final isArriving = eta.toLowerCase() == 'arr' || eta == '-';
    final displayText = isArriving ? 'Arriving' : '$eta min';
    final color = isArriving ? AppColors.success : AppColors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulseDot(color: color),
        const SizedBox(width: 5),
        Text(
          '$routeCode $displayText',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _LegChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LegChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
