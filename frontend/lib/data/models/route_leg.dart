class RouteLeg {
  final String mode;
  final String instruction;
  final int? minutes;
  final String? routeCode;
  final String? fromStop;
  final String? toStop;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;

  const RouteLeg({
    required this.mode,
    required this.instruction,
    this.minutes,
    this.routeCode,
    this.fromStop,
    this.toStop,
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
    mode: json['mode'] as String? ?? '',
    instruction: json['instruction'] as String? ?? '',
    minutes: (json['minutes'] as num?)?.toInt(),
    routeCode: json['routeCode'] as String?,
    fromStop: json['fromStop'] as String?,
    toStop: json['toStop'] as String?,
    fromLat: (json['fromLat'] as num?)?.toDouble(),
    fromLng: (json['fromLng'] as num?)?.toDouble(),
    toLat: (json['toLat'] as num?)?.toDouble(),
    toLng: (json['toLng'] as num?)?.toDouble(),
  );
}
