import 'package:flutter/material.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/weather_utils.dart';
import 'package:frontend/data/models/weather_snapshot.dart';

class WeatherCard extends StatelessWidget {
  final WeatherSnapshot weather;

  const WeatherCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = getWeatherIcon(weather.weatherCode);
    final description = getWeatherDescription(weather.weatherCode);
    final probability = weather.nextHourPrecipitationProbability;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            color: AppTheme.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 32),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kent Ridge Campus \u2022 ${weather.temperatureCelsius.round()}\u00B0C',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$probability%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'INTENSITY',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 128,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.backgroundDark,
                        AppTheme.surfaceVariant,
                      ],
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
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.backgroundDark.withValues(alpha: 0.6),
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
