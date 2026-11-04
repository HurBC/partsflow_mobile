import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/network/token_refresher.dart';
import 'package:partsflow_mobile/core/storage/secure_storage.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:partsflow_mobile/core/storage/token_store.dart';

class FakeStorage implements SecureStorage {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
  @override
  Future<void> deleteAll() async => data.clear();
}

typedef Handler = Future<ResponseBody> Function(RequestOptions o);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  Handler handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

String jwt(int expSeconds) {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${enc({'alg': 'none'})}.${enc({'exp': expSeconds})}.sig';
}

void main() {
  final now = DateTime.utc(2026, 1, 1, 12);
  int at(Duration d) => now.add(d).millisecondsSinceEpoch ~/ 1000;

  group('isExpiring', () {
    test('token vigente', () {
      expect(
        TokenRefresher.isExpiring(jwt(at(const Duration(hours: 1))), now: now),
        isFalse,
      );
    });
    test('dentro del margen de 60s', () {
      expect(
        TokenRefresher.isExpiring(
          jwt(at(const Duration(seconds: 30))),
          now: now,
        ),
        isTrue,
      );
    });
    test('vencido', () {
      expect(
        TokenRefresher.isExpiring(jwt(at(const Duration(hours: -1))), now: now),
        isTrue,
      );
    });
    test('malformado o sin exp se asume vigente', () {
      expect(TokenRefresher.isExpiring('basura', now: now), isFalse);
      expect(TokenRefresher.isExpiring('a.b.c', now: now), isFalse);
    });
    test('isTokenExpiring usa el reloj inyectado', () {
      final t = jwt(at(const Duration(hours: 1)));
      final early = TokenRefresher(
        storage: FakeStorage(),
        tokens: TokenStore(FakeStorage()),
        baseUrl: 'http://x',
        clock: () => now,
      );
      final late = TokenRefresher(
        storage: FakeStorage(),
        tokens: TokenStore(FakeStorage()),
        baseUrl: 'http://x',
        clock: () => now.add(const Duration(hours: 2)),
      );
      expect(early.isTokenExpiring(t), isFalse);
      expect(late.isTokenExpiring(t), isTrue);
    });
  });

  group('refresh', () {
    late FakeStorage storage;
    late FakeAdapter adapter;
    late TokenRefresher refresher;

    setUp(() {
      storage = FakeStorage()
        ..data[StorageKeys.token] = 'old'
        ..data[StorageKeys.refreshToken] = 'rt';
      adapter = FakeAdapter(
        (_) async => json(200, {'token': 'new', 'access_token': 'acc'}),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;
      refresher = TokenRefresher(
        storage: storage,
        tokens: TokenStore(storage),
        baseUrl: 'http://x',
        dio: dio,
      );
    });

    test('exitoso guarda tokens y envía JWT actual + refresh_token', () async {
      expect(await refresher.refresh(), RefreshResult.ok);
      expect(storage.data[StorageKeys.token], 'new');
      expect(storage.data[StorageKeys.accessToken], 'acc');
      expect(storage.data[StorageKeys.refreshToken], 'rt');
      final req = adapter.requests.single;
      expect(req.path, TokenRefresher.refreshPath);
      expect(req.headers['Authorization'], 'old');
      expect(req.data, {'refresh_token': 'rt'});
    });

    test('single-flight: N llamadas concurrentes, 1 request', () async {
      final gate = Completer<void>();
      adapter.handler = (_) async {
        await gate.future;
        return json(200, {'token': 'new'});
      };
      final futures = List.generate(5, (_) => refresher.refresh());
      gate.complete();
      final results = await Future.wait(futures);
      expect(adapter.requests, hasLength(1));
      expect(results, everyElement(RefreshResult.ok));
    });

    test('refresh posterior a uno completo dispara request nuevo', () async {
      await refresher.refresh();
      await refresher.refresh();
      expect(adapter.requests, hasLength(2));
    });

    test('401/400/403 = rejected y limpia sesión', () async {
      for (final code in [401, 400, 403]) {
        storage
          ..data[StorageKeys.token] = 'old'
          ..data[StorageKeys.refreshToken] = 'rt';
        adapter.handler = (_) async => json(code, {'detail': 'no'});
        expect(
          await refresher.refresh(),
          RefreshResult.rejected,
          reason: '$code',
        );
        expect(storage.data.keys, [StorageKeys.sessionExpired]);
      }
    });

    test('5xx = transient y conserva la sesión', () async {
      adapter.handler = (_) async => json(503, {});
      expect(await refresher.refresh(), RefreshResult.transient);
      expect(storage.data[StorageKeys.token], 'old');
      expect(storage.data[StorageKeys.refreshToken], 'rt');
      expect(storage.data.containsKey(StorageKeys.sessionExpired), isFalse);
    });

    test('error de red (sin respuesta) = transient', () async {
      adapter.handler = (o) async => throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      );
      expect(await refresher.refresh(), RefreshResult.transient);
      expect(storage.data[StorageKeys.token], 'old');
    });

    test('sin refresh token guardado = rejected sin request', () async {
      storage.data.remove(StorageKeys.refreshToken);
      expect(await refresher.refresh(), RefreshResult.rejected);
      expect(adapter.requests, isEmpty);
      expect(storage.data[StorageKeys.sessionExpired], '1');
    });

    test('respuesta 200 sin token = rejected', () async {
      adapter.handler = (_) async => json(200, {'foo': 'bar'});
      expect(await refresher.refresh(), RefreshResult.rejected);
      expect(storage.data[StorageKeys.sessionExpired], '1');
    });

    test('refresh_token rotado en la respuesta se guarda', () async {
      adapter.handler = (_) async =>
          json(200, {'token': 'n', 'refresh_token': 'rt2'});
      await refresher.refresh();
      expect(storage.data[StorageKeys.refreshToken], 'rt2');
    });
  });
}
