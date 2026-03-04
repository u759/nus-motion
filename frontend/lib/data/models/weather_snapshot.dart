class WeatherSnapshot {
  final String timezone;
  final String time;
  final double temperatureCelsius;
  final int weatherCode;
  final double precipitationMm;
  final double windSpeedKph;
  final int nextHourPrecipitationProbability;

  const WeatherSnapshot({
    required this.timezone,
    required this.time,
    required this.temperatureCelsius,
    required this.weatherCode,
    required this.precipitationMm,
    required this.windSpeedKph,
    required this.nextHourPrecipitationProbability,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      timezone: json['timezone'] as String,
      time: json['time'] as String,
      temperatureCelsius: (json['temperatureCelsius'] as num).toDouble(),
      weatherCode: json['weatherCode'] as int,
      precipitationMm: (json['precipitationMm'] as num).toDouble(),
      windSpeedKph: (json['windSpeedKph'] as num).toDouble(),
      nextHourPrecipitationProbability:
          json['nextHourPrecipitationProbability'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timezone': timezone,
      'time': time,
      'temperatureCelsius': temperatureCelsius,
      'weatherCode': weatherCode,
      'precipitationMm': precipitationMm,
      'windSpeedKph': windSpeedKph,
      'nextHourPrecipitationProbability': nextHourPrecipitationProbability,
    };
  }
}
