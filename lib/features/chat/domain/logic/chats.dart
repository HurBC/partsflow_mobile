import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';

/// Filtra [items] en el dispositivo: subfiltros (si están activos) y umbral de
/// Pendientes (oculta chats con actividad dentro de [pendingThreshold] minutos).
List<Chat> visibleChats({
  required List<Chat> items,
  required ChatFilters filters,
  required bool thresholdApplies,
  required int pendingThreshold,
  required DateTime now,
}) {
  final limit = Duration(minutes: pendingThreshold);
  return items.where((c) {
    if (filters.isActive && !filters.matches(c)) return false;
    if (thresholdApplies) {
      final at = c.activityAt;
      if (at != null && now.difference(at) <= limit) return false;
    }
    return true;
  }).toList();
}
