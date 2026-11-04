import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/resync_coalescer.dart';

void main() {
  late DateTime t;
  late List<RealtimeEvent> out;
  late ResyncCoalescer c;

  setUp(() {
    t = DateTime(2026);
    out = [];
    c = ResyncCoalescer(sink: out.add, now: () => t);
  });

  test('2 Resync en 300 ms -> 1', () {
    c.add(const RealtimeResync());
    t = t.add(const Duration(milliseconds: 300));
    c.add(const RealtimeResync());
    expect(out.whereType<RealtimeResync>(), hasLength(1));
  });

  test('2 Resync separados por 6 s -> 2', () {
    c.add(const RealtimeResync());
    t = t.add(const Duration(seconds: 6));
    c.add(const RealtimeResync());
    expect(out.whereType<RealtimeResync>(), hasLength(2));
  });

  test('otros eventos pasan siempre', () {
    c.add(const RealtimeResync());
    c.add(const RealtimeNewMessages([]));
    c.add(const RealtimeNewMessages([]));
    expect(out.whereType<RealtimeNewMessages>(), hasLength(2));
  });
}
