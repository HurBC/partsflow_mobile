/// Mensaje de sistema local (p. ej. cambios de Julia).
class ThreadNote {
  const ThreadNote(this.date, this.text);
  final DateTime date;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThreadNote && other.date == date && other.text == text;

  @override
  int get hashCode => Object.hashAll([date, text]);
}
