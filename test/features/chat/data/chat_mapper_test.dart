import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/data/mappers/chat_mapper.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';

void main() {
  group('chatFromJson', () {
    test('mapea un chat completo', () {
      final c = chatFromJson({
        'id': '+56912345678@c.us',
        'name': 'Juan',
        'contact': {
          'displayName': 'Juan P',
          'image': {'url': 'http://img'},
        },
        'lastMessageAt': 1700000000,
        'lastMessage': {
          'flow': 'inbound',
          'ack': 'read',
          'type': 'text',
          'body': 'hola',
          'date': 1700000000,
        },
        'meta': {'unreadCount': '3', 'isUnread': true},
        'client': {
          'id': 9,
          'name': 'Juan',
          'is_ai_active': true,
          'responsible': {'id': 1, 'first_name': 'Ana', 'last_name': 'Paz'},
          'tags': [
            {'name': 'vip', 'color': '#fff'},
            {'name': ''},
          ],
          'issues': [1, 2],
          'has_pending_reminder': true,
        },
      })!;
      expect(c.phone, '56912345678');
      expect(c.contactName, 'Juan P');
      expect(c.imageUrl, 'http://img');
      expect(c.unreadCount, 3);
      expect(c.isUnread, isTrue);
      expect(c.lastMessage!.isInbound, isTrue);
      expect(c.client!.juliaOn, isTrue);
      expect(c.client!.responsible!.firstName, 'Ana');
      expect(c.client!.tags, hasLength(1));
      expect(c.client!.issuesCount, 2);
      expect(c.hasPendingReminder, isTrue);
    });

    test('devuelve null sin id, con id vacío o con entrada no mapa', () {
      expect(chatFromJson({'name': 'x'}), isNull);
      expect(chatFromJson({'id': '  '}), isNull);
      expect(chatFromJson('texto'), isNull);
      expect(chatFromJson(null), isNull);
    });

    test('chat mínimo usa valores por defecto', () {
      final c = chatFromJson({'id': '569@c.us'})!;
      expect(c.unreadCount, 0);
      expect(c.isUnread, isFalse);
      expect(c.client, isNull);
      expect(c.lastMessage, isNull);
      expect(c.hasPendingReminder, isFalse);
    });

    test('has_pending_reminder cae al nivel raíz si el cliente no lo trae', () {
      final c = chatFromJson({
        'id': '569@c.us',
        'client': {'id': 1},
        'has_pending_reminder': true,
      })!;
      expect(c.hasPendingReminder, isTrue);
    });

    test('responsible sin id se ignora', () {
      final c = chatFromJson({
        'id': '569@c.us',
        'client': {
          'responsible': {'first_name': 'X'},
        },
      })!;
      expect(c.client!.responsible, isNull);
    });
  });

  group('messageFromJson', () {
    final base = {'date': '2024-01-01T10:00:00Z'};

    test('mensaje de texto inbound con id y message_id/websocket_id', () {
      final m = messageFromJson({
        ...base,
        'id': 'a1',
        'message_id': 'wamid.X',
        'websocket_id': 'ws1',
        'flow': 'inbound',
        'message': 'hola',
        'status': 'delivered',
      })!;
      expect(m.id, 'a1');
      expect(m.messageId, 'wamid.X');
      expect(m.websocketId, 'ws1');
      expect(m.isInbound, isTrue);
      expect(m.text, 'hola');
      expect(m.type, 'text');
    });

    test('flow outbound', () {
      final m = messageFromJson({...base, 'flow': 'outbound'})!;
      expect(m.isOutbound, isTrue);
      expect(m.isInbound, isFalse);
    });

    test('sin id genera uno a partir de la fecha y el tipo', () {
      final m = messageFromJson({...base, 'type': 'image'})!;
      expect(m.id, endsWith('-image'));
    });

    test('devuelve null sin fecha válida', () {
      expect(messageFromJson({'message': 'x'}), isNull);
      expect(messageFromJson({'date': 'basura'}), isNull);
    });

    test('descarta type action y unknown de system/mobile', () {
      expect(messageFromJson({...base, 'type': 'action'}), isNull);
      expect(
        messageFromJson({...base, 'type': 'unknown', 'source': 'system'}),
        isNull,
      );
      expect(
        messageFromJson({...base, 'type': 'unknown', 'source': 'mobile'}),
        isNull,
      );
      expect(
        messageFromJson({...base, 'type': 'unknown', 'source': 'x'}),
        isNotNull,
      );
    });

    test('media como string es la url', () {
      final m = messageFromJson({...base, 'media': 'http://f/x.jpg'})!;
      expect(m.mediaUrl, 'http://f/x.jpg');
      expect(m.mediaFilename, isNull);
    });

    test(
      'media como mapa llena url, filename, id, mime y caption como texto',
      () {
        final m = messageFromJson({
          ...base,
          'type': 'document',
          'media': {
            'url': 'http://f/d.pdf',
            'filename': 'd.pdf',
            'caption': 'mira',
            'id': 'm1',
            'mime': 'application/pdf',
          },
        })!;
        expect(m.mediaUrl, 'http://f/d.pdf');
        expect(m.mediaFilename, 'd.pdf');
        expect(m.mediaId, 'm1');
        expect(m.mediaMime, 'application/pdf');
        expect(m.text, 'mira');
      },
    );

    test('quoted se mapea', () {
      final m = messageFromJson({
        ...base,
        'quoted': {
          'body': 'orig',
          'fromName': 'Ana',
          'wid': 'w1',
          'type': 'text',
        },
      })!;
      expect(m.quotedBody, 'orig');
      expect(m.quotedFrom, 'Ana');
      expect(m.quotedWid, 'w1');
      expect(m.quotedType, 'text');
    });

    test('is_edited o status edited marca isEdited', () {
      expect(messageFromJson({...base, 'is_edited': true})!.isEdited, isTrue);
      expect(messageFromJson({...base, 'status': 'edited'})!.isEdited, isTrue);
      expect(messageFromJson(base)!.isEdited, isFalse);
    });

    test('ubicación y contactos', () {
      final m = messageFromJson({
        ...base,
        'location': {
          'location_name': 'Taller',
          'latitude': '-33.4',
          'longitude': -70.6,
        },
        'contacts': [
          {
            'name': 'Pedro',
            'phones': [
              {'phone': '+5691'},
              '+5692',
            ],
          },
          {'name': ''},
        ],
      })!;
      expect(m.locationLabel, 'Taller');
      expect(m.latitude, -33.4);
      expect(m.longitude, -70.6);
      expect(m.contactNames, ['Pedro']);
      expect(m.contacts.single.phones, ['+5691', '+5692']);
    });

    test('campos nulos o de tipo raro no lanzan', () {
      final m = messageFromJson({
        ...base,
        'message': null,
        'media': 5,
        'quoted': 'x',
        'error_code': 'abc',
      })!;
      expect(m.text, isNull);
      expect(m.mediaUrl, isNull);
      expect(m.errorCode, isNull);
    });
  });

  group('orderStripFromJson', () {
    test('lista con id y status conocido', () {
      final s = orderStripFromJson([
        {'id': 7, 'status': 'waiting_payment'},
      ]);
      expect(s!.id, '7');
      expect(
        s.stage,
        OrderStage.fromStatus('waiting_payment') ?? OrderStage.porCotizar,
      );
    });

    test('formato {results: []}', () {
      expect(
        orderStripFromJson({
          'results': [
            {'order_id': 'A1'},
          ],
        })!.id,
        'A1',
      );
    });

    test('mapa de columnas con listas', () {
      expect(
        orderStripFromJson({
          'col1': [],
          'col2': [
            {'id': 3},
          ],
        })!.id,
        '3',
      );
    });

    test('status desconocido cae en porCotizar', () {
      expect(
        orderStripFromJson([
          {'id': 1, 'status': 'zzz'},
        ])!.stage,
        OrderStage.porCotizar,
      );
    });

    test('vacío, sin id o no soportado devuelve null', () {
      expect(orderStripFromJson([]), isNull);
      expect(
        orderStripFromJson([
          {'status': 'x'},
        ]),
        isNull,
      );
      expect(orderStripFromJson(null), isNull);
      expect(orderStripFromJson('x'), isNull);
    });
  });

  group('messageFromJson envio', () {
    Map<String, dynamic> base(Map<String, dynamic> x) => {
      'id': 'oid1',
      'message_id': 'wamid1',
      'type': 'text',
      'flow': 'outbound',
      'message': 'hola',
      'date': '2026-01-02T10:00:00Z',
      ...x,
    };
    test('status vacio se deriva de status_code', () {
      for (final (code, st) in [
        (1, 'pending'),
        (2, 'sent'),
        (3, 'delivered'),
        (4, 'read'),
        (5, 'error'),
      ]) {
        expect(
          messageFromJson(base({'status': '', 'status_code': code}))!.status,
          st,
        );
      }
      expect(
        messageFromJson(base({'status': 'read', 'status_code': 1}))!.status,
        'read',
      );
    });
    test('websocket_id local da la misma id que el pendiente', () {
      final m = messageFromJson(base({'websocket_id': 'local-12-3'}))!;
      expect(m.id, 'local-12-3');
      expect(m.websocketId, 'local-12-3');
      expect(messageFromJson(base({'websocket_id': 'abc'}))!.id, 'oid1');
    });
  });
}
