import 'package:flutter/foundation.dart';
import 'package:partsflow_mobile/core/network/interceptors/auth_interceptor.dart';
import 'package:partsflow_mobile/core/network/token_refresher.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/providers/storage_providers.dart';
import 'package:partsflow_mobile/core/utils/pf_log.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';

part 'dio_client.g.dart';

const _baseUrl = String.fromEnvironment("API_BASE_URL");

@Riverpod(keepAlive: true)
TokenRefresher tokenRefresher(Ref ref) => TokenRefresher(
  storage: ref.read(secureStorageProvider),
  baseUrl: _baseUrl,
);

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    AuthInterceptor(
      storage: ref.read(secureStorageProvider),
      refresher: ref.read(tokenRefresherProvider),
      // Sin interceptores: el reintento tras refrescar no puede entrar en bucle.
      retryDio: Dio(BaseOptions(baseUrl: _baseUrl)),
      onSessionExpired: () => ref.invalidate(authStateProvider),
    ),
  );

  // Diagnóstico: método, path, status y body truncado. Nunca headers ni tokens.
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (e, handler) {
        if (pfDebugLog) {
          final r = e.response;
          pfLog(
            'dio ERROR ${e.requestOptions.method} ${e.requestOptions.path} '
            'status=${r?.statusCode} type=${e.type.name} '
            'body=${truncateLog(r?.data)}',
          );
        }
        handler.next(e);
      },
    ),
  );

  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestUrl: true,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }

  return dio;
}
