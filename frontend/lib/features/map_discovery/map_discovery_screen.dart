import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/map_discovery/widgets/stop_card.dart';

const _kNusCampus = LatLng(1.2966, 103.7764);
const _kDefaultZoom = 15.5;

const _kDarkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0e1a21"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#64748b"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0e1a21"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1a2c38"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#223b49"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0b1218"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#14242e"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#12282e"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#162630"}]}
]
''';

class MapDiscoveryScreen extends ConsumerStatefulWidget {
  const MapDiscoveryScreen({super.key});

  @override
  ConsumerState<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends ConsumerState<MapDiscoveryScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  int _expandedStopIndex = 0;
  String? _overlayRouteCode;
  Set<Polyline> _polylines = {};
  Timer? _refreshTimer;
  List<String> _visibleStopNames = [];

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.invalidate(
        nearbyStopsProvider((
          lat: _queryLocation.latitude,
          lng: _queryLocation.longitude,
        )),
      );
      // Collect route codes from cached shuttle data before invalidating
      final routeCodes = <String>{};
      for (final name in _visibleStopNames) {
        final shuttleData = ref.read(shuttlesProvider(name));
        shuttleData.whenData((result) {
          for (final shuttle in result.shuttles) {
            routeCodes.add(shuttle.name);
          }
        });
        ref.invalidate(shuttlesProvider(name));
      }
      // Refresh active buses for all visible routes (capacity data)
      for (final route in routeCodes) {
        ref.invalidate(activeBusesProvider(route));
      }
      if (_overlayRouteCode != null) {
        ref.invalidate(activeBusesProvider(_overlayRouteCode!));
        ref.invalidate(checkpointsProvider(_overlayRouteCode!));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) setState(() => _currentPosition = pos);
  }

  void _centerOnCurrentLocation() {
    final target = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _kNusCampus;
    _mapController?.animateCamera(CameraUpdate.newLatLng(target));
  }

  void _zoomIn() {
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  LatLng get _queryLocation => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : _kNusCampus;

  void _showRouteOverlay(String routeCode) {
    setState(() => _overlayRouteCode = routeCode);
  }

  @override
  Widget build(BuildContext context) {
    final nearbyAsync = ref.watch(
      nearbyStopsProvider((
        lat: _queryLocation.latitude,
        lng: _queryLocation.longitude,
      )),
    );

    // Build route polyline when a route is selected
    if (_overlayRouteCode != null) {
      final checkpointsAsync = ref.watch(
        checkpointsProvider(_overlayRouteCode!),
      );
      checkpointsAsync.whenData((points) {
        final sorted = [...points]
          ..sort((a, b) => a.pointId.compareTo(b.pointId));
        final coords = sorted
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        _polylines = {
          Polyline(
            polylineId: PolylineId(_overlayRouteCode!),
            points: coords,
            color: AppTheme.primary,
            width: 4,
          ),
        };
      });
    }

    // Build markers
    final markers = <Marker>{};
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          zIndexInt: 2,
        ),
      );
    }
    nearbyAsync.whenData((stops) {
      _visibleStopNames = stops.map((s) => s.stopName).toList();
      for (final stop in stops) {
        markers.add(
          Marker(
            markerId: MarkerId(stop.stopName),
            position: LatLng(stop.latitude, stop.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueCyan,
            ),
            infoWindow: InfoWindow(title: stop.stopDisplayName),
            onTap: () {
              final idx = stops.indexOf(stop);
              setState(() => _expandedStopIndex = idx);
            },
          ),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kNusCampus,
              zoom: _kDefaultZoom,
            ),
            style: _kDarkMapStyle,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Top Header + Search ──────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 16),
                  _buildSearchBar(context),
                ],
              ),
            ),
          ),

          // ── Map Controls (right side) ────────────────────
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.42,
            child: _buildMapControls(),
          ),

          // ── Bottom Drawer ────────────────────────────────
          _buildBottomSheet(nearbyAsync),
        ],
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _glassIconButton(Icons.menu),
        const Text(
          'NUS Motion',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: Color(0xFFF1F5F9),
          ),
        ),
        _glassIconButton(Icons.person),
      ],
    );
  }

  Widget _glassIconButton(IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/search'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: AppTheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Search destinations, lines, or stops',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Map controls ─────────────────────────────────────────────────────

  Widget _buildMapControls() {
    return Column(
      children: [
        _mapControlButton(Icons.my_location, _centerOnCurrentLocation),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  _zoomButton(Icons.add, _zoomIn, showBottomBorder: true),
                  _zoomButton(Icons.remove, _zoomOut),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapControlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _zoomButton(
    IconData icon,
    VoidCallback onTap, {
    bool showBottomBorder = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          border: showBottomBorder
              ? Border(
                  bottom: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                  ),
                )
              : null,
        ),
        child: Icon(icon, color: AppTheme.primary),
      ),
    );
  }

  // ── Bottom Sheet ─────────────────────────────────────────────────────

  Widget _buildBottomSheet(AsyncValue<List<NearbyStopResult>> nearbyAsync) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.1,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.1, 0.38, 0.85],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xCC101B22), // rgba(16,27,34,0.8)
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 6,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                  ),
                  // Header
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Text(
                      'Nearby Stops',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                  ),
                  // Stop cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: nearbyAsync.when(
                      data: (stops) => _buildStopList(stops),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Could not load nearby stops',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Extra padding so content doesn't sit under bottom nav
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStopList(List<NearbyStopResult> stops) {
    if (stops.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No nearby stops found',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < stops.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < stops.length - 1 ? 16 : 0),
            child: StopCard(
              stop: stops[i],
              isExpanded: _expandedStopIndex == i,
              onToggle: () {
                setState(() {
                  _expandedStopIndex = _expandedStopIndex == i ? -1 : i;
                });
              },
              onRouteTap: _showRouteOverlay,
            ),
          ),
      ],
    );
  }
}
