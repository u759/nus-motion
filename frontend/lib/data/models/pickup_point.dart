class PickupPoint {
  final int seq;
  final String busstopcode;
  final String longName;
  final String shortName;
  final double lat;
  final double lng;
  final String pickupname;
  final String routeid;

  const PickupPoint({
    required this.seq,
    required this.busstopcode,
    required this.longName,
    required this.shortName,
    required this.lat,
    required this.lng,
    required this.pickupname,
    required this.routeid,
  });

  factory PickupPoint.fromJson(Map<String, dynamic> json) {
    return PickupPoint(
      seq: json['seq'] as int,
      busstopcode: json['busstopcode'] as String,
      longName: json['LongName'] as String,
      shortName: json['ShortName'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      pickupname: json['pickupname'] as String,
      routeid: json['routeid'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seq': seq,
      'busstopcode': busstopcode,
      'LongName': longName,
      'ShortName': shortName,
      'lat': lat,
      'lng': lng,
      'pickupname': pickupname,
      'routeid': routeid,
    };
  }
}
