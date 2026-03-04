import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/models/active_bus.dart';
import 'package:frontend/data/models/announcement.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/bus_stop.dart';
import 'package:frontend/data/models/check_point.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/nearest_stop_result.dart';
import 'package:frontend/data/models/pickup_point.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/data/models/route_schedule.dart';
import 'package:frontend/data/models/service_description.dart';
import 'package:frontend/data/models/shuttle_service_result.dart';
import 'package:frontend/data/models/ticker_tape.dart';
import 'package:frontend/data/models/weather_snapshot.dart';

class TransitService {
  final ApiClient _api;

  // In-memory caches for static data
  List<BusStop>? _stopsCache;
  List<Building>? _buildingsCache;
  List<ServiceDescription>? _serviceDescriptionsCache;

  TransitService(this._api);

  // ── Cached static data ──────────────────────────────────────────

  Future<List<BusStop>> getStops() async {
    return _stopsCache ??= await _api.getStops();
  }

  Future<List<Building>> getBuildings() async {
    return _buildingsCache ??= await _api.getBuildings();
  }

  Future<List<ServiceDescription>> getServiceDescriptions() async {
    return _serviceDescriptionsCache ??= await _api.getServiceDescriptions();
  }

  void invalidateCache() {
    _stopsCache = null;
    _buildingsCache = null;
    _serviceDescriptionsCache = null;
  }

  // ── Pass-through (dynamic data, no caching) ─────────────────────

  Future<ShuttleServiceResult> getShuttles(String stopName) =>
      _api.getShuttles(stopName);

  Future<List<ActiveBus>> getActiveBuses(String routeCode) =>
      _api.getActiveBuses(routeCode);

  Future<List<CheckPoint>> getCheckpoints(String routeCode) =>
      _api.getCheckpoints(routeCode);

  Future<List<Announcement>> getAnnouncements() => _api.getAnnouncements();

  Future<List<RouteSchedule>> getSchedule(String routeCode) =>
      _api.getSchedule(routeCode);

  Future<List<PickupPoint>> getPickupPoints(String routeCode) =>
      _api.getPickupPoints(routeCode);

  Future<List<TickerTape>> getTickerTapes() => _api.getTickerTapes();

  Future<NearestStopResult> getNearestStop(String buildingName) =>
      _api.getNearestStop(buildingName);

  Future<List<NearbyStopResult>> getNearbyStops(
    double lat,
    double lng, {
    int radius = 800,
    int limit = 5,
  }) => _api.getNearbyStops(lat, lng, radius: radius, limit: limit);

  Future<RoutePlanResult> getRoute(String from, String to) =>
      _api.getRoute(from, to);

  Future<WeatherSnapshot> getWeather(double lat, double lng) =>
      _api.getWeather(lat, lng);
}
