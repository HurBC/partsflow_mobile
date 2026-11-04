import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/presentation/providers/orders_providers.dart';

Chat mk({int unread = 0, List<ChatTag>? tags, String? body}) => Chat(
  id: 'c1',
  phone: '1',
  unreadCount: unread,
  lastMessage: ChatLastMessage(body: body, date: DateTime(2026, 1, 1)),
  client: ChatClient(
    id: 'k',
    tags: tags ?? [const ChatTag(name: 'a')],
  ),
);

Message mm({String? text, List<ContactCard>? contacts}) => Message(
  id: 'm1',
  date: DateTime(2026, 1, 1),
  text: text,
  contacts:
      contacts ??
      [
        const ContactCard(name: 'x', phones: ['1']),
      ],
);

OrderSummary mo({int? ticket, List<OrderProduct>? products}) => OrderSummary(
  id: 1,
  ticket: ticket,
  products: products ?? [const OrderProduct(name: 'p')],
);

void main() {
  test('Chat: copia idéntica, campo distinto, listas anidadas', () {
    expect(mk(), mk());
    expect(mk().hashCode, mk().hashCode);
    expect(mk(), isNot(mk(unread: 1)));
    expect(mk(), isNot(mk(body: 'x')));
    expect(mk(), isNot(mk(tags: [const ChatTag(name: 'b')])));
    expect(mk(), mk().copyWith());
  });

  test('Message: igualdad por valor', () {
    expect(mm(text: 'a'), mm(text: 'a'));
    expect(mm(text: 'a').hashCode, mm(text: 'a').hashCode);
    expect(mm(text: 'a'), isNot(mm(text: 'b')));
    expect(mm(), isNot(mm(contacts: [const ContactCard(name: 'y')])));
  });

  test('OrderSummary: igualdad por valor', () {
    expect(mo(ticket: 5), mo(ticket: 5));
    expect(mo(ticket: 5).hashCode, mo(ticket: 5).hashCode);
    expect(mo(ticket: 5), isNot(mo(ticket: 6)));
    expect(mo(), isNot(mo(products: [const OrderProduct(name: 'q')])));
  });

  test('estados: iguales con listas distintas instancias', () {
    expect(ChatListState(items: [mk()]), ChatListState(items: [mk()]));
    expect(
      ChatListState(items: [mk()]),
      isNot(ChatListState(items: [mk(unread: 1)])),
    );
    expect(OrdersListState(items: [mo()]), OrdersListState(items: [mo()]));
    expect(OrdersListState(items: [mo()]), isNot(const OrdersListState()));
  });
}
