import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/thread_note.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/day_utils.dart';

sealed class TimelineEntry {
  const TimelineEntry();
}

class DayEntry extends TimelineEntry {
  const DayEntry(this.date);
  final DateTime date;
}

class MsgEntry extends TimelineEntry {
  const MsgEntry(this.message);
  final Message message;
}

class NoteEntry extends TimelineEntry {
  const NoteEntry(this.note);
  final ThreadNote note;
}

/// Tipo de animación de entrada de un mensaje nuevo.
enum EntranceKind { own, incoming }

typedef LocalSig = ({String sig, DateTime at});

String messageSig(Message m) => '${m.hasMedia}|${(m.text ?? '').trim()}';

/// Resultado de [classifyMessages].
typedef ClassifyResult = ({
  bool baselined,
  DateTime? newest,
  Map<String, EntranceKind> entered,
});

/// Detecta mensajes que aparecen después de cargado el hilo. Nuevo =
/// id desconocido y (local, o más reciente que todo lo conocido): así las
/// páginas antiguas nunca cuentan. Un mensaje del servidor que confirma uno
/// local (misma firma) no se anima otra vez.
///
/// Muta [known] y [localSigs] (estado acumulado del llamador); devuelve el
/// nuevo `baselined`/`newest` y las entradas a animar (id -> tipo).
ClassifyResult classifyMessages({
  required List<Message> all,
  required bool baselined,
  required Set<String> known,
  required List<LocalSig> localSigs,
  required DateTime? newest,
  required DateTime now,
}) {
  final entered = <String, EntranceKind>{};
  localSigs.removeWhere(
    (e) => now.difference(e.at) > const Duration(minutes: 2),
  );
  if (!baselined) {
    for (final m in all) {
      known.add(m.id);
      if (newest == null || m.date.isAfter(newest)) newest = m.date;
    }
    return (baselined: true, newest: newest, entered: entered);
  }
  final base = newest;
  for (final m in all) {
    if (!known.add(m.id)) continue;
    if (m.isLocal) {
      localSigs.add((sig: messageSig(m), at: now));
      entered[m.id] = EntranceKind.own;
      continue;
    }
    if (base != null && !m.date.isAfter(base)) continue;
    if (m.isOutbound) {
      var i = localSigs.indexWhere((e) => e.sig == messageSig(m));
      // Media: el tipo/leyenda local puede diferir del confirmado.
      if (i < 0 && m.hasMedia) {
        i = localSigs.indexWhere((e) => e.sig.startsWith('true|'));
      }
      if (i >= 0) {
        localSigs.removeAt(i);
        continue;
      }
    }
    entered[m.id] = EntranceKind.incoming;
  }
  for (final m in all) {
    if (newest == null || m.date.isAfter(newest)) newest = m.date;
  }
  return (baselined: true, newest: newest, entered: entered);
}

/// Entradas del hilo, de la más nueva a la más antigua (lista invertida), con
/// separadores de día.
List<TimelineEntry> buildTimeline(
  List<Message> messages,
  List<Message> pending,
  List<ThreadNote> notes,
) {
  final all = <({DateTime date, TimelineEntry entry})>[
    for (final m in messages) (date: m.date, entry: MsgEntry(m)),
    for (final m in pending) (date: m.date, entry: MsgEntry(m)),
    for (final n in notes) (date: n.date, entry: NoteEntry(n)),
  ]..sort((a, b) => a.date.compareTo(b.date));

  final asc = <TimelineEntry>[];
  DateTime? lastDay;
  for (final e in all) {
    if (lastDay == null || !sameDay(lastDay, e.date)) {
      asc.add(DayEntry(e.date));
      lastDay = e.date;
    }
    asc.add(e.entry);
  }
  return asc.reversed.toList();
}

/// ¿El mensaje de `entries[j]` es del mismo remitente que [m] y ≤ 2 min de
/// distancia, sin separador de día ni nota entre medio?
bool messagesJoined(
  List<TimelineEntry> entries,
  int j,
  Message m,
  String? myId,
) {
  if (j < 0 || j >= entries.length) return false;
  final o = entries[j];
  if (o is! MsgEntry) return false;
  final other = o.message;
  if (other.isDeleted != m.isDeleted) return false;
  final a = m.author(myId);
  if (a != other.author(myId)) return false;
  if (a != MessageAuthor.client &&
      (m.senderName ?? m.agent) != (other.senderName ?? other.agent)) {
    return false;
  }
  return m.date.difference(other.date).abs() <= const Duration(minutes: 2);
}
