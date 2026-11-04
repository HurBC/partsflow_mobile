import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/day_utils.dart';

void main() {
  test('dateOnly descarta la hora', () {
    expect(dateOnly(DateTime(2025, 3, 4, 15, 30, 10, 5)), DateTime(2025, 3, 4));
  });
  test('dateOnly en medianoche exacta es idempotente', () {
    expect(dateOnly(DateTime(2025, 3, 4)), DateTime(2025, 3, 4));
  });
  test('sameDay true con distinta hora', () {
    expect(
      sameDay(DateTime(2025, 3, 4, 0, 0), DateTime(2025, 3, 4, 23, 59, 59)),
      isTrue,
    );
  });
  test('sameDay false cruzando la medianoche', () {
    expect(
      sameDay(DateTime(2025, 3, 4, 23, 59, 59), DateTime(2025, 3, 5, 0, 0)),
      isFalse,
    );
  });
  test('sameDay false con mismo día de otro mes/año', () {
    expect(sameDay(DateTime(2025, 3, 4), DateTime(2025, 4, 4)), isFalse);
    expect(sameDay(DateTime(2025, 3, 4), DateTime(2026, 3, 4)), isFalse);
  });
}
