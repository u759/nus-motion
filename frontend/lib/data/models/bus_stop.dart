class BusStop {
  final String caption;
  final String name;
  final String longName;
  final String shortName;
  final double latitude;
  final double longitude;

  const BusStop({
    required this.caption,
    required this.name,
    required this.longName,
    required this.shortName,
    required this.latitude,
    required this.longitude,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    return BusStop(
      caption: json['caption'] as String,
      name: json['name'] as String,
      longName: json['LongName'] as String,
      shortName: json['ShortName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'caption': caption,
      'name': name,
      'LongName': longName,
      'ShortName': shortName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
