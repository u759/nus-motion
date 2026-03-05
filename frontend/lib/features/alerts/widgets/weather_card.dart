import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/weather_mapper.dart';
import 'package:frontend/data/models/weather_snapshot.dart';

class WeatherCard extends StatelessWidget {
  final WeatherSnapshot weather;

  const WeatherCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final info = WeatherMapper.fromCode(weather.weatherCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF135BEC), Color(0xFF3B7BF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(info.icon, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weather.temperatureCelsius.round()}°C • ${info.description}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Wind ${weather.windSpeedKph.round()} km/h${weather.nextHourPrecipitationProbability != null ? ' • ${weather.nextHourPrecipitationProbability}% rain' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
