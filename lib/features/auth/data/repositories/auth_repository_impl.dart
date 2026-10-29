import 'package:dio/dio.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/storage/secure_storage.dart';
import 'package:partsflow_mobile/core/storage/storage_keys.dart';
import 'package:partsflow_mobile/core/utils/jwt_decoder.dart';
import 'package:partsflow_mobile/core/utils/json_utils.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/api_user.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/current_user.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/login_outcome.dart';
import 'package:partsflow_mobile/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final SecureStorage _storage;

  @override
  Future<Result<LoginOutcome>> login({
    required String email,
    required String password,
  }) => _run(email, () => _remote.login(email, password));

  @override
  Future<Result<LoginOutcome>> setPermanentPassword({
    required String email,
    required String password,
    required String session,
  }) =>
      _run(email, () => _remote.setPermanentPassword(email, password, session));

  Future<Result<LoginOutcome>> _run(
    String email,
    Future<AuthResponse> Function() call,
  ) async {
    try {
      final res = await call();

      switch (res.error) {
        case null:
          break;
        case 'INVALID_CREDENTIALS':
          return Result.err(Failure.invalidCredentials());
        case 'TEMPORARY_PASSWORD_EXPIRED':
          return Result.err(Failure.temporaryPasswordExpired());
        default:
          return Result.err(Failure.unknown());
      }

      final token = res.token;
      if (token != null) {
        await _storage.write(StorageKeys.token, token);
        final refresh = res.refreshToken;
        if (refresh != null) {
          await _storage.write(StorageKeys.refreshToken, refresh);
        }
        final access = res.accessToken;
        if (access != null) {
          await _storage.write(StorageKeys.accessToken, access);
        }
        return Result.ok(const LoggedIn());
      }

      final session = res.session;
      if (session != null) {
        return Result.ok(NewPasswordRequired(email: email, session: session));
      }

      return Result.err(Failure.unknown());
    } on DioException catch (e) {
      return Result.err(_mapDio(e));
    } catch (_) {
      return Result.err(Failure.unknown());
    }
  }

  Failure _mapDio(DioException e) {
    if (e.response == null) return Failure.network();
    final status = e.response!.statusCode ?? 0;
    if (status >= 500) return Failure.server();
    return Failure.unknown();
  }

  @override
  Future<CurrentUser?> currentUser() async {
    final token = await _storage.read(StorageKeys.token);
    if (token == null) return null;
    final c = decodeJwtPayload(token);
    if (c.isEmpty) return null;

    String s(String key) => (c[key] ?? '').toString();

    return CurrentUser(
      id: s('sub'),
      email: s('email'),
      name: s('name'),
      familyName: s('family_name'),
      subsidiaryId: s('custom:subsidiary_id'),
      subsidiaryName: s('custom:subsidiary_name'),
      supplierName: s('custom:supplier_name'),
      schemaName: s('custom:schema_name'),
    );
  }

  @override
  Future<Result<ApiUser?>> apiUser(String sub) async {
    try {
      final data = await _remote.userByCognitoId(sub);
      final list = data is List ? data : asList(asMap(data)?['results']);
      return Result.ok(list.isEmpty ? null : _apiUser(list.first));
    } on DioException catch (e) {
      return Result.err(_mapDio(e));
    } catch (_) {
      return Result.err(Failure.unknown());
    }
  }

  @override
  Future<void> logout() => _storage.deleteAll();

  ApiUser? _apiUser(Object? json) {
    final m = asMap(json);
    final id = nonEmpty(asStr(m?['id']));
    if (m == null || id == null) return null;
    return ApiUser(
      id: id,
      firstName: asStr(m['first_name']) ?? '',
      lastName: asStr(m['last_name']) ?? '',
      email: asStr(m['email']) ?? '',
    );
  }
}
