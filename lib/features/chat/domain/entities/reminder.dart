/// Recordatorio pendiente de un chat (`clients/reminder/`).
class Reminder {
  const Reminder({
    required this.id,
    required this.chatId,
    required this.dueAt,
    this.comment,
    this.type = 'custom',
    this.responsibleId,
    this.isAutomatic = false,
    this.isExtended = false,
  });

  final String id;
  final String chatId;

  /// Momento en que vence (`reminder_delta_time`, epoch ms).
  final DateTime dueAt;
  final String? comment;
  final String type;
  final String? responsibleId;

  /// Lo creó el sistema (sin responsable o tipo automático).
  final bool isAutomatic;
  final bool isExtended;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Reminder &&
          other.id == id &&
          other.chatId == chatId &&
          other.dueAt == dueAt &&
          other.comment == comment &&
          other.type == type &&
          other.responsibleId == responsibleId &&
          other.isAutomatic == isAutomatic &&
          other.isExtended == isExtended;

  @override
  int get hashCode => Object.hash(
    id,
    chatId,
    dueAt,
    comment,
    type,
    responsibleId,
    isAutomatic,
    isExtended,
  );
}
