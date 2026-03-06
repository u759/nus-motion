import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

/// An animated overlay widget for a single bus marker.
///
/// Uses [AnimatedPositioned] with ease-in-out curves for smooth transitions
/// when bus positions update. Renders on Flutter's compositing layer (GPU).
class BusOverlayMarker extends StatelessWidget {
  const BusOverlayMarker({
    super.key,
    required this.screenX,
    required this.screenY,
    required this.occupancy,
    required this.direction,
    required this.routeColor,
    required this.isSelected,
    required this.onTap,
    this.plate,
    this.speed,
    this.shouldAnimate = true,
  });

  final double screenX;
  final double screenY;
  final double occupancy;
  final double direction;
  final Color routeColor;
  final bool isSelected;
  final VoidCallback onTap;
  final String? plate;
  final int? speed;

  /// When true, animate position changes (bus moved). When false, snap instantly (camera moved).
  final bool shouldAnimate;

  static const double _normalSize = 44.0;
  static const double _selectedSize = 56.0;
  static const Duration _animDuration = Duration(milliseconds: 500);
  static const Curve _animCurve = Curves.easeInOut;

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? _selectedSize : _normalSize;
    // Position centered on screen coordinate
    final left = screenX - size / 2;
    final top = screenY - size / 2;

    // Use Duration.zero when shouldAnimate is false (camera movement) to prevent lag
    final animDuration = shouldAnimate ? _animDuration : Duration.zero;

    return AnimatedPositioned(
      duration: animDuration,
      curve: _animCurve,
      left: left,
      top: top,
      width: isSelected
          ? size + 100
          : size, // Extra width for label when selected
      height: size,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(isSelected ? size + 100 : size, size),
            painter: _BusMarkerPainter(
              occupancy: occupancy,
              direction: direction,
              routeColor: routeColor,
              isSelected: isSelected,
              plate: plate,
              speed: speed,
            ),
          ),
        ),
      ),
    );
  }
}

class _BusMarkerPainter extends CustomPainter {
  _BusMarkerPainter({
    required this.occupancy,
    required this.direction,
    required this.routeColor,
    required this.isSelected,
    this.plate,
    this.speed,
  });

  final double occupancy;
  final double direction;
  final Color routeColor;
  final bool isSelected;
  final String? plate;
  final int? speed;

  /// Computes the occupancy gradient color (green → yellow → red)
  static Color getOccupancyColor(double occupancy) {
    final occ = occupancy.clamp(0.0, 1.0);
    if (occ <= 0.5) {
      return Color.lerp(
        const Color(0xFF4CAF50),
        const Color(0xFFFFC107),
        occ * 2,
      )!;
    } else {
      return Color.lerp(
        const Color(0xFFFFC107),
        const Color(0xFFF44336),
        (occ - 0.5) * 2,
      )!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (isSelected) {
      _paintSelected(canvas, size);
    } else {
      _paintNormal(canvas, size);
    }
  }

  void _paintNormal(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const circleRadius = 14.0;
    const arcStroke = 2.5;

    // Drop shadow
    canvas.drawCircle(
      center + const Offset(0, 1.0),
      circleRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // White surface circle
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Occupancy arc
    final occ = occupancy.clamp(0.0, 1.0);
    if (occ > 0.01) {
      const double startAngle = math.pi / 2; // 6 o'clock
      final double sweepAngle = 2 * math.pi * occ;
      final arcRect = Rect.fromCircle(center: center, radius: circleRadius);
      final arcColor = getOccupancyColor(occ);

      canvas.drawArc(
        arcRect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = arcColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = arcStroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Direction triangle
    _paintDirectionTriangle(
      canvas,
      center,
      circleRadius,
      6.0,
      4.0,
      2.0,
      AppColors.primary,
    );

    // Bus icon
    _paintBusIcon(canvas, center, 16.0, const Color(0xFF424242));
  }

  void _paintSelected(Canvas canvas, Size size) {
    const circleRadius = 17.0;
    const arcStroke = 3.0;
    final circleCenter = Offset(circleRadius + 10, size.height / 2);

    // Drop shadow
    canvas.drawCircle(
      circleCenter + const Offset(0, 1.5),
      circleRadius,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );

    // Blue filled circle
    canvas.drawCircle(
      circleCenter,
      circleRadius,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill,
    );

    // Occupancy arc
    final occ = occupancy.clamp(0.0, 1.0);
    if (occ > 0.01) {
      const double startAngle = math.pi / 2;
      final double sweepAngle = 2 * math.pi * occ;
      final arcRect = Rect.fromCircle(
        center: circleCenter,
        radius: circleRadius,
      );
      final arcColor = getOccupancyColor(occ);

      canvas.drawArc(
        arcRect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = arcColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = arcStroke
          ..strokeCap = StrokeCap.round,
      );
    }

    // Direction triangle
    _paintDirectionTriangle(
      canvas,
      circleCenter,
      circleRadius,
      7.0,
      4.5,
      2.5,
      AppColors.primary,
    );

    // White bus icon
    _paintBusIcon(canvas, circleCenter, 18.0, Colors.white);

    // Info label to the right
    if (plate != null || speed != null) {
      final labelText = [
        plate,
        if (speed != null) '$speed km/h',
      ].whereType<String>().join(' · ');

      final labelPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const labelPadH = 8.0;
      const labelPadV = 4.0;
      final labelW = labelPainter.width + labelPadH * 2;
      final labelH = labelPainter.height + labelPadV * 2;
      const labelGap = 6.0;

      final labelX = circleCenter.dx + circleRadius + labelGap;
      final labelY = circleCenter.dy - labelH / 2;

      final labelRect = RRect.fromLTRBR(
        labelX,
        labelY,
        labelX + labelW,
        labelY + labelH,
        const Radius.circular(6),
      );

      canvas.drawRRect(labelRect, Paint()..color = AppColors.primary);

      labelPainter.paint(
        canvas,
        Offset(labelX + labelPadH, labelY + labelPadV),
      );
    }
  }

  void _paintDirectionTriangle(
    Canvas canvas,
    Offset center,
    double circleRadius,
    double triHeight,
    double triHalfBase,
    double triGap,
    Color color,
  ) {
    final headingRad = (direction - 90) * math.pi / 180;

    final tipX =
        center.dx + (circleRadius + triGap + triHeight) * math.cos(headingRad);
    final tipY =
        center.dy + (circleRadius + triGap + triHeight) * math.sin(headingRad);

    final baseX = center.dx + (circleRadius + triGap) * math.cos(headingRad);
    final baseY = center.dy + (circleRadius + triGap) * math.sin(headingRad);

    final perpAngle = headingRad + math.pi / 2;
    final path = Path()
      ..moveTo(tipX, tipY)
      ..lineTo(
        baseX + triHalfBase * math.cos(perpAngle),
        baseY + triHalfBase * math.sin(perpAngle),
      )
      ..lineTo(
        baseX - triHalfBase * math.cos(perpAngle),
        baseY - triHalfBase * math.sin(perpAngle),
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  void _paintBusIcon(
    Canvas canvas,
    Offset center,
    double iconSize,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_bus_filled.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.directions_bus_filled.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _BusMarkerPainter oldDelegate) {
    return occupancy != oldDelegate.occupancy ||
        direction != oldDelegate.direction ||
        routeColor != oldDelegate.routeColor ||
        isSelected != oldDelegate.isSelected ||
        plate != oldDelegate.plate ||
        speed != oldDelegate.speed;
  }
}
