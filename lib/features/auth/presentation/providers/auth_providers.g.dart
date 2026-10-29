// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'f1ff4dfdd3cf3f5b1f3a27261b699f7a8011a235';

/// Usuario de la sesión actual (claims del JWT).

@ProviderFor(currentUser)
final currentUserProvider = CurrentUserProvider._();

/// Usuario de la sesión actual (claims del JWT).

final class CurrentUserProvider
    extends
        $FunctionalProvider<
          AsyncValue<CurrentUser?>,
          CurrentUser?,
          FutureOr<CurrentUser?>
        >
    with $FutureModifier<CurrentUser?>, $FutureProvider<CurrentUser?> {
  /// Usuario de la sesión actual (claims del JWT).
  CurrentUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $FutureProviderElement<CurrentUser?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CurrentUser?> create(Ref ref) {
    return currentUser(ref);
  }
}

String _$currentUserHash() => r'96a06939e9166a6208d04d472ffe467c0ad574fd';

/// Usuario de SAPI (`users/?cognito_id=<sub>`), con el id numérico que piden
/// los endpoints de chats. null si no hay sesión o la consulta falló
/// (quien lo necesite puede hacer `ref.invalidate(apiUserProvider)` y reintentar).

@ProviderFor(apiUser)
final apiUserProvider = ApiUserProvider._();

/// Usuario de SAPI (`users/?cognito_id=<sub>`), con el id numérico que piden
/// los endpoints de chats. null si no hay sesión o la consulta falló
/// (quien lo necesite puede hacer `ref.invalidate(apiUserProvider)` y reintentar).

final class ApiUserProvider
    extends
        $FunctionalProvider<AsyncValue<ApiUser?>, ApiUser?, FutureOr<ApiUser?>>
    with $FutureModifier<ApiUser?>, $FutureProvider<ApiUser?> {
  /// Usuario de SAPI (`users/?cognito_id=<sub>`), con el id numérico que piden
  /// los endpoints de chats. null si no hay sesión o la consulta falló
  /// (quien lo necesite puede hacer `ref.invalidate(apiUserProvider)` y reintentar).
  ApiUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiUserHash();

  @$internal
  @override
  $FutureProviderElement<ApiUser?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ApiUser?> create(Ref ref) {
    return apiUser(ref);
  }
}

String _$apiUserHash() => r'e2408f0904b6e0cd507d904b69c1507c3fec46b1';

/// Acciones de acceso. El estado solo indica "en curso"; el resultado se devuelve.

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// Acciones de acceso. El estado solo indica "en curso"; el resultado se devuelve.
final class AuthControllerProvider
    extends $NotifierProvider<AuthController, void> {
  /// Acciones de acceso. El estado solo indica "en curso"; el resultado se devuelve.
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$authControllerHash() => r'95844b02daee7e8501258d6072395b75b66e4db6';

/// Acciones de acceso. El estado solo indica "en curso"; el resultado se devuelve.

abstract class _$AuthController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
