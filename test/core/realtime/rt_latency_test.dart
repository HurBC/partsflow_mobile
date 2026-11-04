import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/realtime/rt_latency.dart';

void main() {
  test('full timing', () {
    final l = rtLatencyOf({
      'type': 'text',
      'timing': {'received_at': 900, 'published_at': 950},
    }, 1000)!;
    expect(l.type, 'text');
    expect(l.pubToClientMs, 50);
    expect(l.waliToClientMs, 100);
  });

  test('without received_at', () {
    final l = rtLatencyOf({
      'timing': {'received_at': null, 'published_at': 950},
    }, 1000)!;
    expect(l.type, '-');
    expect(l.waliToClientMs, isNull);
  });

  test('negative values are kept (clock skew)', () {
    final l = rtLatencyOf({
      'timing': {'published_at': 1200},
    }, 1000)!;
    expect(l.pubToClientMs, -200);
  });

  test('no timing / non numeric / not a map', () {
    expect(rtLatencyOf({'type': 'text'}, 1), isNull);
    expect(rtLatencyOf({'timing': 'x'}, 1), isNull);
    expect(
      rtLatencyOf({
        'timing': {'published_at': 'abc'},
      }, 1),
      isNull,
    );
    expect(
      rtLatencyOf({
        'timing': {'published_at': null},
      }, 1),
      isNull,
    );
    expect(rtLatencyOf('str', 1), isNull);
    expect(rtLatencyOf(null, 1), isNull);
    final l = rtLatencyOf({
      'timing': {'published_at': 10, 'received_at': 'bad'},
    }, 20)!;
    expect(l.waliToClientMs, isNull);
  });
}
