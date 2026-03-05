import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/widgets/loading_shimmer.dart';
import 'package:frontend/core/widgets/error_card.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/data/models/bus_stop.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/search_routing/widgets/from_to_input.dart';
import 'package:frontend/features/search_routing/widgets/route_summary_card.dart';

class SearchRoutingScreen extends ConsumerStatefulWidget {
  const SearchRoutingScreen({super.key});

  @override
  ConsumerState<SearchRoutingScreen> createState() =>
      _SearchRoutingScreenState();
}

class _SearchRoutingScreenState extends ConsumerState<SearchRoutingScreen> {
  GoogleMapController? _mapController;
  String _origin = 'Current Location';
  String _destination = '';
  bool _isSearching = false;
  bool _showResults = false;
  List<String> _suggestions = [];
  bool _editingOrigin = false;
  String _resolvedOrigin = '';
  String _resolvedDestination = '';
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    final stops = ref.watch(stopsProvider);
    final buildings = ref.watch(buildingsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Background map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(
                AppConstants.nusLatitude,
                AppConstants.nusLongitude,
              ),
              zoom: AppConstants.defaultZoom,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Floating input card
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: FromToInput(
              origin: _origin,
              destination: _destination,
              onOriginChanged: (val) {
                setState(() {
                  _origin = val;
                  _editingOrigin = true;
                  _isSearching = val.length >= 2;
                  _showResults = false;
                });
                if (val.length >= 2) _updateSuggestions(val, stops, buildings);
              },
              onDestinationChanged: (val) {
                setState(() {
                  _destination = val;
                  _editingOrigin = false;
                  _isSearching = val.length >= 2;
                  _showResults = false;
                });
                if (val.length >= 2) _updateSuggestions(val, stops, buildings);
              },
              onSwap: () {
                setState(() {
                  final temp = _origin;
                  _origin = _destination;
                  _destination = temp;
                  _showResults = false;
                });
              },
              onSubmit: _computeRoute,
            ),
          ),

          // Autocomplete suggestions overlay
          if (_isSearching)
            Positioned(
              top: MediaQuery.of(context).padding.top + 140,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 52),
                  itemBuilder: (context, index) {
                    final name = _suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        name == 'Current Location'
                            ? Icons.my_location
                            : Icons.location_on_outlined,
                        color: name == 'Current Location'
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 20,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: name == 'Current Location'
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      onTap: () => _selectSuggestion(name),
                    );
                  },
                ),
              ),
            ),

          // Route results bottom sheet
          if (_showResults)
            DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.15,
              maxChildSize: 0.75,
              snap: true,
              snapSizes: const [0.15, 0.4, 0.75],
              builder: (context, scrollController) {
                final routeResult = ref.watch(
                  routeProvider((
                    from: _resolvedOrigin,
                    to: _resolvedDestination,
                  )),
                );
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
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
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text(
                          'Suggested Routes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      routeResult.when(
                        data: (result) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: RouteSummaryCard(
                            route: result,
                            isSelected: true,
                            onTap: () {
                              context.go(
                                '/search/detail',
                                extra: {
                                  'route': result,
                                  'origin': _origin,
                                  'destination': _destination,
                                },
                              );
                            },
                          ),
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(20),
                          child: ShimmerList(itemCount: 2, itemHeight: 90),
                        ),
                        error: (error, _) => Padding(
                          padding: const EdgeInsets.all(20),
                          child: ErrorCard(
                            message: error.toString(),
                            onRetry: () => ref.invalidate(routeProvider),
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

  void _updateSuggestions(
    String query,
    AsyncValue<List<BusStop>> stops,
    AsyncValue<List<Building>> buildings,
  ) {
    final q = query.toLowerCase();
    final results = <String>['Current Location'];

    stops.whenData((list) {
      for (final s in list) {
        if (s.longName.toLowerCase().contains(q) ||
            s.shortName.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q) ||
            s.caption.toLowerCase().contains(q)) {
          results.add(s.longName.isNotEmpty ? s.longName : s.name);
        }
      }
    });

    buildings.whenData((list) {
      for (final b in list) {
        if (b.name.toLowerCase().contains(q)) {
          results.add(b.name);
        }
      }
    });

    setState(() => _suggestions = results.take(8).toList());
  }

  void _selectSuggestion(String name) {
    setState(() {
      if (_editingOrigin) {
        _origin = name;
      } else {
        _destination = name;
      }
      _isSearching = false;
      _suggestions = [];
    });
    if (_origin.isNotEmpty && _destination.isNotEmpty) {
      _computeRoute();
    }
  }

  Future<void> _computeRoute() async {
    if (_origin.isEmpty || _destination.isEmpty) return;

    String from = _origin;
    String to = _destination;

    // Resolve "Current Location" to GPS coordinates (backend handles stop-finding)
    if (from == 'Current Location' || to == 'Current Location') {
      setState(() => _resolving = true);
      try {
        final position = await Geolocator.getCurrentPosition();
        final coords = '${position.latitude},${position.longitude}';
        if (from == 'Current Location') from = coords;
        if (to == 'Current Location') to = coords;
      } catch (_) {
        setState(() => _resolving = false);
        return;
      }
    }

    setState(() {
      _resolvedOrigin = from;
      _resolvedDestination = to;
      _isSearching = false;
      _showResults = true;
      _resolving = false;
    });
    ref.read(recentSearchesProvider.notifier).add(_origin, _destination);
  }
}
