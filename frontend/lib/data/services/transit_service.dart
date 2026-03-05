import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/models/bus_stop.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/data/models/active_bus.dart';
import 'package:frontend/data/models/checkpoint.dart';
import 'package:frontend/data/models/announcement.dart';
import 'package:frontend/data/models/route_schedule.dart';
import 'package:frontend/data/models/service_description.dart';
import 'package:frontend/data/models/pickup_point.dart';
import 'package:frontend/data/models/ticker_tape.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/nearest_stop_result.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/data/models/weather_snapshot.dart';

class TransitService {
  final ApiClient _client;

  TransitService(this._client);

  Future<List<BusStop>> getStops() => _client.get(
    '/stops',
    parser: (data) => (data as List)
        .map((e) => BusStop.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<ShuttleServiceResult> getShuttles(String stopName) => _client.get(
    '/shuttles',
    queryParameters: {'stop': stopName},
    parser: (data) =>
        ShuttleServiceResult.fromJson(data as Map<String, dynamic>),
  );

  Future<List<ActiveBus>> getActiveBuses(String route) => _client.get(
    '/active-buses',
    queryParameters: {'route': route},
    parser: (data) => (data as List)
        .map((e) => ActiveBus.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<CheckPoint>> getCheckpoints(String route) => _client.get(
    '/checkpoints',
    queryParameters: {'route': route},
    parser: (data) => (data as List)
        .map((e) => CheckPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<Announcement>> getAnnouncements() => _client.get(
    '/announcements',
    parser: (data) => (data as List)
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<RouteSchedule>> getSchedule(String route) => _client.get(
    '/schedule',
    queryParameters: {'route': route},
    parser: (data) => (data as List)
        .map((e) => RouteSchedule.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<ServiceDescription>> getServiceDescriptions() => _client.get(
    '/service-descriptions',
    parser: (data) => (data as List)
        .map((e) => ServiceDescription.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<PickupPoint>> getPickupPoints(String route) => _client.get(
    '/pickup-points',
    queryParameters: {'route': route},
    parser: (data) => (data as List)
        .map((e) => PickupPoint.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<TickerTape>> getTickerTapes() => _client.get(
    '/ticker-tapes',
    parser: (data) => (data as List)
        .map((e) => TickerTape.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<Building>> getBuildings() => _client.get(
    '/buildings',
    parser: (data) => (data as List)
        .map((e) => Building.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<NearestStopResult> getNearestStop(String buildingName) => _client.get(
    '/buildings/${Uri.encodeComponent(buildingName)}/nearest-stop',
    parser: (data) => NearestStopResult.fromJson(data as Map<String, dynamic>),
  );

  Future<List<NearbyStopResult>> getNearbyStops({
    required double lat,
    required double lng,
    int radius = 800,
    int limit = 5,
  }) => _client.get(
    '/nearby-stops',
    queryParameters: {'lat': lat, 'lng': lng, 'radius': radius, 'limit': limit},
    parser: (data) => (data as List)
        .map((e) => NearbyStopResult.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<RoutePlanResult> getRoute({
    required String from,
    required String to,
  }) => _client.get(
    '/route',
    queryParameters: {'from': from, 'to': to},
    parser: (data) => RoutePlanResult.fromJson(data as Map<String, dynamic>),
  );

  Future<WeatherSnapshot> getWeather({
    required double lat,
    required double lng,
  }) => _client.get(
    '/weather',
    queryParameters: {'lat': lat, 'lng': lng},
    parser: (data) => WeatherSnapshot.fromJson(data as Map<String, dynamic>),
  );

  Future<String?> getPublicity() async {
    try {
      return await _client.get<String?>(
        '/publicity',
        parser: (data) => data?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> getBusLocation({required String route, String? stop}) async {
    try {
      final params = <String, dynamic>{'route': route};
      if (stop != null) params['stop'] = stop;
      return await _client.get<String?>(
        '/bus-location',
        queryParameters: params,
        parser: (data) => data?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
