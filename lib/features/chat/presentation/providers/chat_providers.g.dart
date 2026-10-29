// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(chatRepository)
final chatRepositoryProvider = ChatRepositoryProvider._();

final class ChatRepositoryProvider
    extends $FunctionalProvider<ChatRepository, ChatRepository, ChatRepository>
    with $Provider<ChatRepository> {
  ChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatRepositoryHash();

  @$internal
  @override
  $ProviderElement<ChatRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatRepository create(Ref ref) {
    return chatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRepository>(value),
    );
  }
}

String _$chatRepositoryHash() => r'51ec42dd48e0fa38a535176409010a421cc6e1c0';

/// ¿Aplica la ventana de 24 h? Solo si el tenant usa la API oficial de
/// WhatsApp. Si la consulta falla, no se aplica.

@ProviderFor(windowApplies)
final windowAppliesProvider = WindowAppliesProvider._();

/// ¿Aplica la ventana de 24 h? Solo si el tenant usa la API oficial de
/// WhatsApp. Si la consulta falla, no se aplica.

final class WindowAppliesProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// ¿Aplica la ventana de 24 h? Solo si el tenant usa la API oficial de
  /// WhatsApp. Si la consulta falla, no se aplica.
  WindowAppliesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowAppliesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowAppliesHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return windowApplies(ref);
  }
}

String _$windowAppliesHash() => r'379db9937452654118b2767e78d56aed7bedb3d3';

@ProviderFor(ChatListController)
final chatListControllerProvider = ChatListControllerProvider._();

final class ChatListControllerProvider
    extends $NotifierProvider<ChatListController, ChatListState> {
  ChatListControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatListControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatListControllerHash();

  @$internal
  @override
  ChatListController create() => ChatListController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatListState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatListState>(value),
    );
  }
}

String _$chatListControllerHash() =>
    r'ecdfe93be97482f21fdf3efa501737e77422e0a5';

abstract class _$ChatListController extends $Notifier<ChatListState> {
  ChatListState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ChatListState, ChatListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatListState, ChatListState>,
              ChatListState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
