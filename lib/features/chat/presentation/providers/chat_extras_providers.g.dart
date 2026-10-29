// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_extras_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Respuestas rápidas del proveedor (se recargan al cambiar de usuario).
/// Si falla, lanza: la UI ofrece reintentar con `ref.invalidate`.

@ProviderFor(quickAnswers)
final quickAnswersProvider = QuickAnswersProvider._();

/// Respuestas rápidas del proveedor (se recargan al cambiar de usuario).
/// Si falla, lanza: la UI ofrece reintentar con `ref.invalidate`.

final class QuickAnswersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<QuickAnswer>>,
          List<QuickAnswer>,
          FutureOr<List<QuickAnswer>>
        >
    with
        $FutureModifier<List<QuickAnswer>>,
        $FutureProvider<List<QuickAnswer>> {
  /// Respuestas rápidas del proveedor (se recargan al cambiar de usuario).
  /// Si falla, lanza: la UI ofrece reintentar con `ref.invalidate`.
  QuickAnswersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'quickAnswersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$quickAnswersHash();

  @$internal
  @override
  $FutureProviderElement<List<QuickAnswer>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<QuickAnswer>> create(Ref ref) {
    return quickAnswers(ref);
  }
}

String _$quickAnswersHash() => r'b236991f242d8a877395e102e2fc35dd48070d08';

/// Plantillas aprobadas (sin `hello_world`).

@ProviderFor(approvedTemplates)
final approvedTemplatesProvider = ApprovedTemplatesProvider._();

/// Plantillas aprobadas (sin `hello_world`).

final class ApprovedTemplatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MessageTemplate>>,
          List<MessageTemplate>,
          FutureOr<List<MessageTemplate>>
        >
    with
        $FutureModifier<List<MessageTemplate>>,
        $FutureProvider<List<MessageTemplate>> {
  /// Plantillas aprobadas (sin `hello_world`).
  ApprovedTemplatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'approvedTemplatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$approvedTemplatesHash();

  @$internal
  @override
  $FutureProviderElement<List<MessageTemplate>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MessageTemplate>> create(Ref ref) {
    return approvedTemplates(ref);
  }
}

String _$approvedTemplatesHash() => r'b70f6cd51e900e04aadf3e91208639d3a5a68b85';
