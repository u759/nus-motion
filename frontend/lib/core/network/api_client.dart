import 'package:dio/dio.dart';

import 'package:frontend/core/errors/api_exception.dart';
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

const String kBaseUrl = 'http://localhost:8080/api';

class ApiClient {
  final Dio _dio;

  ApiClient({String baseUrl = kBaseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );

  // ── Bus stops ──────────────────────────────────────────────────────

  Future<List<BusStop>> getStops() async {
    final data = await _get<List>('/stops');
    return data
        .map((e) => BusStop.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Shuttles (ETAs) ───────────────────────────────────────────────

  Future<ShuttleServiceResult> getShuttles(String stopName) async {
    final data = await _get<Map<String, dynamic>>(
      '/shuttles',
      queryParameters: {'stop': stopName},
    );
    return ShuttleServiceResult.fromJson(data);
  }

  // ── Active buses on a route ───────────────────────────────────────

  Future<List<ActiveBus>> getActiveBuses(String routeCode) async {
    final data = await _get<List>(
      '/active-buses',
      queryParameters: {'route': routeCode},
    );
    return data
        .map((e) => ActiveBus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Route checkpoints ─────────────────────────────────────────────

  Future<List<CheckPoint>> getCheckpoints(String routeCode) async {
    final data = await _get<List>(
      '/checkpoints',
      queryParameters: {'route': routeCode},
    );
    return data
        .map((e) => CheckPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Announcements ─────────────────────────────────────────────────

  Future<List<Announcement>> getAnnouncements() async {
    final data = await _get<List>('/announcements');
    return data
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Schedule ──────────────────────────────────────────────────────

  Future<List<RouteSchedule>> getSchedule(String routeCode) async {
    final data = await _get<List>(
      '/schedule',
      queryParameters: {'route': routeCode},
    );
    return data
        .map((e) => RouteSchedule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Service descriptions ──────────────────────────────────────────

  Future<List<ServiceDescription>> getServiceDescriptions() async {
    final data = await _get<List>('/service-descriptions');
    return data
        .map((e) => ServiceDescription.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Pickup points ─────────────────────────────────────────────────

  Future<List<PickupPoint>> getPickupPoints(String routeCode) async {
    final data = await _get<List>(
      '/pickup-points',
      queryParameters: {'route': routeCode},
    );
    return data
        .map((e) => PickupPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Ticker tapes ──────────────────────────────────────────────────

  Future<List<TickerTape>> getTickerTapes() async {
    final data = await _get<List>('/ticker-tapes');
    return data
        .map((e) => TickerTape.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Buildings ─────────────────────────────────────────────────────

  Future<List<Building>> getBuildings() async {
    final data = await _get<List>('/buildings');
    return data
        .map((e) => Building.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Nearest stop to a building ────────────────────────────────────

  Future<NearestStopResult> getNearestStop(String buildingName) async {
    final encoded = Uri.encodeComponent(buildingName);
    final data = await _get<Map<String, dynamic>>(
      '/buildings/$encoded/nearest-stop',
    );
    return NearestStopResult.fromJson(data);
  }

  // ── Nearby stops by coordinate ────────────────────────────────────

  Future<List<NearbyStopResult>> getNearbyStops(
    double lat,
    double lng, {
    int radius = 800,
    int limit = 5,
  }) async {
    final data = await _get<List>(
      '/nearby-stops',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'limit': limit,
      },
    );
    return data
        .map((e) => NearbyStopResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Route planning ────────────────────────────────────────────────

  Future<RoutePlanResult> getRoute(String from, String to) async {
    final data = await _get<Map<String, dynamic>>(
      '/route',
      queryParameters: {'from': from, 'to': to},
    );
    return RoutePlanResult.fromJson(data);
  }

  // ── Weather ───────────────────────────────────────────────────────

  Future<WeatherSnapshot> getWeather(double lat, double lng) async {
    final data = await _get<Map<String, dynamic>>(
      '/weather',
      queryParameters: {'lat': lat, 'lng': lng},
    );
    return WeatherSnapshot.fromJson(data);
  }

  // ── Internal helper ───────────────────────────────────────────────

  Future<T> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw ApiException(
        e.response?.data?.toString() ?? e.message ?? 'Unknown error',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
