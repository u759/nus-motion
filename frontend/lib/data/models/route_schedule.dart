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

  factory RouteSchedule.fromJson(Map<String, dynamic> json) => RouteSchedule(
    dayType: json['DayType'] as String? ?? '',
    firstTime: json['FirstTime'] as String? ?? '',
    lastTime: json['LastTime'] as String? ?? '',
    scheduleType: json['ScheduleType'] as String? ?? '',
  );
}
