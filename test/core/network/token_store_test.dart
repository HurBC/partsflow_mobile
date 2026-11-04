import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/storage/secure_storage.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:partsflow_mobile/core/storage/token_store.dart';

class CountingStorage implements SecureStorage {
  final Map<String, String> data = {};
  int reads = 0;
  @override
  Future<String?> read(String key) async {
    reads++;
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
  @override
  Future<void> deleteAll() async => data.clear();
}

/// Storage con compuertas: el valor leído se captura al llamar read y se
/// entrega al completar [readGate]; write/deleteAll aplican al completar su
/// compuerta.
class GatedStorage implements SecureStorage {
  final Map<String, String> data = {};
  final readGate = Completer<void>();
  final writeGate = Completer<void>();
  final deleteGate = Completer<void>();
  bool writeError = false;
  int reads = 0;

  @override
  Future<String?> read(String key) async {
    reads++;
    final v = data[key];
    if (!readGate.isCompleted || reads == 1) await readGate.future;
    return v;
  }

  @override
  Future<void> write(String key, String value) async {
    if (writeError) throw StateError('write');
    await writeGate.future;
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async => data.remove(key);
  @override
  Future<void> deleteAll() async {
    await deleteGate.future;
    data.clear();
  }
}

void main() {
  late CountingStorage storage;
  late TokenStore store;

  setUp(() {
    storage = CountingStorage()..data[StorageKeys.token] = 't1';
    store = TokenStore(storage);
  });

  test('primera lectura va a storage, las siguientes a caché', () async {
    expect(await store.readToken(), 't1');
    expect(await store.readToken(), 't1');
    expect(storage.reads, 1);
  });

  test('ausencia de token también se cachea', () async {
    expect(await store.readRefreshToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
    expect(storage.reads, 1);
  });

  test('saveTokens actualiza caché y storage', () async {
    await store.readToken();
    await store.saveTokens(token: 't2', refreshToken: 'r', accessToken: 'a');
    expect(await store.readToken(), 't2');
    expect(await store.readRefreshToken(), 'r');
    expect(await store.readAccessToken(), 'a');
    expect(storage.data[StorageKeys.token], 't2');
    expect(storage.data[StorageKeys.refreshToken], 'r');
    expect(storage.reads, 1);
  });

  test('saveTokens sin refresh conserva el anterior', () async {
    storage.data[StorageKeys.refreshToken] = 'r0';
    await store.saveTokens(token: 't2');
    expect(await store.readRefreshToken(), 'r0');
  });

  test('clear borra caché y storage', () async {
    await store.readToken();
    await store.clear();
    expect(storage.data, isEmpty);
    expect(await store.readToken(), isNull);
  });

  test('lectura en vuelo durante clear no repuebla la caché', () async {
    final pending = store.readToken();
    await store.clear();
    await pending;
    storage.data[StorageKeys.token] = 'otro';
    expect(await store.readToken(), 'otro');
  });

  test('expSeconds decodifica una vez por token', () {
    // payload {"exp":123}
    const t = 'e30.eyJleHAiOjEyM30.sig';
    expect(store.expSeconds(t), 123);
    expect(store.expSeconds(t), 123);
    expect(store.expSeconds('basura'), isNull);
  });

  group('carreras', () {
    test('lectura en vuelo durante clear() no repuebla la caché', () async {
      final st = GatedStorage()..data[StorageKeys.token] = 'old';
      final ts = TokenStore(st);
      final read = ts.readToken(); // espera el gate de read
      final clear = ts.clear(); // espera el gate de deleteAll
      st.readGate.complete();
      st.deleteGate.complete();
      expect(await read, 'old');
      await clear;
      expect(await ts.readToken(), isNull);
    });

    test(
      'lectura en vuelo durante saveTokens no deja el valor viejo',
      () async {
        final st = GatedStorage()..data[StorageKeys.token] = 'old';
        final ts = TokenStore(st);
        final read = ts.readToken();
        final save = ts.saveTokens(token: 'new');
        st.readGate.complete();
        st.writeGate.complete();
        await read;
        await save;
        expect(await ts.readToken(), 'new');
      },
    );

    test('write fallido invalida la caché', () async {
      final st = GatedStorage()..data[StorageKeys.token] = 'old';
      st.readGate.complete();
      final ts = TokenStore(st);
      expect(await ts.readToken(), 'old');
      st.writeError = true;
      await expectLater(ts.saveTokens(token: 'new'), throwsStateError);
      st.writeError = false;
      expect(await ts.readToken(), 'old'); // releído de storage
      expect(st.reads, 2);
    });
  });
}
