// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Búsqueda del modo "Todo": consultas en paralelo; cada sección se actualiza
/// por separado. Las búsquedas viejas se descartan (`_seq`).

@ProviderFor(ChatSearchController)
final chatSearchControllerProvider = ChatSearchControllerProvider._();

/// Búsqueda del modo "Todo": consultas en paralelo; cada sección se actualiza
/// por separado. Las búsquedas viejas se descartan (`_seq`).
final class ChatSearchControllerProvider
    extends $NotifierProvider<ChatSearchController, ChatSearchState> {
  /// Búsqueda del modo "Todo": consultas en paralelo; cada sección se actualiza
  /// por separado. Las búsquedas viejas se descartan (`_seq`).
  ChatSearchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatSearchControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatSearchControllerHash();

  @$internal
  @override
  ChatSearchController create() => ChatSearchController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatSearchState>(value),
    );
  }
}

String _$chatSearchControllerHash() =>
    r'4a0905d5c91c646bfbfb1e1414228497b368b5aa';

/// Búsqueda del modo "Todo": consultas en paralelo; cada sección se actualiza
/// por separado. Las búsquedas viejas se descartan (`_seq`).

abstract class _$ChatSearchController extends $Notifier<ChatSearchState> {
  ChatSearchState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ChatSearchState, ChatSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatSearchState, ChatSearchState>,
              ChatSearchState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
