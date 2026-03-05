import 'package:flutter/material.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/route_leg.dart';
import 'package:frontend/data/models/route_plan_result.dart';

/// Map well-known route codes to colours (matches design badges).
Color _badgeColor(String code) {
  final c = code.toUpperCase();
  if (c.startsWith('A')) return AppTheme.primary;
  if (c.startsWith('D')) return Colors.orange;
  if (c.startsWith('K')) return const Color(0xFF8B5CF6);
  if (c.startsWith('E')) return AppTheme.success;
  if (c.startsWith('B')) return AppTheme.error;
  return AppTheme.textMuted;
}

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.result,
    this.dimmed = false,
    this.onViewSteps,
  });

  final RoutePlanResult result;

  /// When true the card is rendered at 80 % opacity (secondary route).
  final bool dimmed;
  final VoidCallback? onViewSteps;

  List<String> get _busRouteCodes => result.legs
      .where((l) => l.mode == 'BUS' && l.routeCode != null)
      .map((l) => l.routeCode!)
      .toSet()
      .toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrival = TimeOfDay.now().replacing(
      hour:
          (TimeOfDay.now().hour +
              (TimeOfDay.now().minute + result.totalMinutes.round()) ~/ 60) %
          24,
      minute: (TimeOfDay.now().minute + result.totalMinutes.round()) % 60,
    );
    final arrivalStr =
        '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';

    Widget card = Container(
      decoration: BoxDecoration(
        color: AppTheme.neutralDark,
        border: Border.all(color: AppTheme.borderDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildBadges()),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.totalMinutes.round()} min',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dimmed ? AppTheme.textSecondary : AppTheme.primary,
                    ),
                  ),
                  Text(
                    'Arriving $arrivalStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing16),

          if (!dimmed) _buildTimeline(context),

          if (!dimmed) ...[
            const SizedBox(height: AppTheme.spacing16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onViewSteps,
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('View Step-by-Step'),
              ),
            ),
          ],

          if (dimmed) ...[
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                const Icon(Icons.info, color: AppTheme.textMuted, size: 20),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    _buildInfoSummary(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (dimmed) {
      card = Opacity(opacity: 0.8, child: card);
    }
    return card;
  }

  Widget _buildBadges() {
    final codes = _busRouteCodes;
    if (codes.isEmpty) return const SizedBox.shrink();
    final widgets = <Widget>[];
    for (var i = 0; i < codes.length; i++) {
      if (i > 0) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
            child: Icon(
              Icons.chevron_right,
              color: AppTheme.textMuted,
              size: 14,
            ),
          ),
        );
      }
      widgets.add(_RouteBadge(code: codes[i], color: _badgeColor(codes[i])));
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }

  Widget _buildTimeline(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 11,
          top: 8,
          bottom: 8,
          child: Container(width: 2, color: AppTheme.borderDark),
        ),
        Column(
          children: [
            for (var i = 0; i < result.legs.length; i++) ...[
              if (i > 0) const SizedBox(height: AppTheme.spacing12),
              _LegRow(
                key: ValueKey('leg_${i}_${result.legs[i].mode}'),
                leg: result.legs[i],
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _buildInfoSummary() {
    final busLegs = result.legs.where((l) => l.mode == 'BUS').toList();
    if (busLegs.isEmpty) return 'Walking route.';
    return 'Direct route via ${busLegs.first.instruction}.';
  }
}

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({required this.code, required this.color});
  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.spacing4),
      ),
      child: Text(
        code,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({super.key, required this.leg});
  final RouteLeg leg;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCircle(),
        const SizedBox(width: AppTheme.spacing16),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildCircle() {
    final (
      Color bg,
      Color border,
      IconData icon,
      Color iconColor,
      bool shadow,
    ) = switch (leg.mode) {
      'WALK' => (
        AppTheme.backgroundDark,
        AppTheme.primary,
        Icons.directions_walk,
        AppTheme.primary,
        false,
      ),
      'BUS' => (
        AppTheme.primary,
        AppTheme.primary,
        Icons.directions_bus,
        Colors.white,
        true,
      ),
      'TRANSFER' => (
        AppTheme.backgroundDark,
        Colors.orange,
        Icons.transfer_within_a_station,
        Colors.orange,
        false,
      ),
      'WAIT' => (
        AppTheme.backgroundDark,
        AppTheme.textMuted,
        Icons.schedule,
        AppTheme.textMuted,
        false,
      ),
      _ => (
        AppTheme.backgroundDark,
        AppTheme.borderDark,
        Icons.circle,
        AppTheme.textMuted,
        false,
      ),
    };

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Icon(icon, size: 14, color: iconColor),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                leg.instruction,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (leg.mode == 'BUS')
              Text(
                'Arriving in 2m',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ],
    );
  }

  String get _subtitle {
    final mins = leg.minutes.round();
    return switch (leg.mode) {
      'WALK' => '$mins min walk',
      'BUS' => '$mins min',
      'WAIT' || 'TRANSFER' => 'Wait time ~ $mins min',
      _ => '$mins min',
    };
  }
}
