import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_extras.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_extras_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';

typedef FiltersResult = ({
  ChatFilters filters,
  AdvancedFilters advanced,
  int threshold,
});

Future<FiltersResult?> showChatFiltersSheet(
  BuildContext context, {
  required ChatFilters filters,
  required AdvancedFilters advanced,
  required int threshold,
  required bool showThreshold,
  required List<Chat> chats,
}) {
  return showModalBottomSheet<FiltersResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: PfColors.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FiltersSheet(
      filters: filters,
      advanced: advanced,
      threshold: threshold,
      showThreshold: showThreshold,
    ),
  );
}

/// Resultado de un selector: `value == null` significa "Todos" (sin filtro).
class _Pick {
  const _Pick(this.value);
  final String? value;
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({
    required this.filters,
    required this.advanced,
    required this.threshold,
    required this.showThreshold,
  });

  final ChatFilters filters;
  final AdvancedFilters advanced;
  final int threshold;
  final bool showThreshold;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late ChatFilters _filters = widget.filters;
  late AdvancedFilters _adv = widget.advanced;
  late int _threshold = widget.threshold;

  static const _all = 'Todos';

  Future<void> _pick({
    required String title,
    required List<(String, String)> options,
    required String? selected,
    required void Function(String?) apply,
    bool searchable = false,
  }) async {
    final r = await showModalBottomSheet<_Pick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: PfColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PickerSheet(
        title: title,
        options: options,
        selected: selected,
        searchable: searchable,
      ),
    );
    if (r == null || !mounted) return;
    setState(() => apply(r.value));
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final tags = ref.watch(filterTagsProvider);
    final statuses = ref.watch(filterStatusesProvider);

    Widget chip(String label, bool value, ValueChanged<bool> apply) {
      return FilterChip(
        label: Text(label),
        selected: value,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: value ? pf.link : pf.textMid,
        ),
        backgroundColor: pf.surface,
        selectedColor: pf.indicator,
        side: BorderSide(
          color: value ? theme.colorScheme.primary : pf.border,
          width: 1.5,
        ),
        shape: const StadiumBorder(),
        onSelected: (v) => setState(() => apply(v)),
      );
    }

    // Fila de una línea: etiqueta a la izquierda, valor actual a la derecha.
    Widget row(
      String label,
      String value,
      VoidCallback? onTap, {
      bool active = false,
    }) {
      return Semantics(
        button: true,
        label: '$label, $value',
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: pf.divider)),
              ),
              child: Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: pf.text,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: active ? pf.link : pf.text2,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: pf.text2),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: pf.text2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    String tagName(List<ClientTag> list, String id) {
      for (final t in list) {
        if (t.id == id) return t.name;
      }
      return 'Etiqueta';
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetGrabber(),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Filtros',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: pf.text,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _filters = const ChatFilters();
                    _adv = const AdvancedFilters();
                  }),
                  child: const Text('Limpiar'),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            label('Mostrar'),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: [
                chip(
                  'No leídos',
                  _filters.unread,
                  (v) => _filters = _filters.copyWith(unread: v),
                ),
                chip(
                  'Sin responder',
                  _filters.unanswered,
                  (v) => _filters = _filters.copyWith(unanswered: v),
                ),
                chip(
                  'Julia',
                  _filters.julia,
                  (v) => _filters = _filters.copyWith(julia: v),
                ),
                chip(
                  'Sin asignar',
                  _filters.unassigned,
                  (v) => _filters = _filters.copyWith(unassigned: v),
                ),
                chip(
                  'Importantes',
                  _adv.important,
                  (v) => _adv = _adv.copyWith(important: v),
                ),
                chip(
                  'Recurrentes',
                  _adv.recurrent,
                  (v) => _adv = _adv.copyWith(recurrent: v),
                ),
                chip(
                  'Con problemas',
                  _adv.hasIssues,
                  (v) => _adv = _adv.copyWith(hasIssues: v),
                ),
                chip(
                  'Sin pedidos',
                  _adv.noOrders,
                  (v) => _adv = _adv.copyWith(noOrders: v),
                ),
              ],
            ),
            label('Filtrar por'),
            row(
              'Canal',
              _adv.channel == null ? _all : leadChannelLabel(_adv.channel!),
              () => _pick(
                title: 'Canal',
                options: leadChannels,
                selected: _adv.channel,
                apply: (v) =>
                    _adv = _adv.copyWith(channel: v, clearChannel: v == null),
              ),
              active: _adv.channel != null,
            ),
            row(
              'Etiqueta',
              tags.when(
                data: (l) =>
                    _adv.tagId == null ? _all : tagName(l, _adv.tagId!),
                loading: () => 'Cargando…',
                error: (_, _) => 'No cargó · tocar para reintentar',
              ),
              tags.when(
                data: (l) => l.isEmpty
                    ? null
                    : () => _pick(
                        title: 'Etiqueta',
                        options: [for (final t in l) (t.id, t.name)],
                        selected: _adv.tagId,
                        searchable: l.length > 8,
                        apply: (v) =>
                            _adv = _adv.copyWith(tagId: v, clearTag: v == null),
                      ),
                loading: () => null,
                error: (_, _) =>
                    () => ref.invalidate(filterTagsProvider),
              ),
              active: _adv.tagId != null,
            ),
            row(
              'Estado',
              statuses.when(
                data: (_) => _adv.status == null
                    ? _all
                    : clientStatusLabel(_adv.status!),
                loading: () => 'Cargando…',
                error: (_, _) => 'No cargó · tocar para reintentar',
              ),
              statuses.when(
                data: (l) => l.isEmpty
                    ? null
                    : () => _pick(
                        title: 'Estado',
                        options: [
                          for (final st in l) (st, clientStatusLabel(st)),
                        ],
                        selected: _adv.status,
                        apply: (v) => _adv = _adv.copyWith(
                          status: v,
                          clearStatus: v == null,
                        ),
                      ),
                loading: () => null,
                error: (_, _) =>
                    () => ref.invalidate(filterStatusesProvider),
              ),
              active: _adv.status != null,
            ),
            row(
              'Problema',
              _adv.issueType == null ? _all : issueTypeLabel(_adv.issueType!),
              () => _pick(
                title: 'Problema',
                options: issueTypes,
                selected: _adv.issueType,
                apply: (v) =>
                    _adv = _adv.copyWith(issueType: v, clearIssue: v == null),
              ),
              active: _adv.issueType != null,
            ),
            if (widget.showThreshold)
              Container(
                constraints: const BoxConstraints(minHeight: 52),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: pf.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pendientes: sin actividad hace',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: pf.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Menos minutos',
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: _threshold > pendingThresholdMin
                          ? () => setState(() => _threshold--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Semantics(
                      liveRegion: true,
                      label: '$_threshold minutos',
                      child: ExcludeSemantics(
                        child: SizedBox(
                          width: 52,
                          child: Text(
                            '$_threshold min',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: pf.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Más minutos',
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: _threshold < pendingThresholdMax
                          ? () => setState(() => _threshold++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, (
                  filters: _filters,
                  advanced: _adv,
                  threshold: _threshold,
                )),
                child: const Text('Ver resultados'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selector pequeño de selección única: "Todos" + opciones; con buscador si
/// [searchable].
class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
  });

  final String title;
  final List<(String, String)> options;
  final String? selected;
  final bool searchable;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final o in widget.options)
        if (q.isEmpty || o.$2.toLowerCase().contains(q)) o,
    ];

    Widget item(String text, String? value) {
      final on = value == widget.selected;
      return Semantics(
        button: true,
        inMutuallyExclusiveGroup: true,
        checked: on,
        label: text,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: () => Navigator.pop(context, _Pick(value)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(
                    on ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 22,
                    color: on ? pf.link : pf.text2,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: pf.text,
                        fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetGrabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: pf.text,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar ${widget.title.toLowerCase()}',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (q.isEmpty) item('Todos', null),
                  for (final o in shown) item(o.$2, o.$1),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Sin coincidencias.',
                        style: TextStyle(color: pf.text2),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
