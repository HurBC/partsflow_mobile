import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';

abstract class OrdersRepository {
  Future<Result<OrdersListPage>> list(OrdersQuery query);

  /// Número de clientes de una etapa (contador de la pestaña).
  Future<Result<int>> count(OrderStage stage, String? search);

  Future<Result<OrderDetail>> detail(int id);

  Future<Result<MoveOutcome>> move(int id, OrderStage to);

  /// Chat del cliente por teléfono; null si no existe.
  Future<Result<Chat?>> findChat(String phone);
}
