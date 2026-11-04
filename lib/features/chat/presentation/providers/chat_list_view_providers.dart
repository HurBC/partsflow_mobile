import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/chats.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';

/// Fuente de hora (inyectable en tests).
DateTime Function() chatNow = DateTime.now;

/// "Ahora" de la lista: lo avanza el reloj de 30 s de la página. Solo lo
/// observa [chatVisibleIdsProvider] cuando aplica el umbral de Pendientes.
class ChatClock extends Notifier<DateTime> {
  @override
  DateTime build() {
    // Se recalcula (now fresco) cada vez que el umbral pasa de aplicar o no.
    ref.watch(chatListControllerProvider.select((s) => s.thresholdApplies));
    return chatNow();
  }

  void tick([DateTime? now]) => state = now ?? chatNow();
}

final chatClockProvider = NotifierProvider<ChatClock, DateTime>(ChatClock.new);

/// Secuencia de ids visibles (con igualdad por valor: un tick o un parche que
/// no cambia qué chats se ven ni su orden no notifica).
class VisibleChatIds {
  const VisibleChatIds(this.ids);

  final List<String> ids;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibleChatIds &&
          const ListEquality<String>().equals(other.ids, ids);

  @override
  int get hashCode => const ListEquality<String>().hash(ids);
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

/// `visible` memoizado: se recalcula solo si cambian items, subfiltros, umbral
/// o (con umbral aplicable) el tick del reloj.
final chatVisibleIdsProvider = Provider<VisibleChatIds>((ref) {
  final v = ref.watch(
    chatListControllerProvider.select(
      (s) => (
        items: s.items,
        filters: s.filters,
        thresholdApplies: s.thresholdApplies,
        pendingThreshold: s.pendingThreshold,
      ),
    ),
  );
  final now = v.thresholdApplies ? ref.watch(chatClockProvider) : _epoch;
  final visible = visibleChats(
    items: v.items,
    filters: v.filters,
    thresholdApplies: v.thresholdApplies,
    pendingThreshold: v.pendingThreshold,
    now: now,
  );
  return VisibleChatIds([for (final c in visible) c.id]);
});

/// Mapa id -> Chat, recalculado una vez por cambio de items.
final chatsByIdProvider = Provider<Map<String, Chat>>((ref) {
  final items = ref.watch(chatListControllerProvider.select((s) => s.items));
  return {for (final c in items) c.id: c};
});

/// El chat con ese id en los items cargados; solo notifica si ese Chat cambia.
final chatByIdProvider = Provider.autoDispose.family<Chat?, String>(
  (ref, id) => ref.watch(chatsByIdProvider.select((m) => m[id])),
);
