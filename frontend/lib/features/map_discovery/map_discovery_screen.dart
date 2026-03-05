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
import 'package:frontend/state/providers.dart';
import 'package:frontend/core/utils/marker_painter.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/features/map_discovery/widgets/stops_tab.dart';
import 'package:frontend/features/map_discovery/widgets/lines_tab.dart';

class MapDiscoveryScreen extends ConsumerStatefulWidget {
  const MapDiscoveryScreen({super.key});

  @override
  ConsumerState<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends ConsumerState<MapDiscoveryScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Timer? _pollTimer;
  Position? _lastPosition;

  // Map selection state
  String? _selectedRoute;
  String? _selectedStop; // stop name
  String? _selectedBusPlate;

  // Tab
  late final TabController _tabController;

  // Custom marker icons
  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _selectedStopIcon;
  Map<String, BitmapDescriptor> _perBusIcons = {};
  Map<String, (BitmapDescriptor, Offset)> _perBusSelectedIcons = {};

  // Panel height (state variable for dynamic adjustment)
  double _panelHeight = 0;

  // Route polyline animation
  AnimationController? _routeAnimController;

  static const _nusCenter = LatLng(
    AppConstants.nusLatitude,
    AppConstants.nusLongitude,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _lastPosition = pos);
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
    } catch (_) {
      // Location unavailable
    }
    _startPolling();
    _generateIcons();
  }

  Future<void> _generateIcons() async {
    _stopIcon = await MarkerPainter.createStopMarker();
    _selectedStopIcon = await MarkerPainter.createSelectedStopMarker();
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
      _selectedBusPlate = null;
      _scrollToSelection = fromMap;
    });
    if (_tabController.index != 0) _tabController.animateTo(0);

    // Center map when selecting from list (not from map tap)
    if (!fromMap && !deselecting) {
      final allStops = ref.read(stopsProvider);
      allStops.whenData((stops) {
        final stop = stops.cast<BusStop?>().firstWhere(
          (s) => s!.name == stopName,
          orElse: () => null,
        );
        if (stop != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(LatLng(stop.latitude, stop.longitude)),
          );
        }
      });
    }
  }

  void _selectRoute(String routeCode, {bool fromMap = false}) {
    final deselecting = _selectedRoute == routeCode;
    setState(() {
      _selectedRoute = deselecting ? null : routeCode;
      _selectedBusPlate = null;
      _scrollToSelection = fromMap;
    });
    if (deselecting) {
      _routeAnimController?.stop();
    } else {
      _startRouteAnimation();
    }
  }

  void _selectBus(String route, ActiveBus bus) {
    _selectRoute(route, fromMap: true);
    setState(() {
      _selectedBusPlate = bus.vehPlate;
      _scrollToSelection = true;
    });
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
      _selectedBusPlate = null;
    });
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

  // --------------- Bus icon generation ---------------

  void _maybeRegenerateBusIcons(Map<String, List<ActiveBus>> busMap) {
    final plates = <String>{};
    for (final buses in busMap.values) {
      for (final b in buses) {
        plates.add(b.vehPlate);
      }
    }
    if (plates.length == _perBusIcons.length &&
        plates.every(_perBusIcons.containsKey)) {
      return;
    }
    _regenerateBusIcons(busMap);
  }

  Future<void> _regenerateBusIcons(Map<String, List<ActiveBus>> busMap) async {
    final icons = <String, BitmapDescriptor>{};
    final selectedIcons = <String, (BitmapDescriptor, Offset)>{};
    for (final entry in busMap.entries) {
      final routeCode = entry.key;
      final color = RouteBadge.colorForRoute(routeCode);
      for (final bus in entry.value) {
        final occ = bus.loadInfo?.occupancy ?? 0;
        final dir = bus.direction;
        icons[bus.vehPlate] = await MarkerPainter.createBusMarker(
          occupancy: occ,
          direction: dir,
          routeColor: color,
        );
        selectedIcons[bus.vehPlate] =
            await MarkerPainter.createSelectedBusMarker(
              occupancy: occ,
              direction: dir,
              routeColor: color,
              plate: bus.vehPlate,
              speed: bus.speed,
              crowdLevel: bus.loadInfo?.crowdLevel,
            );
      }
    }
    if (mounted) {
      setState(() {
        _perBusIcons = icons;
        _perBusSelectedIcons = selectedIcons;
      });
    }
  }

  // --------------- Map overlays ---------------

  Set<Polyline> _buildPolylines() {
    if (_selectedRoute == null) return {};
    final checkpoints = ref.watch(checkpointsProvider(_selectedRoute!));
    return checkpoints.when(
      data: (points) {
        if (points.isEmpty) return <Polyline>{};
        final color = RouteBadge.colorForRoute(_selectedRoute!);
        final allLatLngs = points
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

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
      },
      loading: () => <Polyline>{},
      error: (_, __) => <Polyline>{},
    );
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

  Set<Marker> _buildMarkers() {
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
          final isSelected = _selectedStop == stop.name;
          markers.add(
            Marker(
              markerId: MarkerId('stop_${stop.name}'),
              position: LatLng(stop.latitude, stop.longitude),
              icon: isSelected && selectedStopIcon != null
                  ? selectedStopIcon
                  : stopIcon,
              anchor: const Offset(0.5, 0.5),
              zIndex: 1,
              consumeTapEvents: true,
              onTap: () => _selectStop(stop.name, fromMap: true),
            ),
          );
        }
      });
    }

    // Active bus markers — all buses when no route selected, route buses when selected
    final allBuses = ref.watch(allActiveBusesProvider);
    allBuses.whenData((busMap) {
      _maybeRegenerateBusIcons(busMap);
      for (final entry in busMap.entries) {
        final routeCode = entry.key;
        // Filter to selected route if one is active
        if (_selectedRoute != null && routeCode != _selectedRoute) continue;
        for (final bus in entry.value) {
          final isSelected = _selectedBusPlate == bus.vehPlate;
          if (isSelected) {
            final selected = _perBusSelectedIcons[bus.vehPlate];
            if (selected != null) {
              markers.add(
                Marker(
                  markerId: MarkerId('bus_${bus.vehPlate}'),
                  position: LatLng(bus.lat, bus.lng),
                  icon: selected.$1,
                  anchor: selected.$2,
                  zIndex: 3,
                  consumeTapEvents: true,
                  onTap: () => _selectBus(routeCode, bus),
                ),
              );
            }
          } else {
            final icon = _perBusIcons[bus.vehPlate];
            if (icon != null) {
              markers.add(
                Marker(
                  markerId: MarkerId('bus_${bus.vehPlate}'),
                  position: LatLng(bus.lat, bus.lng),
                  icon: icon,
                  anchor: const Offset(0.5, 0.5),
                  zIndex: 2,
                  consumeTapEvents: true,
                  onTap: () => _selectBus(routeCode, bus),
                ),
              );
            }
          }
        }
      }
    });

    return markers;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _tabController.dispose();
    _routeAnimController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // --------------- Build ---------------

  @override
  Widget build(BuildContext context) {
    final lat = _lastPosition?.latitude ?? AppConstants.nusLatitude;
    final lng = _lastPosition?.longitude ?? AppConstants.nusLongitude;
    final allSortedStops = ref.watch(
      allStopsSortedByDistanceProvider((lat: lat, lng: lng)),
    );
    final screenHeight = MediaQuery.of(context).size.height;
    final topInset = MediaQuery.of(context).padding.top;
    _panelHeight = screenHeight * 0.4;
    // Account for status bar + search bar overlay (~60px below safe area)
    final mapTopPadding = topInset + 60;

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _nusCenter,
              zoom: AppConstants.defaultZoom,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (_) => _clearAll(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            padding: EdgeInsets.only(top: mapTopPadding, bottom: _panelHeight),
            polylines: _buildPolylines(),
            markers: _buildMarkers(),
          ),

          // Route info banner / search bar (animated switch)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: AnimatedSwitcherDefaults(
              duration: const Duration(milliseconds: 250),
              child: _selectedRoute != null
                  ? Container(
                      key: const ValueKey('route_banner'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
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
                          RouteBadge(routeCode: _selectedRoute!, fontSize: 13),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Route $_selectedRoute',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _buildBusCount(),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _clearRoute,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey('search_bar'),
                      onTap: () => context.go('/search'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: AppColors.textMuted,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Where are you heading?',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          // My location button
          Positioned(
            right: 16,
            bottom: _panelHeight + 16,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: AppColors.surface,
              onPressed: () async {
                try {
                  final pos = await Geolocator.getCurrentPosition();
                  if (!mounted) return;
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
                  );
                } catch (_) {}
              },
              child: const Icon(
                Icons.my_location,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),

          // Fixed bottom panel with tabs
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _panelHeight,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Column(
                children: [
                  // Tab bar
                  _buildTabBar(),
                  // Tab content
                  Expanded(
                    child: allSortedStops.when(
                      skipLoadingOnReload: true,
                      data: (stops) => TabBarView(
                        controller: _tabController,
                        children: [
                          StopsTab(
                            stops: stops,
                            selectedStop: _selectedStop,
                            selectedRoute: _selectedRoute,
                            onStopSelected: (name) => _selectStop(name),
                            onRouteSelected: (route) => _selectRoute(route),
                          ),
                          LinesTab(
                            userLat: lat,
                            userLng: lng,
                            selectedRoute: _selectedRoute,
                            shouldScrollToSelection: _scrollToSelection,
                            onRouteSelected: (route) => _selectRoute(route),
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
                          onRetry: () => ref.invalidate(stopsProvider),
                        ),
                      ),
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

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: AppColors.primary,
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

  Widget _buildBusCount() {
    if (_selectedRoute == null) return const SizedBox.shrink();
    final allBuses = ref.watch(allActiveBusesProvider);
    return allBuses.when(
      skipLoadingOnReload: true,
      data: (busMap) {
        final list = busMap[_selectedRoute] ?? [];
        return AnimatedSwitcherDefaults(
          child: Container(
            key: ValueKey(list.length),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${list.length} bus${list.length != 1 ? 'es' : ''}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
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
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
