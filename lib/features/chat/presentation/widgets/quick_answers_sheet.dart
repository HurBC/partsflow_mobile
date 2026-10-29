import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/quick_answer.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_extras_providers.dart';

List<QuickAnswer> filterQuickAnswers(List<QuickAnswer> all, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all.where((a) => a.title.toLowerCase().contains(q)).toList();
}

/// Hoja con buscador. Devuelve la respuesta elegida o null.
Future<QuickAnswer?> showQuickAnswersSheet(
  BuildContext context, {
  String initialQuery = '',
}) => showModalBottomSheet<QuickAnswer>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _QuickAnswersSheet(initialQuery: initialQuery),
);

class _QuickAnswersSheet extends ConsumerStatefulWidget {
  const _QuickAnswersSheet({required this.initialQuery});

  final String initialQuery;

  @override
  ConsumerState<_QuickAnswersSheet> createState() => _QuickAnswersSheetState();
}

class _QuickAnswersSheetState extends ConsumerState<_QuickAnswersSheet> {
  late final _search = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final async = ref.watch(quickAnswersProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Respuestas rápidas',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: pf.text),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                autofocus: widget.initialQuery.isNotEmpty,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar por título',
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
                        'No pudimos cargar las respuestas rápidas.',
                        style: TextStyle(color: pf.text2),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(quickAnswersProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (all) {
                  final items = filterQuickAnswers(all, _search.text);
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          all.isEmpty
                              ? 'Aún no hay respuestas rápidas. Créalas desde el Backoffice.'
                              : 'Sin resultados',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: pf.text2),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: pf.divider),
                    itemBuilder: (_, i) => QuickAnswerTile(
                      answer: items[i],
                      onTap: () => Navigator.pop(context, items[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAnswerTile extends StatelessWidget {
  const QuickAnswerTile({super.key, required this.answer, required this.onTap});

  final QuickAnswer answer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '/${answer.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: pf.text,
                      ),
                    ),
                    if (answer.message != null)
                      Text(
                        answer.message!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: pf.text2),
                      ),
                  ],
                ),
              ),
              if (answer.imageUrl != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.photo_outlined, size: 20, color: pf.text2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
