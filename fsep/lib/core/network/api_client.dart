import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../config/app_config.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Dio HTTP network client wrapper.
class ApiClient {
  ApiClient._internal()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            headers: const {'Accept': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await TokenStorage.instance.readToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }

            final platform = kIsWeb
                ? 'web'
                : Platform.isAndroid
                    ? 'android'
                    : Platform.isIOS
                        ? 'ios'
                        : Platform.isWindows
                            ? 'windows'
                            : Platform.isMacOS
                                ? 'macos'
                                : Platform.isLinux
                                    ? 'linux'
                                    : 'unknown';
            options.headers['X-App-Platform'] = platform;
          } catch (_) {}
          handler.next(options);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  static final ApiClient instance = ApiClient._internal();

  final Dio dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    ResponseType? responseType,
  }) {
    return _guard(() => dio.get<T>(
          path,
          queryParameters: queryParameters,
          options:
              responseType != null ? Options(responseType: responseType) : null,
        ));
  }

  Future<Response<T>> post<T>(String path, {dynamic data}) {
    return _guard(() => dio.post<T>(path, data: data));
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) {
    return _guard(() => dio.put<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(String path, {dynamic data}) {
    return _guard(() => dio.delete<T>(path, data: data));
  }

  Future<Response<T>> _guard<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  ApiException _toApiException(DioException error) {
    var data = error.response?.data;

    if (data is List<int>) {
      try {
        data = jsonDecode(utf8.decode(data));
      } catch (_) {}
    }

    if (data is Map<String, dynamic>) {
      final message = data['message'];
      final rawErrors = data['errors'];

      Map<String, List<String>>? errors;
      if (rawErrors is Map) {
        errors = rawErrors.map(
          (key, value) => MapEntry(
            key.toString(),
            value is List
                ? value.map((e) => e.toString()).toList()
                : [value.toString()],
          ),
        );
      }

      return ApiException(
        message is String ? message : (error.message ?? 'Unexpected network error'),
        statusCode: error.response?.statusCode,
        errors: errors,
      );
    }

    return ApiException(
      error.message ?? 'Unexpected network error',
      statusCode: error.response?.statusCode,
    );
  }
}
