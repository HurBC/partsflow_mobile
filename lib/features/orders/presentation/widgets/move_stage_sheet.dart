import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/presentation/utils/order_format.dart';

/// Hoja "Mover a…". Devuelve la etapa elegida (o null si se cierra).
Future<OrderStage?> showMoveStageSheet(
  BuildContext context, {
  required OrderStage? current,
}) => showModalBottomSheet<OrderStage>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _MoveSheet(current: current),
);

class _MoveSheet extends StatelessWidget {
  const _MoveSheet({required this.current});

  final OrderStage? current;

  static const _blocked = ['Venta finalizada', 'Cancelar pedido'];

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    const allowed = [
      OrderStage.porCotizar,
      OrderStage.cotizacionEnviada,
      OrderStage.posibleVenta,
      OrderStage.devolucion,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Mover a otra etapa',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: pf.text),
              ),
            ),
            const SizedBox(height: 8),
            for (final st in allowed)
              _Row(
                title: st.label,
                dot: stageDot(st),
                subtitle: st == current ? 'Etapa actual' : null,
                enabled: st != current,
                onTap: () => Navigator.of(context).pop(st),
              ),
            _Row(
              title: OrderStage.ventaPorGestionar.label,
              dot: stageDot(OrderStage.ventaPorGestionar),
              subtitle: 'Hazlo desde el Backoffice por ahora',
              enabled: false,
            ),
            for (final t in _blocked)
              _Row(
                title: t,
                dot: pf.text2,
                subtitle: 'Hazlo desde el Backoffice por ahora',
                enabled: false,
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.dot,
    required this.enabled,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final Color dot;
  final String? subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: subtitle == null ? title : '$title, $subtitle',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: pf.text,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: TextStyle(fontSize: 13, color: pf.text2),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
