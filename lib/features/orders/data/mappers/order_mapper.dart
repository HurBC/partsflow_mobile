import 'package:partsflow_mobile/core/utils/json_utils.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';

// Parseo tolerante: todo es opcional y los tipos pueden variar.

String? _fullName(Map<String, dynamic>? m) {
  if (m == null) return null;
  final n = nonEmpty(
    '${asStr(m['first_name']) ?? ''} ${asStr(m['last_name']) ?? ''}',
  );
  return n;
}

List<OrderProduct> _opqs(Object? json) {
  final out = <OrderProduct>[];
  for (final o in asList(json)) {
    final m = asMap(o);
    final name = nonEmpty(asStr(asMap(m?['product'])?['name']));
    if (name != null) {
      out.add(OrderProduct(name: name, quantity: asInt(m?['quantity']) ?? 1));
    }
  }
  return out;
}

/// Pedido de `order_list` + datos del cliente padre. null si no trae `id`.
OrderSummary? orderFromKanban(Object? order, Map<String, dynamic> client) {
  final m = asMap(order);
  final id = asInt(m?['id']);
  if (m == null || id == null) return null;
  final car = asMap(m['client_car']);
  return OrderSummary(
    id: id,
    status: asStr(m['status']),
    source: asStr(m['source']),
    createdAt: asDate(m['created_at']),
    ticket: asInt(m['ticket']),
    responsibleName: _fullName(asMap(m['responsible'])),
    clientId: asStr(client['id']),
    clientName: nonEmpty(asStr(client['full_name'])),
    clientPhone: nonEmpty(asStr(client['phone'])),
    clientPhotoUrl: nonEmpty(asStr(client['profile_picture_url'])),
    clientLastMessageAt: asDate(client['last_message_at']),
    carName: nonEmpty(asStr(car?['name'])),
    plate: nonEmpty(asStr(car?['plate'])),
    products: _opqs(m['opqs']),
    cancelReason: nonEmpty(asStr(m['cancel_reason'])),
  );
}

/// Respuesta de `orders/v2/kanban/`: (pedidos aplanados, count, hay más).
(List<OrderSummary>, int, bool) ordersPageFromJson(Object? json) {
  final map = asMap(json);
  final out = <OrderSummary>[];
  for (final c in asList(map?['results'])) {
    final client = asMap(c);
    if (client == null) continue;
    for (final o in asList(client['order_list'])) {
      final s = orderFromKanban(o, client);
      if (s != null) out.add(s);
    }
  }
  return (out, asInt(map?['count']) ?? out.length, map?['next'] != null);
}

/// `GET orders/{id}/`. null si el JSON no es un pedido.
OrderSummary? orderFromDetail(Object? json) {
  final m = asMap(json);
  final id = asInt(m?['id']);
  if (m == null || id == null) return null;
  final client = asMap(m['client']);
  final car = asMap(m['client_car']); // puede venir como id numérico
  return OrderSummary(
    id: id,
    status: asStr(m['status']),
    source: asStr(m['source']),
    createdAt: asDate(m['created_at']),
    ticket: asInt(m['ticket']),
    responsibleName: _fullName(asMap(m['responsible'])),
    clientId: asStr(client?['id']),
    clientName:
        nonEmpty(asStr(client?['full_name'])) ??
        nonEmpty(asStr(client?['name'])),
    clientPhone: nonEmpty(asStr(client?['phone'])),
    clientEmail: nonEmpty(asStr(client?['email'])),
    clientPhotoUrl: nonEmpty(asStr(client?['profile_picture_url'])),
    carName: nonEmpty(asStr(car?['name'])),
    plate: nonEmpty(asStr(car?['plate'])),
    cancelReason: nonEmpty(asStr(m['cancel_reason'])),
  );
}

List<Object?> _results(Object? json) =>
    json is List ? json : asList(asMap(json)?['results']);

List<OrderProduct> productsFromJson(Object? json) => _opqs(_results(json));

List<QuoteLine> quoteFromJson(Object? json) {
  final out = <QuoteLine>[];
  for (final r in _results(json)) {
    final m = asMap(r);
    if (m == null) continue;
    final name = nonEmpty(asStr(asMap(m['product'])?['name']));
    if (name == null) continue;
    final brand = m['brand'] is Map
        ? asStr(asMap(m['brand'])?['name'])
        : asStr(m['brand']);
    final disc = m['discount'];
    out.add(
      QuoteLine(
        name: name,
        brand: nonEmpty(brand),
        quantity: asInt(m['quantity']) ?? 1,
        // `cost` es el precio de venta ingresado, sin descuento y con o sin IVA
        // según `is_vat_included`; `unit_cost`/`vat_cost` ya vienen normalizados.
        unitPrice: _positive(asInt(m['unit_cost'])) ?? asInt(m['cost']),
        lineTotal: _positive(asInt(m['vat_cost'])),
        discount: disc is num ? disc.toDouble() : double.tryParse('$disc'),
        isProposed: asBool(m['is_proposed']) ?? false,
        isAccepted: asBool(m['is_accepted']) ?? false,
        isOutOfStock: asBool(m['is_out_of_stock']) ?? false,
        observations: nonEmpty(asStr(m['observations'])),
      ),
    );
  }
  return out;
}

List<OrderNote> notesFromJson(Object? json) {
  final out = <OrderNote>[];
  for (final r in _results(json)) {
    final m = asMap(r);
    final text = nonEmpty(asStr(m?['comment']));
    if (m == null || text == null) continue;
    final a = m['user'] ?? m['author'] ?? m['created_by'];
    final author = a is Map
        ? (_fullName(asMap(a)) ?? nonEmpty(asStr(asMap(a)?['name'])))
        : nonEmpty(asStr(a));
    out.add(
      OrderNote(text: text, createdAt: asDate(m['created_at']), author: author),
    );
  }
  return out;
}

int? _positive(int? v) => v == null || v <= 0 ? null : v;
