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

/// Etiquetas del proveedor para el filtro de la lista.

@ProviderFor(filterTags)
final filterTagsProvider = FilterTagsProvider._();

/// Etiquetas del proveedor para el filtro de la lista.

final class FilterTagsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ClientTag>>,
          List<ClientTag>,
          FutureOr<List<ClientTag>>
        >
    with $FutureModifier<List<ClientTag>>, $FutureProvider<List<ClientTag>> {
  /// Etiquetas del proveedor para el filtro de la lista.
  FilterTagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filterTagsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filterTagsHash();

  @$internal
  @override
  $FutureProviderElement<List<ClientTag>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ClientTag>> create(Ref ref) {
    return filterTags(ref);
  }
}

String _$filterTagsHash() => r'e9623505ed3107e3dfd27a63a87c63d2dd888edc';

/// Estados de cliente disponibles en la sucursal.

@ProviderFor(filterStatuses)
final filterStatusesProvider = FilterStatusesProvider._();

/// Estados de cliente disponibles en la sucursal.

final class FilterStatusesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// Estados de cliente disponibles en la sucursal.
  FilterStatusesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filterStatusesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filterStatusesHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return filterStatuses(ref);
  }
}

String _$filterStatusesHash() => r'b904fd63750d78734ff46ae2502391703a26d2e4';
