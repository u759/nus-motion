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
  if (c.startsWith('E')) return const Color(0xFF10B981);
  if (c.startsWith('B')) return const Color(0xFFEF4444);
  return const Color(0xFF64748B); // slate fallback
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

  // Extract unique bus route codes for badge row.
  List<String> get _busRouteCodes => result.legs
      .where((l) => l.mode == 'BUS' && l.routeCode != null)
      .map((l) => l.routeCode!)
      .toSet()
      .toList();

  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: badges + time ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildBadges()),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${result.totalMinutes.round()} min',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: dimmed
                          ? const Color(0xFFCBD5E1)
                          : AppTheme.primary,
                    ),
                  ),
                  Text(
                    'Arriving $arrivalStr',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Timeline ────────────────────────────────────────────
          if (!dimmed) _buildTimeline(),

          // ── "View Step-by-Step" button ──────────────────────────
          if (!dimmed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onViewSteps,
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('View Step-by-Step'),
              ),
            ),
          ],

          // ── Info line for dimmed card ────────────────────────────
          if (dimmed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info, color: AppTheme.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _buildInfoSummary(),
                    style: const TextStyle(
                      fontSize: 11,
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

  // ── Badge row ───────────────────────────────────────────────────────
  Widget _buildBadges() {
    final codes = _busRouteCodes;
    if (codes.isEmpty) return const SizedBox.shrink();
    final widgets = <Widget>[];
    for (var i = 0; i < codes.length; i++) {
      if (i > 0) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
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

  // ── Timeline ────────────────────────────────────────────────────────
  Widget _buildTimeline() {
    return Stack(
      children: [
        // Vertical connector
        Positioned(
          left: 11,
          top: 8,
          bottom: 8,
          child: Container(width: 2, color: AppTheme.borderDark),
        ),
        Column(
          children: [
            for (var i = 0; i < result.legs.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _LegRow(leg: result.legs[i]),
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

// ── Route badge chip ──────────────────────────────────────────────────

class _RouteBadge extends StatelessWidget {
  const _RouteBadge({required this.code, required this.color});
  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Single leg row with icon ──────────────────────────────────────────

class _LegRow extends StatelessWidget {
  const _LegRow({required this.leg});
  final RouteLeg leg;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCircle(),
        const SizedBox(width: 16),
        Expanded(child: _buildContent()),
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
        const Color(0xFF64748B),
        Icons.schedule,
        const Color(0xFF64748B),
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

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main instruction line
        Row(
          children: [
            Expanded(
              child: Text(
                leg.instruction,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (leg.mode == 'BUS')
              const Text(
                'Arriving in 2m',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4ADE80), // green-400
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        // Subtitle
        Text(
          _subtitle,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
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
