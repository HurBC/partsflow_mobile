import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_key.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/reminder.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/reminder_extension.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/client_extras_sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reminders_controller.g.dart';

/// Reloj inyectable (tests lo sobreescriben).
@Riverpod(keepAlive: true)
DateTime Function() reminderClock(Ref ref) => DateTime.now;

/// Recordatorios pendientes de un chat. Si la carga falla, el estado es error
/// (la UI reintenta con `ref.invalidate`); si una acción falla, la lista queda
/// sin cambios y la acción devuelve false.
@riverpod
class RemindersController extends _$RemindersController {
  @override
  Future<List<Reminder>> build(ChatKey chatKey) async {
    final r = await ref
        .read(chatRepositoryProvider)
        .pendingReminders(chatKey.id);
    return switch (r) {
      Ok(:final value) => value,
      Err() => throw StateError('reminders'),
    };
  }

  Future<bool> resolve(Reminder reminder) async {
    final r = await ref
        .read(chatRepositoryProvider)
        .resolveReminder(reminder.id);
    if (r is! Ok<bool>) return false;
    _remove(reminder);
    return true;
  }

  /// Reprograma [reminder] a [until]; false si ya pasó o falla la red.
  Future<bool> extend(Reminder reminder, DateTime until) async {
    final minutes = minutesUntil(ref.read(reminderClockProvider)(), until);
    if (minutes == null) return false;
    final me = await ref.read(apiUserProvider.future);
    final userId = reminder.responsibleId ?? me?.id;
    if (userId == null) return false;
    final r = await ref
        .read(chatRepositoryProvider)
        .extendReminder(reminder: reminder, userId: userId, minutes: minutes);
    if (r is! Ok<bool>) return false;
    final current = state.value ?? const <Reminder>[];
    final updated = Reminder(
      id: reminder.id,
      chatId: reminder.chatId,
      dueAt: until,
      comment: reminder.comment,
      type: reminder.type,
      responsibleId: reminder.responsibleId,
      isAutomatic: reminder.isAutomatic,
      isExtended: true,
    );
    state = AsyncData(
      [
        for (final c in current)
          if (c.id == reminder.id) updated else c,
      ]..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
    );
    // El servidor reemplaza el recordatorio (nuevo id): recarga en silencio.
    ref.invalidateSelf();
    return true;
  }

  void _remove(Reminder reminder) {
    final next = [
      for (final c in state.value ?? const <Reminder>[])
        if (c.id != reminder.id) c,
    ];
    state = AsyncData(next);
    if (next.isEmpty) {
      applyClientExtrasFromRef(ref, chatKey.initial, hasPendingReminder: false);
    }
  }
}
