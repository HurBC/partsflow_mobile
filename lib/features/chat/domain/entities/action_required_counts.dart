/// Respuesta de `GET chat/summary/action-required-counts/`: listas planas de
/// ids de pedido y teléfonos de clientes que llevan más de 1 h sin gestión.
class ActionRequiredCounts {
  const ActionRequiredCounts({
    this.toQuoteOrders = const [],
    this.optionsAcceptedOrders = const [],
    this.importantClients = const [],
  });

  static const empty = ActionRequiredCounts();

  /// Pedidos por cotizar.
  final List<int> toQuoteOrders;

  /// Ventas por gestionar (cotización aceptada).
  final List<int> optionsAcceptedOrders;

  /// Teléfonos de clientes importantes sin responder.
  final List<String> importantClients;

  bool get isEmpty =>
      toQuoteOrders.isEmpty &&
      optionsAcceptedOrders.isEmpty &&
      importantClients.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is ActionRequiredCounts &&
      _same(other.toQuoteOrders, toQuoteOrders) &&
      _same(other.optionsAcceptedOrders, optionsAcceptedOrders) &&
      _same(other.importantClients, importantClients);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(toQuoteOrders),
    Object.hashAll(optionsAcceptedOrders),
    Object.hashAll(importantClients),
  );
}

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
