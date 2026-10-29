import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/api_user.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/current_user.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/login_outcome.dart';

abstract class AuthRepository {
  Future<Result<LoginOutcome>> login({
    required String email,
    required String password,
  });

  Future<Result<LoginOutcome>> setPermanentPassword({
    required String email,
    required String password,
    required String session,
  });

  /// Usuario según los claims del JWT guardado; null si no hay sesión.
  Future<CurrentUser?> currentUser();

  /// Usuario de SAPI (id numérico) a partir del `sub` de Cognito.
  Future<Result<ApiUser?>> apiUser(String sub);

  Future<void> logout();
}
