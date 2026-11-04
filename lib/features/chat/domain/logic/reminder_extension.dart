/// Opción rápida para extender un recordatorio.
class ReminderExtensionOption {
  const ReminderExtensionOption(this.label, this.until);

  final String label;
  final DateTime until;

  @override
  bool operator ==(Object other) =>
      other is ReminderExtensionOption &&
      other.label == label &&
      other.until == until;

  @override
  int get hashCode => Object.hash(label, until);
}

/// +1 h, +3 h y mañana 9:00 (hora local) a partir de [now] (inyectable).
List<ReminderExtensionOption> reminderExtensionOptions(DateTime now) => [
  ReminderExtensionOption('+1 hora', now.add(const Duration(hours: 1))),
  ReminderExtensionOption('+3 horas', now.add(const Duration(hours: 3))),
  ReminderExtensionOption(
    'Mañana 9:00',
    DateTime(now.year, now.month, now.day + 1, 9),
  ),
];

/// Minutos (≥ 1, redondeados hacia arriba) desde [now] hasta [until]; null si
/// [until] no es futuro.
int? minutesUntil(DateTime now, DateTime until) {
  final ms = until.difference(now).inMilliseconds;
  if (ms <= 0) return null;
  return (ms / 60000).ceil();
}
