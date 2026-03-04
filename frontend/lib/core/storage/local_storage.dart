import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  static const _favRoutesKey = 'favorite_routes';
  static const _favStopsKey = 'favorite_stops';
  static const _recentSearchesKey = 'recent_searches';
  static const _recentTripsKey = 'recent_trips';
  static const _boxName = 'nus_motion';

  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  // ── Favorite routes ───────────────────────────────────────────────

  List<String> getFavoriteRoutes() {
    return List<String>.from(_box.get(_favRoutesKey, defaultValue: <String>[]));
  }

  Future<void> saveFavoriteRoutes(List<String> routes) async {
    await _box.put(_favRoutesKey, routes);
  }

  // ── Favorite stops ────────────────────────────────────────────────

  List<String> getFavoriteStops() {
    return List<String>.from(_box.get(_favStopsKey, defaultValue: <String>[]));
  }

  Future<void> saveFavoriteStops(List<String> stops) async {
    await _box.put(_favStopsKey, stops);
  }

  // ── Recent searches ───────────────────────────────────────────────

  List<String> getRecentSearches() {
    return List<String>.from(
      _box.get(_recentSearchesKey, defaultValue: <String>[]),
    );
  }

  Future<void> saveRecentSearches(List<String> searches) async {
    await _box.put(_recentSearchesKey, searches);
  }

  // ── Recent trips ──────────────────────────────────────────────────

  List<Map<String, String>> getRecentTrips() {
    final raw = _box.get(_recentTripsKey, defaultValue: <String>[]);
    return List<String>.from(
      raw,
    ).map((e) => Map<String, String>.from(jsonDecode(e) as Map)).toList();
  }

  Future<void> saveRecentTrips(List<Map<String, String>> trips) async {
    final encoded = trips.map((t) => jsonEncode(t)).toList();
    await _box.put(_recentTripsKey, encoded);
  }
}
