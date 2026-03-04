import 'shuttle.dart';

class ShuttleServiceResult {
  final String name;
  final String caption;
  final List<Shuttle> shuttles;

  const ShuttleServiceResult({
    required this.name,
    required this.caption,
    required this.shuttles,
  });

  factory ShuttleServiceResult.fromJson(Map<String, dynamic> json) {
    return ShuttleServiceResult(
      name: json['name'] as String,
      caption: json['caption'] as String,
      shuttles: (json['shuttles'] as List<dynamic>)
          .map((e) => Shuttle.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'caption': caption,
      'shuttles': shuttles.map((e) => e.toJson()).toList(),
    };
  }
}
