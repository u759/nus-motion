import 'package:frontend/core/storage/local_storage.dart';

class FavoritesRepository {
  final LocalStorage _storage;

  FavoritesRepository(this._storage);

  // ── Favorite routes ───────────────────────────────────────────────

  List<String> getFavoriteRoutes() => _storage.getFavoriteRoutes();

  bool isFavoriteRoute(String routeCode) =>
      _storage.getFavoriteRoutes().contains(routeCode);

  Future<void> addFavoriteRoute(String routeCode) async {
    final routes = _storage.getFavoriteRoutes();
    if (!routes.contains(routeCode)) {
      routes.add(routeCode);
      await _storage.saveFavoriteRoutes(routes);
    }
  }

  Future<void> removeFavoriteRoute(String routeCode) async {
    final routes = _storage.getFavoriteRoutes();
    routes.remove(routeCode);
    await _storage.saveFavoriteRoutes(routes);
  }

  // ── Favorite stops ────────────────────────────────────────────────

  List<String> getFavoriteStops() => _storage.getFavoriteStops();

  bool isFavoriteStop(String stopName) =>
      _storage.getFavoriteStops().contains(stopName);

  Future<void> addFavoriteStop(String stopName) async {
    final stops = _storage.getFavoriteStops();
    if (!stops.contains(stopName)) {
      stops.add(stopName);
      await _storage.saveFavoriteStops(stops);
    }
  }

  Future<void> removeFavoriteStop(String stopName) async {
    final stops = _storage.getFavoriteStops();
    stops.remove(stopName);
    await _storage.saveFavoriteStops(stops);
  }

  // ── Recent searches ───────────────────────────────────────────────

  List<String> getRecentSearches() => _storage.getRecentSearches();

  Future<void> addRecentSearch(String query) async {
    final searches = _storage.getRecentSearches();
    searches.remove(query); // remove duplicate if exists
    searches.insert(0, query); // most recent first
    if (searches.length > 20) {
      searches.removeRange(20, searches.length);
    }
    await _storage.saveRecentSearches(searches);
  }

  Future<void> clearRecentSearches() async {
    await _storage.saveRecentSearches([]);
  }

  // ── Recent trips ──────────────────────────────────────────────────

  List<Map<String, String>> getRecentTrips() => _storage.getRecentTrips();

  Future<void> addRecentTrip(Map<String, String> trip) async {
    final trips = _storage.getRecentTrips();
    trips.removeWhere(
      (t) => t['from'] == trip['from'] && t['to'] == trip['to'],
    );
    trips.insert(0, trip);
    if (trips.length > 10) {
      trips.removeRange(10, trips.length);
    }
    await _storage.saveRecentTrips(trips);
  }
}
