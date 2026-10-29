import 'package:dio/dio.dart';

/// Llamadas HTTP crudas a SAPI; devuelve el JSON sin interpretar.
/// Los errores de red/HTTP se relanzan como [DioException].
class OrdersRemoteDataSource {
  OrdersRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Object?> kanban(Map<String, dynamic> params) async =>
      (await _dio.get<Object?>(
        'orders/v2/kanban/',
        queryParameters: params,
      )).data;

  Future<Object?> order(int id) async =>
      (await _dio.get<Object?>('orders/$id/')).data;

  Future<Object?> products(int id) async => (await _dio.get<Object?>(
    'orders/orderproductquantity/',
    queryParameters: {'order': id, 'limit': 50},
  )).data;

  Future<Object?> quotation(int id) async => (await _dio.get<Object?>(
    'quotations/summary/',
    queryParameters: {'order': id, 'limit': 100},
  )).data;

  Future<Object?> comments(int id) async => (await _dio.get<Object?>(
    'orders/ordercomment/',
    queryParameters: {'order': id, 'limit': 20},
  )).data;

  Future<void> manualUpdate(int id, String status) => _dio.patch<Object?>(
    'orders/$id/manual_update/',
    data: {'id': id, 'status': status},
  );

  Future<Object?> searchChat(String phone) async => (await _dio.get<Object?>(
    'chat/search/',
    queryParameters: {
      'size': 1,
      'include': 'lastMessage',
      'search': 'client_phone:,$phone',
    },
  )).data;
}
