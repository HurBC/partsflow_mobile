import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/messages.dart';

import '../../_fixtures.dart';

void main() {
  final t0 = DateTime(2025, 1, 1, 10);
  DateTime at(int min) => t0.add(Duration(minutes: min));

  group('mergeMessages', () {
    test('listas vacías devuelven lista vacía', () {
      expect(mergeMessages([], []), isEmpty);
    });
    test('une sin solapar y ordena por fecha ascendente', () {
      final r = mergeMessages(
        [msg('c', at(3)), msg('a', at(1))],
        [msg('b', at(2))],
      );
      expect(r.map((m) => m.id), ['a', 'b', 'c']);
    });
    test('b pisa a a cuando comparten id', () {
      final r = mergeMessages(
        [msg('a', at(1), text: 'viejo')],
        [msg('a', at(1), text: 'nuevo')],
      );
      expect(r, hasLength(1));
      expect(r.single.text, 'nuevo');
    });
    test('páginas solapadas no duplican', () {
      final p1 = [msg('1', at(1)), msg('2', at(2)), msg('3', at(3))];
      final p2 = [msg('3', at(3)), msg('4', at(4))];
      expect(mergeMessages(p1, p2).map((m) => m.id), ['1', '2', '3', '4']);
    });
    test('a vacía devuelve b ordenada', () {
      expect(
        mergeMessages([], [msg('b', at(2)), msg('a', at(1))]).map((m) => m.id),
        ['a', 'b'],
      );
    });
  });

  group('applyStatusUpdates', () {
    final base = [
      msg('1', at(1), status: 'sent', websocketId: 'w1'),
      msg('2', at(2), status: 'sent'),
    ];
    test('items vacíos devuelven null', () {
      expect(applyStatusUpdates(base, []), isNull);
    });
    test('items sin status devuelven null', () {
      expect(
        applyStatusUpdates(base, [
          {'websocket_id': 'w1'},
        ]),
        isNull,
      );
    });
    test('items sin id devuelven null', () {
      expect(
        applyStatusUpdates(base, [
          {'status': 'read'},
        ]),
        isNull,
      );
    });
    test('casa por websocket_id contra websocketId', () {
      final r = applyStatusUpdates(base, [
        {'websocket_id': 'w1', 'status': 'read'},
      ]);
      expect(r!.map((m) => m.status), ['read', 'sent']);
    });
    test('sin websocket_id usa id contra m.id', () {
      final r = applyStatusUpdates(base, [
        {'id': '2', 'status': 'delivered'},
      ]);
      expect(r!.map((m) => m.status), ['sent', 'delivered']);
    });
    test('id del item también casa contra websocketId del mensaje', () {
      final r = applyStatusUpdates(base, [
        {'id': 'w1', 'status': 'read'},
      ]);
      expect(r!.first.status, 'read');
    });
    test('mismo status devuelve null', () {
      expect(
        applyStatusUpdates(base, [
          {'websocket_id': 'w1', 'status': 'sent'},
        ]),
        isNull,
      );
    });
    test('devuelve lista nueva sin mutar la original', () {
      final r = applyStatusUpdates(base, [
        {'websocket_id': 'w1', 'status': 'read'},
      ]);
      expect(identical(r, base), isFalse);
      expect(base.first.status, 'sent');
    });
    test('ignora items inválidos y aplica los válidos', () {
      final r = applyStatusUpdates(base, [
        {'websocket_id': 'w1'},
        {'id': '2', 'status': 'read'},
      ]);
      expect(r!.map((m) => m.status), ['sent', 'read']);
    });
  });
}
