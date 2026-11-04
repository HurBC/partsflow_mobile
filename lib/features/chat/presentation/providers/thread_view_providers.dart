import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_key.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/timeline.dart';

/// Entradas de las que depende la timeline del hilo (igualdad por valor).
class ThreadTimelineInput {
  const ThreadTimelineInput({
    required this.messages,
    required this.pending,
    required this.notes,
    required this.historyLoaded,
  });

  final List<Message> messages;
  final List<Message> pending;
  final List<ThreadNote> notes;
  final bool historyLoaded;

  static const _eq = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadTimelineInput &&
          other.historyLoaded == historyLoaded &&
          _eq.equals(other.messages, messages) &&
          _eq.equals(other.pending, pending) &&
          _eq.equals(other.notes, notes);

  @override
  int get hashCode => Object.hash(
    historyLoaded,
    _eq.hash(messages),
    _eq.hash(pending),
    _eq.hash(notes),
  );
}

/// Solo emite cuando cambian mensajes/pendientes/notas/historyLoaded (no con
/// loadingOlder, replyTo, status de carga, etc.).
final threadTimelineInputProvider = Provider.autoDispose
    .family<ThreadTimelineInput, ChatKey>((ref, key) {
      final s = ref.watch(
        chatThreadProvider(key).select(
          (s) => ThreadTimelineInput(
            messages: s.messages,
            pending: s.pending,
            notes: s.notes,
            historyLoaded: s.historyLoaded,
          ),
        ),
      );
      return s;
    });

/// Timeline memoizada: se recalcula solo si cambia [ThreadTimelineInput].
final threadTimelineProvider = Provider.autoDispose
    .family<List<TimelineEntry>, ChatKey>((ref, key) {
      final i = ref.watch(threadTimelineInputProvider(key));
      return buildTimeline(i.messages, i.pending, i.notes);
    });
