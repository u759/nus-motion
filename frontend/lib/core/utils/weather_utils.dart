import 'package:flutter/material.dart';

IconData getWeatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code >= 1 && code <= 3) return Icons.cloud;
  if (code >= 45 && code <= 48) return Icons.foggy;
  if (code >= 51 && code <= 55) return Icons.grain;
  if (code >= 61 && code <= 65) return Icons.water_drop;
  if (code >= 71 && code <= 75) return Icons.ac_unit;
  if (code >= 80 && code <= 82) return Icons.umbrella;
  if (code >= 95 && code <= 99) return Icons.thunderstorm;
  return Icons.help_outline;
}

String getWeatherDescription(int code) {
  if (code == 0) return 'Clear sky';
  if (code == 1) return 'Mainly clear';
  if (code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code >= 45 && code <= 48) return 'Fog';
  if (code == 51) return 'Light drizzle';
  if (code == 53) return 'Moderate drizzle';
  if (code == 55) return 'Dense drizzle';
  if (code == 61) return 'Slight rain';
  if (code == 63) return 'Moderate rain';
  if (code == 65) return 'Heavy rain';
  if (code == 71) return 'Slight snow';
  if (code == 73) return 'Moderate snow';
  if (code == 75) return 'Heavy snow';
  if (code == 80) return 'Slight rain showers';
  if (code == 81) return 'Moderate rain showers';
  if (code == 82) return 'Violent rain showers';
  if (code == 95) return 'Thunderstorm';
  if (code == 96) return 'Thunderstorm with slight hail';
  if (code == 99) return 'Thunderstorm with heavy hail';
  return 'Unknown';
}
