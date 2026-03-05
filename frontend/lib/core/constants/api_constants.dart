class ApiConstants {
  static const String baseUrl = 'http://localhost:8080/api';
  static const Duration timeout = Duration(seconds: 15);
  static const Duration pollShuttles = Duration(seconds: 10);
  static const Duration pollActiveBuses = Duration(seconds: 12);
  static const Duration pollAnnouncements = Duration(seconds: 30);
  static const Duration pollWeather = Duration(minutes: 5);
  static const Duration pollNearbyStops = Duration(seconds: 20);
}
