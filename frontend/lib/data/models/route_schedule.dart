class RouteSchedule {
  final String dayType;
  final String firstTime;
  final String lastTime;
  final String scheduleType;

  const RouteSchedule({
    required this.dayType,
    required this.firstTime,
    required this.lastTime,
    required this.scheduleType,
  });

  factory RouteSchedule.fromJson(Map<String, dynamic> json) {
    return RouteSchedule(
      dayType: json['DayType'] as String,
      firstTime: json['FirstTime'] as String,
      lastTime: json['LastTime'] as String,
      scheduleType: json['ScheduleType'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'DayType': dayType,
      'FirstTime': firstTime,
      'LastTime': lastTime,
      'ScheduleType': scheduleType,
    };
  }
}
