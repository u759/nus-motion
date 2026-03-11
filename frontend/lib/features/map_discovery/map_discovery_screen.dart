import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/widgets/loading_shimmer.dart';
import 'package:frontend/core/widgets/error_card.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/active_bus.dart';
import 'package:frontend/data/models/bus_stop.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/route_leg.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/core/utils/marker_painter.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/features/map_discovery/widgets/stops_tab.dart';
import 'package:frontend/features/map_discovery/widgets/lines_tab.dart';
import 'package:frontend/features/map_discovery/widgets/bus_overlay_marker.dart';
import 'package:frontend/features/map_discovery/widgets/location_overlay_marker.dart';
import 'package:frontend/features/map_discovery/widgets/search_dropdown.dart';
import 'package:frontend/features/map_discovery/widgets/route_suggestions_panel.dart';
import 'package:frontend/features/map_discovery/widgets/route_detail_view.dart';
import 'package:frontend/features/map_discovery/models/navigation_state.dart';
import 'package:frontend/features/map_discovery/utils/route_geometry.dart';

class MapDiscoveryScreen extends ConsumerStatefulWidget {
  const MapDiscoveryScreen({super.key});

  @override
  ConsumerState<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends ConsumerState<MapDiscoveryScreen>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  GoogleMapController? _mapController;
  Timer? _pollTimer;
  Timer? _highlightFlashTimer;
  Position? _lastPosition;

  // Map selection state
  String? _selectedRoute;
  String? _selectedStop; // stop name — controls detail view in StopsTab
  String? _highlightedStop; // marker highlight only — no detail view
  String? _selectedBusPlate;

  // Tab
  late final TabController _tabController;

  // Custom marker icons (stops only — buses use overlay)
  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _selectedStopIcon;
  BitmapDescriptor? _destinationIcon;

  // Panel height (state variable for dynamic adjustment)
  double _panelHeight = 0;

  // Map top padding (for overlay positioning)
  double _mapTopPadding = 0;

  // Device pixel ratio for marker rendering
  double _dpr = 2.0;

  // Route polyline animation
  AnimationController? _routeAnimController;

  // Bus overlay screen positions (for GPU-accelerated animation)
  Map<String, Offset> _busScreenPositions = {};

  // Cached checkpoint LatLngs for selected route polyline (explore mode)
  List<LatLng> _routeCheckpointLatLngs = [];

  // Track previous bus lat/lng to detect actual position changes (vs camera movement)
  final Map<String, LatLng> _previousBusPositions = {};
  Set<String> _busesWithPositionChange = {};

  // Camera position for synchronous projection
  CameraPosition? _currentCameraPosition;

  // Map widget key for getting dimensions
  final GlobalKey _mapKey = GlobalKey();

  // Last known map size for resize detection
  Size? _lastMapSize;

  // Location overlay state (custom compass-heading marker)
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _streamPosition; // Real-time position from Geolocator stream
  Offset? _locationScreenPosition; // Screen coordinates for location marker

  static const _nusCenter = LatLng(
    AppConstants.nusLatitude,
    AppConstants.nusLongitude,
  );

  // Minimal map style — suppress POIs, transit labels, and visual clutter
  static const _lightMapStyle = '''
[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]
''';

  // Dark map style — suppress POIs/transit + dark colors
  static const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"landscape.man_made","elementType":"geometry.stroke","stylers":[{"color":"#334e87"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"road","elementType":"labels.text.stroke","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#b0d5ce"}]},
  {"featureType":"road.highway","elementType":"labels.text.stroke","stylers":[{"color":"#023e58"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4e6d70"}]}
]
''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _initLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newDpr = MediaQuery.devicePixelRatioOf(context);
    if (newDpr != _dpr ||
        _stopIcon == null ||
        _selectedStopIcon == null ||
        _destinationIcon == null) {
      _dpr = newDpr;
      _generateIcons();
    }
  }

  Future<void> _initLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lastPosition = pos;
        _streamPosition = pos;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );

      // Subscribe to position stream for real-time location updates
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5, // Update every 5 meters
            ),
          ).listen((position) {
            if (!mounted) return;
            setState(() => _streamPosition = position);
            _updateLocationScreenPosition();
          });
    } catch (_) {
      // Location unavailable
    }
    _startPolling();
  }

  /// Update screen coordinates for the location marker.
  void _updateLocationScreenPosition() {
    final camera = _currentCameraPosition;
    final mapSize = _lastMapSize;
    final position = _streamPosition;
    if (camera == null ||
        mapSize == null ||
        mapSize.isEmpty ||
        position == null) {
      return;
    }

    final screenPos = _latLngToScreen(
      LatLng(position.latitude, position.longitude),
      camera,
      mapSize,
    );

    setState(() => _locationScreenPosition = screenPos);
  }

  Future<void> _generateIcons() async {
    _stopIcon = await MarkerPainter.createStopMarker(dpr: _dpr);
    _selectedStopIcon = await MarkerPainter.createSelectedStopMarker(dpr: _dpr);
    _destinationIcon = await MarkerPainter.createDestinationMarker(dpr: _dpr);
    if (mounted) setState(() {});
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(shuttlesProvider);
      ref.invalidate(allActiveBusesProvider);
    });
  }

  // --------------- Selection handlers ---------------

  bool _scrollToSelection = false;

  void _selectStop(String stopName, {bool fromMap = false}) {
    final deselecting = _selectedStop == stopName;
    setState(() {
      _selectedStop = deselecting ? null : stopName;
      _highlightedStop = deselecting ? null : stopName; // Sync highlight
      _selectedBusPlate = null;
      if (deselecting) _selectedRoute = null; // Clear route when exiting detail
      _scrollToSelection = fromMap;
    });
    if (deselecting) _routeAnimController?.stop();
    if (_tabController.index != 0) _tabController.animateTo(0);

    // Center map on the selected stop (not when deselecting)
    if (!deselecting) {
      final allStops = ref.read(stopsProvider);
      allStops.whenData((stops) {
        for (final s in stops) {
          if (s.name == stopName) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLng(LatLng(s.latitude, s.longitude)),
            );
            break;
          }
        }
      });
    }
  }

  /// Centers the map on a stop and highlights the marker (without opening detail view).
  void _locateStop(String stopName) {
    setState(() {
      _highlightedStop = stopName;
      // Don't set _selectedStop — keeps list view
    });

    // Center the map on the stop
    final allStops = ref.read(stopsProvider);
    allStops.whenData((stops) {
      BusStop? stop;
      for (final s in stops) {
        if (s.name == stopName) {
          stop = s;
          break;
        }
      }
      if (stop != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(stop.latitude, stop.longitude)),
        );
      }
    });
  }

  /// Flashes the marker highlight briefly (for timeline tap feedback).
  void _flashHighlightStop(String stopCode) {
    _highlightFlashTimer?.cancel();

    setState(() {
      _highlightedStop = stopCode;
    });

    _highlightFlashTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _highlightedStop == stopCode) {
        setState(() {
          _highlightedStop = null;
        });
      }
    });
  }

  /// Highlights a stop when viewing a route (from map marker tap).
  /// Does NOT clear the selected route or open the stop detail view.
  void _highlightStopInRoute(String stopCode) {
    setState(() {
      _highlightedStop = stopCode;
      // Don't clear _selectedRoute — user is viewing the route
      // Don't set _selectedStop — that opens the detail view
    });

    // Center the map on the stop
    final allStops = ref.read(stopsProvider);
    allStops.whenData((stops) {
      for (final s in stops) {
        if (s.name == stopCode) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(LatLng(s.latitude, s.longitude)),
          );
          break;
        }
      }
    });
  }

  void _selectRoute(String routeCode, {bool fromMap = false}) {
    final deselecting = _selectedRoute == routeCode;
    setState(() {
      _selectedRoute = deselecting ? null : routeCode;
      _selectedBusPlate = null;
      _highlightedStop = null; // Clear stop highlight when route selected
      _scrollToSelection = fromMap;
    });
    if (deselecting) {
      _routeAnimController?.stop();
    } else {
      _startRouteAnimation();
    }
  }

  void _selectBus(String route, ActiveBus bus) {
    final deselecting = _selectedBusPlate == bus.vehPlate;
    final previousRoute = _selectedRoute; // Capture before setState
    setState(() {
      if (deselecting) {
        _selectedRoute = null;
        _selectedBusPlate = null;
      } else {
        _selectedRoute = route;
        _selectedBusPlate = bus.vehPlate;
        _scrollToSelection = true;
      }
    });
    if (deselecting) {
      _routeAnimController?.stop();
    } else if (previousRoute != route) {
      // Only animate if route actually changed
      _startRouteAnimation();
    }
  }

  void _clearRoute() {
    _routeAnimController?.stop();
    setState(() {
      _selectedRoute = null;
      _selectedBusPlate = null;
    });
  }

  void _clearAll() {
    _routeAnimController?.stop();
    setState(() {
      _selectedRoute = null;
      _selectedStop = null;
      _highlightedStop = null;
      _selectedBusPlate = null;
    });
  }

  /// Handles destination selection from search dropdown.
  void _onDestinationSelected() {
    final navState = ref.read(navigationStateProvider);
    final destination = navState.destination;
    if (destination != null && mounted) {
      // Center map on the selected destination
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(destination.latitude, destination.longitude),
          17.0, // Zoom in on destination
        ),
      );
      // Clear any existing stop/route selection
      _clearAll();
    }
  }

  void _startRouteAnimation() {
    _routeAnimController?.dispose();
    _routeAnimController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _routeAnimController!.forward(from: 0);
  }

  double get _routeProgress {
    final v = _routeAnimController?.value ?? 1.0;
    return Curves.easeOut.transform(v);
  }

  // --------------- Bus overlay position management ---------------

  /// Mercator tile size at zoom 0
  static const _tileSize = 256.0;

  /// Convert latitude to world Y coordinate (pixels at zoom 0)
  static double _latToY(double lat) {
    final siny = math.sin(lat * math.pi / 180);
    final clampedSiny = siny.clamp(-0.9999, 0.9999);
    return _tileSize *
        (0.5 - math.log((1 + clampedSiny) / (1 - clampedSiny)) / (4 * math.pi));
  }

  /// Convert longitude to world X coordinate (pixels at zoom 0)
  static double _lngToX(double lng) {
    return _tileSize * (0.5 + lng / 360);
  }

  /// Calculate meters per pixel at the given camera position.
  /// Used for scaling the accuracy circle.
  static double _calculateMetersPerPixel(CameraPosition camera) {
    // At the equator, each zoom level halves the meters per pixel
    // meters per pixel = (Earth circumference / 256) / 2^zoom * cos(lat)
    const earthCircumference = 40075016.686; // meters
    final latRad = camera.target.latitude * math.pi / 180;
    return (earthCircumference / 256) /
        math.pow(2, camera.zoom) *
        math.cos(latRad);
  }

  /// Synchronously convert lat/lng to screen coordinates using Mercator projection
  Offset _latLngToScreen(LatLng point, CameraPosition camera, Size mapSize) {
    final scale = math.pow(2, camera.zoom).toDouble();

    // Point in world pixels
    final pointX = _lngToX(point.longitude) * scale;
    final pointY = _latToY(point.latitude) * scale;

    // Camera center in world pixels
    final centerX = _lngToX(camera.target.longitude) * scale;
    final centerY = _latToY(camera.target.latitude) * scale;

    // Offset from center
    final dx = pointX - centerX;
    final dy = pointY - centerY;

    // Screen position
    // Horizontal: no padding asymmetry
    final screenX = mapSize.width / 2 + dx;
    // Vertical: account for asymmetric padding — camera target appears at
    // visual center, not geometric center. Since topPadding < bottomPadding,
    // paddingOffsetY is negative, shifting markers UP.
    final paddingOffsetY = (_mapTopPadding - _panelHeight) / 2;
    final screenY = mapSize.height / 2 + dy + paddingOffsetY;

    return Offset(screenX, screenY);
  }

  /// Called when camera moves — update stored position and recalculate overlay positions
  void _onCameraMove(CameraPosition position) {
    _currentCameraPosition = position;
    _updateBusScreenPositions(animate: false);
    _updateLocationScreenPosition();
  }

  /// Called when camera stops moving — final position update
  void _onCameraIdle() {
    _updateBusScreenPositions(animate: false);
    _updateLocationScreenPosition();
  }

  /// Synchronously update screen coordinates for all visible buses
  /// [animate] - if false, markers snap instantly (camera movement);
  ///             if true, markers animate (bus position data changed)
  void _updateBusScreenPositions({bool animate = true}) {
    final camera = _currentCameraPosition;
    if (camera == null) return;

    final renderBox = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    final mapSize = renderBox?.size;
    if (mapSize == null || mapSize.isEmpty) return;

    final allBuses = ref.read(allActiveBusesProvider).valueOrNull;
    if (allBuses == null || allBuses.isEmpty) {
      if (_busScreenPositions.isNotEmpty) {
        setState(() => _busScreenPositions = {});
      }
      return;
    }

    final newPositions = <String, Offset>{};
    final positionChanges = <String>{};

    for (final entry in allBuses.entries) {
      final routeCode = entry.key;
      if (_selectedRoute != null && routeCode != _selectedRoute) continue;

      for (final bus in entry.value) {
        final screenPos = _latLngToScreen(
          LatLng(bus.lat, bus.lng),
          camera,
          mapSize,
        );
        newPositions[bus.vehPlate] = screenPos;

        // Track position changes for animation
        if (animate) {
          final currentLatLng = LatLng(bus.lat, bus.lng);
          final previousLatLng = _previousBusPositions[bus.vehPlate];
          if (previousLatLng == null ||
              previousLatLng.latitude != currentLatLng.latitude ||
              previousLatLng.longitude != currentLatLng.longitude) {
            positionChanges.add(bus.vehPlate);
            _previousBusPositions[bus.vehPlate] = currentLatLng;
          }
        }
      }
    }

    setState(() {
      _busScreenPositions = newPositions;
      _busesWithPositionChange = positionChanges;
    });
  }

  /// Determines which bus plate to track (highlight) when a route is selected.
  /// Returns the plate of the next arriving bus for the first bus leg.
  String? _getTrackedBusPlate(NavigationState navState) {
    final route = navState.route;
    if (route == null) return null;

    // Find the first bus leg
    RouteLeg? firstBusLeg;
    for (final leg in route.legs) {
      if (leg.isBus) {
        firstBusLeg = leg;
        break;
      }
    }
    if (firstBusLeg == null || firstBusLeg.fromStop == null) return null;

    // Get all stops to match fromStop
    final stops = ref.read(stopsProvider).valueOrNull;
    if (stops == null) return null;

    // Find the stop matching fromStop (check name, longName, caption)
    BusStop? matchedStop;
    for (final s in stops) {
      if (s.longName == firstBusLeg.fromStop ||
          s.name == firstBusLeg.fromStop ||
          s.caption == firstBusLeg.fromStop) {
        matchedStop = s;
        break;
      }
    }
    if (matchedStop == null) return null;

    // Get shuttle info for this stop (use stop.name as the key)
    final shuttles = ref.read(shuttlesProvider(matchedStop.name)).valueOrNull;
    if (shuttles == null) return null;

    // Find the shuttle for this route
    for (final shuttle in shuttles.shuttles) {
      if (shuttle.name == firstBusLeg.routeCode) {
        // Return plate if not empty
        final plate = shuttle.arrivalTimeVehPlate;
        return plate.isNotEmpty ? plate : null;
      }
    }

    return null;
  }

  /// Build highlighted stop overlay (appears above bus markers)
  Widget? _buildHighlightedStopOverlay() {
    final stopCode = _highlightedStop ?? _selectedStop;
    if (stopCode == null) return null;

    final camera = _currentCameraPosition;
    final mapSize = _lastMapSize;
    if (camera == null || mapSize == null || mapSize.isEmpty) return null;

    final allStops = ref.read(stopsProvider).valueOrNull;
    if (allStops == null) return null;

    BusStop? targetStop;
    for (final s in allStops) {
      if (s.name == stopCode) {
        targetStop = s;
        break;
      }
    }
    if (targetStop == null) return null;

    final screenPos = _latLngToScreen(
      LatLng(targetStop.latitude, targetStop.longitude),
      camera,
      mapSize,
    );

    // Only show highlight ring if a bus marker is close enough to obscure the stop
    const obscureThreshold =
        30.0; // pixels — bus marker radius + stop icon radius
    bool isBusNearby = false;
    for (final busPos in _busScreenPositions.values) {
      final dx = (busPos.dx - screenPos.dx).abs();
      final dy = (busPos.dy - screenPos.dy).abs();
      if (dx < obscureThreshold && dy < obscureThreshold) {
        isBusNearby = true;
        break;
      }
    }
    if (!isBusNearby) return null;

    // Highlight ring around the stop (appears above bus markers)
    final colors = context.nusColors;
    return Positioned(
      left: screenPos.dx - 18,
      top: screenPos.dy - 18,
      child: IgnorePointer(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.primary, width: 3),
            color: colors.primary.withValues(alpha: 0.15),
          ),
        ),
      ),
    );
  }

  // --------------- Map overlays ---------------

  Set<Polyline> _buildPolylines(NavigationState navState) {
    // Route preview mode: show route legs
    if (navState.status == NavigationStatus.routePreview &&
        navState.route != null) {
      return _buildRoutePreviewPolylines(navState.route!);
    }

    // Explore mode: show selected route (uses cached checkpoint data)
    if (_selectedRoute == null || _routeCheckpointLatLngs.isEmpty) return {};
    final color = RouteBadge.colorForRoute(_selectedRoute!);
    final allLatLngs = _routeCheckpointLatLngs;

    final progress = _routeProgress;
    if (progress >= 1.0) {
      return {
        Polyline(
          polylineId: PolylineId('route_$_selectedRoute'),
          points: allLatLngs,
          color: color,
          width: 5,
        ),
      };
    }

    // Find nearest checkpoint to user
    final userLat = _lastPosition?.latitude ?? AppConstants.nusLatitude;
    final userLng = _lastPosition?.longitude ?? AppConstants.nusLongitude;
    int nearestIdx = 0;
    double minDist = double.infinity;
    for (int i = 0; i < allLatLngs.length; i++) {
      final d = _haversineDist(
        userLat,
        userLng,
        allLatLngs[i].latitude,
        allLatLngs[i].longitude,
      );
      if (d < minDist) {
        minDist = d;
        nearestIdx = i;
      }
    }

    // Two arms growing from nearest: forward and backward
    final n = allLatLngs.length;
    final forwardCount = ((n - nearestIdx) * progress).ceil().clamp(
      1,
      n - nearestIdx,
    );
    final backwardCount = ((nearestIdx + 1) * progress).ceil().clamp(
      1,
      nearestIdx + 1,
    );

    final startIdx = nearestIdx - (backwardCount - 1);
    final endIdx = nearestIdx + forwardCount;

    final visiblePoints = allLatLngs.sublist(
      startIdx.clamp(0, n),
      endIdx.clamp(0, n),
    );

    if (visiblePoints.length < 2) return {};

    return {
      Polyline(
        polylineId: PolylineId('route_$_selectedRoute'),
        points: visiblePoints,
        color: color,
        width: 5,
      ),
    };
  }

  Set<Polyline> _buildRoutePreviewPolylines(RoutePlanResult route) {
    final polylines = <Polyline>{};
    final userPosition = _currentUserLatLng;
    final destinationPosition = _selectedNavigationDestinationPosition(
      ref.read(navigationStateProvider),
    );

    for (int i = 0; i < route.legs.length; i++) {
      final leg = route.legs[i];

      if (leg.isWalk) {
        final points = _resolveWalkLegPoints(
          leg,
          userPosition: userPosition,
          destinationPosition: destinationPosition,
          isFirstLeg: i == 0,
        );
        if (points == null) {
          continue;
        }

        polylines.add(
          Polyline(
            polylineId: PolylineId('preview_walk_$i'),
            points: points,
            color: const Color(0xFF94A3B8), // Walk path - neutral gray
            width: 4,
            patterns: [PatternItem.dash(15), PatternItem.gap(10)],
          ),
        );
        continue;
      }

      if (leg.isBus && leg.routeCode != null) {
        if (leg.fromLat == null ||
            leg.fromLng == null ||
            leg.toLat == null ||
            leg.toLng == null) {
          continue;
        }

        final points = [
          LatLng(leg.fromLat!, leg.fromLng!),
          LatLng(leg.toLat!, leg.toLng!),
        ];
        final busPoints = _buildBusLegPoints(leg, fallbackPoints: points);
        polylines.add(
          Polyline(
            polylineId: PolylineId('preview_bus_$i'),
            points: busPoints,
            color: RouteBadge.colorForRoute(leg.routeCode!),
            width: 5,
          ),
        );
      }
    }

    return polylines;
  }

  LatLng? get _currentUserLatLng {
    final lastPosition = _lastPosition;
    if (lastPosition == null) {
      return null;
    }

    return LatLng(lastPosition.latitude, lastPosition.longitude);
  }

  LatLng? _selectedNavigationDestinationPosition(NavigationState navState) {
    final destination = navState.destination;
    if (destination == null) {
      return null;
    }

    return LatLng(destination.latitude, destination.longitude);
  }

  List<LatLng>? _resolveWalkLegPoints(
    RouteLeg leg, {
    LatLng? userPosition,
    LatLng? destinationPosition,
    bool isFirstLeg = false,
  }) {
    // For the first walk leg, always use live user position as the origin
    // to ensure the polyline tracks the user's actual location.
    final startLat = isFirstLeg
        ? (userPosition?.latitude ?? leg.fromLat)
        : (leg.fromLat ?? userPosition?.latitude);
    final startLng = isFirstLeg
        ? (userPosition?.longitude ?? leg.fromLng)
        : (leg.fromLng ?? userPosition?.longitude);
    final endLat = leg.toLat ?? destinationPosition?.latitude;
    final endLng = leg.toLng ?? destinationPosition?.longitude;

    if (startLat == null ||
        startLng == null ||
        endLat == null ||
        endLng == null) {
      return null;
    }

    return [LatLng(startLat, startLng), LatLng(endLat, endLng)];
  }

  List<LatLng> _buildBusLegPoints(
    RouteLeg leg, {
    required List<LatLng> fallbackPoints,
  }) {
    final routeCode = leg.routeCode;
    final fromLat = leg.fromLat;
    final fromLng = leg.fromLng;
    final toLat = leg.toLat;
    final toLng = leg.toLng;

    if (routeCode == null ||
        fromLat == null ||
        fromLng == null ||
        toLat == null ||
        toLng == null) {
      return fallbackPoints;
    }

    final checkpoints = ref.watch(checkpointsProvider(routeCode)).valueOrNull;
    if (checkpoints == null || checkpoints.isEmpty) {
      return fallbackPoints;
    }

    return clipCheckpointSegment(
          checkpoints: checkpoints,
          boardingPoint: LatLng(fromLat, fromLng),
          alightingPoint: LatLng(toLat, toLng),
        ) ??
        fallbackPoints;
  }

  static double _haversineDist(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371e3;
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

  Set<Marker> _buildMarkers(NavigationState navState) {
    if (navState.destination != null || navState.route != null) {
      return _buildRouteContextMarkers(navState);
    }

    final markers = <Marker>{};
    final stopIcon = _stopIcon;
    final selectedStopIcon = _selectedStopIcon;

    // Determine which stop codes belong to the selected route (if any)
    Set<String>? routeStopCodes;
    if (_selectedRoute != null) {
      final pp = ref.watch(pickupPointsProvider(_selectedRoute!));
      pp.whenData((points) {
        routeStopCodes = points.map((p) => p.busstopcode).toSet();
      });
    }

    // Show bus stops — all when no route selected, only route stops when selected
    if (stopIcon != null) {
      final allStops = ref.watch(stopsProvider);
      allStops.whenData((stops) {
        for (final stop in stops) {
          // Filter to route stops when a route is selected
          if (routeStopCodes != null && !routeStopCodes!.contains(stop.name)) {
            continue;
          }
          final isSelected =
              _selectedStop == stop.name || _highlightedStop == stop.name;
          markers.add(
            Marker(
              markerId: MarkerId('stop_${stop.name}'),
              position: LatLng(stop.latitude, stop.longitude),
              icon: isSelected && selectedStopIcon != null
                  ? selectedStopIcon
                  : stopIcon,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 1,
              consumeTapEvents: true,
              onTap: () {
                // When a route is selected, highlight the stop without
                // exiting the route view or opening stop detail
                if (_selectedRoute != null) {
                  _highlightStopInRoute(stop.name);
                } else {
                  _selectStop(stop.name, fromMap: true);
                }
              },
            ),
          );
        }
      });
    }

    return markers;
  }

  Set<Marker> _buildRouteContextMarkers(NavigationState navState) {
    final markers = <Marker>{};
    final route = navState.route;
    final stopIcon = _stopIcon;
    final selectedStopIcon = _selectedStopIcon;
    final destinationIcon = _destinationIcon;

    final activeStopName = _activeRouteStopName(navState);
    final seenStopKeys = <String>{};

    if (route != null && stopIcon != null) {
      for (final leg in route.legs) {
        if (!leg.isBus) continue;

        _addRouteStopMarker(
          markers: markers,
          seenStopKeys: seenStopKeys,
          stopName: leg.fromStop,
          lat: leg.fromLat,
          lng: leg.fromLng,
          stopIcon: stopIcon,
          selectedStopIcon: selectedStopIcon,
          activeStopName: activeStopName,
        );
        _addRouteStopMarker(
          markers: markers,
          seenStopKeys: seenStopKeys,
          stopName: leg.toStop,
          lat: leg.toLat,
          lng: leg.toLng,
          stopIcon: stopIcon,
          selectedStopIcon: selectedStopIcon,
          activeStopName: activeStopName,
        );
      }
    }

    final destinationPosition = _routeDestinationPosition(navState);
    if (destinationPosition != null && destinationIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('route_destination'),
          position: destinationPosition,
          icon: destinationIcon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 12,
        ),
      );
    }

    return markers;
  }

  void _addRouteStopMarker({
    required Set<Marker> markers,
    required Set<String> seenStopKeys,
    required String? stopName,
    required double? lat,
    required double? lng,
    required BitmapDescriptor stopIcon,
    required BitmapDescriptor? selectedStopIcon,
    required String? activeStopName,
  }) {
    if (lat == null || lng == null) return;

    final normalizedStopName = _normalizeRouteStopName(stopName);
    final markerKey =
        normalizedStopName ??
        '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    if (!seenStopKeys.add(markerKey)) return;

    final isActive =
        normalizedStopName != null && normalizedStopName == activeStopName;

    markers.add(
      Marker(
        markerId: MarkerId('route_stop_$markerKey'),
        position: LatLng(lat, lng),
        icon: isActive && selectedStopIcon != null
            ? selectedStopIcon
            : stopIcon,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: isActive ? 8 : 4,
      ),
    );
  }

  String? _activeRouteStopName(NavigationState navState) {
    // Live navigation disabled for MVP — no active stop highlighting
    return null;
  }

  String? _normalizeRouteStopName(String? stopName) {
    final trimmed = stopName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  LatLng? _routeDestinationPosition(NavigationState navState) {
    final destination = navState.destination;
    if (destination != null) {
      return LatLng(destination.latitude, destination.longitude);
    }

    final route = navState.route;
    if (route == null || route.legs.isEmpty) {
      return null;
    }

    final lastLeg = route.legs.last;
    if (lastLeg.toLat == null || lastLeg.toLng == null) {
      return null;
    }

    return LatLng(lastLeg.toLat!, lastLeg.toLng!);
  }

  @override
  Future<bool> didPopRoute() async {
    if (!mounted) return false;
    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    if (currentPath != '/') return false;
    final hasSelection =
        _selectedRoute != null ||
        _selectedStop != null ||
        _selectedBusPlate != null;
    if (hasSelection) {
      _clearAll();
      return true;
    }
    return false;
  }

  /// Fit map camera to show the entire navigation route.
  void _fitMapToRoute(RoutePlanResult route) {
    final points = <LatLng>[];

    // Add user position as origin
    if (_lastPosition != null) {
      points.add(LatLng(_lastPosition!.latitude, _lastPosition!.longitude));
    }

    // Add all leg endpoints
    for (final leg in route.legs) {
      if (leg.fromLat != null && leg.fromLng != null) {
        points.add(LatLng(leg.fromLat!, leg.fromLng!));
      }
      if (leg.toLat != null && leg.toLng != null) {
        points.add(LatLng(leg.toLat!, leg.toLng!));
      }
    }

    if (points.length < 2) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    const padding = 0.002;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - padding, minLng - padding),
          northeast: LatLng(maxLat + padding, maxLng + padding),
        ),
        60,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _resumeLocationStream();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _positionStreamSubscription?.cancel();
      _positionStreamSubscription = null;
    }
  }

  void _resumeLocationStream() {
    if (_positionStreamSubscription != null) return;
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) {
          if (!mounted) return;
          setState(() => _streamPosition = position);
          _updateLocationScreenPosition();
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _highlightFlashTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _tabController.dispose();
    _routeAnimController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // --------------- Helpers for sub-widgets ---------------

  String? _getFirstBusLegRouteCode(NavigationState navState) {
    if (navState.route == null) return null;
    for (final leg in navState.route!.legs) {
      if (leg.isBus) return leg.routeCode;
    }
    return null;
  }

  Future<void> _handleRecenter() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
    } catch (_) {}
  }

  void _handleCenterMap(double lat, double lng, String stopCode) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
    _flashHighlightStop(stopCode);
  }

  void _handleStopsBusSelected(String route, String plate) {
    final allBuses = ref.read(allActiveBusesProvider).valueOrNull;
    if (allBuses == null) return;
    final buses = allBuses[route] ?? [];
    final bus = buses.cast<ActiveBus?>().firstWhere(
      (b) => b!.vehPlate == plate,
      orElse: () => null,
    );
    if (bus != null) _selectBus(route, bus);
  }

  void _handleLinesBusSelected(String route, String plate) {
    final allBuses = ref.read(allActiveBusesProvider).valueOrNull;
    if (allBuses == null) return;
    final buses = allBuses[route] ?? [];
    final bus = buses.cast<ActiveBus?>().firstWhere(
      (b) => b!.vehPlate == plate,
      orElse: () => null,
    );
    if (bus == null) return;
    if (_selectedBusPlate == plate) {
      setState(() => _selectedBusPlate = null);
    } else {
      _selectBus(route, bus);
    }
  }

  // --------------- Build ---------------

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lat = _lastPosition?.latitude ?? AppConstants.nusLatitude;
    final lng = _lastPosition?.longitude ?? AppConstants.nusLongitude;
    final allSortedStops = ref.watch(
      allStopsSortedByDistanceProvider((lat: lat, lng: lng)),
    );
    final screenHeight = MediaQuery.of(context).size.height;
    final topInset = MediaQuery.of(context).padding.top;
    _panelHeight = screenHeight * 0.4;
    // Account for status bar + search bar overlay (~60px below safe area)
    _mapTopPadding = topInset + 60;

    // Get current bus data for overlay
    final allBuses = ref.watch(allActiveBusesProvider);
    final busMap = allBuses.valueOrNull ?? <String, List<ActiveBus>>{};

    // Watch navigation state to react to destination/route selection
    final navState = ref.watch(navigationStateProvider);

    // Listen for pending stop selection from Saved tab (or other screens)
    ref.listen<String?>(pendingStopSelectionProvider, (previous, next) {
      if (next != null) {
        // Clear the pending selection immediately
        ref.read(pendingStopSelectionProvider.notifier).state = null;
        // Select the stop (this centers map and shows detail view)
        _selectStop(next);
      }
    });

    // Listen for bus data changes and update screen positions
    // (moved out of _buildMarkers to avoid side effects during build)
    ref.listen(allActiveBusesProvider, (_, next) {
      next.whenData((_) {
        _updateBusScreenPositions(animate: true);
      });
    });

    // Cache checkpoint data for selected route polylines (explore mode)
    if (_selectedRoute != null && navState.route == null) {
      ref.listen(checkpointsProvider(_selectedRoute!), (_, next) {
        next.whenData((points) {
          setState(() {
            _routeCheckpointLatLngs = points
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();
          });
        });
      });
      // Eagerly read already-available data (e.g. cached from previous selection)
      final cpVal = ref.read(checkpointsProvider(_selectedRoute!));
      cpVal.whenData((points) {
        _routeCheckpointLatLngs = points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      });
    } else {
      _routeCheckpointLatLngs = [];
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Google Map (base layer) — wrapped with LayoutBuilder for resize detection
          LayoutBuilder(
            builder: (context, constraints) {
              final currentSize = constraints.biggest;

              // Detect resize and schedule position update (skip initial build)
              if (_lastMapSize != null && _lastMapSize != currentSize) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _updateBusScreenPositions(animate: false);
                });
              }
              _lastMapSize = currentSize;

              return KeyedSubtree(
                key: _mapKey,
                child: Builder(
                  builder: (context) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _nusCenter,
                        zoom: AppConstants.defaultZoom,
                      ),
                      style: isDark ? _darkMapStyle : _lightMapStyle,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        // Set initial camera position for projection
                        _currentCameraPosition = CameraPosition(
                          target: _nusCenter,
                          zoom: AppConstants.defaultZoom,
                        );
                        // Initial position calculation after map is ready
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted)
                            _updateBusScreenPositions(animate: false);
                        });

                        final navState = ref.read(navigationStateProvider);
                        if (navState.status == NavigationStatus.routePreview &&
                            navState.route != null) {
                          _fitMapToRoute(navState.route!);
                        }
                      },
                      onCameraMove: _onCameraMove,
                      onCameraIdle: _onCameraIdle,
                      onTap: (_) => _clearAll(),
                      myLocationEnabled:
                          false, // Using custom LocationOverlayMarker
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      padding: EdgeInsets.only(
                        top: _mapTopPadding,
                        bottom: _panelHeight,
                      ),
                      polylines: _buildPolylines(navState),
                      markers: _buildMarkers(navState),
                    );
                  },
                ),
              );
            },
          ),

          // GPU-accelerated bus marker overlay layer
          _BusOverlays(
            busMap: busMap,
            isRoutePreview: navState.route != null,
            trackedPlate: navState.route != null
                ? _getTrackedBusPlate(navState)
                : null,
            trackedRouteCode: navState.route != null
                ? _getFirstBusLegRouteCode(navState)
                : null,
            selectedRoute: _selectedRoute,
            selectedBusPlate: _selectedBusPlate,
            busScreenPositions: _busScreenPositions,
            busesWithPositionChange: _busesWithPositionChange,
            onBusTap: _selectBus,
          ),

          // Custom location marker with compass heading (below bus markers)
          if (_locationScreenPosition != null)
            LocationOverlayMarker(
              key: const ValueKey('location_overlay'),
              screenX: _locationScreenPosition!.dx,
              screenY: _locationScreenPosition!.dy,
              accuracy: _streamPosition?.accuracy,
              metersPerPixel: _currentCameraPosition != null
                  ? _calculateMetersPerPixel(_currentCameraPosition!)
                  : null,
              shouldAnimate: false, // Snap position during camera moves
            ),

          // Highlighted stop overlay (appears above bus markers) — hide when route is selected
          if (navState.route == null && _buildHighlightedStopOverlay() != null)
            _buildHighlightedStopOverlay()!,

          // Route info banner / destination preview / search bar — hide when route detail is shown
          if (navState.route == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: _RouteBanner(
                selectedRoute: _selectedRoute,
                destination: navState.destination,
                lastPosition: _lastPosition,
                activeBuses: allBuses,
                onClearRoute: _clearRoute,
                onDestinationSelected: _onDestinationSelected,
                onCancelNavigation: () {
                  ref.read(navigationStateProvider.notifier).cancelNavigation();
                },
              ),
            ),

          // My location button — hide when route detail is shown
          if (navState.route == null)
            _MapFABs(panelHeight: _panelHeight, onRecenter: _handleRecenter),

          // Bottom panel (fixed height) — hide when route is selected
          // Wrap with MediaQuery.removeViewInsets to ignore keyboard
          if (navState.route == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _panelHeight,
              child: MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: _BottomPanel(
                  navState: navState,
                  allSortedStops: allSortedStops,
                  userLat: lat,
                  userLng: lng,
                  tabController: _tabController,
                  selectedStop: _selectedStop,
                  selectedRoute: _selectedRoute,
                  selectedBusPlate: _selectedBusPlate,
                  highlightedStop: _highlightedStop,
                  scrollToSelection: _scrollToSelection,
                  lastPosition: _lastPosition,
                  onStopSelected: (name) => _selectStop(name),
                  onStopLocate: _locateStop,
                  onRouteSelected: (route) => _selectRoute(route),
                  onCenterMap: _handleCenterMap,
                  onStopsBusSelected: _handleStopsBusSelected,
                  onLinesBusSelected: _handleLinesBusSelected,
                  onRetryStops: () => ref.invalidate(stopsProvider),
                ),
              ),
            ),

          // Route detail view — overlay chrome above the shared map surface
          if (navState.route != null &&
              navState.status == NavigationStatus.routePreview)
            RouteDetailView(
              route: navState.route!,
              userPosition: _lastPosition,
              onRouteFocusRequested: () {
                if (navState.route != null) {
                  _fitMapToRoute(navState.route!);
                }
              },
              onBack: () {
                // Clear selected route and return to suggestions
                ref.read(navigationStateProvider.notifier).deselectRoute();
              },
            ),
        ],
      ),
    );
  }
}

// --------------- Extracted Sub-Widgets ---------------

/// GPU-accelerated bus marker overlay layer.
/// Renders bus position markers on the map — one of the hottest re-rendering paths.
class _BusOverlays extends StatelessWidget {
  const _BusOverlays({
    required this.busMap,
    required this.isRoutePreview,
    this.trackedPlate,
    this.trackedRouteCode,
    this.selectedRoute,
    this.selectedBusPlate,
    required this.busScreenPositions,
    required this.busesWithPositionChange,
    required this.onBusTap,
  });

  final Map<String, List<ActiveBus>> busMap;
  final bool isRoutePreview;
  final String? trackedPlate;
  final String? trackedRouteCode;
  final String? selectedRoute;
  final String? selectedBusPlate;
  final Map<String, Offset> busScreenPositions;
  final Set<String> busesWithPositionChange;
  final void Function(String routeCode, ActiveBus bus) onBusTap;

  @override
  Widget build(BuildContext context) {
    if (isRoutePreview) {
      if (trackedPlate == null) return const SizedBox.shrink();
      return IgnorePointer(
        ignoring: true,
        child: Stack(
          children: _buildOverlays(
            filterRouteCode: trackedRouteCode,
            highlightPlate: trackedPlate,
          ),
        ),
      );
    }
    return IgnorePointer(
      ignoring: false,
      child: Stack(children: _buildOverlays()),
    );
  }

  List<Widget> _buildOverlays({
    String? filterRouteCode,
    String? highlightPlate,
  }) {
    final overlays = <Widget>[];

    for (final entry in busMap.entries) {
      final routeCode = entry.key;
      if (selectedRoute != null && routeCode != selectedRoute) continue;
      if (filterRouteCode != null && routeCode != filterRouteCode) continue;

      final color = RouteBadge.colorForRoute(routeCode);

      for (final bus in entry.value) {
        final screenPos = busScreenPositions[bus.vehPlate];
        if (screenPos == null) continue;

        final isSelected =
            selectedBusPlate == bus.vehPlate || bus.vehPlate == highlightPlate;

        overlays.add(
          BusOverlayMarker(
            key: ValueKey('bus_overlay_${bus.vehPlate}'),
            screenX: screenPos.dx,
            screenY: screenPos.dy,
            occupancy: bus.loadInfo?.occupancy ?? 0,
            direction: bus.direction,
            routeColor: color,
            isSelected: isSelected,
            plate: bus.vehPlate,
            speed: bus.speed,
            shouldAnimate: busesWithPositionChange.contains(bus.vehPlate),
            onTap: () => onBusTap(routeCode, bus),
          ),
        );
      }
    }

    return overlays;
  }
}

/// Route info banner, destination preview, or search bar at the top of the map.
class _RouteBanner extends StatelessWidget {
  const _RouteBanner({
    this.selectedRoute,
    this.destination,
    this.lastPosition,
    required this.activeBuses,
    required this.onClearRoute,
    required this.onDestinationSelected,
    required this.onCancelNavigation,
  });

  final String? selectedRoute;
  final Building? destination;
  final Position? lastPosition;
  final AsyncValue<Map<String, List<ActiveBus>>> activeBuses;
  final VoidCallback onClearRoute;
  final VoidCallback onDestinationSelected;
  final VoidCallback onCancelNavigation;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcherDefaults(
      duration: const Duration(milliseconds: 250),
      child: selectedRoute != null
          ? _buildRouteBanner(context)
          : destination != null
          ? _buildDestinationPreview(context, destination!)
          : SearchDropdown(
              key: const ValueKey('search_bar'),
              userPosition: lastPosition,
              onDestinationSelected: onDestinationSelected,
            ),
    );
  }

  Widget _buildRouteBanner(BuildContext context) {
    final colors = context.nusColors;
    return Container(
      key: const ValueKey('route_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          RouteBadge(routeCode: selectedRoute!, fontSize: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Route $selectedRoute',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          _buildBusCount(context),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClearRoute,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close, size: 18, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusCount(BuildContext context) {
    if (selectedRoute == null) return const SizedBox.shrink();
    final colors = context.nusColors;
    return activeBuses.when(
      skipLoadingOnReload: true,
      data: (busMap) {
        final list = busMap[selectedRoute] ?? [];
        return AnimatedSwitcherDefaults(
          child: Container(
            key: ValueKey(list.length),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.successBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${list.length} bus${list.length != 1 ? 'es' : ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.success,
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildDestinationPreview(BuildContext context, Building destination) {
    final colors = context.nusColors;
    return Container(
      key: const ValueKey('destination_preview'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.infoBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.location_on, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Destination',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancelNavigation,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.close, size: 18, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// My-location floating action button.
class _MapFABs extends StatelessWidget {
  const _MapFABs({required this.panelHeight, required this.onRecenter});

  final double panelHeight;
  final Future<void> Function() onRecenter;

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      right: 16,
      bottom: panelHeight + 16,
      child: FloatingActionButton.small(
        heroTag: 'myLocation',
        backgroundColor: colors.surface,
        onPressed: onRecenter,
        child: Icon(Icons.my_location, color: colors.primary, size: 22),
      ),
    );
  }
}

/// Bottom panel showing stops/lines tabs or route suggestions.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.navState,
    required this.allSortedStops,
    required this.userLat,
    required this.userLng,
    required this.tabController,
    this.selectedStop,
    this.selectedRoute,
    this.selectedBusPlate,
    this.highlightedStop,
    required this.scrollToSelection,
    this.lastPosition,
    required this.onStopSelected,
    required this.onStopLocate,
    required this.onRouteSelected,
    required this.onCenterMap,
    required this.onStopsBusSelected,
    required this.onLinesBusSelected,
    required this.onRetryStops,
  });

  final NavigationState navState;
  final AsyncValue<List<NearbyStopResult>> allSortedStops;
  final double userLat;
  final double userLng;
  final TabController tabController;
  final String? selectedStop;
  final String? selectedRoute;
  final String? selectedBusPlate;
  final String? highlightedStop;
  final bool scrollToSelection;
  final Position? lastPosition;
  final void Function(String) onStopSelected;
  final void Function(String) onStopLocate;
  final void Function(String) onRouteSelected;
  final void Function(double, double, String) onCenterMap;
  final void Function(String, String) onStopsBusSelected;
  final void Function(String, String) onLinesBusSelected;
  final VoidCallback onRetryStops;

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (navState.status == NavigationStatus.routePreview &&
        navState.destination != null) {
      return RouteSuggestionsPanel(
        destination: navState.destination!,
        userPosition: lastPosition,
      );
    }

    return Column(
      children: [
        _buildTabBar(context),
        Expanded(
          child: allSortedStops.when(
            skipLoadingOnReload: true,
            data: (stops) => TabBarView(
              controller: tabController,
              children: [
                StopsTab(
                  stops: stops,
                  selectedStop: selectedStop,
                  selectedRoute: selectedRoute,
                  onStopSelected: onStopSelected,
                  onStopLocate: onStopLocate,
                  onRouteSelected: onRouteSelected,
                  onCenterMap: onCenterMap,
                  onBusSelected: onStopsBusSelected,
                ),
                LinesTab(
                  userLat: userLat,
                  userLng: userLng,
                  selectedRoute: selectedRoute,
                  selectedBusPlate: selectedBusPlate,
                  highlightedStopCode: highlightedStop,
                  shouldScrollToSelection: scrollToSelection,
                  onRouteSelected: onRouteSelected,
                  onCenterMap: onCenterMap,
                  onBusSelected: onLinesBusSelected,
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: ShimmerList(itemCount: 3, itemHeight: 80),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: ErrorCard(
                message: error.toString(),
                onRetry: onRetryStops,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final colors = context.nusColors;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderLight)),
      ),
      child: TabBar(
        controller: tabController,
        labelColor: colors.primary,
        unselectedLabelColor: colors.textMuted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: colors.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(
            height: 38,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined, size: 16),
                SizedBox(width: 5),
                Text('Stops'),
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_outlined, size: 16),
                SizedBox(width: 5),
                Text('Lines'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
