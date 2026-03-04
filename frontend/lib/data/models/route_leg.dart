class RouteLeg {
  final String mode;
  final String instruction;
  final double minutes;
  final String? routeCode;
  final String? fromStop;
  final String? toStop;
  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;

  const RouteLeg({
    required this.mode,
    required this.instruction,
    required this.minutes,
    this.routeCode,
    this.fromStop,
    this.toStop,
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      mode: json['mode'] as String,
      instruction: json['instruction'] as String,
      minutes: (json['minutes'] as num).toDouble(),
      routeCode: json['routeCode'] as String?,
      fromStop: json['fromStop'] as String?,
      toStop: json['toStop'] as String?,
      fromLat: (json['fromLat'] as num).toDouble(),
      fromLng: (json['fromLng'] as num).toDouble(),
      toLat: (json['toLat'] as num).toDouble(),
      toLng: (json['toLng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'instruction': instruction,
      'minutes': minutes,
      'routeCode': routeCode,
      'fromStop': fromStop,
      'toStop': toStop,
      'fromLat': fromLat,
      'fromLng': fromLng,
      'toLat': toLat,
      'toLng': toLng,
    };
  }
}
