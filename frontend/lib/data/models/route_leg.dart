class RouteLeg {
  static const String modeWalk = 'WALK';
  static const String modeWait = 'WAIT';
  static const String modeBus = 'BUS';

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

  static String normalizeMode(String? rawMode) {
    final normalizedMode = rawMode?.trim().toUpperCase() ?? '';

    switch (normalizedMode) {
      case 'WALK':
        return modeWalk;
      case 'WAIT':
        return modeWait;
      case 'RIDE':
      case 'BUS':
        return modeBus;
      default:
        return normalizedMode;
    }
  }

  String get normalizedMode => normalizeMode(mode);

  bool get isWalk => normalizedMode == modeWalk;

  bool get isWait => normalizedMode == modeWait;

  bool get isBus => normalizedMode == modeBus;

  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
    mode: normalizeMode(json['mode']?.toString()),
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
