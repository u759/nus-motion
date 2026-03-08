import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/active_bus.dart';
import 'package:frontend/data/models/pickup_point.dart';

/// A timeline-style list of pickup points (bus stops) for a route.
class PickupPointsList extends StatefulWidget {
  const PickupPointsList({
    super.key,
    required this.points,
    required this.routeCode,
    this.selectedStopCode,
    this.activeBuses,
    this.onStopTapped,
    this.userLat,
    this.userLng,
  });

  final List<PickupPoint> points;
  final String routeCode;

  /// Stop code to highlight in the timeline (e.g., current stop being viewed)
  final String? selectedStopCode;

  /// Active buses to show as markers on the timeline
  final List<ActiveBus>? activeBuses;

  /// Callback when a stop is tapped (for centering map, etc.)
  final void Function(PickupPoint stop)? onStopTapped;

  /// User's current latitude (for showing user position on timeline)
  final double? userLat;

  /// User's current longitude (for showing user position on timeline)
  final double? userLng;

  /// Row height approximation for positioning bus markers.
  static const double _rowHeight = 36.0;

  @override
  State<PickupPointsList> createState() => _PickupPointsListState();
}

class _PickupPointsListState extends State<PickupPointsList> {
  final _rowKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String stopCode) =>
      _rowKeys.putIfAbsent(stopCode, () => GlobalKey());

  @override
  void didUpdateWidget(covariant PickupPointsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to highlighted stop when selectedStopCode changes
    if (widget.selectedStopCode != null &&
        widget.selectedStopCode != oldWidget.selectedStopCode) {
      _scrollToSelectedStop();
    }
  }

  void _scrollToSelectedStop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _rowKeys[widget.selectedStopCode];
      if (key?.currentContext == null) return;
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3, // Show stop slightly above center
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final routeColor = RouteBadge.colorForRoute(widget.routeCode);
    final sorted = [...widget.points]..sort((a, b) => a.seq.compareTo(b.seq));

    final rows = [
      for (int i = 0; i < sorted.length; i++)
        _PickupPointRow(
          key: _keyFor(sorted[i].busstopcode),
          index: i + 1,
          name: sorted[i].longName.isNotEmpty
              ? sorted[i].longName
              : sorted[i].pickupname,
          shortName: sorted[i].shortName,
          routeColor: routeColor,
          isFirst: i == 0,
          isLast: i == sorted.length - 1,
          isHighlighted: sorted[i].busstopcode == widget.selectedStopCode,
          onTap: widget.onStopTapped != null ? () => widget.onStopTapped!(sorted[i]) : null,
        ),
    ];

    // Check if we need any markers
    final hasActiveBuses =
        widget.activeBuses != null && widget.activeBuses!.isNotEmpty && sorted.length >= 2;
    final showUserMarker =
        widget.userLat != null && widget.userLng != null && sorted.length >= 2;

    // If no markers needed, return plain column
    if (!hasActiveBuses && !showUserMarker) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }

    // Calculate approximate total height
    final totalHeight = sorted.length * PickupPointsList._rowHeight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
        // Bus markers overlay
        if (hasActiveBuses)
          for (final bus in widget.activeBuses!)
            _TimelineBusMarker(
              bus: bus,
              progress: _calculateBusProgress(bus, sorted),
              totalHeight: totalHeight,
              routeColor: routeColor,
            ),
        // User position marker
        if (showUserMarker)
          _TimelineUserMarker(
            progress: _calculateUserProgress(widget.userLat!, widget.userLng!, sorted),
            totalHeight: totalHeight,
          ),
      ],
    );
  }

  /// Calculates the progress (0.0 to 1.0) of the user along the route.
  ///
  /// Uses Haversine distance to find which segment the user is on,
  /// then calculates progress as a distance ratio within that segment.
  double _calculateUserProgress(
    double lat,
    double lng,
    List<PickupPoint> sortedPoints,
  ) {
    if (sortedPoints.length < 2) return 0.0;

    final distances = sortedPoints
        .map((p) => _haversineDistance(lat, lng, p.lat, p.lng))
        .toList();

    int bestSegIdx = 0;
    double minSum = double.infinity;

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final d1 = distances[i];
      final d2 = distances[i + 1];
      final sum = d1 + d2;
      if (sum < minSum) {
        minSum = sum;
        bestSegIdx = i;
      }
    }

    final d1 = distances[bestSegIdx];
    final d2 = distances[bestSegIdx + 1];
    final progressInSegment = d1 / (d1 + d2);

    final segmentLength = 1.0 / (sortedPoints.length - 1);
    return (bestSegIdx + progressInSegment) * segmentLength;
  }

  /// Calculates the progress (0.0 to 1.0) of a bus along the route.
  ///
  /// Uses Haversine distance to find which segment the bus is on,
  /// then calculates progress as a distance ratio within that segment.
  double _calculateBusProgress(ActiveBus bus, List<PickupPoint> sortedPoints) {
    if (sortedPoints.length < 2) return 0.0;

    // Calculate distance from bus to each stop
    final distances = sortedPoints
        .map((p) => _haversineDistance(bus.lat, bus.lng, p.lat, p.lng))
        .toList();

    // Find the segment where bus is located (minimum sum of distances)
    int bestSegIdx = 0;
    double minSum = double.infinity;

    for (int i = 0; i < sortedPoints.length - 1; i++) {
      final d1 = distances[i];
      final d2 = distances[i + 1];
      final sum = d1 + d2;
      if (sum < minSum) {
        minSum = sum;
        bestSegIdx = i;
      }
    }

    // Calculate progress within segment
    final d1 = distances[bestSegIdx];
    final d2 = distances[bestSegIdx + 1];
    final progressInSegment =
        d1 / (d1 + d2); // 0 = at first stop, 1 = at second

    // Convert to global progress (0.0 to 1.0 across all stops)
    final segmentLength = 1.0 / (sortedPoints.length - 1);
    return (bestSegIdx + progressInSegment) * segmentLength;
  }

  /// Haversine distance in meters between two lat/lng points.
  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * math.pi / 180;
}

// ─── Pickup Point Row ────────────────────────────────────────

class _PickupPointRow extends StatefulWidget {
  final int index;
  final String name;
  final String shortName;
  final Color routeColor;
  final bool isFirst;
  final bool isLast;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const _PickupPointRow({
    super.key,
    required this.index,
    required this.name,
    required this.shortName,
    required this.routeColor,
    this.isFirst = false,
    this.isLast = false,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  State<_PickupPointRow> createState() => _PickupPointRowState();
}

class _PickupPointRowState extends State<_PickupPointRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  late final Animation<double> _flashAnim;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flashAnim = CurvedAnimation(
      parent: _flashController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Trigger flash animation: quick flash in, then fade out
    _flashController.forward(from: 0).then((_) {
      if (mounted) _flashController.reverse();
    });
    // Call the original tap handler
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _flashAnim,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: widget.routeColor.withValues(
                alpha: 0.2 * _flashAnim.value,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: child,
          );
        },
        child: IntrinsicHeight(
          child: Container(
            decoration: widget.isHighlighted
                ? BoxDecoration(
                    color: widget.routeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomPaint(
                  painter: _TimelinePainter(
                    routeColor: widget.routeColor,
                    isFirst: widget.isFirst,
                    isLast: widget.isLast,
                    isFilled: widget.isHighlighted,
                  ),
                  child: const SizedBox(width: 30),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        if (widget.isHighlighted)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.location_on,
                              size: 14,
                              color: widget.routeColor,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: widget.isHighlighted
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: widget.isHighlighted
                                      ? widget.routeColor
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (widget.shortName.isNotEmpty &&
                                  widget.shortName != widget.name)
                                Text(
                                  widget.shortName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Timeline Painter ────────────────────────────────────────

class _TimelinePainter extends CustomPainter {
  final Color routeColor;
  final bool isFirst;
  final bool isLast;
  final bool isFilled;

  _TimelinePainter({
    required this.routeColor,
    required this.isFirst,
    required this.isLast,
    this.isFilled = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const circleRadius = 5.0;
    const borderWidth = 2.0;
    const lineWidth = 2.0;

    final linePaint = Paint()
      ..color = routeColor.withValues(alpha: 0.2)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Draw vertical line segments
    if (!isFirst) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, centerY - circleRadius),
        linePaint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, centerY + circleRadius),
        Offset(centerX, size.height),
        linePaint,
      );
    }

    // Draw circle fill
    final fillPaint = Paint()
      ..color = (isFirst || isLast || isFilled) ? routeColor : AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), circleRadius, fillPaint);

    // Draw circle border
    final borderPaint = Paint()
      ..color = routeColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
      Offset(centerX, centerY),
      circleRadius - borderWidth / 2,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      routeColor != old.routeColor ||
      isFirst != old.isFirst ||
      isLast != old.isLast ||
      isFilled != old.isFilled;
}

// ─── Timeline Bus Marker ─────────────────────────────────────

class _TimelineBusMarker extends StatelessWidget {
  final ActiveBus bus;
  final double progress; // 0.0 to 1.0
  final double totalHeight;
  final Color routeColor;

  const _TimelineBusMarker({
    required this.bus,
    required this.progress,
    required this.totalHeight,
    required this.routeColor,
  });

  @override
  Widget build(BuildContext context) {
    // Center of timeline column is at x=15 (width 30 / 2)
    const timelineCenterX = 15.0;
    const markerSize = 20.0;

    // Calculate y position based on progress
    // Account for row padding (first circle is at ~rowHeight/2)
    final halfRowHeight = PickupPointsList._rowHeight / 2;
    final effectiveHeight = totalHeight - PickupPointsList._rowHeight;
    final top = halfRowHeight + (progress * effectiveHeight) - (markerSize / 2);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: timelineCenterX - markerSize / 2,
      top: top,
      width: markerSize,
      height: markerSize,
      child: Container(
        decoration: BoxDecoration(
          color: routeColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(Icons.directions_bus, color: Colors.white, size: 12),
      ),
    );
  }
}

// ─── Timeline User Marker ─────────────────────────────────────

class _TimelineUserMarker extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double totalHeight;

  const _TimelineUserMarker({
    required this.progress,
    required this.totalHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Center of timeline column is at x=15 (width 30 / 2)
    const timelineCenterX = 15.0;
    const markerSize = 20.0;

    // Calculate y position based on progress
    // Account for row padding (first circle is at ~rowHeight/2)
    final halfRowHeight = PickupPointsList._rowHeight / 2;
    final effectiveHeight = totalHeight - PickupPointsList._rowHeight;
    final top = halfRowHeight + (progress * effectiveHeight) - (markerSize / 2);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      left: timelineCenterX - markerSize / 2,
      top: top.clamp(0, totalHeight - markerSize),
      width: markerSize,
      height: markerSize,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 12),
      ),
    );
  }
}
