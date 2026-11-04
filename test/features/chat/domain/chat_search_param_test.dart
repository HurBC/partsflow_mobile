import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';

void main() {
  group('chatSearchParam', () {
    test('sin texto no hay param', () {
      expect(chatSearchParam(SearchMode.all, '  '), isNull);
      expect(chatSearchParam(SearchMode.orderId, ''), isNull);
    });

    test('modo Todo envía el texto; los demás, prefijo,texto', () {
      expect(chatSearchParam(SearchMode.all, ' juan '), 'juan');
      expect(chatSearchParam(SearchMode.client, 'juan'), 'client_name:,juan');
      expect(chatSearchParam(SearchMode.phone, '569'), 'client_phone:,569');
    });

    test('prefijos de pedido igual que el BO', () {
      expect(SearchMode.orderId.prefix, 'order_id:');
      expect(SearchMode.orderNote.prefix, 'order_note:');
      expect(
        chatSearchParam(SearchMode.orderNote, 'urgente retiro'),
        'order_note:,urgente retiro',
      );
      expect(chatSearchParam(SearchMode.orderId, '1234'), 'order_id:,1234');
    });

    test('order_id conserva solo los números', () {
      expect(chatSearchParam(SearchMode.orderId, '#1234'), 'order_id:,1234');
      expect(
        chatSearchParam(SearchMode.orderId, '12, 34 56'),
        'order_id:,12,34,56',
      );
      expect(chatSearchParam(SearchMode.orderId, 'abc'), isNull);
      expect(isInvalidOrderIdSearch(SearchMode.orderId, 'abc'), isTrue);
      expect(isInvalidOrderIdSearch(SearchMode.orderId, '12'), isFalse);
      expect(isInvalidOrderIdSearch(SearchMode.client, 'abc'), isFalse);
    });
  });
}
