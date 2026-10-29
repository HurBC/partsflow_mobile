// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orders_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ordersRepository)
final ordersRepositoryProvider = OrdersRepositoryProvider._();

final class OrdersRepositoryProvider
    extends
        $FunctionalProvider<
          OrdersRepository,
          OrdersRepository,
          OrdersRepository
        >
    with $Provider<OrdersRepository> {
  OrdersRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ordersRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ordersRepositoryHash();

  @$internal
  @override
  $ProviderElement<OrdersRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OrdersRepository create(Ref ref) {
    return ordersRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OrdersRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OrdersRepository>(value),
    );
  }
}

String _$ordersRepositoryHash() => r'cf6d2a6196be904cfed595aae1ac297ea899cb2f';

@ProviderFor(OrdersListController)
final ordersListControllerProvider = OrdersListControllerProvider._();

final class OrdersListControllerProvider
    extends $NotifierProvider<OrdersListController, OrdersListState> {
  OrdersListControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ordersListControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ordersListControllerHash();

  @$internal
  @override
  OrdersListController create() => OrdersListController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OrdersListState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OrdersListState>(value),
    );
  }
}

String _$ordersListControllerHash() =>
    r'a7a4ad4b83ba9f52464011db0208106c4f0d9dc6';

abstract class _$OrdersListController extends $Notifier<OrdersListState> {
  OrdersListState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<OrdersListState, OrdersListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OrdersListState, OrdersListState>,
              OrdersListState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Detalle de un pedido (pedido + productos + cotización + notas). Falla solo
/// si no se pudo leer nada; los fallos parciales quedan como secciones vacías.

@ProviderFor(orderDetail)
final orderDetailProvider = OrderDetailFamily._();

/// Detalle de un pedido (pedido + productos + cotización + notas). Falla solo
/// si no se pudo leer nada; los fallos parciales quedan como secciones vacías.

final class OrderDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<OrderDetail>,
          OrderDetail,
          FutureOr<OrderDetail>
        >
    with $FutureModifier<OrderDetail>, $FutureProvider<OrderDetail> {
  /// Detalle de un pedido (pedido + productos + cotización + notas). Falla solo
  /// si no se pudo leer nada; los fallos parciales quedan como secciones vacías.
  OrderDetailProvider._({
    required OrderDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'orderDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$orderDetailHash();

  @override
  String toString() {
    return r'orderDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<OrderDetail> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<OrderDetail> create(Ref ref) {
    final argument = this.argument as int;
    return orderDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OrderDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$orderDetailHash() => r'e6d464d2328caaf9471ed1de60a1ac5951a4e2d7';

/// Detalle de un pedido (pedido + productos + cotización + notas). Falla solo
/// si no se pudo leer nada; los fallos parciales quedan como secciones vacías.

final class OrderDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<OrderDetail>, int> {
  OrderDetailFamily._()
    : super(
        retry: null,
        name: r'orderDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Detalle de un pedido (pedido + productos + cotización + notas). Falla solo
  /// si no se pudo leer nada; los fallos parciales quedan como secciones vacías.

  OrderDetailProvider call(int id) =>
      OrderDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'orderDetailProvider';
}
