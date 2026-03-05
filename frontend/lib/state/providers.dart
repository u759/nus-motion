import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

// -- Location Stream --
final positionStreamProvider = StreamProvider<Position>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
    ),
  );
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
final shuttlesProvider = FutureProvider.family<ShuttleServiceResult, String>((
  ref,
  stopName,
) {
  return ref.watch(transitServiceProvider).getShuttles(stopName);
});

final activeBusesProvider = FutureProvider.family<List<ActiveBus>, String>((
  ref,
  route,
) {
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
final allStopsSortedByDistanceProvider =
    FutureProvider.family<List<NearbyStopResult>, ({double lat, double lng})>((
      ref,
      params,
    ) async {
      final stops = await ref.watch(stopsProvider.future);
      final results = stops.map((stop) {
        final distance = _haversine(
          params.lat,
          params.lng,
          stop.latitude,
          stop.longitude,
        );
        return NearbyStopResult(
          stopName: stop.name,
          stopDisplayName: stop.longName.isNotEmpty ? stop.longName : stop.name,
          latitude: stop.latitude,
          longitude: stop.longitude,
          distanceMeters: distance,
          walkingMinutes: (distance / 80).ceil(),
        );
      }).toList()..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      return results;
    });

double _haversine(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371000.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return R * 2 * atan2(sqrt(a), sqrt(1 - a));
}

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
