import 'package:hive_flutter/hive_flutter.dart';

class FavoritesRepository {
  Box<String> get _favBox => Hive.box<String>('favorites');
  Box<String> get _recentBox => Hive.box<String>('recents');

  // Favorite Stops
  List<String> getFavoriteStops() {
    return _favBox.values
        .where((v) => v.startsWith('stop:'))
        .map((v) => v.substring(5))
        .toList();
  }

  bool isStopFavorite(String stopName) {
    return _favBox.values.contains('stop:$stopName');
  }

  Future<void> toggleStopFavorite(String stopName) async {
    final key = 'stop:$stopName';
    final existingKey = _favBox.keys.cast<dynamic>().firstWhere(
      (k) => _favBox.get(k) == key,
      orElse: () => null,
    );
    if (existingKey != null) {
      await _favBox.delete(existingKey);
    } else {
      await _favBox.add(key);
    }
  }

  // Favorite Routes
  List<({String from, String to})> getFavoriteRoutes() {
    return _favBox.values.where((v) => v.startsWith('route:')).map((v) {
      final parts = v.substring(6).split('|');
      return (from: parts[0], to: parts.length > 1 ? parts[1] : '');
    }).toList();
  }

  bool isRouteFavorite(String from, String to) {
    return _favBox.values.contains('route:$from|$to');
  }

  Future<void> toggleRouteFavorite(String from, String to) async {
    final key = 'route:$from|$to';
    final existingKey = _favBox.keys.cast<dynamic>().firstWhere(
      (k) => _favBox.get(k) == key,
      orElse: () => null,
    );
    if (existingKey != null) {
      await _favBox.delete(existingKey);
    } else {
      await _favBox.add(key);
    }
  }

  // Recent Searches
  List<({String from, String to})> getRecentSearches() {
    return _recentBox.values
        .map((v) {
          final parts = v.split('|');
          return (from: parts[0], to: parts.length > 1 ? parts[1] : '');
        })
        .toList()
        .reversed
        .toList();
  }

  Future<void> addRecentSearch(String from, String to) async {
    final key = '$from|$to';
    // Remove duplicate if exists
    final existingKey = _recentBox.keys.cast<dynamic>().firstWhere(
      (k) => _recentBox.get(k) == key,
      orElse: () => null,
    );
    if (existingKey != null) {
      await _recentBox.delete(existingKey);
    }
    await _recentBox.add(key);
    // Keep only last 10
    while (_recentBox.length > 10) {
      await _recentBox.deleteAt(0);
    }
  }

  Future<void> clearRecentSearches() async {
    await _recentBox.clear();
  }
}
