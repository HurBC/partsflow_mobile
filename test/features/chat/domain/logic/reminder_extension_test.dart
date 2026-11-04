import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/reminder_extension.dart';

void main() {
  final now = DateTime(2026, 3, 31, 22, 30);

  test('quick options: +1h, +3h, tomorrow 9:00 (month rollover)', () {
    final o = reminderExtensionOptions(now);
    expect(o.map((e) => e.label), ['+1 hora', '+3 horas', 'Mañana 9:00']);
    expect(o[0].until, DateTime(2026, 3, 31, 23, 30));
    expect(o[1].until, DateTime(2026, 4, 1, 1, 30));
    expect(o[2].until, DateTime(2026, 4, 1, 9));
  });

  test('minutesUntil rounds up and rejects past', () {
    expect(minutesUntil(now, now.add(const Duration(seconds: 61))), 2);
    expect(minutesUntil(now, now.add(const Duration(hours: 1))), 60);
    expect(minutesUntil(now, now), isNull);
    expect(minutesUntil(now, now.subtract(const Duration(minutes: 1))), isNull);
  });
}
