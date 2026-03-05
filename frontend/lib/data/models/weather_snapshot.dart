class WeatherSnapshot {
  final String timezone;
  final String time;
  final double temperatureCelsius;
  final int weatherCode;
  final double precipitationMm;
  final double windSpeedKph;
  final int? nextHourPrecipitationProbability;

  const WeatherSnapshot({
    required this.timezone,
    required this.time,
    required this.temperatureCelsius,
    required this.weatherCode,
    required this.precipitationMm,
    required this.windSpeedKph,
    this.nextHourPrecipitationProbability,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) =>
      WeatherSnapshot(
        timezone: json['timezone'] as String? ?? '',
        time: json['time'] as String? ?? '',
        temperatureCelsius:
            (json['temperatureCelsius'] as num?)?.toDouble() ?? 0,
        weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
        precipitationMm: (json['precipitationMm'] as num?)?.toDouble() ?? 0,
        windSpeedKph: (json['windSpeedKph'] as num?)?.toDouble() ?? 0,
        nextHourPrecipitationProbability:
            (json['nextHourPrecipitationProbability'] as num?)?.toInt(),
      );
}
