// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_thread_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Conversación de un chat. La clave es el Chat (igualdad por id): la primera
/// instancia se crea con el Chat recibido por `extra` desde la lista.

@ProviderFor(ChatThread)
final chatThreadProvider = ChatThreadFamily._();

/// Conversación de un chat. La clave es el Chat (igualdad por id): la primera
/// instancia se crea con el Chat recibido por `extra` desde la lista.
final class ChatThreadProvider
    extends $NotifierProvider<ChatThread, ThreadState> {
  /// Conversación de un chat. La clave es el Chat (igualdad por id): la primera
  /// instancia se crea con el Chat recibido por `extra` desde la lista.
  ChatThreadProvider._({
    required ChatThreadFamily super.from,
    required Chat super.argument,
  }) : super(
         retry: null,
         name: r'chatThreadProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatThreadHash();

  @override
  String toString() {
    return r'chatThreadProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChatThread create() => ChatThread();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThreadState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThreadState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatThreadProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatThreadHash() => r'c37ece9f9eb6f52b6d9eb74321b8569c96589674';

/// Conversación de un chat. La clave es el Chat (igualdad por id): la primera
/// instancia se crea con el Chat recibido por `extra` desde la lista.

final class ChatThreadFamily extends $Family
    with
        $ClassFamilyOverride<
          ChatThread,
          ThreadState,
          ThreadState,
          ThreadState,
          Chat
        > {
  ChatThreadFamily._()
    : super(
        retry: null,
        name: r'chatThreadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Conversación de un chat. La clave es el Chat (igualdad por id): la primera
  /// instancia se crea con el Chat recibido por `extra` desde la lista.

  ChatThreadProvider call(Chat chat) =>
      ChatThreadProvider._(argument: chat, from: this);

  @override
  String toString() => r'chatThreadProvider';
}

/// Conversación de un chat. La clave es el Chat (igualdad por id): la primera
/// instancia se crea con el Chat recibido por `extra` desde la lista.

abstract class _$ChatThread extends $Notifier<ThreadState> {
  late final _$args = ref.$arg as Chat;
  Chat get chat => _$args;

  ThreadState build(Chat chat);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ThreadState, ThreadState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThreadState, ThreadState>,
              ThreadState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
