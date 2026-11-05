import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';

enum SendStatus { sent, suppressed, conflict, rejected }

class SendOutcome {
  const SendOutcome(this.status, [this.detail, this.created]);

  final SendStatus status;
  final String? detail;

  /// Mensaje real devuelto por el POST (id = websocket_id local enviado), o
  /// null si la respuesta no lo trae (null / respuesta sintética del gate).
  final Message? created;

  bool get ok => status == SendStatus.sent;
}

class OrderStrip {
  const OrderStrip({required this.id, required this.stage});

  final String id;
  final OrderStage stage;

  String get stageLabel => stage.label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderStrip && other.id == id && other.stage == stage;

  @override
  int get hashCode => Object.hashAll([id, stage]);
}
