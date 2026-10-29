import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';

/// $24.990
String money(int v) {
  final digits = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${v < 0 ? '-' : ''}\$$buf';
}

Color stageDot(OrderStage? s) => switch (s) {
  OrderStage.porCotizar || null => PfColors.stagePorCotizar,
  OrderStage.cotizacionEnviada => PfColors.stageCotizacionEnviada,
  OrderStage.posibleVenta => PfColors.stagePosibleVenta,
  OrderStage.ventaPorGestionar => PfColors.stageVentaPorGestionar,
  OrderStage.devolucion => PfColors.stageDevolucion,
};

/// "hoy 09:32", "ayer 18:05", "lunes 10:00", "12 de marzo 09:32".
String createdLabel(DateTime d) => '${dayLabel(d).toLowerCase()} ${hm(d)}';

/// "hace 41 min".
String ago(DateTime d) => 'hace ${relativeShort(d)}';

/// Nombre a mostrar del cliente de un pedido.
String orderClientName(OrderSummary o) {
  final n = o.clientName?.trim();
  if (n != null && n.isNotEmpty) return n;
  final p = formatPhone(o.clientPhone ?? '');
  return p.isEmpty ? 'Sin nombre' : p;
}

String? originLabel(OrderSummary o) => switch (o.source) {
  'ai_order_taker' => 'Julia',
  'widget' => 'Widget',
  'backoffice' => 'Operador',
  _ => null,
};
