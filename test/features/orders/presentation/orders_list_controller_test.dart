import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart'
    show ListStatus;
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/domain/repositories/orders_repository.dart';
import 'package:partsflow_mobile/features/orders/presentation/providers/orders_providers.dart';

class FakeRepo implements OrdersRepository {
  int lists = 0;
  final countCalls = <OrderStage>[];
  final queries = <OrdersQuery>[];
  bool hasMore = false;

  /// Si se fija, las listas con offset > 0 esperan este completer.
  Completer<void>? moreGate;

  /// Counts retenidos por etapa y valores a devolver (por defecto 5).
  final countHold = <OrderStage, Completer<void>>{};
  final countValue = <OrderStage, int>{};

  @override
  Future<Result<OrdersListPage>> list(OrdersQuery q) async {
    lists++;
    queries.add(q);
    final off = q.offset;
    if (off > 0) await moreGate?.future;
    return Result.ok(
      OrdersListPage(
        items: [
          OrderSummary(id: off * 100 + 1, status: 'quotation_sent'),
          OrderSummary(id: off * 100 + 2, status: 'quotation_sent'),
        ],
        count: 10,
        hasMore: hasMore,
      ),
    );
  }

  @override
  Future<Result<int>> count(OrderStage stage, String? search) async {
    countCalls.add(stage);
    await countHold[stage]?.future;
    return Result.ok(countValue[stage] ?? 5);
  }

  @override
  Future<Result<OrderSummary>> order(int id) => throw UnimplementedError();

  @override
  Future<Result<OrderDetail>> detail(int id) => throw UnimplementedError();

  @override
  Future<Result<MoveOutcome>> move(int id, OrderStage to) =>
      throw UnimplementedError();

  @override
  Future<Result<Chat?>> findChat(String phone) => throw UnimplementedError();
}

void main() {
  late FakeRepo repo;
  late DateTime t;
  late ProviderContainer c;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  OrdersListController ctl() => c.read(ordersListControllerProvider.notifier);
  OrdersListState st() => c.read(ordersListControllerProvider);

  setUp(() async {
    repo = FakeRepo();
    t = DateTime(2026);
    c = ProviderContainer(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(repo),
        ordersClockProvider.overrideWithValue(() => t),
        authStateProvider.overrideWith((ref) async => true),
      ],
    );
    addTearDown(c.dispose);
    await c.read(authStateProvider.future);
    c.listen(ordersListControllerProvider, (_, _) {});
    await settle();
    await settle();
    // Carga inicial: 1 lista + 4 counts.
    expect(repo.lists, 1);
    expect(repo.countCalls.length, OrderStage.values.length - 1);
    expect(st().status, ListStatus.data);
    repo.lists = 0;
    repo.countCalls.clear();
  });

  test('tick de poll normal: 1 lista, 0 counts', () async {
    t = t.add(const Duration(seconds: 30));
    await ctl().autoPoll();
    await settle();
    expect(repo.lists, 1);
    expect(repo.countCalls, isEmpty);
  });

  test('pasados 5 min el poll incluye counts', () async {
    t = t.add(const Duration(minutes: 5, seconds: 1));
    await ctl().autoPoll();
    await settle();
    expect(repo.lists, 1);
    expect(repo.countCalls.length, OrderStage.values.length - 1);
  });

  test('mover etapa: +-1 local y counts solo de 2 etapas', () async {
    final from = st().stage;
    final before = Map.of(st().counts);
    final to = OrderStage.posibleVenta;
    await ctl().onOrderMoved(1, from, to);
    expect(repo.lists, 0);
    expect(repo.countCalls.toSet(), {from, to});
    expect(repo.countCalls.length, 2);
    expect(st().items.map((o) => o.id), [2]);
    // Confirmado por el servidor (fake devuelve 5).
    expect(st().counts[to], 5);
    expect(before[from], isNotNull);
  });

  test('mover etapa: ajuste local inmediato', () async {
    final from = st().stage;
    final to = OrderStage.posibleVenta;
    final before = Map.of(st().counts);
    final f = ctl().onOrderMoved(1, from, to);
    expect(st().counts[from], before[from]! - 1);
    expect(st().counts[to], before[to]! + 1);
    await f;
  });

  test('montar tab con datos > 30 s: 1 recarga; frescos: 0', () async {
    t = t.add(const Duration(seconds: 10));
    await ctl().onTabShown();
    expect(repo.lists, 0);
    t = t.add(const Duration(seconds: 31));
    await ctl().onTabShown();
    await settle();
    expect(repo.lists, 1);
  });

  test('loadMore tras quitar un pedido: offset 39, luego normal', () async {
    repo.hasMore = true;
    await ctl().reload();
    await settle();
    await ctl().loadMore(); // 2 páginas
    expect(st().pagesLoaded, 2);
    repo.queries.clear();
    await ctl().onOrderMoved(1, st().stage, OrderStage.posibleVenta);
    await ctl().loadMore();
    expect(repo.queries.last.offset, 39);
    await ctl().loadMore();
    expect(repo.queries.last.offset, 60);
  });

  test(
    'mover a la etapa visible con loadingMore: recarga al terminar',
    () async {
      repo.hasMore = true;
    await ctl().reload();
    await settle();
      repo.moreGate = Completer<void>();
      repo.lists = 0;
      final more = ctl().loadMore();
      await settle();
      expect(st().loadingMore, isTrue);
      await ctl().onOrderMoved(99, OrderStage.posibleVenta, st().stage);
      expect(repo.lists, 1); // solo el loadMore en vuelo
      repo.moreGate!.complete();
      await more;
      await settle();
      // 1 loadMore + 1 recarga de la primera página.
      expect(repo.lists, 2);
      expect(repo.queries.last.offset, 0);
    },
  );

  test('counts parciales durante carga completa: ambos se aplican', () async {
    final hold = OrderStage.values.firstWhere(
      (e) =>
          e != st().stage &&
          e != OrderStage.posibleVenta &&
          e != OrderStage.values.last,
    );
    final from = OrderStage.posibleVenta;
    final to = OrderStage.values.last;
    repo.countHold[hold] = Completer<void>();
    repo.countValue[hold] = 7;
    repo.countValue[to] = 9;
    t = t.add(const Duration(minutes: 5, seconds: 1));
    await ctl().autoPoll();
    await settle();
    await ctl().onOrderMoved(99, from, to);
    repo.countHold[hold]!.complete();
    await settle();
    await settle();
    expect(st().counts[hold], 7);
    expect(st().counts[to], 9);
  });
}
