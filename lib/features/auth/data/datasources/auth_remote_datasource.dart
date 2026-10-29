import 'package:dio/dio.dart';

/// Respuesta cruda de los endpoints de acceso de SAPI.
class AuthResponse {
  const AuthResponse({
    this.token,
    this.accessToken,
    this.refreshToken,
    this.session,
    this.error,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    token: json['token'] as String?,
    accessToken: json['access_token'] as String?,
    refreshToken: json['refresh_token'] as String?,
    session: json['session'] as String?,
    error: json['error']?.toString(),
  );

  final String? token;
  final String? accessToken;
  final String? refreshToken;
  final String? session;
  final String? error;
}

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthResponse> login(String email, String password) =>
      _post('users/login/', {'email': email, 'password': password});

  Future<AuthResponse> setPermanentPassword(
    String email,
    String password,
    String session,
  ) => _post('users/set_permanent_password/', {
    'email': email,
    'password': password,
    'session': session,
  });

  Future<Object?> userByCognitoId(String sub) async => (await _dio.get<Object?>(
    'users/',
    queryParameters: {'cognito_id': sub},
  )).data;

  /// Los errores de negocio llegan como `{error: ...}` con status 4xx:
  /// se devuelven como [AuthResponse]; solo red/5xx se relanzan.
  Future<AuthResponse> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await _dio.post(path, data: body);
      return _parse(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final parsed = e.response == null ? null : _parse(e.response!.data);
      if (parsed != null &&
          parsed.error != null &&
          status != null &&
          status < 500) {
        return parsed;
      }
      rethrow;
    }
  }

  AuthResponse _parse(Object? data) => data is Map<String, dynamic>
      ? AuthResponse.fromJson(data)
      : const AuthResponse();
}
