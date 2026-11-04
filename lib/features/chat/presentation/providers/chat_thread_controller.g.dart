// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_thread_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Conversación de un chat. La clave es un ChatKey (igualdad por id): la primera
/// instancia se crea con el snapshot recibido por `extra` desde la lista.

@ProviderFor(ChatThread)
final chatThreadProvider = ChatThreadFamily._();

/// Conversación de un chat. La clave es un ChatKey (igualdad por id): la primera
/// instancia se crea con el snapshot recibido por `extra` desde la lista.
final class ChatThreadProvider
    extends $NotifierProvider<ChatThread, ThreadState> {
  /// Conversación de un chat. La clave es un ChatKey (igualdad por id): la primera
  /// instancia se crea con el snapshot recibido por `extra` desde la lista.
  ChatThreadProvider._({
    required ChatThreadFamily super.from,
    required ChatKey super.argument,
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

String _$chatThreadHash() => r'9c1cc9a86f8e9a4e40d18b96969f0c1da84b99dc';

/// Conversación de un chat. La clave es un ChatKey (igualdad por id): la primera
/// instancia se crea con el snapshot recibido por `extra` desde la lista.

final class ChatThreadFamily extends $Family
    with
        $ClassFamilyOverride<
          ChatThread,
          ThreadState,
          ThreadState,
          ThreadState,
          ChatKey
        > {
  ChatThreadFamily._()
    : super(
        retry: null,
        name: r'chatThreadProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Conversación de un chat. La clave es un ChatKey (igualdad por id): la primera
  /// instancia se crea con el snapshot recibido por `extra` desde la lista.

  ChatThreadProvider call(ChatKey key) =>
      ChatThreadProvider._(argument: key, from: this);

  @override
  String toString() => r'chatThreadProvider';
}

/// Conversación de un chat. La clave es un ChatKey (igualdad por id): la primera
/// instancia se crea con el snapshot recibido por `extra` desde la lista.

abstract class _$ChatThread extends $Notifier<ThreadState> {
  late final _$args = ref.$arg as ChatKey;
  ChatKey get key => _$args;

  ThreadState build(ChatKey key);
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
