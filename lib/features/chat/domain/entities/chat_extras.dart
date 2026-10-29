/// Nota interna sobre el cliente.
class ClientNote {
  const ClientNote({
    required this.id,
    required this.comment,
    this.authorId,
    this.authorName,
    this.createdAt,
  });

  final String id;
  final String comment;
  final String? authorId;
  final String? authorName;
  final DateTime? createdAt;
}

/// Etiqueta del proveedor (asignable a clientes).
class ClientTag {
  const ClientTag({
    required this.id,
    required this.name,
    this.color,
    this.isSystem = false,
  });

  final String id;
  final String name;
  final String? color;
  final bool isSystem;
}

/// Problema activo de un cliente.
class ClientIssue {
  const ClientIssue({
    required this.id,
    required this.type,
    this.comment,
    this.createdAt,
  });

  final String id;
  final String type;
  final String? comment;
  final DateTime? createdAt;

  String get typeLabel => issueTypeLabel(type);
}

/// Tipos de problema (valor del servidor, texto en español), en orden de UI.
const issueTypes = <(String, String)>[
  ('order_followup', 'Seguimiento de pedido'),
  ('incomplete_order', 'Pedido incompleto'),
  ('wrong_products', 'Productos equivocados'),
  ('refund', 'Reembolso'),
  ('failed_contact', 'Comunicación fallida'),
  ('meli', 'Problemas con MeLi'),
  ('angry_client', 'Cliente enojado'),
  ('other', 'Otro problema'),
];

String issueTypeLabel(String type) {
  for (final (v, l) in issueTypes) {
    if (v == type) return l;
  }
  return 'Otro problema';
}
