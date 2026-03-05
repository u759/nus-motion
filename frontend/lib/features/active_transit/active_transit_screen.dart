import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/data/models/route_leg.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/active_transit/widgets/trip_status_card.dart';
import 'package:frontend/features/active_transit/widgets/stops_timeline.dart';

class ActiveTransitScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? tripData;

  const ActiveTransitScreen({super.key, this.tripData});

  @override
  ConsumerState<ActiveTransitScreen> createState() =>
      _ActiveTransitScreenState();
}

class _ActiveTransitScreenState extends ConsumerState<ActiveTransitScreen> {
  GoogleMapController? _mapController;
  Timer? _pollTimer;
  int _currentStopIndex = 0;

  RoutePlanResult? get _route => widget.tripData?['route'] as RoutePlanResult?;
  String get _origin => widget.tripData?['origin'] as String? ?? '';
  String get _destination => widget.tripData?['destination'] as String? ?? '';

  List<String> get _allStops {
    if (_route == null) return [];
    final stops = <String>[];
    for (final leg in _route!.legs) {
      if (leg.fromStop != null && !stops.contains(leg.fromStop)) {
        stops.add(leg.fromStop!);
      }
      if (leg.toStop != null && !stops.contains(leg.toStop)) {
        stops.add(leg.toStop!);
      }
    }
    return stops;
  }

  String? get _activeBusRoute {
    for (final leg in _route?.legs ?? <RouteLeg>[]) {
      if (leg.mode == 'BUS' && leg.routeCode != null) return leg.routeCode;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final route = _activeBusRoute;
      if (route != null) {
        ref.invalidate(activeBusesProvider(route));
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_route == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: const Center(child: Text('No trip data')),
      );
    }

    final stops = _allStops;
    final totalStops = stops.length;
    final progress = totalStops > 1
        ? _currentStopIndex / (totalStops - 1)
        : 0.0;
    final routeCode = _activeBusRoute ?? 'BUS';

    // Get bus route description
    final busLeg = _route!.legs.firstWhere(
      (l) => l.mode == 'BUS',
      orElse: () => const RouteLeg(mode: 'BUS', instruction: 'Bus service'),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Route $routeCode',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.errorBg,
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Exit',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),

          // Map section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    _route!.legs.first.fromLat ?? 1.2966,
                    _route!.legs.first.fromLng ?? 103.7764,
                  ),
                  zoom: 15,
                ),
                onMapCreated: (c) => _mapController = c,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                liteModeEnabled: true,
              ),
            ),
          ),

          // Status card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TripStatusCard(
                stopsRemaining: totalStops - _currentStopIndex - 1,
                destination: _destination,
                minutesRemaining: _route!.totalMinutes,
                progress: progress,
                nextStop: _currentStopIndex + 1 < totalStops
                    ? stops[_currentStopIndex + 1]
                    : _destination,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Stops timeline
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StopsTimeline(
                stops: stops,
                currentIndex: _currentStopIndex,
                destination: _destination,
                onStopAdvance: () {
                  if (_currentStopIndex < totalStops - 1) {
                    setState(() => _currentStopIndex++);
                  }
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
