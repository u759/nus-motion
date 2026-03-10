import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

/// A GPU-rendered location marker showing compass heading direction.
///
/// Mimics the Google Maps blue dot style with:
/// - Flat blue filled circle with white border
/// - Translucent cone pointing in compass heading direction
/// - Optional accuracy circle
///
/// Uses device magnetometer/compass for heading instead of GPS heading,
/// which provides accurate direction even when stationary.
class LocationOverlayMarker extends StatefulWidget {
  const LocationOverlayMarker({
    super.key,
    required this.screenX,
    required this.screenY,
    this.accuracy,
    this.metersPerPixel,
    this.shouldAnimate = true,
  });

  /// Screen X coordinate (center of marker).
  final double screenX;

  /// Screen Y coordinate (center of marker).
  final double screenY;

  /// GPS accuracy in meters (for accuracy circle). Null hides the circle.
  final double? accuracy;

  /// Meters per pixel at current zoom level (for accuracy circle scaling).
  final double? metersPerPixel;

  /// When true, animate position changes. When false, snap instantly.
  final bool shouldAnimate;

  /// Marker size reduced by ~17% from original 24.0
  static const double markerSize = 20.0;
  static const Duration _posAnimDuration = Duration(milliseconds: 500);
  static const Curve _posAnimCurve = Curves.easeInOut;

  @override
  State<LocationOverlayMarker> createState() => _LocationOverlayMarkerState();
}

class _LocationOverlayMarkerState extends State<LocationOverlayMarker>
    with SingleTickerProviderStateMixin {
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool _hasCompass = false;

  /// Current displayed heading (smoothly animated).
  double _displayedHeading = 0.0;

  /// Target heading from compass (raw input after basic filtering).
  double _targetHeading = 0.0;

  /// Compass accuracy in degrees (± error). Used to determine cone width.
  /// Higher value = less accurate = wider cone.
  double _compassAccuracy = 30.0; // Default to reasonable value

  /// Track if we've received at least one valid heading.
  bool _hasValidHeading = false;

  /// Ticker for continuous smooth animation.
  late AnimationController _tickerController;

  /// Smoothing factor per frame. Lower = smoother but slower response.
  /// At 60fps, 0.08 gives ~12 frames to reach target = ~200ms response time.
  static const double _smoothingFactor = 0.08;

  @override
  void initState() {
    super.initState();
    // Use a repeating animation controller as a ticker for smooth updates
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
    _initCompass();
  }

  Future<void> _initCompass() async {
    // Check if compass is available
    final compassStream = FlutterCompass.events;
    if (compassStream == null) {
      // Compass not available — marker will show without direction indicator
      return;
    }

    _compassSubscription = compassStream.listen((event) {
      if (!mounted) return;

      final rawHeading = event.heading;

      // CRITICAL: When heading is null, keep the last known heading.
      // Don't reset to 0/north — this causes the fluctuation bug.
      if (rawHeading == null) return;

      // Update compass accuracy if available (in degrees ± error)
      final accuracy = event.accuracy;
      if (accuracy != null && accuracy > 0) {
        // Clamp to reasonable range (10° min, 90° max cone width)
        _compassAccuracy = accuracy.clamp(10.0, 90.0);
      }

      // Store as target heading (the ticker will smoothly animate towards it)
      _targetHeading = rawHeading;

      if (!_hasValidHeading) {
        // First valid reading — jump immediately
        _displayedHeading = rawHeading;
        _hasValidHeading = true;
      }
    });

    if (mounted) {
      setState(() => _hasCompass = true);
      // Start the ticker to continuously smooth the heading
      _tickerController.repeat();
    }
  }

  /// Called each frame by the ticker to smoothly animate heading.
  void _onTick() {
    if (!_hasValidHeading || !mounted) return;

    // Calculate shortest angular distance (handling 360°/0° wrap)
    double delta = _targetHeading - _displayedHeading;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;

    // Skip update if already at target (within tolerance)
    if (delta.abs() < 0.1) return;

    // Apply exponential smoothing
    _displayedHeading += delta * _smoothingFactor;

    // Normalize to 0-360
    if (_displayedHeading < 0) _displayedHeading += 360;
    if (_displayedHeading >= 360) _displayedHeading -= 360;

    // Trigger repaint
    setState(() {});
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = LocationOverlayMarker.markerSize;
    final left = widget.screenX - size / 2;
    final top = widget.screenY - size / 2;

    // Calculate accuracy circle radius in pixels
    double? accuracyRadius;
    if (widget.accuracy != null &&
        widget.metersPerPixel != null &&
        widget.metersPerPixel! > 0) {
      accuracyRadius = widget.accuracy! / widget.metersPerPixel!;
      // Clamp to reasonable range
      accuracyRadius = accuracyRadius.clamp(size / 2, 200.0);
    }

    final animDuration = widget.shouldAnimate
        ? LocationOverlayMarker._posAnimDuration
        : Duration.zero;

    return AnimatedPositioned(
      duration: animDuration,
      curve: LocationOverlayMarker._posAnimCurve,
      left: left - (accuracyRadius ?? 0),
      top: top - (accuracyRadius ?? 0),
      width: size + (accuracyRadius ?? 0) * 2,
      height: size + (accuracyRadius ?? 0) * 2,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(
              size + (accuracyRadius ?? 0) * 2,
              size + (accuracyRadius ?? 0) * 2,
            ),
            painter: _LocationMarkerPainter(
              heading: _hasCompass && _hasValidHeading
                  ? _displayedHeading
                  : null,
              compassAccuracy: _compassAccuracy,
              accuracyRadius: accuracyRadius,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationMarkerPainter extends CustomPainter {
  _LocationMarkerPainter({
    this.heading,
    this.compassAccuracy = 30.0,
    this.accuracyRadius,
  });

  /// Compass heading in degrees (0-360, 0 = North). Null if compass unavailable.
  final double? heading;

  /// Compass accuracy in degrees (± error). Used to determine cone width.
  final double compassAccuracy;

  /// Accuracy circle radius in pixels. Null hides the circle.
  final double? accuracyRadius;

  // Design constants — reduced by ~17% for smaller marker
  static const double _dotRadius = 8.0;
  static const double _borderWidth = 2.5;
  static const double _coneRadius =
      38.0; // How far the cone extends from center (longer for Google Maps style)

  // Google Maps location blue
  static const Color _locationBlue = Color(0xFF4285F4);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Draw accuracy circle (if provided)
    if (accuracyRadius != null) {
      canvas.drawCircle(
        center,
        accuracyRadius!,
        Paint()
          ..color = _locationBlue.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        accuracyRadius!,
        Paint()
          ..color = _locationBlue.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // 2. Draw heading cone FIRST (behind the dot)
    if (heading != null) {
      _paintHeadingCone(canvas, center, size, heading!);
    }

    // 3. Draw drop shadow
    canvas.drawCircle(
      center + const Offset(0, 1.0),
      _dotRadius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // 4. Draw white circle (filled, so no anti-alias gap with the blue dot)
    canvas.drawCircle(
      center,
      _dotRadius + _borderWidth,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // 5. Draw flat blue filled circle on top
    canvas.drawCircle(
      center,
      _dotRadius,
      Paint()
        ..color = _locationBlue
        ..style = PaintingStyle.fill,
    );
  }

  /// Paints a Google Maps-style translucent heading cone with radial gradient.
  void _paintHeadingCone(
    Canvas canvas,
    Offset center,
    Size size,
    double heading,
  ) {
    // Cone angle is based on compass accuracy (wider cone = less accurate)
    // compassAccuracy is in degrees (± error), so total width = 2x accuracy
    // Clamp to reasonable range: min 50°, max 140° for more visible cone
    final coneAngle = (compassAccuracy * 2.5).clamp(50.0, 140.0);

    // Convert to radians (0 = North = up on screen)
    // Canvas Y is inverted, so north (-90°) points up
    final headingRad = (heading - 90) * math.pi / 180;
    final halfAngleRad = (coneAngle / 2) * math.pi / 180;

    // Create cone path as an arc sector
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: _coneRadius),
        headingRad - halfAngleRad,
        coneAngle * math.pi / 180,
        false,
      )
      ..close();

    // Create radial gradient that fades to fully transparent at edge
    // The gradient shader rect must match the cone radius for proper alignment
    final gradientRect = Rect.fromCircle(center: center, radius: _coneRadius);
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          _locationBlue.withValues(alpha: 0.35),
          _locationBlue.withValues(alpha: 0.20),
          _locationBlue.withValues(alpha: 0.08),
          _locationBlue.withValues(alpha: 0.02),
          _locationBlue.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(gradientRect);

    canvas.drawPath(path, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant _LocationMarkerPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.compassAccuracy != compassAccuracy ||
        oldDelegate.accuracyRadius != accuracyRadius;
  }
}
