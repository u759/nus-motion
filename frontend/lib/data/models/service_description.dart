class ServiceDescription {
  final String route;
  final String routeDescription;
  final String routeLongName;

  const ServiceDescription({
    required this.route,
    required this.routeDescription,
    required this.routeLongName,
  });

  factory ServiceDescription.fromJson(Map<String, dynamic> json) =>
      ServiceDescription(
        route: json['Route'] as String? ?? '',
        routeDescription: json['RouteDescription'] as String? ?? '',
        routeLongName: json['RouteLongName'] as String? ?? '',
      );
}
