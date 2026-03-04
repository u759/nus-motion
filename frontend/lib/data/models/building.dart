class Building {
  final String elementId;
  final String name;
  final String address;
  final String postal;
  final double latitude;
  final double longitude;

  const Building({
    required this.elementId,
    required this.name,
    required this.address,
    required this.postal,
    required this.latitude,
    required this.longitude,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      elementId: json['elementId'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      postal: json['postal'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'elementId': elementId,
      'name': name,
      'address': address,
      'postal': postal,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
