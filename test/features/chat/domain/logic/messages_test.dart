import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/data/mappers/chat_mapper.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/messages.dart';

import '../../_fixtures.dart';

void main() {
  final t0 = DateTime(2025, 1, 1, 10);
  DateTime at(int min) => t0.add(Duration(minutes: min));

  Message mm(
    String id,
    DateTime date, {
    String? messageId,
    String? websocketId,
    String? status,
  }) => Message(
    id: id,
    date: date,
    messageId: messageId,
    websocketId: websocketId,
    status: status,
  );

  group('mergeMessages', () {
    test(
      'mismo messageId con id distinto no duplica y conserva el id existente',
      () {
        final r = mergeMessages(
          [mm('t-1', at(1), messageId: 'm1')],
          [mm('real', at(1), messageId: 'm1')],
        );
        expect(r.map((m) => m.id), ['t-1']);
      },
    );
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

  group('ids de evento (sin id) y merge', () {
    test(
      'dos del evento con misma fecha y tipo y distinto message_id: ambos',
      () {
        final a = messageFromJson({
          'message_id': 'm1',
          'type': 'text',
          'date': '2025-01-01T10:00:00Z',
        })!;
        final b = messageFromJson({
          'message_id': 'm2',
          'type': 'text',
          'date': '2025-01-01T10:00:00Z',
        })!;
        expect(a.id, isNot(b.id));
        expect(applyNewMessages([a], [b])!.length, 2);
        expect(mergeMessages([a], [b]).length, 2);
      },
    );
    test('mismo id, distinto messageId: son mensajes distintos', () {
      final r = applyNewMessages(
        [mm('x', at(1), messageId: 'm1')],
        [mm('x', at(2), messageId: 'm2')],
      );
      expect(r!.length, 2);
    });
    test(
      'historial con mismo message_id reemplaza al parche sin cambiar su id',
      () {
        final patched = messageFromJson({
          'message_id': 'm1',
          'type': 'text',
          'date': '2025-01-01T10:00:00Z',
        })!;
        final r = mergeMessages(
          [patched],
          [mm('real', at(0), messageId: 'm1')],
        );
        expect(r.map((m) => m.id), [patched.id]);
      },
    );
    test('merge no retrocede el status al reemplazar', () {
      final r = mergeMessages(
        [mm('a', at(1), messageId: 'm1', status: 'read')],
        [mm('b', at(1), messageId: 'm1', status: 'sent')],
      );
      expect(r.single.status, 'read');
      expect(r.single.id, 'a');
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

  group('applyStatusUpdates por message_id', () {
    final hist = [mm('h1', at(1), messageId: 'm1', status: 'sent')];
    test('casa mensaje de historial (sin websocketId) por message_id', () {
      final r = applyStatusUpdates(hist, [
        {
          'id': null,
          'message_id': 'm1',
          'websocket_id': 'w9',
          'status': 'read',
        },
      ]);
      expect(r!.single.status, 'read');
    });
    test('no retrocede read -> delivered', () {
      final l = [mm('h1', at(1), messageId: 'm1', status: 'read')];
      expect(
        applyStatusUpdates(l, [
          {'message_id': 'm1', 'status': 'delivered'},
        ]),
        isNull,
      );
    });
    test('estados fuera de orden (removed) sí se aplican', () {
      final r = applyStatusUpdates(hist, [
        {'message_id': 'm1', 'status': 'removed'},
      ]);
      expect(r!.single.status, 'removed');
    });
  });

  group('applyNewMessages', () {
    final base = [
      mm('a', at(1), messageId: 'ma'),
      mm('c', at(3), messageId: 'mc', websocketId: 'wc', status: 'sent'),
    ];
    test('lista vacía de entrantes -> null', () {
      expect(applyNewMessages(base, []), isNull);
    });
    test('sobre lista vacía inserta', () {
      expect(
        applyNewMessages([], [mm('x', at(1), messageId: 'mx')])!.length,
        1,
      );
    });
    test('nuevo al final', () {
      final r = applyNewMessages(base, [mm('d', at(4), messageId: 'md')]);
      expect(r!.map((m) => m.id), ['a', 'c', 'd']);
    });
    test('nuevo intermedio por fecha', () {
      final r = applyNewMessages(base, [mm('b', at(2), messageId: 'mb')]);
      expect(r!.map((m) => m.id), ['a', 'b', 'c']);
    });
    test('no muta la original', () {
      applyNewMessages(base, [mm('d', at(4), messageId: 'md')]);
      expect(base, hasLength(2));
    });
    test('duplicado por messageId -> null', () {
      expect(
        applyNewMessages(base, [mm('otro', at(3), messageId: 'mc')]),
        isNull,
      );
    });
    test('duplicado por id -> null', () {
      expect(applyNewMessages(base, [mm('a', at(1))]), isNull);
    });
    test('duplicado por websocketId -> null', () {
      expect(
        applyNewMessages(base, [mm('z', at(3), websocketId: 'wc')]),
        isNull,
      );
    });
    test('existente avanza su status', () {
      final r = applyNewMessages(base, [
        mm('z', at(3), messageId: 'mc', status: 'delivered'),
      ]);
      expect(r!.last.status, 'delivered');
      expect(r, hasLength(2));
    });
    test('existente no retrocede su status', () {
      expect(
        applyNewMessages(base, [
          mm('z', at(3), messageId: 'mc', status: 'temp'),
        ]),
        isNull,
      );
    });
    test('dos nuevos en el mismo evento, uno repetido', () {
      final r = applyNewMessages(base, [
        mm('d', at(4), messageId: 'md'),
        mm('d2', at(4), messageId: 'md'),
      ]);
      expect(r!.map((m) => m.id), ['a', 'c', 'd']);
    });
  });

  group('applyMessageUpdates', () {
    test('reemplaza contenido conservando el id existente', () {
      final cur = [
        Message(
          id: 'local-1',
          messageId: 'w1',
          date: DateTime.utc(2025),
          type: 'image',
          mediaPending: true,
        ),
      ];
      final next = applyMessageUpdates(cur, [
        Message(
          id: 'srv-1',
          messageId: 'w1',
          date: DateTime.utc(2025),
          type: 'image',
          mediaUrl: 'http://x/y.jpg',
        ),
      ])!;
      expect(next.single.id, 'local-1');
      expect(next.single.mediaUrl, 'http://x/y.jpg');
      expect(next.single.mediaPending, isFalse);
    });

    test('no retrocede el status', () {
      final cur = [mm('a', at(0), messageId: 'w1', status: 'read')];
      final next = applyMessageUpdates(cur, [
        Message(
          id: 'a',
          messageId: 'w1',
          date: at(0),
          status: 'sent',
          mediaUrl: 'u',
        ),
      ])!;
      expect(next.single.status, 'read');
      expect(next.single.mediaUrl, 'u');
    });

    test('inserta ordenado si no existe', () {
      final cur = [
        mm('a', at(0), messageId: 'w1'),
        mm('c', at(10), messageId: 'w3'),
      ];
      final next = applyMessageUpdates(cur, [mm('b', at(5), messageId: 'w2')])!;
      expect(next.map((m) => m.messageId), ['w1', 'w2', 'w3']);
    });

    test('null si no cambia nada o no hay entrantes', () {
      final cur = [mm('a', at(0), messageId: 'w1', status: 'sent')];
      expect(
        applyMessageUpdates(cur, [
          mm('a', at(0), messageId: 'w1', status: 'sent'),
        ]),
        isNull,
      );
      expect(applyMessageUpdates(cur, const []), isNull);
    });
  });

  test('messageFromJson mapea media.pending', () {
    final p = messageFromJson({
      'message_id': 'w1',
      'type': 'image',
      'date': '2026-01-02T10:00:00Z',
      'media': {'id': 'm', 'mime': 'image/jpeg', 'pending': true},
    })!;
    expect(p.mediaPending, isTrue);
    expect(p.mediaUrl, isNull);
    final r = messageFromJson({
      'message_id': 'w1',
      'type': 'image',
      'date': '2026-01-02T10:00:00Z',
      'media': {'id': 'm', 'url': 'http://x', 'pending': false},
    })!;
    expect(r.mediaPending, isFalse);
    expect(r.mediaUrl, 'http://x');
  });

  group('carrera de media pendiente', () {
    Message img({
      String? url,
      bool pending = false,
      String? localPath,
      double? progress,
    }) => Message(
      id: 'a',
      messageId: 'w1',
      date: DateTime.utc(2025),
      type: 'image',
      mediaUrl: url,
      mediaFilename: url == null ? null : 'f.jpg',
      mediaPending: pending,
      localPath: localPath,
      uploadProgress: progress,
    );

    test('mergeMessages: respuesta vieja pending no pisa media resuelta', () {
      final r = mergeMessages(
        [img(url: 'http://x/f.jpg')],
        [img(pending: true)],
      ).single;
      expect(r.mediaUrl, 'http://x/f.jpg');
      expect(r.mediaFilename, 'f.jpg');
      expect(r.mediaPending, isFalse);
    });
    test('mergeMessages: pending sobre pending se mantiene', () {
      final r = mergeMessages(
        [img(pending: true)],
        [img(pending: true)],
      ).single;
      expect(r.mediaPending, isTrue);
    });
    test('mergeMessages: resuelta sobre pending aplica', () {
      final r = mergeMessages([img(pending: true)], [img(url: 'u')]).single;
      expect(r.mediaUrl, 'u');
      expect(r.mediaPending, isFalse);
    });
    test('applyMessageUpdates: update viejo pending no pisa resuelta', () {
      final r = applyMessageUpdates([img(url: 'u')], [img(pending: true)]);
      expect(r, isNull);
    });
    test('applyMessageUpdates conserva localPath y progreso locales', () {
      final r = applyMessageUpdates(
        [img(pending: true, localPath: '/tmp/a.jpg', progress: 0.5)],
        [img(url: 'u')],
      )!.single;
      expect(r.mediaUrl, 'u');
      expect(r.localPath, '/tmp/a.jpg');
      expect(r.uploadProgress, 0.5);
    });
  });
}
