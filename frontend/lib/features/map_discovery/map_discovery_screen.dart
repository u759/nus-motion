import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/widgets/loading_shimmer.dart';
import 'package:frontend/core/widgets/error_card.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/map_discovery/widgets/nearby_stop_card.dart';

class MapDiscoveryScreen extends ConsumerStatefulWidget {
  const MapDiscoveryScreen({super.key});

  @override
  ConsumerState<MapDiscoveryScreen> createState() => _MapDiscoveryScreenState();
}

class _MapDiscoveryScreenState extends ConsumerState<MapDiscoveryScreen> {
  GoogleMapController? _mapController;
  Timer? _pollTimer;
  Position? _lastPosition;
  final _sheetController = DraggableScrollableController();

  static const _nusCenter = LatLng(
    AppConstants.nusLatitude,
    AppConstants.nusLongitude,
  );

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
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
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      ref.invalidate(nearbyStopsProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sheetController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lat = _lastPosition?.latitude ?? AppConstants.nusLatitude;
    final lng = _lastPosition?.longitude ?? AppConstants.nusLongitude;
    final nearbyStops = ref.watch(nearbyStopsProvider((lat: lat, lng: lng)));

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
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Floating search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: GestureDetector(
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
                    Icon(Icons.search, color: AppColors.textMuted, size: 22),
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

          // My location button
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.35 + 16,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: AppColors.surface,
              onPressed: () async {
                final pos = await Geolocator.getCurrentPosition();
                _mapController?.animateCamera(
                  CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
                );
              },
              child: const Icon(
                Icons.my_location,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),

          // Bottom sheet
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.35,
            minChildSize: 0.12,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.12, 0.35, 0.85],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: const Border(
                    top: BorderSide(color: AppColors.borderLight),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // Title
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Text(
                        'Nearby Stops',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // Content
                    nearbyStops.when(
                      data: (stops) {
                        if (stops.isEmpty) {
                          return const EmptyState(
                            icon: Icons.location_off,
                            title: 'No stops nearby',
                            subtitle: 'Try moving closer to the NUS campus',
                          );
                        }
                        return Column(
                          children: stops
                              .map((stop) => NearbyStopCard(stop: stop))
                              .toList(),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(20),
                        child: ShimmerList(itemCount: 3, itemHeight: 100),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.all(20),
                        child: ErrorCard(
                          message: error.toString(),
                          onRetry: () => ref.invalidate(nearbyStopsProvider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
