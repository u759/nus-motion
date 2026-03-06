import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/widgets/pickup_points_list.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/pickup_point.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/data/models/route_leg.dart';
import 'package:frontend/state/providers.dart';

/// Route detail chrome rendered above the main discovery map during preview.
class RouteDetailView extends ConsumerStatefulWidget {
  final RoutePlanResult route;
  final Position? userPosition;
  final VoidCallback onBack;
  final VoidCallback? onRouteFocusRequested;

  const RouteDetailView({
    super.key,
    required this.route,
    required this.userPosition,
    required this.onBack,
    this.onRouteFocusRequested,
  });

  @override
  ConsumerState<RouteDetailView> createState() => _RouteDetailViewState();
}

class _RouteDetailViewState extends ConsumerState<RouteDetailView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  /// Tracks which bus leg indices are currently expanded to show stops.
  final Set<int> _expandedLegs = {};

  void _toggleLegExpansion(int index) {
    setState(() {
      if (_expandedLegs.contains(index)) {
        _expandedLegs.remove(index);
      } else {
        _expandedLegs.add(index);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    widget.onRouteFocusRequested?.call();
  }

  @override
  void didUpdateWidget(covariant RouteDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) {
      widget.onRouteFocusRequested?.call();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topInset = MediaQuery.of(context).padding.top;
    final panelHeight = screenHeight * 0.45;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Back button floats at top
          Positioned(top: topInset + 12, left: 16, child: _buildBackButton()),
          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: panelHeight,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildPanelHeader(),
                  const Divider(height: 1, color: AppColors.borderLight),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: _buildJourneyTimeline(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: widget.onBack,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: AppColors.textPrimary,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          ..._buildRouteBadges(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.route.to,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${widget.route.totalMinutes} min',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRouteBadges() {
    final badges = <Widget>[];
    final busLegs = widget.route.legs.where((leg) => leg.isBus).toList();

    for (int i = 0; i < busLegs.length; i++) {
      if (busLegs[i].routeCode != null) {
        if (i > 0) {
          badges.add(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.textMuted,
              ),
            ),
          );
        }
        badges.add(RouteBadge(routeCode: busLegs[i].routeCode!, fontSize: 11));
      }
    }

    if (badges.isEmpty) {
      badges.add(
        const Icon(
          Icons.directions_walk,
          size: 20,
          color: AppColors.textSecondary,
        ),
      );
      badges.add(const SizedBox(width: 6));
      badges.add(
        const Text(
          'Walking only',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return badges;
  }

  /// Determines which leg index is currently active based on user position.
  /// Returns null if position is unavailable or cannot be determined.
  int? _getCurrentLegIndex() {
    if (widget.userPosition == null) return null;

    final legs = widget.route.legs;
    final userLat = widget.userPosition!.latitude;
    final userLng = widget.userPosition!.longitude;

    // Find first bus leg to get boarding stop coordinates
    RouteLeg? firstBusLeg;
    int busLegIndex = -1;
    for (int i = 0; i < legs.length; i++) {
      if (legs[i].isBus) {
        firstBusLeg = legs[i];
        busLegIndex = i;
        break;
      }
    }

    if (firstBusLeg == null) {
      // Walking only route - highlight the first walk leg
      final walkIdx = legs.indexWhere((l) => l.isWalk);
      return walkIdx >= 0 ? walkIdx : null;
    }

    // Boarding stop coordinates (fromLat/fromLng on the bus leg)
    final stopLat = firstBusLeg.fromLat;
    final stopLng = firstBusLeg.fromLng;

    if (stopLat == null || stopLng == null) return null;

    // Calculate distance to boarding stop
    final distanceToStop = _haversineDistance(
      userLat,
      userLng,
      stopLat,
      stopLng,
    );

    const arrivalThreshold = 15.0; // meters

    // If within threshold of stop, we're in waiting phase
    if (distanceToStop <= arrivalThreshold) {
      // Find the WAIT leg index
      final waitIndex = legs.indexWhere((l) => l.isWait);
      return waitIndex >= 0 ? waitIndex : busLegIndex;
    }

    // Check if we've left the stop (started riding)
    // Find destination coordinates from the last bus leg
    RouteLeg? lastBusLeg;
    for (int i = legs.length - 1; i >= 0; i--) {
      if (legs[i].isBus) {
        lastBusLeg = legs[i];
        break;
      }
    }

    if (lastBusLeg?.toLat != null && lastBusLeg?.toLng != null) {
      final distanceToDest = _haversineDistance(
        userLat,
        userLng,
        lastBusLeg!.toLat!,
        lastBusLeg.toLng!,
      );

      // If we're closer to destination than boarding stop, we're riding
      if (distanceToDest < distanceToStop &&
          distanceToStop > arrivalThreshold * 2) {
        return busLegIndex;
      }
    }

    // Otherwise, still walking
    final walkIdx = legs.indexWhere((l) => l.isWalk);
    return walkIdx >= 0 ? walkIdx : null;
  }

  /// Calculates the Haversine distance between two coordinate points in meters.
  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371e3; // Earth radius in meters
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Widget _buildJourneyTimeline() {
    final legs = widget.route.legs;
    if (legs.isEmpty) {
      return const Center(
        child: Text(
          'No route details available',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final currentLegIndex = _getCurrentLegIndex();

    return Column(
      children: [
        for (int i = 0; i < legs.length; i++) ...[
          _buildTimelineLeg(
            legs[i],
            i,
            isLast: i == legs.length - 1,
            isActive: currentLegIndex == i,
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineLeg(
    RouteLeg leg,
    int index, {
    bool isLast = false,
    bool isActive = false,
  }) {
    final isWalk = leg.isWalk;
    final isWait = leg.isWait;
    final isBus = leg.isBus;
    final isExpanded = _expandedLegs.contains(index);
    final color = isWalk
        ? AppColors.textMuted
        : isWait
        ? AppColors.warning
        : (leg.routeCode != null
              ? RouteBadge.colorForRoute(leg.routeCode!)
              : AppColors.primary);
    final title = _formatLegTitle(leg, index);
    final subtitle = leg.isWait && leg.instruction == title
        ? null
        : leg.instruction;

    final legContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leg.isBus && leg.routeCode != null) ...[
              RouteBadge(routeCode: leg.routeCode!, fontSize: 10),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            // Show expand/collapse icon for bus legs
            if (isBus) ...[
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (leg.minutes != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${leg.minutes} min',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        // Show expanded stops for bus legs
        if (isBus && isExpanded && leg.routeCode != null)
          _buildExpandedStops(leg, color, index),
      ],
    );

    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.success.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppColors.success : color,
                  width: 2,
                ),
              ),
              child: Icon(
                isWalk
                    ? Icons.directions_walk
                    : isWait
                    ? Icons.schedule
                    : Icons.directions_bus,
                size: 14,
                color: isActive ? AppColors.success : color,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: isExpanded ? 180 : 50,
                color: AppColors.border,
              ),
          ],
        ),

        const SizedBox(width: 12),

        // Leg content (tappable for bus legs)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: isBus
                ? GestureDetector(
                    onTap: () => _toggleLegExpansion(index),
                    behavior: HitTestBehavior.opaque,
                    child: legContent,
                  )
                : legContent,
          ),
        ),
      ],
    );

    // Wrap with highlight container if active (gradient overlay, no border)
    if (isActive) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              AppColors.success.withValues(alpha: 0.15),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: rowContent,
      );
    }

    return rowContent;
  }

  /// Builds the expanded list of stops between fromStop and toStop for a bus leg.
  Widget _buildExpandedStops(RouteLeg leg, Color routeColor, int legIndex) {
    if (leg.routeCode == null) return const SizedBox.shrink();

    final pickupPointsAsync = ref.watch(pickupPointsProvider(leg.routeCode!));

    return pickupPointsAsync.when(
      data: (points) {
        final filteredPoints = _getStopsBetween(
          points,
          leg.fromStop,
          leg.toStop,
        );
        final displayPoints = filteredPoints.isNotEmpty
            ? filteredPoints
            : points;

        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: PickupPointsList(
            points: displayPoints,
            routeCode: leg.routeCode!,
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: routeColor),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Filters pickup points to only those between fromStop and toStop (inclusive).
  List<PickupPoint> _getStopsBetween(
    List<PickupPoint> points,
    String? fromStop,
    String? toStop,
  ) {
    if (fromStop == null || toStop == null || points.isEmpty) {
      return [];
    }

    // Sort by sequence
    final sorted = [...points]..sort((a, b) => a.seq.compareTo(b.seq));

    // Find indices of from/to stops by matching name
    int fromIdx = -1;
    int toIdx = -1;

    for (int i = 0; i < sorted.length; i++) {
      final name = sorted[i].longName.isNotEmpty
          ? sorted[i].longName
          : sorted[i].pickupname;
      if (fromIdx == -1 && _matchStopName(name, fromStop)) {
        fromIdx = i;
      }
      if (_matchStopName(name, toStop)) {
        toIdx = i;
      }
    }

    if (fromIdx == -1 || toIdx == -1 || fromIdx >= toIdx) {
      return [];
    }

    return sorted.sublist(fromIdx, toIdx + 1);
  }

  /// Checks if stop name matches (case-insensitive, handles partial matches).
  bool _matchStopName(String pointName, String legStopName) {
    final a = pointName.toLowerCase().trim();
    final b = legStopName.toLowerCase().trim();
    return a == b || a.contains(b) || b.contains(a);
  }

  String _formatLegTitle(RouteLeg leg, int index) {
    if (leg.isWalk) {
      if (index == 0) return 'Walk to ${leg.toStop ?? "bus stop"}';
      if (leg.toStop != null) return 'Walk to ${leg.toStop}';
      return 'Walk to destination';
    }

    if (leg.isWait) {
      return leg.instruction;
    }

    return 'Take ${leg.routeCode ?? "bus"} to ${leg.toStop ?? "stop"}';
  }
}
