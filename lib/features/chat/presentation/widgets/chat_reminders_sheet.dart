import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_key.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/reminder.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/reminder_extension.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/reminders_controller.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/chat_format.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_client_sheets.dart';

/// Recordatorios pendientes del cliente: resolver, extender y crear.
Future<void> showClientRemindersSheet(BuildContext context, Chat chat) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: PfColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RemindersSheet(chat: chat),
    );

/// "Hoy 15:30" / "Mañana 09:00" / "12 de marzo, 09:00" para fechas futuras o
/// pasadas (vencido se marca aparte).
String reminderDueLabel(DateTime due, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = due.toLocal();
  final days = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(n.year, n.month, n.day)).inDays;
  final day = switch (days) {
    0 => 'Hoy',
    1 => 'Mañana',
    _ => dayLabel(d, now: n),
  };
  return '$day, ${hm(d)}';
}

class _RemindersSheet extends ConsumerStatefulWidget {
  const _RemindersSheet({required this.chat});

  final Chat chat;

  @override
  ConsumerState<_RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends ConsumerState<_RemindersSheet> {
  final _msg = GlobalKey<ScaffoldMessengerState>();
  String? _busyId;

  ChatKey get _key => ChatKey(widget.chat);

  void _snack(String text, {bool error = false}) {
    _msg.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? const Color(0xFF9F1D1D) : null,
        ),
      );
  }

  Future<void> _run(
    Reminder r,
    Future<bool> Function() action,
    String ok,
  ) async {
    if (_busyId != null) return;
    setState(() => _busyId = r.id);
    final done = await action();
    if (!mounted) return;
    setState(() => _busyId = null);
    _snack(
      done ? ok : 'No se pudo completar la acción. Intenta de nuevo.',
      error: !done,
    );
  }

  Future<void> _resolve(Reminder r) => _run(
    r,
    () => ref.read(remindersControllerProvider(_key).notifier).resolve(r),
    'Recordatorio resuelto',
  );

  Future<void> _extend(Reminder r, DateTime until) => _run(
    r,
    () => ref.read(remindersControllerProvider(_key).notifier).extend(r, until),
    'Recordatorio extendido',
  );

  Future<void> _extendCustom(Reminder r) async {
    final now = ref.read(reminderClockProvider)();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final until = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (minutesUntil(ref.read(reminderClockProvider)(), until) == null) {
      _snack('Elige una fecha y hora futuras', error: true);
      return;
    }
    await _extend(r, until);
  }

  Future<void> _showExtendOptions(Reminder r) async {
    final now = ref.read(reminderClockProvider)();
    final options = reminderExtensionOptions(now);
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(o.label),
                subtitle: Text(reminderDueLabel(o.until, now: now)),
                onTap: () => Navigator.pop(ctx, o),
              ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Personalizado…'),
              onTap: () => Navigator.pop(ctx, 'custom'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice is ReminderExtensionOption) {
      await _extend(r, choice.until);
    } else {
      await _extendCustom(r);
    }
  }

  Future<void> _create() async {
    await showClientReminderSheet(context, widget.chat);
    if (!mounted) return;
    ref.invalidate(remindersControllerProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(remindersControllerProvider(_key));
    final now = ref.read(reminderClockProvider)();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: ScaffoldMessenger(
          key: _msg,
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
                      'Recordatorios',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: pf.text,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: async.when(
                    skipLoadingOnReload: true,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: TextButton(
                        onPressed: () =>
                            ref.invalidate(remindersControllerProvider(_key)),
                        child: const Text('No pudimos cargar. Reintentar'),
                      ),
                    ),
                    data: (items) => items.isEmpty
                        ? Center(
                            child: Text(
                              'Sin recordatorios pendientes',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: pf.text2,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) => _ReminderTile(
                              reminder: items[i],
                              now: now,
                              busy: _busyId == items[i].id,
                              onResolve: () => _resolve(items[i]),
                              onExtend: () => _showExtendOptions(items[i]),
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add_alert_outlined),
                      label: const Text('Nuevo recordatorio'),
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
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.reminder,
    required this.now,
    required this.busy,
    required this.onResolve,
    required this.onExtend,
  });

  final Reminder reminder;
  final DateTime now;
  final bool busy;
  final VoidCallback onResolve;
  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);
    final theme = Theme.of(context);
    final overdue = reminder.dueAt.isBefore(now);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 18,
                color: overdue ? const Color(0xFF9F1D1D) : pf.text2,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${reminderDueLabel(reminder.dueAt, now: now)}'
                  '${overdue ? ' · vencido' : ''}',
                  style: theme.textTheme.titleSmall?.copyWith(color: pf.text),
                ),
              ),
              if (reminder.isAutomatic)
                Chip(
                  label: const Text('Automático'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (reminder.comment != null) ...[
            const SizedBox(height: 4),
            Text(
              reminder.comment!,
              style: theme.textTheme.bodyMedium?.copyWith(color: pf.text2),
            ),
          ],
          const SizedBox(height: 6),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                TextButton.icon(
                  onPressed: onResolve,
                  icon: const Icon(Icons.check),
                  label: const Text('Resolver'),
                ),
                TextButton.icon(
                  onPressed: onExtend,
                  icon: const Icon(Icons.update),
                  label: const Text('Extender'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
