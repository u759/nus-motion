import 'package:dio/dio.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_exception.dart';

class ApiClient {
  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.timeout,
        receiveTimeout: ApiConstants.timeout,
      ),
    );
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
