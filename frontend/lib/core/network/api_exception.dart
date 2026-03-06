import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Request timed out');
      case DioExceptionType.connectionError:
        return const ApiException('No internet connection');
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 404) return ApiException('Not found', statusCode: code);
        if (code == 422) {
          return ApiException('Invalid request', statusCode: code);
        }
        if (code != null && code >= 500) {
          return ApiException(
            'Service temporarily unavailable',
            statusCode: code,
          );
        }
        return ApiException('Request failed', statusCode: code);
      default:
        return ApiException(e.message ?? 'Unknown error');
    }
  }

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
