import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';

Chat _chat({
  int unread = 0,
  bool isUnread = false,
  String? flow,
  ChatClient? client,
}) => Chat(
  id: '1@c.us',
  phone: '1',
  unreadCount: unread,
  isUnread: isUnread,
  lastMessage: flow == null ? null : ChatLastMessage(flow: flow),
  client: client,
);

void main() {
  group('ChatFilters.matches', () {
    test('sin filtros activos acepta todo', () {
      expect(const ChatFilters().matches(_chat()), isTrue);
      expect(const ChatFilters().isActive, isFalse);
    });

    test('unread acepta unreadCount > 0 o isUnread', () {
      const f = ChatFilters(unread: true);
      expect(f.matches(_chat()), isFalse);
      expect(f.matches(_chat(unread: 2)), isTrue);
      expect(f.matches(_chat(isUnread: true)), isTrue);
    });

    test('unanswered exige último mensaje inbound', () {
      const f = ChatFilters(unanswered: true);
      expect(f.matches(_chat(flow: 'inbound')), isTrue);
      expect(f.matches(_chat(flow: 'outbound')), isFalse);
      expect(f.matches(_chat()), isFalse);
    });

    test('julia usa isAiActive y si es null operation_mode automatic', () {
      const f = ChatFilters(julia: true);
      expect(f.matches(_chat()), isFalse);
      expect(
        f.matches(_chat(client: const ChatClient(isAiActive: true))),
        isTrue,
      );
      expect(
        f.matches(_chat(client: const ChatClient(operationMode: 'automatic'))),
        isTrue,
      );
      expect(
        f.matches(
          _chat(
            client: const ChatClient(
              isAiActive: false,
              operationMode: 'automatic',
            ),
          ),
        ),
        isFalse,
      );
    });

    test('unassigned acepta sin cliente o sin responsable', () {
      const f = ChatFilters(unassigned: true);
      expect(f.matches(_chat()), isTrue);
      expect(f.matches(_chat(client: const ChatClient())), isTrue);
      expect(
        f.matches(
          _chat(
            client: const ChatClient(
              responsible: ChatResponsible(
                id: '1',
                firstName: 'A',
                lastName: 'B',
              ),
            ),
          ),
        ),
        isFalse,
      );
    });

    test('filtros combinados se aplican con AND', () {
      const f = ChatFilters(unread: true, unanswered: true);
      expect(f.matches(_chat(unread: 1, flow: 'inbound')), isTrue);
      expect(f.matches(_chat(unread: 1, flow: 'outbound')), isFalse);
      expect(f.matches(_chat(flow: 'inbound')), isFalse);
    });
  });

  group('AdvancedFilters ==', () {
    test('instancias con los mismos valores son iguales y mismo hashCode', () {
      const a = AdvancedFilters(channel: 'web', important: true);
      const b = AdvancedFilters(channel: 'web', important: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difiere si cambia cualquier campo', () {
      const base = AdvancedFilters();
      expect(base == const AdvancedFilters(channel: 'web'), isFalse);
      expect(base == const AdvancedFilters(tagId: '1'), isFalse);
      expect(base == const AdvancedFilters(status: 's'), isFalse);
      expect(base == const AdvancedFilters(issueType: 'i'), isFalse);
      expect(base == const AdvancedFilters(recurrent: true), isFalse);
      expect(base == const AdvancedFilters(important: true), isFalse);
      expect(base == const AdvancedFilters(hasIssues: true), isFalse);
      expect(base == const AdvancedFilters(noOrders: true), isFalse);
    });

    test('count, toParams y copyWith con clear', () {
      const a = AdvancedFilters(channel: 'web', recurrent: true);
      expect(a.count, 2);
      expect(a.toParams(), {
        'lead_generation_channel': 'web',
        'is_recurrent': 'true',
      });
      expect(a.copyWith(clearChannel: true).channel, isNull);
      // comportamiento actual: pasar null no limpia el campo.
      expect(a.copyWith(channel: null).channel, 'web');
    });
  });
}
