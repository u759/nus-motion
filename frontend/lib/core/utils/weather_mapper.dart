import 'package:flutter/material.dart';

class WeatherInfo {
  final IconData icon;
  final String description;
  const WeatherInfo(this.icon, this.description);
}

class WeatherMapper {
  static WeatherInfo fromCode(int code) {
    if (code == 0) return const WeatherInfo(Icons.wb_sunny, 'Clear sky');
    if (code <= 3) return const WeatherInfo(Icons.cloud, 'Partly cloudy');
    if (code <= 49) return const WeatherInfo(Icons.foggy, 'Foggy');
    if (code <= 59) return const WeatherInfo(Icons.grain, 'Drizzle');
    if (code <= 69) return const WeatherInfo(Icons.water_drop, 'Rain');
    if (code <= 79) return const WeatherInfo(Icons.ac_unit, 'Snow');
    if (code <= 84) return const WeatherInfo(Icons.water_drop, 'Rain showers');
    if (code <= 94) {
      return const WeatherInfo(Icons.thunderstorm, 'Thunderstorm');
    }
    if (code <= 99) {
      return const WeatherInfo(Icons.thunderstorm, 'Thunderstorm with hail');
    }
    return const WeatherInfo(Icons.help_outline, 'Unknown');
  }
}
