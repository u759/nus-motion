import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerPainter {
  /// Simple white circle with thin dark border (like Google Maps mobile stops).
  static Future<BitmapDescriptor> createStopMarker({double dpr = 2.0}) async {
    const double dpSize = 10;
    final double size = dpSize * dpr;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final center = Offset(size / 2, size / 2);
    final borderWidth = 1.5 * dpr;
    final radius = (size - borderWidth) / 2;

    // White fill
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Dark border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF3C3C3C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    return _toBitmap(recorder, size, dpr);
  }

  /// Larger blue-filled circle to indicate selection (matches selected bus style).
  static Future<BitmapDescriptor> createSelectedStopMarker({
    double dpr = 2.0,
  }) async {
    const double dpSize = 18;
    final double size = dpSize * dpr;
    const Color selectedBlue = Color(0xFF135BEC);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final center = Offset(size / 2, size / 2);
    final radius = size / 2 - 1.0 * dpr;

    // Drop shadow
    canvas.drawCircle(
      center + Offset(0, 0.5 * dpr),
      radius,
      Paint()
        ..color = selectedBlue.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * dpr),
    );

    // Blue fill
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = selectedBlue
        ..style = PaintingStyle.fill,
    );

    // White inner dot
    canvas.drawCircle(
      center,
      radius * 0.4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    return _toBitmap(recorder, size, dpr);
  }

  /// Larger blue destination marker that stays within the selected-stop
  /// visual language while adding a more prominent halo.
  static Future<BitmapDescriptor> createDestinationMarker({
    double dpr = 2.0,
  }) async {
    // Match the bus-stop highlight ring style for UI consistency:
    // 36dp circle with 3dp blue border + translucent blue fill.
    const double dpSize = 36;
    final double size = dpSize * dpr;
    const Color selectedBlue = Color(0xFF135BEC);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final center = Offset(size / 2, size / 2);
    final borderWidth = 3.0 * dpr;
    final radius = size / 2 - borderWidth / 2;

    // Translucent blue fill
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = selectedBlue.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    // Solid blue border ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = selectedBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    return _toBitmap(recorder, size, dpr);
  }

  /// MD3-style circular bus icon with a load-percentage arc.
  ///
  /// The arc starts at 6 o'clock and sweeps clockwise. The arc colour
  /// is a single solid tone that shifts green → yellow → red with [occupancy].
  ///
  /// A small direction triangle (coloured [routeColor]) points in the
  /// bus's travel heading ([direction] in degrees, 0 = North, clockwise).
  static Future<BitmapDescriptor> createBusMarker({
    required double occupancy,
    required double direction,
    required Color routeColor,
    double dpr = 2.0,
  }) async {
    const double dpSize = 44; // canvas has padding for the direction triangle
    final double size = dpSize * dpr;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final center = Offset(size / 2, size / 2);
    final arcStroke = 2.5 * dpr;
    final circleRadius = 14.0 * dpr; // smaller bus circle

    // --- Drop shadow ---
    canvas.drawCircle(
      center + Offset(0, 1.0 * dpr),
      circleRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * dpr),
    );

    // --- White surface circle ---
    canvas.drawCircle(
      center,
      circleRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // --- Occupancy arc (the circle's edge, only where load extends) ---
    final occ = occupancy.clamp(0.0, 1.0);
    if (occ > 0.01) {
      const double startAngle = math.pi / 2; // 6 o'clock
      final double sweepAngle = 2 * math.pi * occ;
      final arcRect = Rect.fromCircle(center: center, radius: circleRadius);

      // Solid colour: green (0%) → yellow (50%) → red (100%)
      final Color arcColor;
      if (occ <= 0.5) {
        arcColor = Color.lerp(
          const Color(0xFF4CAF50),
          const Color(0xFFFFC107),
          occ * 2,
        )!;
      } else {
        arcColor = Color.lerp(
          const Color(0xFFFFC107),
          const Color(0xFFF44336),
          (occ - 0.5) * 2,
        )!;
      }

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

    // --- Direction triangle (blue, pointing in travel heading) ---
    final headingRad = (direction - 90) * math.pi / 180;
    final triHeight = 6.0 * dpr;
    final triHalfBase = 4.0 * dpr;
    final triGap = 2.0 * dpr;

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
        ..color = const Color(0xFF135BEC)
        ..style = PaintingStyle.fill,
    );

    // --- Bus icon (Material Icons glyph) ---
    final iconSize = 16.0 * dpr;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_bus_filled.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.directions_bus_filled.fontFamily,
          color: const Color(0xFF424242),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );

    return _toBitmap(recorder, size, dpr);
  }

  /// Selected bus marker — larger blue circle with white bus icon
  /// and a compact info label to the right.
  static Future<(BitmapDescriptor, Offset)> createSelectedBusMarker({
    required double occupancy,
    required double direction,
    required Color routeColor,
    String? plate,
    int? speed,
    String? crowdLevel,
    double dpr = 2.0,
  }) async {
    const Color selectedBlue = Color(0xFF135BEC);
    final circleRadius = 17.0 * dpr;
    final arcStroke = 3.0 * dpr;

    // --- Pre-measure the label ---
    final labelText = [
      ?plate,
      if (speed != null) '$speed km/h',
      if (crowdLevel != null && crowdLevel != 'Unknown') crowdLevel,
    ].join(' · ');

    final labelFontSize = 11.0 * dpr;
    final labelPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          fontSize: labelFontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelPadH = 8.0 * dpr;
    final labelPadV = 4.0 * dpr;
    final labelH = labelPainter.height + labelPadV * 2;
    final labelW = labelPainter.width + labelPadH * 2;
    final labelGap = 6.0 * dpr;

    // Direction triangle space
    final triHeight = 7.0 * dpr;
    final triGap = 2.5 * dpr;
    final triSpace = triGap + triHeight;

    // Canvas sizing: circle + tri space on all sides, label to the right
    final circleArea = (circleRadius + triSpace) * 2;
    final canvasW = circleArea + labelGap + labelW;
    final canvasH = circleArea;
    final circleCenter = Offset(circleArea / 2, canvasH / 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasW, canvasH));

    // --- Drop shadow ---
    canvas.drawCircle(
      circleCenter + Offset(0, 1.5 * dpr),
      circleRadius,
      Paint()
        ..color = selectedBlue.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 * dpr),
    );

    // --- Blue filled circle ---
    canvas.drawCircle(
      circleCenter,
      circleRadius,
      Paint()
        ..color = selectedBlue
        ..style = PaintingStyle.fill,
    );

    // --- Occupancy arc ---
    final occ = occupancy.clamp(0.0, 1.0);
    if (occ > 0.01) {
      const double startAngle = math.pi / 2;
      final double sweepAngle = 2 * math.pi * occ;
      final arcRect = Rect.fromCircle(
        center: circleCenter,
        radius: circleRadius,
      );

      final Color arcColor;
      if (occ <= 0.5) {
        arcColor = Color.lerp(
          const Color(0xFF4CAF50),
          const Color(0xFFFFC107),
          occ * 2,
        )!;
      } else {
        arcColor = Color.lerp(
          const Color(0xFFFFC107),
          const Color(0xFFF44336),
          (occ - 0.5) * 2,
        )!;
      }

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

    // --- Direction triangle ---
    final headingRad = (direction - 90) * math.pi / 180;
    final triHalfBase = 4.5 * dpr;

    final tipX =
        circleCenter.dx +
        (circleRadius + triGap + triHeight) * math.cos(headingRad);
    final tipY =
        circleCenter.dy +
        (circleRadius + triGap + triHeight) * math.sin(headingRad);

    final baseX =
        circleCenter.dx + (circleRadius + triGap) * math.cos(headingRad);
    final baseY =
        circleCenter.dy + (circleRadius + triGap) * math.sin(headingRad);

    final perpAngle = headingRad + math.pi / 2;
    final triPath = Path()
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
      triPath,
      Paint()
        ..color = selectedBlue
        ..style = PaintingStyle.fill,
    );

    // --- White bus icon ---
    final iconSize = 18.0 * dpr;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_bus_filled.codePoint),
        style: TextStyle(
          fontSize: iconSize,
          fontFamily: Icons.directions_bus_filled.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(circleCenter.dx - tp.width / 2, circleCenter.dy - tp.height / 2),
    );

    // --- Info label pill to the right of the circle ---
    if (labelText.isNotEmpty) {
      final labelLeft = circleArea + labelGap;
      final labelTop = (canvasH - labelH) / 2;
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(labelLeft, labelTop, labelW, labelH),
        Radius.circular(labelH / 2),
      );

      // Label shadow
      canvas.drawRRect(
        labelRect.shift(Offset(0, 1.0 * dpr)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * dpr),
      );

      // Label background
      canvas.drawRRect(labelRect, Paint()..color = const Color(0xFF1E1E1E));

      // Label text
      labelPainter.paint(
        canvas,
        Offset(labelLeft + labelPadH, labelTop + labelPadV),
      );
    }

    // Return the bitmap + anchor as a record
    final anchorX = circleCenter.dx / canvasW;
    final anchorY = circleCenter.dy / canvasH;

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasW.ceil(), canvasH.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final descriptor = BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
    return (descriptor, Offset(anchorX, anchorY));
  }

  // ------------------------------------------------------------------
  static Future<BitmapDescriptor> _toBitmap(
    ui.PictureRecorder recorder,
    double size,
    double dpr,
  ) async {
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.ceil(), size.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      imagePixelRatio: dpr,
    );
  }
}
