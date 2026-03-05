import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shimmer/shimmer.dart';

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
  int _expandedStopIndex = 0;
  String? _overlayRouteCode;
  Set<Polyline> _polylines = {};
  Timer? _refreshTimer;
  List<String> _visibleStopNames = [];

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      ref.invalidate(
        nearbyStopsProvider((
          lat: _queryLocation.latitude,
          lng: _queryLocation.longitude,
        )),
      );
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

  Position? get _currentPosition =>
      ref.read(positionStreamProvider).valueOrNull;

  void _centerOnCurrentLocation() {
    HapticFeedback.lightImpact();
    final pos = _currentPosition;
    final target = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : _kNusCampus;
    _mapController?.animateCamera(CameraUpdate.newLatLng(target));
  }

  void _zoomIn() {
    HapticFeedback.selectionClick();
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    HapticFeedback.selectionClick();
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  LatLng get _queryLocation {
    final pos = _currentPosition;
    return pos != null ? LatLng(pos.latitude, pos.longitude) : _kNusCampus;
  }

  void _showRouteOverlay(String routeCode) {
    setState(() => _overlayRouteCode = routeCode);
  }

  @override
  Widget build(BuildContext context) {
    // Watch live position stream — triggers rebuild on movement
    final posAsync = ref.watch(positionStreamProvider);
    final pos = posAsync.valueOrNull;

    final nearbyAsync = ref.watch(
      nearbyStopsProvider((
        lat: _queryLocation.latitude,
        lng: _queryLocation.longitude,
      )),
    );

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

    final markers = <Marker>{};
    if (pos != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(pos.latitude, pos.longitude),
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
          // ── Google Map ──────────────────────────────────────
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kNusCampus,
              zoom: _kDefaultZoom,
            ),
            style: _kDarkMapStyle,
            onMapCreated: (controller) => _mapController = controller,
            markers: markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Top Header + Search ────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TopBar(),
                  const SizedBox(height: AppTheme.spacing16),
                  _SearchBar(),
                ],
              ),
            ),
          ),

          // ── Map Controls (right side) ──────────────────────
          Positioned(
            right: AppTheme.spacing16,
            bottom: MediaQuery.of(context).size.height * 0.42,
            child: _MapControls(
              onMyLocation: _centerOnCurrentLocation,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
            ),
          ),

          // ── Bottom Drawer ──────────────────────────────────
          _buildBottomSheet(nearbyAsync),
        ],
      ),
    );
  }

  // ── Bottom Sheet ─────────────────────────────────────────────────

  Widget _buildBottomSheet(AsyncValue<List<NearbyStopResult>> nearbyAsync) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.1,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.1, 0.38, 0.85],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXl),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark.withValues(alpha: 0.92),
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
                      margin: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacing12,
                      ),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusFull,
                        ),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing24,
                      0,
                      AppTheme.spacing24,
                      AppTheme.spacing16,
                    ),
                    child: Text(
                      'Nearby Stops',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  // Stop cards
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing24,
                    ),
                    child: nearbyAsync.when(
                      data: (stops) => _buildStopList(stops),
                      loading: () => _buildShimmerList(),
                      error: (e, _) => _buildErrorState(
                        'Could not load nearby stops',
                        onRetry: () => ref.invalidate(
                          nearbyStopsProvider((
                            lat: _queryLocation.latitude,
                            lng: _queryLocation.longitude,
                          )),
                        ),
                      ),
                    ),
                  ),
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
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          children: [
            Icon(
              Icons.location_off_outlined,
              color: AppTheme.textMuted,
              size: 40,
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              'No nearby stops found',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < stops.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i < stops.length - 1 ? AppTheme.spacing16 : 0,
            ),
            child: StopCard(
              key: ValueKey(stops[i].stopName),
              stop: stops[i],
              isExpanded: _expandedStopIndex == i,
              onToggle: () {
                HapticFeedback.selectionClick();
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

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: AppTheme.neutralDark,
      child: Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, {VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, color: AppTheme.textMuted, size: 40),
          const SizedBox(height: AppTheme.spacing12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (onRetry != null) ...[
            const SizedBox(height: AppTheme.spacing16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Extracted Widgets ──────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _GlassIconButton(icon: Icons.menu, onTap: () {}),
        Text(
          'NUS Motion',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(letterSpacing: -0.5),
        ),
        _GlassIconButton(icon: Icons.person, onTap: () {}),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: AppTheme.backgroundDark.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: AppTheme.backgroundDark.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: InkWell(
            onTap: () => context.go('/search'),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
                vertical: AppTheme.spacing16,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: AppTheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    'Search destinations, lines, or stops',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  final VoidCallback onMyLocation;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _MapControls({
    required this.onMyLocation,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GlassControlButton(
          icon: Icons.my_location,
          onTap: onMyLocation,
          circular: true,
        ),
        const SizedBox(height: AppTheme.spacing12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  _ZoomButton(
                    icon: Icons.add,
                    onTap: onZoomIn,
                    showBorder: true,
                  ),
                  _ZoomButton(icon: Icons.remove, onTap: onZoomOut),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool circular;

  const _GlassControlButton({
    required this.icon,
    required this.onTap,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: AppTheme.backgroundDark.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: SizedBox(
              height: 48,
              width: 48,
              child: Icon(icon, color: AppTheme.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool showBorder;

  const _ZoomButton({
    required this.icon,
    required this.onTap,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          width: 48,
          decoration: showBorder
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                )
              : null,
          child: Icon(icon, color: AppTheme.primary),
        ),
      ),
    );
  }
}
