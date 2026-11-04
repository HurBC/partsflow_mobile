import 'package:partsflow_mobile/core/storage/secure_storage.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:partsflow_mobile/core/utils/jwt_decoder.dart';

/// Única vía para leer/escribir/borrar los tokens de sesión. Cachea en memoria
/// tras la primera lectura (el secure storage de Android es lento) y escribe
/// siempre a través de [SecureStorage], así la caché no se desincroniza.
/// Una sola instancia por proceso (provider keepAlive).
class TokenStore {
  TokenStore(this._storage);

  final SecureStorage _storage;

  final Map<String, String?> _cache = {};

  // Se incrementa en cada write/clear: una lectura que estaba en vuelo antes
  // de un cambio no debe poblar la caché con un valor viejo.
  int _generation = 0;

  String? _expFor;
  int? _exp;

  Future<String?> readToken() => _read(StorageKeys.token);
  Future<String?> readRefreshToken() => _read(StorageKeys.refreshToken);
  Future<String?> readAccessToken() => _read(StorageKeys.accessToken);

  Future<String?> _read(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    final gen = _generation;
    final value = await _storage.read(key);
    if (gen == _generation) _cache[key] = value;
    return value;
  }

  /// Guarda los tokens no nulos (los nulos se dejan como están). Primero
  /// persiste y después actualiza la caché; si el write falla, invalida la
  /// caché de las claves afectadas (no queda un valor no persistido).
  Future<void> saveTokens({
    required String token,
    String? refreshToken,
    String? accessToken,
  }) async {
    // Antes y después del await: ninguna lectura iniciada antes de que
    // termine el write puede poblar la caché con el valor viejo.
    _generation++;
    final writes = <String, String>{
      StorageKeys.token: token,
      StorageKeys.accessToken: ?accessToken,
      StorageKeys.refreshToken: ?refreshToken,
    };
    try {
      for (final e in writes.entries) {
        await _storage.write(e.key, e.value);
      }
      _generation++;
      _cache.addAll(writes);
    } catch (_) {
      _generation++;
      _cache.removeWhere((k, _) => writes.containsKey(k));
      rethrow;
    }
  }

  /// Logout / sesión muerta: borra todo el secure storage y la caché.
  Future<void> clear() async {
    _generation++;
    _cache.clear();
    _expFor = null;
    _exp = null;
    try {
      await _storage.deleteAll();
    } finally {
      _generation++;
      _cache.clear();
    }
  }

  /// `exp` (segundos epoch) del JWT; decodifica una sola vez por token.
  int? expSeconds(String token) {
    if (_expFor == token) return _exp;
    final exp = decodeJwtPayload(token)['exp'];
    _expFor = token;
    _exp = exp is num ? exp.toInt() : null;
    return _exp;
  }
}
