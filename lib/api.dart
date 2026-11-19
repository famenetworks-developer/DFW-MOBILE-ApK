import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class ApiException implements Exception {
  const ApiException(this.message, [this.code]);
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class ApiService {
  ApiService._() {
    dio.interceptors.add(CookieManager(_cookies));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'access_token');
          if (token != null && options.headers['Authorization'] == null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode == 401 &&
              request.path != 'api/auth/login' &&
              request.path != 'api/auth/refresh' &&
              request.extra['retried'] != true) {
            try {
              final refresh = await dio.post(
                'api/auth/refresh',
                options: Options(extra: {'retried': true}),
              );
              final token = refresh.data['access_token'] as String?;
              if (token != null) {
                await _storage.write(key: 'access_token', value: token);
                request.extra['retried'] = true;
                request.headers['Authorization'] = 'Bearer $token';
                return handler.resolve(await dio.fetch(request));
              }
            } catch (_) {
              await clearSession();
            }
          }
          handler.next(error);
        },
      ),
    );
  }
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://wtp.famenetworks.net/',
  );
  static final ApiService instance = ApiService._();
  static const _storage = FlutterSecureStorage();
  final _cookies = CookieJar();
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final r = await dio.post(
        'api/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      final data = Map<String, dynamic>.from(r.data);
      await _storage.write(key: 'access_token', value: data['access_token']);
      await _storage.write(key: 'user', value: jsonEncode(data['user']));
      return Map<String, dynamic>.from(data['user']);
    } on DioException catch (e) {
      throw _friendly(e);
    }
  }

  Future<Map<String, dynamic>?> restoreUser() async {
    if (await _storage.read(key: 'access_token') == null) return null;
    try {
      final r = await dio.get('api/auth/me');
      final user = Map<String, dynamic>.from(r.data);
      await _storage.write(key: 'user', value: jsonEncode(user));
      return user;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await dio.post('api/auth/logout');
    } catch (_) {}
    await clearSession();
  }

  Future<void> clearSession() => _storage.deleteAll();
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    try {
      return (await dio.get(path, queryParameters: query)).data;
    } on DioException catch (e) {
      throw _friendly(e);
    }
  }

  Future<dynamic> post(
    String path, {
    Object? data,
    bool idempotent = false,
  }) async {
    try {
      return (await dio.post(
        path,
        data: data,
        options: Options(
          headers: idempotent ? {'Idempotency-Key': const Uuid().v4()} : null,
        ),
      )).data;
    } on DioException catch (e) {
      throw _friendly(e);
    }
  }

  Future<Stream<Map<String, dynamic>>> events() async {
    final response = await dio.get<ResponseBody>(
      'api/events',
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );
    return response.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data:'))
        .map(
          (line) =>
              Map<String, dynamic>.from(jsonDecode(line.substring(5).trim())),
        );
  }

  ApiException _friendly(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return ApiException(
        data['message']?.toString() ?? 'Request failed',
        data['code']?.toString(),
      );
    }
    return ApiException(
      e.type == DioExceptionType.connectionError
          ? 'Unable to connect. Check your internet connection.'
          : 'The server did not complete the request. Please try again.',
    );
  }
}
