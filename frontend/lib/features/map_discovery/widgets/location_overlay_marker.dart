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
  double _heading = 0.0;
  double _targetHeading = 0.0;
  bool _hasCompass = false;
  
  /// Smoothed heading using low-pass filter to prevent jitter.
  double _smoothedHeading = 0.0;
  
  /// Low-pass filter smoothing factor. Lower = smoother but slower response.
  static const double _smoothingAlpha = 0.15;
  
  /// Track if we've received at least one valid heading.
  bool _hasValidHeading = false;

  late AnimationController _headingAnimController;
  late Animation<double> _headingAnimation;

  @override
  void initState() {
    super.initState();
    _headingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _headingAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _headingAnimController, curve: Curves.easeOut),
    );
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
      
      // Apply low-pass filter to smooth heading changes
      final smoothed = _applyLowPassFilter(rawHeading);
      _animateHeadingTo(smoothed);
    });

    if (mounted) {
      setState(() => _hasCompass = true);
    }
  }
  
  /// Applies low-pass filter to smooth heading, handling 360°/0° crossover.
  double _applyLowPassFilter(double newHeading) {
    if (!_hasValidHeading) {
      // First valid reading — use it directly
      _smoothedHeading = newHeading;
      _hasValidHeading = true;
      return newHeading;
    }
    
    // Calculate delta, handling 360°/0° wrap-around
    double delta = newHeading - _smoothedHeading;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    
    // Apply low-pass filter
    _smoothedHeading += delta * _smoothingAlpha;
    
    // Normalize to 0-360
    if (_smoothedHeading < 0) _smoothedHeading += 360;
    if (_smoothedHeading >= 360) _smoothedHeading -= 360;
    
    return _smoothedHeading;
  }

  void _animateHeadingTo(double newHeading) {
    // Normalize heading difference to avoid spinning the long way
    double diff = newHeading - _heading;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    _targetHeading = _heading + diff;

    _headingAnimation = Tween<double>(
      begin: _heading,
      end: _targetHeading,
    ).animate(
      CurvedAnimation(parent: _headingAnimController, curve: Curves.easeOut),
    );

    _headingAnimController.forward(from: 0).then((_) {
      if (mounted) {
        // Normalize heading to 0-360 after animation completes
        setState(() {
          _heading = _targetHeading % 360;
          if (_heading < 0) _heading += 360;
        });
      }
    });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _headingAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = LocationOverlayMarker.markerSize;
    final left = widget.screenX - size / 2;
    final top = widget.screenY - size / 2;

    // Calculate accuracy circle radius in pixels
    double? accuracyRadius;
    if (widget.accuracy != null && widget.metersPerPixel != null && widget.metersPerPixel! > 0) {
      accuracyRadius = widget.accuracy! / widget.metersPerPixel!;
      // Clamp to reasonable range
      accuracyRadius = accuracyRadius.clamp(size / 2, 200.0);
    }

    final animDuration =
        widget.shouldAnimate ? LocationOverlayMarker._posAnimDuration : Duration.zero;

    return AnimatedPositioned(
      duration: animDuration,
      curve: LocationOverlayMarker._posAnimCurve,
      left: left - (accuracyRadius ?? 0),
      top: top - (accuracyRadius ?? 0),
      width: size + (accuracyRadius ?? 0) * 2,
      height: size + (accuracyRadius ?? 0) * 2,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _headingAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(
                  size + (accuracyRadius ?? 0) * 2,
                  size + (accuracyRadius ?? 0) * 2,
                ),
                painter: _LocationMarkerPainter(
                  heading: _hasCompass ? _headingAnimation.value : null,
                  accuracyRadius: accuracyRadius,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LocationMarkerPainter extends CustomPainter {
  _LocationMarkerPainter({
    this.heading,
    this.accuracyRadius,
  });

  /// Compass heading in degrees (0-360, 0 = North). Null if compass unavailable.
  final double? heading;

  /// Accuracy circle radius in pixels. Null hides the circle.
  final double? accuracyRadius;

  // Design constants — reduced by ~17% for smaller marker
  static const double _dotRadius = 8.0;
  static const double _borderWidth = 2.5;
  static const double _coneRadius = 22.0; // How far the cone extends from center
  static const double _coneAngle = 65.0; // degrees (60-70 as per spec)

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

    // 4. Draw white border
    canvas.drawCircle(
      center,
      _dotRadius + _borderWidth / 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = _borderWidth,
    );

    // 5. Draw flat blue filled circle (no 3D effect)
    canvas.drawCircle(
      center,
      _dotRadius,
      Paint()
        ..color = _locationBlue
        ..style = PaintingStyle.fill,
    );
  }

  /// Paints a Google Maps-style translucent heading cone with radial gradient.
  void _paintHeadingCone(Canvas canvas, Offset center, Size size, double heading) {
    // Convert heading to radians (0 = North = up on screen)
    // Canvas Y is inverted, so north (-90°) points up
    final headingRad = (heading - 90) * math.pi / 180;
    final halfAngleRad = (_coneAngle / 2) * math.pi / 180;

    // Create cone path as an arc sector
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: _coneRadius),
        headingRad - halfAngleRad,
        _coneAngle * math.pi / 180,
        false,
      )
      ..close();

    // Create radial gradient: blue at center fading to transparent at edge
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          _locationBlue.withValues(alpha: 0.35),
          _locationBlue.withValues(alpha: 0.15),
          _locationBlue.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: _coneRadius),
      );

    canvas.drawPath(path, gradientPaint);
  }

  @override
  bool shouldRepaint(covariant _LocationMarkerPainter oldDelegate) {
    return oldDelegate.heading != heading ||
        oldDelegate.accuracyRadius != accuracyRadius;
  }
}
