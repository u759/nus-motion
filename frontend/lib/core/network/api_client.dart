import 'package:dio/dio.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_exception.dart';

class _CachedResponse {
  final dynamic data;
  final DateTime expiry;

  _CachedResponse(this.data, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
}

class ApiClient {
  static const int _maxCacheSize = 100;

  late final Dio dio;
  final Map<String, _CachedResponse> _cache = {};

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.timeout,
        receiveTimeout: ApiConstants.timeout,
      ),
    );
    dio.interceptors.add(_cacheInterceptor());
  }

  Interceptor _cacheInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final key = _cacheKey(options);
        final cached = _cache[key];
        if (cached != null && !cached.isExpired) {
          return handler.resolve(
            Response(
              requestOptions: options,
              data: cached.data,
              statusCode: 200,
            ),
            true,
          );
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final ttl = _ttlForPath(response.requestOptions.path);
        if (ttl != null) {
          final key = _cacheKey(response.requestOptions);
          _cache[key] = _CachedResponse(response.data, DateTime.now().add(ttl));
          _evictIfNeeded();
        }
        handler.next(response);
      },
    );
  }

  String _cacheKey(RequestOptions options) {
    final query = options.queryParameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final qs = query.map((e) => '${e.key}=${e.value}').join('&');
    return '${options.method}:${options.path}?$qs';
  }

  static Duration? _ttlForPath(String path) {
    if (path.contains('/busstops') ||
        path.contains('/buildings') ||
        path.contains('/ServiceDescription')) {
      return const Duration(minutes: 5);
    }
    if (path.contains('/ShuttleService') || path.contains('/ActiveBus')) {
      return const Duration(seconds: 3);
    }
    if (path.contains('/route')) {
      return const Duration(seconds: 5);
    }
    return null;
  }

  void _evictIfNeeded() {
    // Remove expired entries first
    _cache.removeWhere((_, v) => v.isExpired);
    // If still over limit, remove oldest entries
    while (_cache.length > _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) parser,
  }) async {
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      return parser(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
