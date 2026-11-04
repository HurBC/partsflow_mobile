import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';

String _frame(Map<String, dynamic> m) => jsonEncode(m);

void main() {
  group('parseRealtimeFrame', () {
    test('chat_list_new_message produce RealtimeNewMessages con los ítems', () {
      final e = parseRealtimeFrame(
        _frame({
          'type': 'chat_list_new_message',
          'new_messages_data': [
            {'phone': '56911111111', 'message': 'hola'},
            {'phone': '56922222222'},
          ],
        }),
      );
      expect(e, isA<RealtimeNewMessages>());
      final items = (e as RealtimeNewMessages).items;
      expect(items, hasLength(2));
      expect(items.first['message'], 'hola');
    });

    test('new_messages_data ausente da lista vacía', () {
      final e = parseRealtimeFrame(_frame({'type': 'chat_list_new_message'}));
      expect((e as RealtimeNewMessages).items, isEmpty);
    });

    test('descarta ítems que no son mapas', () {
      final e = parseRealtimeFrame(
        _frame({
          'type': 'chat_list_new_message',
          'new_messages_data': [
            1,
            'x',
            {'phone': '1'},
          ],
        }),
      );
      expect((e as RealtimeNewMessages).items, hasLength(1));
    });

    test('chat_list_message_status_update produce RealtimeStatusUpdates', () {
      final e = parseRealtimeFrame(
        _frame({
          'type': 'chat_list_message_status_update',
          'message_status_update_data': [
            {'websocket_id': 'w1', 'status': 'read'},
          ],
        }),
      );
      expect(e, isA<RealtimeStatusUpdates>());
      expect((e as RealtimeStatusUpdates).items.single['status'], 'read');
    });

    test('chat_list_message_update produce RealtimeMessageUpdates', () {
      final e = parseRealtimeFrame(
        _frame({
          'type': 'chat_list_message_update',
          'message_update_data': [
            {
              'message_id': 'm1',
              'update_reason': 'media_ready',
              'media': {'url': 'u', 'pending': false},
            },
          ],
          'whatsapp_provider': 'wali',
        }),
      );
      expect(e, isA<RealtimeMessageUpdates>());
      expect((e as RealtimeMessageUpdates).items.single['message_id'], 'm1');
    });

    test('los cuatro tipos client_* producen RealtimeClientChanged', () {
      for (final t in const [
        'client_updated',
        'client_tags_updated',
        'client_issues_updated',
        'client_general_attributes_updated',
      ]) {
        final e = parseRealtimeFrame(
          _frame({
            'type': t,
            'client_data': {'id': 5},
          }),
        );
        expect(e, isA<RealtimeClientChanged>(), reason: t);
        expect((e as RealtimeClientChanged).type, t);
        expect(e.data['id'], 5);
      }
    });

    test('client_updated sin client_data trae mapa vacío', () {
      final e = parseRealtimeFrame(_frame({'type': 'client_updated'}));
      expect((e as RealtimeClientChanged).data, isEmpty);
    });

    test('tipo desconocido devuelve null', () {
      expect(parseRealtimeFrame(_frame({'type': 'otra_cosa'})), isNull);
    });

    test('JSON sin type devuelve null', () {
      expect(parseRealtimeFrame(_frame({'foo': 1})), isNull);
    });

    test('texto que no es JSON devuelve null sin lanzar', () {
      expect(parseRealtimeFrame('no es json {'), isNull);
    });

    test('JSON que no es objeto devuelve null', () {
      expect(parseRealtimeFrame('[1,2,3]'), isNull);
    });

    test('frame que no es String (binario/null) devuelve null', () {
      expect(parseRealtimeFrame(null), isNull);
      expect(parseRealtimeFrame(<int>[1, 2]), isNull);
    });
  });

  group('phoneDigits', () {
    test('extrae solo dígitos y corta en @', () {
      expect(phoneDigits('56912345678@c.us'), '56912345678');
      expect(phoneDigits('+56 9 1234-5678'), '56912345678');
      expect(phoneDigits(null), '');
    });
  });

  group('phoneOfItem', () {
    test('usa phone cuando está', () {
      expect(phoneOfItem({'phone': '+56911111111'}), '56911111111');
    });

    test('usa chat.id cuando no hay phone', () {
      expect(
        phoneOfItem({
          'chat': {'id': '56922222222@c.us'},
        }),
        '56922222222',
      );
    });

    test('usa chat_id cuando no hay phone ni chat', () {
      expect(phoneOfItem({'chat_id': '56933333333@c.us'}), '56933333333');
    });

    test('devuelve null si no hay nada', () {
      expect(phoneOfItem({}), isNull);
      expect(phoneOfItem({'phone': '', 'chat': <String, dynamic>{}}), isNull);
    });

    test('chat.id tiene prioridad sobre phone (chats BSUID)', () {
      expect(
        phoneOfItem({
          'phone': '56911111111',
          'chat': {'id': '56999999999@c.us'},
        }),
        '56999999999',
      );
    });

    test('normalized_chat_id gana sobre phone', () {
      expect(
        phoneOfItem({
          'phone': '56911111111',
          'normalized_chat_id': '56955555555@c.us',
        }),
        '56955555555',
      );
    });

    test('salta claves cuyo valor no tiene dígitos', () {
      expect(
        phoneOfItem({'phone': 'abc', 'from': '56944444444@c.us'}),
        '56944444444',
      );
    });
  });
}
