import 'package:frontend/data/models/route_leg.dart';

class RoutePlanResult {
  final String from;
  final String to;
  final int totalMinutes;
  final int walkingMinutes;
  final int waitingMinutes;
  final int busMinutes;
  final int transfers;
  final List<RouteLeg> legs;

  const RoutePlanResult({
    required this.from,
    required this.to,
    required this.totalMinutes,
    required this.walkingMinutes,
    required this.waitingMinutes,
    required this.busMinutes,
    required this.transfers,
    required this.legs,
  });

  factory RoutePlanResult.fromJson(Map<String, dynamic> json) =>
      RoutePlanResult(
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
        totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
        walkingMinutes: (json['walkingMinutes'] as num?)?.toInt() ?? 0,
        waitingMinutes: (json['waitingMinutes'] as num?)?.toInt() ?? 0,
        busMinutes: (json['busMinutes'] as num?)?.toInt() ?? 0,
        transfers: (json['transfers'] as num?)?.toInt() ?? 0,
        legs:
            (json['legs'] as List<dynamic>?)
                ?.map((e) => RouteLeg.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
