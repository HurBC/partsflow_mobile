import 'package:dio/dio.dart';
import 'package:partsflow_mobile/core/storage/secure_storage.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:partsflow_mobile/core/utils/jwt_decoder.dart';
import 'package:partsflow_mobile/core/utils/pf_log.dart';

enum RefreshResult {
  /// Tokens nuevos guardados.
  ok,

  /// SAPI/Cognito rechazó el refresh (o no hay refresh token): la sesión murió y ya se limpió.
  rejected,

  /// Falla transitoria (sin red, timeout, 5xx): la sesión sigue guardada.
  transient,
}

/// Renueva el token igual que el BO: `POST users/refresh_token/` con el JWT
/// actual (aunque esté vencido) en `Authorization` y `{refresh_token}` en el
/// body. Responde `{token, access_token}`; el refresh token no rota.
/// Un solo vuelo a la vez; usa su propio Dio (sin interceptores).
class TokenRefresher {
  TokenRefresher({required SecureStorage storage, required String baseUrl})
    : _storage = storage,
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

  static const refreshPath = 'users/refresh_token/';
  static const expiryMargin = Duration(seconds: 60);

  final SecureStorage _storage;
  final Dio _dio;
  Future<RefreshResult>? _inFlight;

  /// true si el JWT vence en menos de [expiryMargin] (o ya venció).
  /// Sin claim `exp` legible se asume vigente.
  static bool isExpiring(String token) {
    final exp = decodeJwtPayload(token)['exp'];
    if (exp is! num) return false;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
    return expiresAt.difference(DateTime.now().toUtc()) < expiryMargin;
  }

  /// Marca la sesión como vencida: borra todo y deja el aviso para el login.
  Future<void> expireSession() async {
    await _storage.deleteAll();
    await _storage.write(StorageKeys.sessionExpired, '1');
  }

  Future<RefreshResult> refresh() => _inFlight ??= _run().whenComplete(() {
    _inFlight = null;
  });

  Future<RefreshResult> _run() async {
    pfLog('refresh: inicio');
    try {
      final token = await _storage.read(StorageKeys.token);
      final refreshToken = await _storage.read(StorageKeys.refreshToken);
      if (token == null || refreshToken == null) {
        pfLog('refresh: sin token o refresh token guardado');
        await expireSession();
        return RefreshResult.rejected;
      }

      final res = await _dio.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Authorization': token}),
      );
      final newToken = res.data?['token'] as String?;
      if (newToken == null) {
        pfLog('refresh: status=${res.statusCode} sin token en la respuesta');
        await expireSession();
        return RefreshResult.rejected;
      }
      await _storage.write(StorageKeys.token, newToken);
      final access = res.data?['access_token'] as String?;
      if (access != null) await _storage.write(StorageKeys.accessToken, access);
      final rotated = res.data?['refresh_token'] as String?;
      if (rotated != null) {
        await _storage.write(StorageKeys.refreshToken, rotated);
      }
      pfLog('refresh: ok status=${res.statusCode}');
      return RefreshResult.ok;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      pfLog('refresh: falló status=$status type=${e.type.name}');
      // SAPI: 401 = NotAuthorizedException (refresh vencido/revocado); 400 = request inválido.
      if (status == 401 || status == 400 || status == 403) {
        await expireSession();
        return RefreshResult.rejected;
      }
      return RefreshResult.transient;
    } catch (e) {
      pfLog('refresh: error inesperado ${e.runtimeType}');
      return RefreshResult.transient;
    }
  }
}
