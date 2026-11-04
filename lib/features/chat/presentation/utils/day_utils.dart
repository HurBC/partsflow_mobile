/// Fecha sin hora (medianoche local).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) => dateOnly(a) == dateOnly(b);
