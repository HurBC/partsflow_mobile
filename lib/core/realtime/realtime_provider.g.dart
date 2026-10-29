// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'realtime_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Conexión de tiempo real. El estado es "¿hay conexión en tiempo real?".
/// Conecta tras el login y se cierra con el logout; sin `WS_BASE_URL` /
/// `WS_ORIGIN` no hace nada (solo sondeo).

@ProviderFor(Realtime)
final realtimeProvider = RealtimeProvider._();

/// Conexión de tiempo real. El estado es "¿hay conexión en tiempo real?".
/// Conecta tras el login y se cierra con el logout; sin `WS_BASE_URL` /
/// `WS_ORIGIN` no hace nada (solo sondeo).
final class RealtimeProvider extends $NotifierProvider<Realtime, bool> {
  /// Conexión de tiempo real. El estado es "¿hay conexión en tiempo real?".
  /// Conecta tras el login y se cierra con el logout; sin `WS_BASE_URL` /
  /// `WS_ORIGIN` no hace nada (solo sondeo).
  RealtimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'realtimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$realtimeHash();

  @$internal
  @override
  Realtime create() => Realtime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$realtimeHash() => r'd0f65d4a615bae2627db2506a9043d08237a618b';

/// Conexión de tiempo real. El estado es "¿hay conexión en tiempo real?".
/// Conecta tras el login y se cierra con el logout; sin `WS_BASE_URL` /
/// `WS_ORIGIN` no hace nada (solo sondeo).

abstract class _$Realtime extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
