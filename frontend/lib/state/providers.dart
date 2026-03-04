import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/local_storage.dart';
import 'package:frontend/data/models/active_bus.dart';
import 'package:frontend/data/models/announcement.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/bus_stop.dart';
import 'package:frontend/data/models/check_point.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/data/models/service_description.dart';
import 'package:frontend/data/models/shuttle_service_result.dart';
import 'package:frontend/data/models/ticker_tape.dart';
import 'package:frontend/data/models/weather_snapshot.dart';
import 'package:frontend/data/repositories/favorites_repository.dart';
import 'package:frontend/data/services/transit_service.dart';

// ── Core singletons ───────────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final localStorageProvider = Provider<LocalStorage>((ref) => LocalStorage());

final transitServiceProvider = Provider<TransitService>(
  (ref) => TransitService(ref.watch(apiClientProvider)),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(localStorageProvider)),
);

// ── Transit data (cached via TransitService) ──────────────────────────

final stopsProvider = FutureProvider<List<BusStop>>(
  (ref) => ref.watch(transitServiceProvider).getStops(),
);

final buildingsProvider = FutureProvider<List<Building>>(
  (ref) => ref.watch(transitServiceProvider).getBuildings(),
);

final serviceDescriptionsProvider = FutureProvider<List<ServiceDescription>>(
  (ref) => ref.watch(transitServiceProvider).getServiceDescriptions(),
);

// ── Parameterized providers ───────────────────────────────────────────

final shuttlesProvider = FutureProvider.family<ShuttleServiceResult, String>(
  (ref, stopName) => ref.watch(transitServiceProvider).getShuttles(stopName),
);

final activeBusesProvider = FutureProvider.family<List<ActiveBus>, String>(
  (ref, routeCode) =>
      ref.watch(transitServiceProvider).getActiveBuses(routeCode),
);

final checkpointsProvider = FutureProvider.family<List<CheckPoint>, String>(
  (ref, routeCode) =>
      ref.watch(transitServiceProvider).getCheckpoints(routeCode),
);

// ── Location-dependent providers ──────────────────────────────────────

final nearbyStopsProvider =
    FutureProvider.family<List<NearbyStopResult>, ({double lat, double lng})>(
      (ref, params) => ref
          .watch(transitServiceProvider)
          .getNearbyStops(params.lat, params.lng),
    );

final weatherProvider =
    FutureProvider.family<WeatherSnapshot, ({double lat, double lng})>(
      (ref, params) =>
          ref.watch(transitServiceProvider).getWeather(params.lat, params.lng),
    );

// ── Routing ───────────────────────────────────────────────────────────

final routeProvider =
    FutureProvider.family<RoutePlanResult, ({String from, String to})>(
      (ref, params) =>
          ref.watch(transitServiceProvider).getRoute(params.from, params.to),
    );

// ── Alerts ────────────────────────────────────────────────────────────

final announcementsProvider = FutureProvider<List<Announcement>>(
  (ref) => ref.watch(transitServiceProvider).getAnnouncements(),
);

final tickerTapesProvider = FutureProvider<List<TickerTape>>(
  (ref) => ref.watch(transitServiceProvider).getTickerTapes(),
);

// ── Favorites (StateNotifier-based) ───────────────────────────────────

class FavoriteRoutesNotifier extends StateNotifier<List<String>> {
  final FavoritesRepository _repo;

  FavoriteRoutesNotifier(this._repo) : super(_repo.getFavoriteRoutes());

  Future<void> add(String routeCode) async {
    await _repo.addFavoriteRoute(routeCode);
    state = _repo.getFavoriteRoutes();
  }

  Future<void> remove(String routeCode) async {
    await _repo.removeFavoriteRoute(routeCode);
    state = _repo.getFavoriteRoutes();
  }

  Future<void> toggle(String routeCode) async {
    if (state.contains(routeCode)) {
      await remove(routeCode);
    } else {
      await add(routeCode);
    }
  }
}

final favoriteRoutesProvider =
    StateNotifierProvider<FavoriteRoutesNotifier, List<String>>(
      (ref) => FavoriteRoutesNotifier(ref.watch(favoritesRepositoryProvider)),
    );

class FavoriteStopsNotifier extends StateNotifier<List<String>> {
  final FavoritesRepository _repo;

  FavoriteStopsNotifier(this._repo) : super(_repo.getFavoriteStops());

  Future<void> add(String stopName) async {
    await _repo.addFavoriteStop(stopName);
    state = _repo.getFavoriteStops();
  }

  Future<void> remove(String stopName) async {
    await _repo.removeFavoriteStop(stopName);
    state = _repo.getFavoriteStops();
  }

  Future<void> toggle(String stopName) async {
    if (state.contains(stopName)) {
      await remove(stopName);
    } else {
      await add(stopName);
    }
  }
}

final favoriteStopsProvider =
    StateNotifierProvider<FavoriteStopsNotifier, List<String>>(
      (ref) => FavoriteStopsNotifier(ref.watch(favoritesRepositoryProvider)),
    );

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  final FavoritesRepository _repo;

  RecentSearchesNotifier(this._repo) : super(_repo.getRecentSearches());

  Future<void> add(String query) async {
    await _repo.addRecentSearch(query);
    state = _repo.getRecentSearches();
  }

  Future<void> remove(String query) async {
    final searches = List<String>.from(state);
    searches.remove(query);
    state = searches;
  }

  Future<void> clear() async {
    await _repo.clearRecentSearches();
    state = [];
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>(
      (ref) => RecentSearchesNotifier(ref.watch(favoritesRepositoryProvider)),
    );
