import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/theme.dart';
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            const Text(
              'Plan Your Trip',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Find the best route across NUS',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // From/To input
            FromToInput(
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
            const SizedBox(height: 16),

            // Autocomplete suggestions (inline)
            if (_isSearching && _suggestions.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 52),
                  itemBuilder: (context, index) {
                    final name = _suggestions[index];
                    final isCurrent = name == 'Current Location';
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isCurrent
                            ? Icons.my_location
                            : Icons.location_on_outlined,
                        color: isCurrent
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 20,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent
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

            // Resolving indicator
            if (_resolving)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Getting your location\u2026',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Route results
            if (_showResults && !_resolving) _buildResults(),

            // Empty state (before any search)
            if (!_isSearching && !_showResults && !_resolving)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyState(
                  icon: Icons.directions_bus,
                  title: 'Search for a route',
                  subtitle:
                      'Enter an origin and destination above to find '
                      'the best way to get around NUS',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final routeResult = ref.watch(
      routeProvider((from: _resolvedOrigin, to: _resolvedDestination)),
    );

    return routeResult.when(
      data: (routes) {
        if (routes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 32),
            child: EmptyState(
              icon: Icons.route,
              title: 'No routes found',
              subtitle: 'Try a different origin or destination',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Suggested Routes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${routes.length} option${routes.length != 1 ? 's' : ''} found',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < routes.length; i++)
              RouteSummaryCard(
                key: ValueKey('route-$i'),
                route: routes[i],
                isSelected: i == 0,
                onTap: () {
                  context.go(
                    '/search/detail',
                    extra: {
                      'route': routes[i],
                      'origin': _origin,
                      'destination': _destination,
                    },
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: ShimmerList(itemCount: 3, itemHeight: 90),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ErrorCard(
          message: error.toString(),
          onRetry: () => ref.invalidate(routeProvider),
        ),
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

    // Resolve "Current Location" to GPS coordinates
    if (from == 'Current Location' || to == 'Current Location') {
      setState(() => _resolving = true);
      try {
        final position = await Geolocator.getCurrentPosition();
        final coords = '${position.latitude},${position.longitude}';
        if (from == 'Current Location') from = coords;
        if (to == 'Current Location') to = coords;
      } catch (_) {
        if (mounted) setState(() => _resolving = false);
        return;
      }
    }

    if (!mounted) return;
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
