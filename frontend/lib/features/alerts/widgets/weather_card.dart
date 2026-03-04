import 'package:flutter/material.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/weather_utils.dart';
import 'package:frontend/data/models/weather_snapshot.dart';

class WeatherCard extends StatelessWidget {
  final WeatherSnapshot weather;

  const WeatherCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final icon = getWeatherIcon(weather.weatherCode);
    final description = getWeatherDescription(weather.weatherCode);
    final probability = weather.nextHourPrecipitationProbability;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          // ── Top panel ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kent Ridge Campus • ${weather.temperatureCelsius.round()}°C',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$probability%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const Text(
                      'INTENSITY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Radar placeholder ──────────────────────────────
          SizedBox(
            height: 128,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.radar,
                      size: 48,
                      color: AppTheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                // Gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF0F172A).withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
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
