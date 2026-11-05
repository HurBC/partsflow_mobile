import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/action_required_provider.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_list_motion.dart';

/// Tope de pedidos que muestra el BO ("+50") y que abre su kanban.
const actionRequiredMaxOrders = 50;

String actionCardCountLabel(ActionCard c, int n) =>
    c != ActionCard.importantClients && n > actionRequiredMaxOrders
    ? '+$actionRequiredMaxOrders'
    : '$n';

String actionCardTitle(ActionCard c) => switch (c) {
  ActionCard.importantClients => 'Clientes importantes',
  ActionCard.toQuote => 'Pedidos por cotizar',
  ActionCard.optionsAccepted => 'Ventas por gestionar',
};

String _short(ActionCard c) => switch (c) {
  ActionCard.importantClients => 'importantes',
  ActionCard.toQuote => 'por cotizar',
  ActionCard.optionsAccepted => 'por gestionar',
};

IconData _icon(ActionCard c) => switch (c) {
  ActionCard.importantClients => Icons.star_outline,
  ActionCard.toQuote => Icons.request_quote_outlined,
  ActionCard.optionsAccepted => Icons.shopping_bag_outlined,
};

/// Fila compacta de tarjetas de acción requerida sobre el listado (equivale a
/// ChatSummaryCards del BO). Oculta si no hay nada que mostrar.
class ActionRequiredBar extends ConsumerWidget {
  const ActionRequiredBar({super.key, required this.onOpen});

  final void Function(ActionCard card) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(actionRequiredProvider);
    final cards = s.visible;
    if (cards.isEmpty) return const SizedBox.shrink();
    final pf = PfColors.of(context);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: pf.surface,
        border: Border(bottom: BorderSide(color: pf.divider)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = cards[i];
          return _CardChip(
            key: ValueKey(c),
            card: c,
            count: s.countOf(c),
            onTap: () => onOpen(c),
            onDismiss: () =>
                ref.read(actionRequiredProvider.notifier).dismiss(c),
          );
        },
      ),
    );
  }
}

class _CardChip extends StatefulWidget {
  const _CardChip({
    super.key,
    required this.card,
    required this.count,
    required this.onTap,
    required this.onDismiss,
  });

  final ActionCard card;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_CardChip> createState() => _CardChipState();
}

class _CardChipState extends State<_CardChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.08,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 55,
    ),
  ]).animate(_nudge);

  @override
  void didUpdateWidget(_CardChip old) {
    super.didUpdateWidget(old);
    if (widget.count > old.count && !MediaQuery.disableAnimationsOf(context)) {
      _nudge.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final onTap = widget.onTap;
    final onDismiss = widget.onDismiss;
    final pf = PfColors.of(context);
    final label = actionCardCountLabel(card, widget.count);
    return ScaleTransition(
      scale: _scale,
      child: Semantics(
        container: true,
        label:
            '${actionCardTitle(card)}: $label, hace más de 1 hora. Toca para ver.',
        child: ExcludeSemantics(
          child: Material(
            color: pf.warnBg,
            shape: StadiumBorder(side: BorderSide(color: pf.border)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Row(
                      children: [
                        Icon(_icon(card), size: 16, color: pf.warnFg),
                        const SizedBox(width: 6),
                        SlideUpSwitcher(
                          value: label,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: pf.warnFg,
                            ),
                          ),
                        ),
                        Text(
                          ' ${_short(card)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: pf.warnFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 16, color: pf.warnFg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja con los pedidos de una tarjeta (máx. 50, como el kanban del BO).
/// Devuelve el id elegido o null.
Future<int?> showActionOrdersSheet(
  BuildContext context, {
  required ActionCard card,
  required List<int> orderIds,
}) {
  final shown = orderIds.take(actionRequiredMaxOrders).toList();
  return showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: PfColors.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, scroll) {
        final pf = PfColors.of(ctx);
        return Column(
          children: [
            const SheetGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  header: true,
                  child: Text(
                    '${actionCardTitle(card)} · hace más de 1 hora',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: shown.length,
                itemBuilder: (_, i) => ListTile(
                  minTileHeight: 56,
                  leading: Icon(Icons.receipt_long_outlined, color: pf.text2),
                  title: Text('Pedido #${shown[i]}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, shown[i]),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
