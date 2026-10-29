import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/network/dio_client.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/providers/storage_providers.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:partsflow_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/api_user.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/current_user.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/login_outcome.dart';
import 'package:partsflow_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    AuthRemoteDataSource(ref.watch(dioProvider)),
    ref.watch(secureStorageProvider),
  );
}

/// Usuario de la sesión actual (claims del JWT).
@riverpod
Future<CurrentUser?> currentUser(Ref ref) async {
  final isAuthenticated = await ref.watch(authStateProvider.future);
  if (!isAuthenticated) return null;
  return ref.read(authRepositoryProvider).currentUser();
}

/// Usuario de SAPI (`users/?cognito_id=<sub>`), con el id numérico que piden
/// los endpoints de chats. null si no hay sesión o la consulta falló
/// (quien lo necesite puede hacer `ref.invalidate(apiUserProvider)` y reintentar).
@Riverpod(keepAlive: true)
Future<ApiUser?> apiUser(Ref ref) async {
  final isAuthenticated = await ref.watch(authStateProvider.future);
  if (!isAuthenticated) return null;
  final me = await ref.read(authRepositoryProvider).currentUser();
  if (me == null || me.id.isEmpty) return null;
  final result = await ref.read(authRepositoryProvider).apiUser(me.id);
  return switch (result) {
    Ok(:final value) => value,
    Err() => null,
  };
}

/// Acciones de acceso. El estado solo indica "en curso"; el resultado se devuelve.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  void build() {}

  Future<Result<LoginOutcome>> login(String email, String password) {
    return _guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email.trim(), password: password),
    );
  }

  Future<Result<LoginOutcome>> setPermanentPassword({
    required String email,
    required String password,
    required String session,
  }) {
    return _guard(
      () => ref
          .read(authRepositoryProvider)
          .setPermanentPassword(
            email: email,
            password: password,
            session: session,
          ),
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    ref.invalidate(authStateProvider);
  }

  Future<Result<LoginOutcome>> _guard(
    Future<Result<LoginOutcome>> Function() action,
  ) async {
    final result = await action();
    // Con sesión iniciada, el router redirige solo al invalidar authState.
    if (result case Ok(value: LoggedIn())) {
      ref.invalidate(authStateProvider);
    }
    return result;
  }
}

String loginErrorMessage(Failure failure) => switch (failure) {
  InvalidCredentialsFailure() => 'Correo o contraseña incorrectos',
  TemporaryPasswordExpiredFailure() =>
    'Tu contraseña temporal expiró. Pide una nueva para continuar.',
  NetworkFailure() => 'Sin conexión. Revisa tu internet.',
  _ => 'No pudimos iniciar sesión. Intenta de nuevo.',
};

String newPasswordErrorMessage(Failure failure) => switch (failure) {
  TemporaryPasswordExpiredFailure() =>
    'Tu contraseña temporal expiró. Pide una nueva para continuar.',
  NetworkFailure() => 'Sin conexión. Revisa tu internet.',
  _ => 'No pudimos guardar tu contraseña. Intenta de nuevo.',
};
