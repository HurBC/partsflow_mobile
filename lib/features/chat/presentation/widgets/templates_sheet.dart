import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message_template.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_extras_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';

typedef TemplateChoice = ({
  MessageTemplate template,
  Map<String, String> values,
});

/// Elegir plantilla, completar variables y enviar. Muestra el resultado en un
/// SnackBar. Lo usan el menú "+" y "Elegir plantilla" de la ventana de 24 h.
Future<void> pickAndSendTemplate(
  BuildContext context,
  WidgetRef ref,
  Chat chat,
) async {
  final choice = await showModalBottomSheet<TemplateChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _TemplatesSheet(),
  );
  if (choice == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final r = await ref
      .read(chatThreadProvider(chat).notifier)
      .sendTemplate(choice.template, choice.values);
  if (r.message.isEmpty) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(r.message)));
}

class _TemplatesSheet extends ConsumerStatefulWidget {
  const _TemplatesSheet();

  @override
  ConsumerState<_TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends ConsumerState<_TemplatesSheet> {
  final _search = TextEditingController();
  MessageTemplate? _selected;
  final _fields = <String, TextEditingController>{};

  @override
  void dispose() {
    _search.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _select(MessageTemplate t) {
    for (final c in _fields.values) {
      c.dispose();
    }
    _fields.clear();
    for (final v in t.variables) {
      _fields[v.key] = TextEditingController();
    }
    setState(() => _selected = t);
  }

  Map<String, String> get _values => {
    for (final e in _fields.entries) e.key: e.value.text.trim(),
  };

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.85;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: _selected == null
            ? _list(context)
            : _detail(context, _selected!),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final pf = PfColors.of(context);
    final async = ref.watch(approvedTemplatesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Plantillas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: pf.text),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No pudimos cargar las plantillas.',
                    style: TextStyle(color: pf.text2),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(approvedTemplatesProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
            data: (all) {
              final q = _search.text.trim().toLowerCase();
              final items = q.isEmpty
                  ? all
                  : all.where((t) => t.name.toLowerCase().contains(q)).toList();
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    all.isEmpty
                        ? 'No hay plantillas aprobadas'
                        : 'Sin resultados',
                    style: TextStyle(color: pf.text2),
                  ),
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: pf.divider),
                itemBuilder: (_, i) {
                  final t = items[i];
                  final reason = t.unsupportedReason;
                  return InkWell(
                    onTap: reason == null ? () => _select(t) : null,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 64),
                      child: Opacity(
                        opacity: reason == null ? 1 : 0.55,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: pf.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reason ?? t.render(const {}),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: reason == null ? pf.text2 : pf.warnFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _sectionLabel(String type) => switch (type) {
    'HEADER' => 'Encabezado',
    'FOOTER' => 'Pie',
    _ => 'Cuerpo',
  };

  Widget _detail(BuildContext context, MessageTemplate t) {
    final pf = PfColors.of(context);
    final vars = t.variables;
    final values = _values;
    final complete = values.values.every((v) => v.isNotEmpty);
    final preview = t.render(values);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver a la lista',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => setState(() => _selected = null),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: pf.text),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              Text(
                'Vista previa',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pf.text2,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pf.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pf.border),
                ),
                child: Text(
                  preview,
                  style: TextStyle(
                    fontSize: 15,
                    height: 21 / 15,
                    color: pf.text,
                  ),
                ),
              ),
              if (vars.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Completa las variables',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: pf.text2,
                  ),
                ),
                for (final v in vars)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _fields[v.key],
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText:
                            'Variable {{${v.index}}} · ${_sectionLabel(t.components[v.component].type)}',
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            12 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: complete
                  ? () => Navigator.pop<TemplateChoice>(context, (
                      template: t,
                      values: values,
                    ))
                  : null,
              icon: const Icon(Icons.send, size: 20),
              label: const Text('Enviar plantilla'),
            ),
          ),
        ),
      ],
    );
  }
}
