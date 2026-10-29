import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/presentation/utils/order_format.dart';

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final name = orderClientName(order);
    final amount = order.ticket == null ? 'Sin monto' : money(order.ticket!);
    final car = (order.carName ?? '').isEmpty ? 'Sin vehículo' : order.carName!;
    final wait = order.clientLastMessageAt == null
        ? null
        : ago(order.clientLastMessageAt!);

    return Semantics(
      button: true,
      label: [
        'Pedido ${order.id}',
        name,
        amount,
        order.productsLabel,
        car,
        if (order.plate != null) order.plate!,
        if (order.isJulia) 'Creado por Julia',
        ?wait,
      ].join(', '),
      child: ExcludeSemantics(
        child: Material(
          color: pf.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '#${order.id}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: pf.text2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: pf.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        amount,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: order.ticket == null ? pf.text2 : pf.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    order.productsLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: pf.textMid),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          car,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: pf.text2),
                        ),
                      ),
                      if (order.plate != null) ...[
                        const SizedBox(width: 8),
                        PlateBadge(plate: order.plate!),
                      ],
                      if (order.isJulia) ...[
                        const SizedBox(width: 8),
                        const JuliaBadge(),
                      ],
                      const Spacer(),
                      if (wait != null)
                        Text(
                          wait,
                          style: TextStyle(fontSize: 13, color: pf.text2),
                        ),
                    ],
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

class PlateBadge extends StatelessWidget {
  const PlateBadge({super.key, required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        border: Border.all(color: pf.textMid, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        plate.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: pf.textMid,
        ),
      ),
    );
  }
}

class JuliaBadge extends StatelessWidget {
  const JuliaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: pf.juliaBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 11, color: pf.juliaFg),
          const SizedBox(width: 3),
          Text(
            'Julia',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: pf.juliaFg,
            ),
          ),
        ],
      ),
    );
  }
}
