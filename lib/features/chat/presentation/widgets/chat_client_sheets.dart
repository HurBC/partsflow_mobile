import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_extras.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_common.dart';

/// Notas, etiquetas, problemas y recordatorio de un chat (Fase 5B).

Future<void> _show(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: PfColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => child,
    );

Future<void> showClientNotesSheet(BuildContext context, Chat chat) =>
    _show(context, _NotesSheet(chat: chat));

Future<void> showClientTagsSheet(BuildContext context, Chat chat) =>
    _show(context, _TagsSheet(chat: chat));

Future<void> showClientIssuesSheet(BuildContext context, Chat chat) =>
    _show(context, _IssuesSheet(chat: chat));

Future<void> showClientReminderSheet(BuildContext context, Chat chat) =>
    _show(context, _ReminderSheet(chat: chat));

String _stamp(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${dayLabel(l)}, ${hm(l)}';
}

/// Marco común: título, SnackBars propios (la hoja tapa al Scaffold de la
/// página) y altura fija que sube con el teclado.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.title,
    required this.messenger,
    required this.child,
    this.height = 0.8,
  });

  final String title;
  final GlobalKey<ScaffoldMessengerState> messenger;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * height,
        child: ScaffoldMessenger(
          key: messenger,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: pf.text),
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _snack(
  GlobalKey<ScaffoldMessengerState> key,
  String text, {
  bool error = false,
}) {
  final m = key.currentState;
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFF9F1D1D) : null,
      ),
    );
}

String _failText(Failure failure) =>
    failureMessage(failure).startsWith('Sin conexión')
    ? 'Sin conexión. Revisa tu internet.'
    : 'No se pudo completar la acción. Intenta de nuevo.';

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      ErrorState(message: 'No pudimos cargar los datos.', onRetry: onRetry);
}

class _BusyButton extends StatelessWidget {
  const _BusyButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    ),
  );
}

// ---- B1 Notas ---------------------------------------------------------------

class _NotesSheet extends ConsumerStatefulWidget {
  const _NotesSheet({required this.chat});

  final Chat chat;

  @override
  ConsumerState<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends ConsumerState<_NotesSheet> {
  final _msg = GlobalKey<ScaffoldMessengerState>();
  final _input = TextEditingController();
  List<ClientNote>? _notes;
  bool _loadFailed = false;
  bool _saving = false;
  String? _deleting;

  String? get _clientId => widget.chat.client?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _clientId;
    if (id == null) {
      setState(() => _loadFailed = true);
      return;
    }
    setState(() => _loadFailed = false);
    final r = await ref.read(chatRepositoryProvider).clientNotes(id);
    if (!mounted) return;
    switch (r) {
      case Ok(:final value):
        setState(() => _notes = value);
      case Err():
        setState(() => _loadFailed = true);
    }
  }

  bool _isMine(ClientNote n, String? myId, String? myName) {
    if (n.authorId != null && myId != null) return n.authorId == myId;
    return n.authorName != null && myName != null && n.authorName == myName;
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    final id = _clientId;
    if (text.isEmpty || id == null || _saving) return;
    final me = await ref.read(apiUserProvider.future);
    if (!mounted) return;
    if (me == null) {
      _snack(_msg, 'No pudimos identificar tu usuario', error: true);
      return;
    }
    setState(() => _saving = true);
    final r = await ref
        .read(chatRepositoryProvider)
        .addClientNote(clientId: id, userId: me.id, comment: text);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (r) {
      case Ok():
        _input.clear();
        _snack(_msg, 'Nota agregada');
        _load();
      case Err(:final failure):
        _snack(_msg, _failText(failure), error: true);
    }
  }

  Future<void> _delete(ClientNote n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar nota?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = n.id);
    final r = await ref.read(chatRepositoryProvider).deleteClientNote(n.id);
    if (!mounted) return;
    setState(() => _deleting = null);
    switch (r) {
      case Ok():
        setState(() => _notes = _notes?.where((x) => x.id != n.id).toList());
        _snack(_msg, 'Nota eliminada');
      case Err(:final failure):
        _snack(_msg, _failText(failure), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final me = ref.watch(apiUserProvider).value;
    final myId = me?.id;
    final myName = me == null ? null : '${me.firstName} ${me.lastName}'.trim();
    final notes = _notes;
    return _Frame(
      title: 'Notas del cliente',
      messenger: _msg,
      child: Column(
        children: [
          Expanded(
            child: _loadFailed
                ? _Retry(onRetry: _load)
                : notes == null
                ? const Center(child: CircularProgressIndicator())
                : notes.isEmpty
                ? Center(
                    child: Text(
                      'Aún no hay notas para este cliente.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: pf.text2,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => Divider(color: pf.divider),
                    itemBuilder: (_, i) {
                      final n = notes[i];
                      final mine = _isMine(n, myId, myName);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.comment,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: pf.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      n.authorName ?? 'Sin autor',
                                      _stamp(n.createdAt),
                                    ].where((e) => e.isNotEmpty).join(' · '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: pf.text2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (mine)
                            _deleting == n.id
                                ? const SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    tooltip: 'Eliminar nota',
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(n),
                                  ),
                        ],
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nueva nota',
                    hintText: 'Escribe una nota sobre el cliente',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _BusyButton(
                  label: 'Agregar nota',
                  busy: _saving,
                  onPressed: _input.text.trim().isEmpty ? null : _add,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- B2 Etiquetas -----------------------------------------------------------

Color tagColor(String? hex, Color fallback) {
  var h = (hex ?? '').trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final v = h.length == 6 ? int.tryParse(h, radix: 16) : null;
  return v == null ? fallback : Color(0xFF000000 | v);
}

class _TagsSheet extends ConsumerStatefulWidget {
  const _TagsSheet({required this.chat});

  final Chat chat;

  @override
  ConsumerState<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends ConsumerState<_TagsSheet> {
  final _msg = GlobalKey<ScaffoldMessengerState>();
  List<ClientTag>? _all;
  Set<String> _assigned = {};
  final _busy = <String>{};
  bool _failed = false;

  String? get _clientId => widget.chat.client?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _clientId;
    if (id == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _failed = false);
    final repo = ref.read(chatRepositoryProvider);
    final res = await Future.wait([repo.allTags(), repo.clientTags(id)]);
    if (!mounted) return;
    final all = res[0];
    final mine = res[1];
    if (all is Ok<List<ClientTag>> && mine is Ok<List<ClientTag>>) {
      setState(() {
        _all = all.value;
        _assigned = {for (final t in mine.value) t.id};
      });
    } else {
      setState(() => _failed = true);
    }
  }

  void _publish() {
    final all = _all ?? const [];
    final tags = [
      for (final t in all)
        if (_assigned.contains(t.id)) ChatTag(name: t.name, color: t.color),
    ];
    ref
        .read(chatThreadProvider(widget.chat).notifier)
        .applyClientExtras(tags: tags);
  }

  Future<void> _toggle(ClientTag t) async {
    final id = _clientId;
    if (id == null || _busy.contains(t.id)) return;
    final wasOn = _assigned.contains(t.id);
    setState(() {
      _busy.add(t.id);
      wasOn ? _assigned.remove(t.id) : _assigned.add(t.id);
    });
    final r = await ref.read(chatRepositoryProvider).toggleTag(t.id, id);
    if (!mounted) return;
    setState(() {
      _busy.remove(t.id);
      if (r is Err) {
        wasOn ? _assigned.add(t.id) : _assigned.remove(t.id);
      }
    });
    switch (r) {
      case Ok():
        _publish();
      case Err(:final failure):
        _snack(
          _msg,
          'No se pudo ${wasOn ? 'quitar' : 'asignar'} la etiqueta "${t.name}". ${_failText(failure)}',
          error: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final all = _all;
    return _Frame(
      title: 'Etiquetas',
      messenger: _msg,
      child: _failed
          ? _Retry(onRetry: _load)
          : all == null
          ? const Center(child: CircularProgressIndicator())
          : all.isEmpty
          ? Center(
              child: Text(
                'No hay etiquetas creadas.',
                style: theme.textTheme.bodyMedium?.copyWith(color: pf.text2),
              ),
            )
          : ListView(
              padding: EdgeInsets.only(
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                for (final t in all)
                  Semantics(
                    button: true,
                    checked: _assigned.contains(t.id),
                    label: t.name,
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: () => _toggle(t),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 56),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: tagColor(t.color, pf.text2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  t.name,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: pf.text,
                                  ),
                                ),
                              ),
                              if (_busy.contains(t.id))
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else if (_assigned.contains(t.id))
                                Icon(Icons.check, color: pf.text),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---- B3 Problemas -----------------------------------------------------------

class _IssuesSheet extends ConsumerStatefulWidget {
  const _IssuesSheet({required this.chat});

  final Chat chat;

  @override
  ConsumerState<_IssuesSheet> createState() => _IssuesSheetState();
}

class _IssuesSheetState extends ConsumerState<_IssuesSheet> {
  final _msg = GlobalKey<ScaffoldMessengerState>();
  final _comment = TextEditingController();
  List<ClientIssue>? _issues;
  bool _failed = false;
  bool _saving = false;
  String? _resolving;
  String _type = 'other';

  String? get _clientId => widget.chat.client?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _clientId;
    if (id == null) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _failed = false);
    final r = await ref.read(chatRepositoryProvider).clientIssues(id);
    if (!mounted) return;
    switch (r) {
      case Ok(:final value):
        setState(() => _issues = value);
      case Err():
        setState(() => _failed = true);
    }
  }

  void _publish() => ref
      .read(chatThreadProvider(widget.chat).notifier)
      .applyClientExtras(issuesCount: _issues?.length);

  Future<void> _create() async {
    final id = _clientId;
    if (id == null || _saving) return;
    setState(() => _saving = true);
    final r = await ref
        .read(chatRepositoryProvider)
        .createIssue(clientId: id, type: _type, comment: _comment.text);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (r) {
      case Ok():
        _comment.clear();
        setState(() => _type = 'other');
        _snack(_msg, 'Problema registrado');
        await _load();
        if (mounted) _publish();
      case Err(:final failure):
        _snack(_msg, _failText(failure), error: true);
    }
  }

  Future<void> _resolve(ClientIssue i) async {
    setState(() => _resolving = i.id);
    final r = await ref.read(chatRepositoryProvider).resolveIssue(i.id);
    if (!mounted) return;
    setState(() => _resolving = null);
    switch (r) {
      case Ok():
        setState(() => _issues = _issues?.where((x) => x.id != i.id).toList());
        _snack(_msg, 'Problema resuelto');
        _publish();
      case Err(:final failure):
        _snack(_msg, _failText(failure), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final issues = _issues;
    return _Frame(
      title: 'Registrar problema',
      messenger: _msg,
      height: 0.9,
      child: _failed
          ? _Retry(onRetry: _load)
          : issues == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Text(
                  'Problemas activos',
                  style: theme.textTheme.titleSmall?.copyWith(color: pf.text2),
                ),
                const SizedBox(height: 8),
                if (issues.isEmpty)
                  Text(
                    'Este cliente no tiene problemas activos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: pf.text2,
                    ),
                  ),
                for (final i in issues)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: BoxDecoration(
                      color: pf.errBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i.typeLabel,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: pf.errFg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (i.comment != null)
                                Text(
                                  i.comment!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: pf.errFg,
                                  ),
                                ),
                              if (i.createdAt != null)
                                Text(
                                  _stamp(i.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: pf.errFg,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _resolving == i.id
                            ? const SizedBox(
                                width: 44,
                                height: 44,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            : TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  foregroundColor: pf.errFg,
                                ),
                                onPressed: () => _resolve(i),
                                child: const Text('Resolver'),
                              ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Nuevo problema',
                  style: theme.textTheme.titleSmall?.copyWith(color: pf.text2),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final (value, label) in issueTypes)
                      ChoiceChip(
                        label: Text(label),
                        selected: _type == value,
                        onSelected: (_) => setState(() => _type = value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _comment,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Comentario (opcional)',
                  ),
                ),
                const SizedBox(height: 12),
                _BusyButton(
                  label: 'Registrar problema',
                  busy: _saving,
                  onPressed: _create,
                ),
              ],
            ),
    );
  }
}

// ---- B4 Recordatorio --------------------------------------------------------

typedef _Opt = (String label, String unit, int value);

const _reminderOptions = <_Opt>[
  ('5 minutos', 'minutes', 5),
  ('10 minutos', 'minutes', 10),
  ('30 minutos', 'minutes', 30),
  ('1 hora', 'hours', 1),
  ('4 horas', 'hours', 4),
  ('1 día', 'days', 1),
];

const _customUnits = <(String, String)>[
  ('minutes', 'Minutos'),
  ('hours', 'Horas'),
  ('days', 'Días'),
];

class _ReminderSheet extends ConsumerStatefulWidget {
  const _ReminderSheet({required this.chat});

  final Chat chat;

  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  final _msg = GlobalKey<ScaffoldMessengerState>();
  final _comment = TextEditingController();
  final _number = TextEditingController(text: '15');
  int _selected =
      0; // índice en _reminderOptions; _reminderOptions.length = custom
  String _customUnit = 'minutes';
  bool _saving = false;

  bool get _custom => _selected == _reminderOptions.length;

  @override
  void dispose() {
    _comment.dispose();
    _number.dispose();
    super.dispose();
  }

  int? get _customValue {
    final v = int.tryParse(_number.text.trim());
    return (v == null || v < 1 || v > 9999) ? null : v;
  }

  bool get _valid => !_custom || _customValue != null;

  Future<void> _save() async {
    if (_saving || !_valid) return;
    final me = await ref.read(apiUserProvider.future);
    if (!mounted) return;
    if (me == null) {
      _snack(_msg, 'No pudimos identificar tu usuario', error: true);
      return;
    }
    final unit = _custom ? _customUnit : _reminderOptions[_selected].$2;
    final time = _custom ? _customValue! : _reminderOptions[_selected].$3;
    setState(() => _saving = true);
    // El BO envía `chat_id: props.chatId` = id crudo del chat (Wali).
    final r = await ref
        .read(chatRepositoryProvider)
        .createReminder(
          chatId: widget.chat.id,
          userId: me.id,
          unit: unit,
          time: time,
          comment: _comment.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (r) {
      case Ok():
        ref
            .read(chatThreadProvider(widget.chat).notifier)
            .applyClientExtras(hasPendingReminder: true);
        final root = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        root
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Recordatorio creado')));
      case Err(:final failure):
        _snack(_msg, _failText(failure), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    return _Frame(
      title: 'Recordarme más tarde',
      messenger: _msg,
      height: 0.9,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'Te avisamos en…',
            style: theme.textTheme.titleSmall?.copyWith(color: pf.text2),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < _reminderOptions.length; i++)
                ChoiceChip(
                  label: Text(_reminderOptions[i].$1),
                  selected: _selected == i,
                  onSelected: (_) => setState(() => _selected = i),
                ),
              ChoiceChip(
                label: const Text('Personalizado'),
                selected: _custom,
                onSelected: (_) =>
                    setState(() => _selected = _reminderOptions.length),
              ),
            ],
          ),
          if (_custom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _number,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      errorText: _valid ? null : 'Inválido',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final (v, l) in _customUnits)
                        ChoiceChip(
                          label: Text(l),
                          selected: _customUnit == v,
                          onSelected: (_) => setState(() => _customUnit = v),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Comentario (opcional)',
            ),
          ),
          const SizedBox(height: 16),
          _BusyButton(
            label: 'Crear recordatorio',
            busy: _saving,
            onPressed: _valid ? _save : null,
          ),
        ],
      ),
    );
  }
}
