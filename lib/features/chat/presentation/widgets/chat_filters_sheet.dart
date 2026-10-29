import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';

typedef FiltersResult = ({ChatFilters filters, SearchMode mode});

Future<FiltersResult?> showChatFiltersSheet(
  BuildContext context, {
  required ChatFilters filters,
  required SearchMode mode,
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
    builder: (_) => _FiltersSheet(filters: filters, mode: mode, chats: chats),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({
    required this.filters,
    required this.mode,
    required this.chats,
  });

  final ChatFilters filters;
  final SearchMode mode;
  final List<Chat> chats;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late ChatFilters _filters = widget.filters;
  late SearchMode _mode = widget.mode;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final count = widget.chats.where(_filters.matches).length;

    Widget toggle(
      String label,
      String hint,
      bool value,
      ChatFilters Function(bool) apply,
    ) {
      return MergeSemantics(
        child: Semantics(
          toggled: value,
          label: label,
          hint: hint,
          child: InkWell(
            onTap: () => setState(() => _filters = apply(!value)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: pf.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: pf.text,
                            ),
                          ),
                          Text(
                            hint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: pf.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ExcludeSemantics(child: PfSwitch(value: value)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.paddingOf(context).bottom,
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
                      'Filtrar chats',
                      style: theme.textTheme.titleLarge?.copyWith(
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
            const SizedBox(height: 10),
            Text(
              'Mostrar solo',
              style: theme.textTheme.bodySmall?.copyWith(
                color: pf.text2,
                fontWeight: FontWeight.w600,
              ),
            ),
            toggle(
              'No leídos',
              'Tienen mensajes que no has abierto',
              _filters.unread,
              (v) => _filters.copyWith(unread: v),
            ),
            toggle(
              'Sin responder',
              'El último mensaje es del cliente',
              _filters.unanswered,
              (v) => _filters.copyWith(unanswered: v),
            ),
            toggle(
              'Julia atendiendo',
              'Chats en modo automático',
              _filters.julia,
              (v) => _filters.copyWith(julia: v),
            ),
            toggle(
              'Sin asignar',
              'Nadie es responsable todavía',
              _filters.unassigned,
              (v) => _filters.copyWith(unassigned: v),
            ),
            const SizedBox(height: 18),
            Text(
              'Buscar por',
              style: theme.textTheme.bodySmall?.copyWith(
                color: pf.text2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              container: true,
              label: 'Buscar por',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in SearchMode.values)
                    _ModeChip(
                      label: m.label,
                      selected: m == _mode,
                      onTap: () => setState(() => _mode = m),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _filters = const ChatFilters();
                        _mode = SearchMode.all;
                      }),
                      child: const Text('Limpiar'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, (
                        filters: _filters,
                        mode: _mode,
                      )),
                      child: Text(
                        count == 1 ? 'Ver 1 chat' : 'Ver $count chats',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? pf.indicator : pf.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? primary : pf.border,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? pf.link : pf.textMid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
