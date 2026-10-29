/// Etapas del pedido que muestra la app (las mismas del Kanban del Backoffice).
enum OrderStage {
  porCotizar(
    'Por cotizar',
    [
      'identifying_car',
      'identifying_products',
      'searching_oems',
      'searching_stock',
      'order_quoted',
    ],
    'identifying_car',
    null,
  ),
  cotizacionEnviada(
    'Cotización enviada',
    ['quotation_sent'],
    'quotation_sent',
    true,
  ),
  posibleVenta('Posible venta', ['options_accepted'], 'options_accepted', true),
  ventaPorGestionar(
    'Venta por gestionar',
    ['purchase_completed'],
    'purchase_completed',
    true,
  ),
  devolucion(
    'Devolución por gestionar',
    ['devolution_requested'],
    'devolution_requested',
    false,
  );

  const OrderStage(this.label, this.statuses, this.moveStatus, this.pending);

  final String label;

  /// Estados de SAPI que forman la etapa (filtro `status=` de la lista).
  final List<String> statuses;

  /// Estado al que se mueve un pedido cuando se elige esta etapa.
  final String moveStatus;

  /// Valor del filtro `pending=` (null = sin filtro).
  final bool? pending;

  /// Texto corto para las pestañas.
  String get tabLabel => this == devolucion ? 'Devolución' : label;

  static OrderStage? fromStatus(String? status) {
    for (final s in values) {
      if (s.statuses.contains(status)) return s;
    }
    return null;
  }
}

class OrderProduct {
  const OrderProduct({required this.name, this.quantity = 1});

  final String name;
  final int quantity;
}

class OrderSummary {
  const OrderSummary({
    required this.id,
    this.status,
    this.source,
    this.createdAt,
    this.ticket,
    this.responsibleName,
    this.clientId,
    this.clientName,
    this.clientPhone,
    this.clientEmail,
    this.clientPhotoUrl,
    this.clientLastMessageAt,
    this.carName,
    this.plate,
    this.products = const [],
    this.cancelReason,
  });

  final int id;
  final String? status;
  final String? source;
  final DateTime? createdAt;

  /// Monto en CLP (null = sin cotizar).
  final int? ticket;
  final String? responsibleName;
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String? clientEmail;
  final String? clientPhotoUrl;
  final DateTime? clientLastMessageAt;
  final String? carName;
  final String? plate;
  final List<OrderProduct> products;
  final String? cancelReason;

  OrderStage? get stage => OrderStage.fromStatus(status);
  bool get isJulia => source == 'ai_order_taker';

  /// "Pastillas de freno y 2 más".
  String get productsLabel {
    if (products.isEmpty) return 'Sin productos';
    final first = products.first.name;
    final more = products.length - 1;
    return more > 0 ? '$first y $more más' : first;
  }

  /// Completa con [o] lo que a este pedido le falte.
  OrderSummary fillFrom(OrderSummary? o) {
    if (o == null) return this;
    return OrderSummary(
      id: id,
      status: status ?? o.status,
      source: source ?? o.source,
      createdAt: createdAt ?? o.createdAt,
      ticket: ticket ?? o.ticket,
      responsibleName: responsibleName ?? o.responsibleName,
      clientId: clientId ?? o.clientId,
      clientName: clientName ?? o.clientName,
      clientPhone: clientPhone ?? o.clientPhone,
      clientEmail: clientEmail ?? o.clientEmail,
      clientPhotoUrl: clientPhotoUrl ?? o.clientPhotoUrl,
      clientLastMessageAt: clientLastMessageAt ?? o.clientLastMessageAt,
      carName: carName ?? o.carName,
      plate: plate ?? o.plate,
      products: products.isEmpty ? o.products : products,
      cancelReason: cancelReason ?? o.cancelReason,
    );
  }

  OrderSummary copyWith({List<OrderProduct>? products}) => OrderSummary(
    id: id,
    status: status,
    source: source,
    createdAt: createdAt,
    ticket: ticket,
    responsibleName: responsibleName,
    clientId: clientId,
    clientName: clientName,
    clientPhone: clientPhone,
    clientEmail: clientEmail,
    clientPhotoUrl: clientPhotoUrl,
    clientLastMessageAt: clientLastMessageAt,
    carName: carName,
    plate: plate,
    products: products ?? this.products,
    cancelReason: cancelReason,
  );
}

/// Línea de la cotización (`quotations/summary/`).
class QuoteLine {
  const QuoteLine({
    required this.name,
    this.brand,
    this.quantity = 1,
    this.unitPrice,
    this.lineTotal,
    this.discount,
    this.isProposed = false,
    this.isAccepted = false,
    this.isOutOfStock = false,
    this.observations,
  });

  final String name;
  final String? brand;
  final int quantity;

  /// `unit_cost`: precio unitario con IVA y descuento aplicado, en CLP.
  final int? unitPrice;

  /// `vat_cost`: total de la línea con IVA y descuento (unitario × cantidad), en CLP.
  final int? lineTotal;

  /// 0..1
  final double? discount;
  final bool isProposed;
  final bool isAccepted;
  final bool isOutOfStock;
  final String? observations;

  int? get total =>
      lineTotal ?? (unitPrice == null ? null : unitPrice! * quantity);
}

class OrderNote {
  const OrderNote({required this.text, this.createdAt, this.author});

  final String text;
  final DateTime? createdAt;
  final String? author;
}

class OrderDetail {
  const OrderDetail({this.order, this.quote = const [], this.notes = const []});

  /// null si `orders/{id}/` falló (se usa la fila de la lista).
  final OrderSummary? order;
  final List<QuoteLine> quote;
  final List<OrderNote> notes;
}

class OrdersQuery {
  const OrdersQuery({
    required this.stage,
    this.search,
    this.offset = 0,
    this.limit = 20,
  });

  final OrderStage stage;

  /// Valor ya armado de `search=` (ver [searchParamFor]).
  final String? search;
  final int offset;
  final int limit;
}

/// Página de la lista. Viene paginada por CLIENTE: [count] es el número de
/// clientes y [items] los pedidos aplanados de esos clientes.
class OrdersListPage {
  const OrdersListPage({
    required this.items,
    required this.count,
    required this.hasMore,
  });

  final List<OrderSummary> items;
  final int count;
  final bool hasMore;
}

class MoveOutcome {
  const MoveOutcome({required this.ok, this.detail});

  final bool ok;
  final String? detail;
}

/// `id:,<n>` si son solo dígitos (≤ 7), `client_phone:,<tel>` si parece
/// teléfono; null si no se puede buscar con ese texto.
String? searchParamFor(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  if (!RegExp(r'^[\d\s+\-()]+$').hasMatch(t)) return null;
  final digits = t.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(t) && digits.length <= 7) return 'id:,$digits';
  if (digits.length >= 8) return 'client_phone:,$digits';
  return null;
}
