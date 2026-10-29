import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart'
    show failureMessage;
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/presentation/providers/orders_providers.dart';
import 'package:partsflow_mobile/features/orders/presentation/utils/order_format.dart';
import 'package:partsflow_mobile/features/orders/presentation/widgets/move_stage_sheet.dart';
import 'package:partsflow_mobile/features/orders/presentation/widgets/order_tile.dart';

class OrderDetailPage extends ConsumerStatefulWidget {
  const OrderDetailPage({super.key, required this.id, this.initial});

  final int id;

  /// Fila de la lista (si se llegó desde ahí); se muestra mientras carga.
  final OrderSummary? initial;

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  bool _moving = false;
  bool _openingChat = false;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openChat(String phone) async {
    if (_openingChat) return;
    setState(() => _openingChat = true);
    final r = await ref.read(ordersRepositoryProvider).findChat(phone);
    if (!mounted) return;
    setState(() => _openingChat = false);
    switch (r) {
      case Ok(:final value) when value != null:
        context.push(AppRoutes.chatDetail(value.id), extra: value);
      case Ok():
        _snack('No encontramos el chat de este cliente');
      case Err(:final failure):
        _snack(failureMessage(failure));
    }
  }

  Future<void> _move(OrderSummary order) async {
    final to = await showMoveStageSheet(context, current: order.stage);
    if (to == null || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Mover el pedido #${order.id} a ${to.label}?'),
        content: to == OrderStage.cotizacionEnviada
            ? const Text(
                'Julia podría hacer seguimiento automático con el cliente.',
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _moving = true);
    final r = await ref.read(ordersRepositoryProvider).move(order.id, to);
    if (!mounted) return;
    setState(() => _moving = false);
    switch (r) {
      case Ok(:final value) when value.ok:
        _snack('Pedido #${order.id} movido a ${to.label}');
        ref.invalidate(orderDetailProvider(widget.id));
        ref.read(ordersListControllerProvider.notifier).poll();
      case Ok(:final value):
        _snack(value.detail ?? 'No pudimos mover el pedido. Intenta de nuevo.');
      case Err(:final failure):
        _snack(failureMessage(failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final async = ref.watch(orderDetailProvider(widget.id));
    final detail = async.value;
    final order = (detail?.order ?? widget.initial)?.fillFrom(widget.initial);

    Widget body;
    if (order == null) {
      body = async.hasError
          ? ErrorState(
              message: failureMessage(
                async.error is Failure
                    ? async.error! as Failure
                    : Failure.unknown(),
              ),
              onRetry: () => ref.invalidate(orderDetailProvider(widget.id)),
            )
          : const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(orderDetailProvider(widget.id));
          await ref
              .read(orderDetailProvider(widget.id).future)
              .then((_) {}, onError: (_) {});
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            _StageCard(order: order),
            const SizedBox(height: 10),
            _ClientCard(
              order: order,
              busy: _openingChat,
              onChat: order.clientPhone == null
                  ? null
                  : () => _openChat(order.clientPhone!),
            ),
            const SizedBox(height: 10),
            _QuoteCard(
              order: order,
              detail: detail,
              loading: async.isLoading && detail == null,
              failed: async.hasError && detail == null,
              onRetry: () => ref.invalidate(orderDetailProvider(widget.id)),
            ),
            if (detail != null && detail.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _NotesCard(notes: detail.notes),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${widget.id}'),
        backgroundColor: pf.surface,
      ),
      body: body,
      bottomNavigationBar: order == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: pf.surface,
                border: Border(top: BorderSide(color: pf.divider)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _moving ? null : () => _move(order),
                      child: _moving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Mover a otra etapa'),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Semantics(
      container: true,
      label: label,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pf.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: pf.text2,
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final stage = order.stage;
    final origin = originLabel(order);
    final created = order.createdAt == null
        ? null
        : 'Creado ${createdLabel(order.createdAt!)}${origin == null ? '' : ' · $origin'}';
    return _Card(
      label: 'Etapa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pf.indicator,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: stageDot(stage),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  stage?.label ?? (order.status ?? 'Sin etapa'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pf.textMid,
                  ),
                ),
              ],
            ),
          ),
          if (created != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                created,
                style: TextStyle(fontSize: 13, color: pf.text2),
              ),
            ),
          if (order.responsibleName != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Responsable: ${order.responsibleName}',
                style: TextStyle(fontSize: 13, color: pf.text2),
              ),
            ),
          if (order.cancelReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Motivo: ${order.cancelReason}',
                style: TextStyle(fontSize: 13, color: pf.text2),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.order,
    required this.busy,
    required this.onChat,
  });

  final OrderSummary order;
  final bool busy;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final name = orderClientName(order);
    final (bg, fg) = avatarColors(name);
    final phone = order.clientPhone == null
        ? ''
        : maskPhone(order.clientPhone!);
    final car = (order.carName ?? '').isEmpty ? null : order.carName;
    return _Card(
      label: 'Cliente y vehículo',
      child: Column(
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                  child: Text(
                    initialsOf(name),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: pf.text,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: TextStyle(fontSize: 13, color: pf.text2),
                      ),
                    if (order.clientEmail != null)
                      Text(
                        order.clientEmail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: pf.text2),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Abrir chat con $name',
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onChat,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Chat'),
                ),
              ),
            ],
          ),
          if (car != null || order.plate != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: pf.divider),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.directions_car_outlined, size: 18, color: pf.text2),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    car ?? 'Sin vehículo',
                    style: TextStyle(fontSize: 14, color: pf.textMid),
                  ),
                ),
                if (order.plate != null) ...[
                  const SizedBox(width: 8),
                  PlateBadge(plate: order.plate!),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.order,
    required this.detail,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  final OrderSummary order;
  final OrderDetail? detail;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final quote = detail?.quote ?? const <QuoteLine>[];
    final accepted = quote.where((l) => l.isAccepted).toList();
    final others = quote.where((l) => !l.isAccepted).toList();
    final draft = order.stage == OrderStage.porCotizar;

    final children = <Widget>[];
    if (quote.isEmpty) {
      children.add(const _SectionTitle('Productos'));
      if (order.products.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              loading ? 'Cargando…' : 'Sin productos',
              style: TextStyle(fontSize: 14, color: pf.text2),
            ),
          ),
        );
      }
      for (final p in order.products) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              p.quantity > 1 ? '${p.quantity} × ${p.name}' : p.name,
              style: TextStyle(fontSize: 15, color: pf.text),
            ),
          ),
        );
      }
      if (failed) {
        children.add(
          TextButton(
            onPressed: onRetry,
            child: const Text('No pudimos actualizar. Reintentar'),
          ),
        );
      }
      if (order.ticket != null) {
        children.add(_TotalRow('Monto del pedido', order.ticket!));
      }
    } else {
      children.add(
        _SectionTitle(draft ? 'Cotización (borrador)' : 'Cotización'),
      );
      for (final l in [...accepted, ...others]) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _QuoteRow(line: l),
          ),
        );
      }
      if (accepted.isNotEmpty) {
        final total = accepted.fold<int>(0, (a, l) => a + (l.total ?? 0));
        children.add(_TotalRow('Elegida por el cliente', total));
      }
    }

    return _Card(
      label: 'Cotización',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.amount);

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: pf.divider)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: pf.textMid)),
            Text(
              money(amount),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: pf.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.line});

  final QuoteLine line;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final meta = [
      if (line.brand != null) line.brand!,
      if (line.quantity > 1)
        '${line.quantity} × ${line.unitPrice == null ? '—' : money(line.unitPrice!)}',
      if (line.isOutOfStock) 'sin stock',
      if (line.isAccepted) 'elegida por el cliente',
      if (!line.isAccepted && line.isProposed) 'opción',
      if (line.discount != null && line.discount! > 0)
        '${(line.discount! * 100).round()}% dcto.',
      ?line.observations,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: pf.text,
                ),
              ),
              if (meta.isNotEmpty)
                Text(meta, style: TextStyle(fontSize: 13, color: pf.text2)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          line.total == null ? 'Sin precio' : money(line.total!),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: line.total == null ? pf.text2 : pf.text,
          ),
        ),
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final List<OrderNote> notes;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return _Card(
      label: 'Notas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Notas'),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.text, style: TextStyle(fontSize: 14, color: pf.text)),
                  Text(
                    [
                      ?n.author,
                      if (n.createdAt != null) createdLabel(n.createdAt!),
                    ].join(' · '),
                    style: TextStyle(fontSize: 12, color: pf.text2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
