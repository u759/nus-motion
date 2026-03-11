import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/services/transit_service.dart';
import 'package:frontend/data/repositories/favorites_repository.dart';
import 'package:frontend/data/models/bus_stop.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/data/models/active_bus.dart';
import 'package:frontend/data/models/checkpoint.dart';
import 'package:frontend/data/models/announcement.dart';
import 'package:frontend/data/models/service_description.dart';
import 'package:frontend/data/models/ticker_tape.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/pickup_point.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/data/models/route_schedule.dart';
import 'package:frontend/data/models/weather_snapshot.dart';

// -- Singletons --
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final transitServiceProvider = Provider<TransitService>((ref) {
  return TransitService(ref.watch(apiClientProvider));
});

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository();
});

// -- Cached static data --
final stopsProvider = FutureProvider<List<BusStop>>((ref) {
  return ref.watch(transitServiceProvider).getStops();
});

final buildingsProvider = FutureProvider<List<Building>>((ref) {
  return ref.watch(transitServiceProvider).getBuildings();
});

final serviceDescriptionsProvider = FutureProvider<List<ServiceDescription>>((
  ref,
) {
  return ref.watch(transitServiceProvider).getServiceDescriptions();
});

// -- Parameterized queries --
final shuttlesProvider = FutureProvider.autoDispose
    .family<ShuttleServiceResult, String>((ref, stopName) {
      return ref.watch(transitServiceProvider).getShuttles(stopName);
    });

final activeBusesProvider = FutureProvider.autoDispose
    .family<List<ActiveBus>, String>((ref, route) {
      return ref.watch(transitServiceProvider).getActiveBuses(route);
    });

final checkpointsProvider = FutureProvider.family<List<CheckPoint>, String>((
  ref,
  route,
) {
  return ref.watch(transitServiceProvider).getCheckpoints(route);
});

final pickupPointsProvider = FutureProvider.family<List<PickupPoint>, String>((
  ref,
  route,
) {
  return ref.watch(transitServiceProvider).getPickupPoints(route);
});

final scheduleProvider = FutureProvider.family<List<RouteSchedule>, String>((
  ref,
  route,
) {
  return ref.watch(transitServiceProvider).getSchedule(route);
});

final nearbyStopsProvider =
    FutureProvider.family<List<NearbyStopResult>, ({double lat, double lng})>((
      ref,
      params,
    ) {
      return ref
          .watch(transitServiceProvider)
          .getNearbyStops(lat: params.lat, lng: params.lng);
    });

final routeProvider =
    FutureProvider.family<List<RoutePlanResult>, ({String from, String to})>((
      ref,
      params,
    ) {
      return ref
          .watch(transitServiceProvider)
          .getRoute(from: params.from, to: params.to);
    });

final weatherProvider =
    FutureProvider.family<WeatherSnapshot, ({double lat, double lng})>((
      ref,
      params,
    ) {
      return ref
          .watch(transitServiceProvider)
          .getWeather(lat: params.lat, lng: params.lng);
    });

/// All bus stops sorted by distance from a given position, as NearbyStopResult.
/// Uses backend calculation for walking time (single source of truth).
final allStopsSortedByDistanceProvider =
    FutureProvider.family<List<NearbyStopResult>, ({double lat, double lng})>((
      ref,
      params,
    ) {
      // Use backend with large radius to get all stops with proper walking time calculation
      return ref
          .watch(transitServiceProvider)
          .getNearbyStops(
            lat: params.lat,
            lng: params.lng,
            radius: 5000, // 5km — covers entire NUS campus
            limit: 100, // all stops (there are ~30 bus stops)
          );
    });

// -- Non-parameterized feeds --
final announcementsProvider = FutureProvider<List<Announcement>>((ref) {
  return ref.watch(transitServiceProvider).getAnnouncements();
});

final tickerTapesProvider = FutureProvider<List<TickerTape>>((ref) {
  return ref.watch(transitServiceProvider).getTickerTapes();
});

/// All active buses across every known route, keyed by route code.
final allActiveBusesProvider = FutureProvider<Map<String, List<ActiveBus>>>((
  ref,
) async {
  final service = ref.watch(transitServiceProvider);
  final descriptions = await ref.watch(serviceDescriptionsProvider.future);
  final routes = descriptions.map((d) => d.route).toList();
  final results = <String, List<ActiveBus>>{};
  await Future.wait(
    routes.map((route) async {
      try {
        results[route] = await service.getActiveBuses(route);
      } catch (_) {
        results[route] = [];
      }
    }),
  );
  return results;
});

// -- Local persistence notifiers --
final favoriteStopsProvider =
    StateNotifierProvider<FavoriteStopsNotifier, List<String>>((ref) {
      return FavoriteStopsNotifier(ref.watch(favoritesRepositoryProvider));
    });

class FavoriteStopsNotifier extends StateNotifier<List<String>> {
  final FavoritesRepository _repo;
  FavoriteStopsNotifier(this._repo) : super(_repo.getFavoriteStops());

  Future<void> toggle(String stopName) async {
    await _repo.toggleStopFavorite(stopName);
    state = _repo.getFavoriteStops();
  }

  bool isFavorite(String stopName) => state.contains(stopName);
}

final favoriteRoutesProvider =
    StateNotifierProvider<
      FavoriteRoutesNotifier,
      List<({String from, String to})>
    >((ref) {
      return FavoriteRoutesNotifier(ref.watch(favoritesRepositoryProvider));
    });

class FavoriteRoutesNotifier
    extends StateNotifier<List<({String from, String to})>> {
  final FavoritesRepository _repo;
  FavoriteRoutesNotifier(this._repo) : super(_repo.getFavoriteRoutes());

  Future<void> toggle(String from, String to) async {
    await _repo.toggleRouteFavorite(from, to);
    state = _repo.getFavoriteRoutes();
  }

  bool isFavorite(String from, String to) =>
      state.any((r) => r.from == from && r.to == to);
}

// -- Cross-screen communication --
/// Pending stop selection from Saved tab (or other screens).
/// When set, MapDiscoveryScreen will select this stop and clear the provider.
final pendingStopSelectionProvider = StateProvider<String?>((ref) => null);

// -- Recent Searches --
final recentSearchesProvider =
    StateNotifierProvider<
      RecentSearchesNotifier,
      List<({String from, String to})>
    >((ref) {
      return RecentSearchesNotifier(ref.watch(favoritesRepositoryProvider));
    });

class RecentSearchesNotifier
    extends StateNotifier<List<({String from, String to})>> {
  final FavoritesRepository _repo;
  RecentSearchesNotifier(this._repo) : super(_repo.getRecentSearches());

  Future<void> add(String from, String to) async {
    await _repo.addRecentSearch(from, to);
    state = _repo.getRecentSearches();
  }

  Future<void> clear() async {
    await _repo.clearRecentSearches();
    state = [];
  }
}

// -- Theme Mode --
enum AppThemeMode { light, dark, system }

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
      return ThemeModeNotifier();
    });

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  static const _boxName = 'settings';
  static const _key = 'themeMode';

  ThemeModeNotifier() : super(AppThemeMode.system) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final box = Hive.box<String>(_boxName);
    final stored = box.get(_key);
    if (stored != null) {
      state = AppThemeMode.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => AppThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    final box = Hive.box<String>(_boxName);
    await box.put(_key, mode.name);
  }
}

/// Convert AppThemeMode to Flutter's ThemeMode
ThemeMode toFlutterThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}
