import 'package:dio/dio.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/utils/json_utils.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/data/mappers/chat_mapper.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:partsflow_mobile/features/orders/data/mappers/order_mapper.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/domain/repositories/orders_repository.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  OrdersRepositoryImpl(this._remote);

  final OrdersRemoteDataSource _remote;

  Failure _fail(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (e.response == null) return Failure.network();
      if (status == 401) return Failure.unauthorization();
      if (status != null && status >= 500) return Failure.server();
    }
    return Failure.unknown();
  }

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Result.ok(await run());
    } catch (e) {
      return Result.err(_fail(e));
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _params(OrdersQuery q) {
    final now = DateTime.now();
    return {
      'limit': q.limit,
      'offset': q.offset,
      'status': q.stage.statuses.join(','),
      'pending': ?q.stage.pending?.toString(),
      'client_last_message_at_range':
          '${_ymd(now.subtract(const Duration(days: 7)))},${_ymd(now)}',
      'search': ?q.search,
    };
  }

  @override
  Future<Result<OrdersListPage>> list(OrdersQuery query) => _guard(() async {
    final (items, count, more) = ordersPageFromJson(
      await _remote.kanban(_params(query)),
    );
    return OrdersListPage(items: items, count: count, hasMore: more);
  });

  @override
  Future<Result<int>> count(OrderStage stage, String? search) =>
      _guard(() async {
        final (_, count, _) = ordersPageFromJson(
          await _remote.kanban(
            _params(OrdersQuery(stage: stage, search: search, limit: 1)),
          ),
        );
        return count;
      });

  @override
  Future<Result<OrderDetail>> detail(int id) async {
    var anyOk = false;
    Future<Object?> part(
      Future<Object?> Function() call,
      Object? Function(Object?) f,
    ) async {
      try {
        final r = f(await call());
        anyOk = true;
        return r;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait<Object?>([
      part(() => _remote.order(id), orderFromDetail),
      part(() => _remote.products(id), productsFromJson),
      part(() => _remote.quotation(id), quoteFromJson),
      part(() => _remote.comments(id), notesFromJson),
    ]);
    if (!anyOk) return Result.err(Failure.network());
    var order = results[0] as OrderSummary?;
    final products = results[1] as List<OrderProduct>?;
    if (order != null && products != null && products.isNotEmpty) {
      order = order.copyWith(products: products);
    }
    return Result.ok(
      OrderDetail(
        order: order,
        quote: (results[2] as List<QuoteLine>?) ?? const [],
        notes: (results[3] as List<OrderNote>?) ?? const [],
      ),
    );
  }

  @override
  Future<Result<MoveOutcome>> move(int id, OrderStage to) async {
    try {
      await _remote.manualUpdate(id, to.moveStatus);
      return Result.ok(const MoveOutcome(ok: true));
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        return Result.ok(
          MoveOutcome(
            ok: false,
            detail: nonEmpty(asStr(asMap(e.response?.data)?['detail'])),
          ),
        );
      }
      return Result.err(_fail(e));
    } catch (e) {
      return Result.err(_fail(e));
    }
  }

  @override
  Future<Result<Chat?>> findChat(String phone) => _guard(() async {
    final data = await _remote.searchChat(phone);
    final raw = data is List ? data : asList(asMap(data)?['chats']);
    return raw.isEmpty ? null : chatFromJson(raw.first);
  });
}
