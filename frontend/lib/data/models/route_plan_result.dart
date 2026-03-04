import 'route_leg.dart';

class RoutePlanResult {
  final String from;
  final String to;
  final double totalMinutes;
  final double walkingMinutes;
  final double waitingMinutes;
  final double busMinutes;
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

  factory RoutePlanResult.fromJson(Map<String, dynamic> json) {
    return RoutePlanResult(
      from: json['from'] as String,
      to: json['to'] as String,
      totalMinutes: (json['totalMinutes'] as num).toDouble(),
      walkingMinutes: (json['walkingMinutes'] as num).toDouble(),
      waitingMinutes: (json['waitingMinutes'] as num).toDouble(),
      busMinutes: (json['busMinutes'] as num).toDouble(),
      transfers: json['transfers'] as int,
      legs: (json['legs'] as List<dynamic>)
          .map((e) => RouteLeg.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'totalMinutes': totalMinutes,
      'walkingMinutes': walkingMinutes,
      'waitingMinutes': waitingMinutes,
      'busMinutes': busMinutes,
      'transfers': transfers,
      'legs': legs.map((e) => e.toJson()).toList(),
    };
  }
}
