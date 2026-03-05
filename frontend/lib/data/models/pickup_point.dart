class PickupPoint {
  final int seq;
  final String busstopcode;
  final String longName;
  final String shortName;
  final double lat;
  final double lng;
  final String pickupname;
  final int routeid;

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

  factory PickupPoint.fromJson(Map<String, dynamic> json) => PickupPoint(
    seq: (json['seq'] as num?)?.toInt() ?? 0,
    busstopcode: json['busstopcode'] as String? ?? '',
    longName: json['LongName'] as String? ?? '',
    shortName: json['ShortName'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lng: (json['lng'] as num?)?.toDouble() ?? 0,
    pickupname: json['pickupname'] as String? ?? '',
    routeid: (json['routeid'] as num?)?.toInt() ?? 0,
  );
}
