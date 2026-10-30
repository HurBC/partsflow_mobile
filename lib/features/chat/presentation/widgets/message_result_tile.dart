import 'package:flutter/material.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';

/// Resultado de búsqueda por texto libre: chat + fragmento del mensaje que
/// coincidió (`referenceMessage`) con la coincidencia en negrita.
class MessageResultTile extends StatelessWidget {
  const MessageResultTile({
    super.key,
    required this.chat,
    required this.query,
    required this.onTap,
  });

  final Chat chat;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final name = chatDisplayName(chat);
    final ref = chat.referenceMessage;
    final text = ref?.text ?? '';
    final date = listTime(ref?.date ?? chat.activityAt);
    final mine = ref?.isOutbound ?? false;
    final snippet = snippetAround(text, query);

    final base = theme.textTheme.bodyMedium?.copyWith(color: pf.text2);
    return Semantics(
      button: true,
      label: [
        name,
        if (date.isNotEmpty) date,
        if (mine) 'Tú',
        if (text.isNotEmpty) text,
      ].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: pf.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatAvatar(chat: chat),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: pf.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            date,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: pf.text2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          style: base,
                          children: [
                            if (mine)
                              TextSpan(
                                text: 'Tú: ',
                                style: TextStyle(
                                  color: pf.textMid,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ...highlightSpans(
                              snippet,
                              query,
                              TextStyle(
                                color: pf.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

/// Términos a resaltar: la frase completa; si no aparece, cada palabra ≥ 2.
List<String> _terms(String text, String query) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  if (text.toLowerCase().contains(q.toLowerCase())) return [q];
  return [
    for (final w in q.split(RegExp(r'\s+')))
      if (w.length >= 2) w,
  ];
}

/// Recorta [text] alrededor de la primera coincidencia (≈ 40 caracteres antes)
/// para que el fragmento se vea aunque el mensaje sea largo.
String snippetAround(String text, String query, {int lead = 40}) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final terms = _terms(t, query);
  var at = -1;
  final low = t.toLowerCase();
  for (final term in terms) {
    final i = low.indexOf(term.toLowerCase());
    if (i >= 0 && (at < 0 || i < at)) at = i;
  }
  if (at <= lead) return t;
  return '…${t.substring(at - lead)}';
}

/// Parte [text] en spans, con [bold] en las coincidencias (sin distinguir
/// mayúsculas).
List<InlineSpan> highlightSpans(String text, String query, TextStyle bold) {
  final terms = _terms(text, query);
  if (terms.isEmpty) return [TextSpan(text: text)];
  final re = RegExp(terms.map(RegExp.escape).join('|'), caseSensitive: false);
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    spans.add(TextSpan(text: m.group(0), style: bold));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}
