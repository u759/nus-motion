import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/bus_stop.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/search_routing/widgets/route_card.dart';
import 'package:frontend/features/search_routing/widgets/suggestion_tile.dart';

class SearchRoutingScreen extends ConsumerStatefulWidget {
  const SearchRoutingScreen({super.key});

  @override
  ConsumerState<SearchRoutingScreen> createState() =>
      _SearchRoutingScreenState();
}

class _SearchRoutingScreenState extends ConsumerState<SearchRoutingScreen> {
  final _toController = TextEditingController();
  final _toFocus = FocusNode();
  int _tabIndex = 0; // 0=Suggested, 1=Nearby, 2=Recent

  final String _fromValue = 'Current Location';
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _toFocus.requestFocus();
    _toController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _toController.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  void _submitRoute() {
    final dest = _toController.text.trim();
    if (dest.isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(dest);
    setState(() => _hasSubmitted = true);
  }

  void _selectSuggestion(String name) {
    _toController.text = name;
    _submitRoute();
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _hasSubmitted
                  ? _buildRouteResults()
                  : _buildSearchContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sticky header: back/title/settings + inputs + tabs ─────────
  Widget _buildHeader() {
    return Container(
      color: AppTheme.backgroundDark.withValues(alpha: 0.95),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _circleButton(Icons.arrow_back, () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                }),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Routing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.settings_input_component,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ],
            ),
          ),

          // Input fields
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                // From (readonly)
                _inputField(
                  icon: Icons.radio_button_checked,
                  iconColor: AppTheme.primary.withValues(alpha: 0.6),
                  child: Text(
                    _fromValue,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  active: false,
                ),
                const SizedBox(height: 12),
                // To (editable)
                _inputField(
                  icon: Icons.location_on,
                  iconColor: AppTheme.primary,
                  active: true,
                  child: TextField(
                    controller: _toController,
                    focusNode: _toFocus,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search destination…',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _submitRoute(),
                  ),
                  trailing: _toController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _toController.clear();
                            setState(() => _hasSubmitted = false);
                          },
                          child: const Icon(
                            Icons.cancel,
                            color: AppTheme.textMuted,
                            size: 18,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),

          // Tabs
          const SizedBox(height: 12),
          _buildTabs(),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 24),
      ),
    );
  }

  Widget _inputField({
    required IconData icon,
    required Color iconColor,
    required Widget child,
    required bool active,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutralDark,
        borderRadius: BorderRadius.circular(8),
        border: active
            ? Border.all(
                color: AppTheme.primary.withValues(alpha: 0.5),
                width: 1,
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(child: child),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  // ── Tabs ────────────────────────────────────────────────────────
  Widget _buildTabs() {
    const labels = ['Suggested', 'Nearby', 'Recent'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderDark)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == _tabIndex;
          return GestureDetector(
            onTap: () => setState(() {
              _tabIndex = i;
              _hasSubmitted = false;
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                labels[i].toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: active ? AppTheme.primary : AppTheme.textMuted,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Search content (suggestions / nearby / recent) ──────────────
  Widget _buildSearchContent() {
    return switch (_tabIndex) {
      0 => _buildSuggestedTab(),
      1 => _buildNearbyTab(),
      2 => _buildRecentTab(),
      _ => const SizedBox.shrink(),
    };
  }

  // ── Suggested tab ───────────────────────────────────────────────
  Widget _buildSuggestedTab() {
    final query = _toController.text.trim().toLowerCase();
    final stopsAsync = ref.watch(stopsProvider);
    final buildingsAsync = ref.watch(buildingsProvider);
    final recents = ref.watch(recentSearchesProvider);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Autocomplete panel
        if (query.isNotEmpty)
          _buildAutocompletePanel(query, stopsAsync, buildingsAsync, recents),
      ],
    );
  }

  Widget _buildAutocompletePanel(
    String query,
    AsyncValue<List<BusStop>> stopsAsync,
    AsyncValue<List<Building>> buildingsAsync,
    List<String> recents,
  ) {
    // Combine matching results
    final List<_SuggestionItem> items = [];

    // Recent matches first
    for (final r in recents) {
      if (r.toLowerCase().contains(query)) {
        items.add(_SuggestionItem(r, null, SuggestionType.recent));
      }
    }

    // Bus stop matches
    stopsAsync.whenData((stops) {
      for (final s in stops) {
        if (s.longName.toLowerCase().contains(query) ||
            s.shortName.toLowerCase().contains(query) ||
            s.name.toLowerCase().contains(query)) {
          items.add(
            _SuggestionItem(
              s.longName.isNotEmpty ? s.longName : s.name,
              s.shortName.isNotEmpty ? s.shortName : null,
              SuggestionType.stop,
            ),
          );
        }
      }
    });

    // Building matches
    buildingsAsync.whenData((buildings) {
      for (final b in buildings) {
        if (b.name.toLowerCase().contains(query)) {
          items.add(
            _SuggestionItem(b.name, b.address, SuggestionType.building),
          );
        }
      }
    });

    if (items.isEmpty) return const SizedBox.shrink();

    // Limit visible suggestions
    final visible = items.take(8).toList();

    return Container(
      color: AppTheme.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUGGESTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in visible)
            SuggestionTile(
              name: item.name,
              subtitle: item.subtitle,
              type: item.type,
              onTap: () => _selectSuggestion(item.name),
            ),
        ],
      ),
    );
  }

  // ── Nearby tab ──────────────────────────────────────────────────
  Widget _buildNearbyTab() {
    // Use a default NUS campus location as fallback
    const lat = 1.2966;
    const lng = 103.7764;
    final nearbyAsync = ref.watch(nearbyStopsProvider((lat: lat, lng: lng)));

    return nearbyAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Failed to load nearby stops',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      ),
      data: (stops) => _buildNearbyStopsList(stops),
    );
  }

  Widget _buildNearbyStopsList(List<NearbyStopResult> stops) {
    if (stops.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No nearby stops found',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stops.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'NEARBY STOPS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 2.0,
              ),
            ),
          );
        }
        final stop = stops[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _NearbyStopCard(
            stop: stop,
            onTap: () => _selectSuggestion(stop.stopName),
          ),
        );
      },
    );
  }

  // ── Recent tab ──────────────────────────────────────────────────
  Widget _buildRecentTab() {
    final recents = ref.watch(recentSearchesProvider);
    if (recents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No recent searches',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final r in recents)
          SuggestionTile(
            name: r,
            type: SuggestionType.recent,
            onTap: () => _selectSuggestion(r),
          ),
      ],
    );
  }

  // ── Route results ───────────────────────────────────────────────
  Widget _buildRouteResults() {
    final dest = _toController.text.trim();
    final routeAsync = ref.watch(routeProvider((from: _fromValue, to: dest)));

    return routeAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.textMuted,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not find a route',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _hasSubmitted = false),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (result) => _buildRouteResultsList(result),
    );
  }

  Widget _buildRouteResultsList(RoutePlanResult result) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'FASTEST ROUTES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 2.0,
            ),
          ),
        ),

        // Primary route card
        RouteCard(result: result),

        const SizedBox(height: 12),

        // Secondary card (dimmed) – reuse same result for visual match
        RouteCard(result: result, dimmed: true),

        const SizedBox(height: 24),

        // Nearby stops section at bottom
        _buildNearbyStopsFooter(),
      ],
    );
  }

  Widget _buildNearbyStopsFooter() {
    const lat = 1.2966;
    const lng = 103.7764;
    final nearbyAsync = ref.watch(nearbyStopsProvider((lat: lat, lng: lng)));

    return nearbyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stops) {
        if (stops.isEmpty) return const SizedBox.shrink();
        final visible = stops.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'NEARBY STOPS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            for (final stop in visible) ...[
              _NearbyStopCard(
                stop: stop,
                onTap: () => _selectSuggestion(stop.stopName),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

// ── Helper models ─────────────────────────────────────────────────────

class _SuggestionItem {
  const _SuggestionItem(this.name, this.subtitle, this.type);
  final String name;
  final String? subtitle;
  final SuggestionType type;
}

// ── Nearby stop card ──────────────────────────────────────────────────

class _NearbyStopCard extends StatelessWidget {
  const _NearbyStopCard({required this.stop, this.onTap});
  final NearbyStopResult stop;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.neutralDark.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_bus, color: AppTheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.stopDisplayName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stop.distanceMeters.round()}m away',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
