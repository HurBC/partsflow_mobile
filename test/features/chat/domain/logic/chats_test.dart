import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/chats.dart';

import '../../_fixtures.dart';

void main() {
  realtimePatchTests();
  final now = DateTime(2025, 6, 1, 12);
  List<String> run(
    List<Chat> items, {
    ChatFilters filters = const ChatFilters(),
    bool threshold = false,
    int minutes = 30,
  }) => visibleChats(
    items: items,
    filters: filters,
    thresholdApplies: threshold,
    pendingThreshold: minutes,
    now: now,
  ).map((c) => c.id).toList();

  test('sin filtros ni umbral devuelve todo', () {
    expect(run([chat('a'), chat('b')]), ['a', 'b']);
  });
  test('filtro unread deja solo los no leídos', () {
    expect(
      run([
        chat('a', unreadCount: 2),
        chat('b'),
      ], filters: const ChatFilters(unread: true)),
      ['a'],
    );
  });
  test('filtro julia usa client.juliaOn', () {
    final on = chat('a', client: const ClientStub(auto: true).build());
    expect(run([on, chat('b')], filters: const ChatFilters(julia: true)), [
      'a',
    ]);
  });
  test('filtros combinados son AND', () {
    final a = chat(
      'a',
      unreadCount: 1,
      client: const ClientStub(auto: true).build(),
    );
    final b = chat('b', unreadCount: 1);
    expect(run([a, b], filters: const ChatFilters(unread: true, julia: true)), [
      'a',
    ]);
  });
  test('umbral oculta chats con actividad reciente', () {
    final recent = chat(
      'r',
      lastMessageAt: now.subtract(const Duration(minutes: 5)),
    );
    final old = chat(
      'o',
      lastMessageAt: now.subtract(const Duration(minutes: 90)),
    );
    expect(run([recent, old], threshold: true), ['o']);
  });
  test('umbral no aplicado muestra los recientes', () {
    final recent = chat(
      'r',
      lastMessageAt: now.subtract(const Duration(minutes: 5)),
    );
    expect(run([recent]), ['r']);
  });
  test('activityAt null no se oculta aunque el umbral aplique', () {
    expect(run([chat('n')], threshold: true), ['n']);
  });
  test('borde exacto del umbral (==) se oculta', () {
    final edge = chat(
      'e',
      lastMessageAt: now.subtract(const Duration(minutes: 30)),
    );
    // comportamiento actual: difference <= limit oculta, así que el borde exacto se oculta.
    expect(run([edge], threshold: true), isEmpty);
  });
  test('un segundo más allá del umbral se muestra', () {
    final past = chat(
      'p',
      lastMessageAt: now.subtract(const Duration(minutes: 30, seconds: 1)),
    );
    expect(run([past], threshold: true), ['p']);
  });
  test('activityAt cae a lastMessage.date', () {
    final c = chat(
      'l',
      lastMessage: ChatLastMessage(
        date: now.subtract(const Duration(minutes: 1)),
      ),
    );
    expect(run([c], threshold: true), isEmpty);
  });
  test('filtro y umbral se combinan', () {
    final a = chat(
      'a',
      unreadCount: 1,
      lastMessageAt: now.subtract(const Duration(hours: 5)),
    );
    final b = chat('b', unreadCount: 1, lastMessageAt: now);
    expect(
      run([a, b], filters: const ChatFilters(unread: true), threshold: true),
      ['a'],
    );
  });
}

class ClientStub {
  const ClientStub({required this.auto});
  final bool auto;
  ChatClient build() =>
      ChatClient(operationMode: auto ? 'automatic' : 'manual');
}

// ---- Parche de lista con eventos realtime ----
void realtimePatchTests() {
  final t0 = DateTime.utc(2026, 1, 1, 10);
  final t1 = DateTime.utc(2026, 1, 1, 11);
  const idA = '56911111111@c.us';
  const idB = '56922222222@c.us';

  Chat mk(
    String id, {
    DateTime? at,
    String? flow,
    String? mid,
    int unread = 0,
  }) => Chat(
    id: id,
    phone: id.split('@').first,
    lastMessageAt: at ?? t0,
    unreadCount: unread,
    lastMessage: ChatLastMessage(
      flow: flow ?? 'outbound',
      ack: 'sent',
      date: at ?? t0,
      messageId: mid,
    ),
    client: ChatClient(id: 'c-$id'),
  );

  Message? parse(Map<String, dynamic> m) => Message(
    id: m['message_id'] as String,
    messageId: m['message_id'] as String,
    date: DateTime.parse(m['date'] as String),
    flow: m['flow'] as String?,
    text: m['message'] as String?,
  );

  Map<String, dynamic> ev(String chatId, String mid, String flow, DateTime d) =>
      {
        'message_id': mid,
        'flow': flow,
        'message': 'x',
        'date': d.toIso8601String(),
        'chat': {'id': chatId},
      };

  ChatListPatch run(
    List<Chat> items,
    Map<String, dynamic> e, {
    String? open,
    ChatTab tab = ChatTab.all,
  }) => applyNewMessages(items, [e], parse: parse, isOpen: (id) => id == open, tab: tab);

  group('applyNewMessages', () {
    test('entrante a chat cerrado: sube al tope y unread+1', () {
      final p = run([
        mk(idB),
        mk(idA, flow: 'inbound'),
      ], ev(idA, 'm1', 'inbound', t1));
      expect(p.needsReload, isFalse);
      expect(p.items!.map((c) => c.id), [idA, idB]);
      expect(p.items!.first.unreadCount, 1);
      expect(p.items!.first.lastMessage!.messageId, 'm1');
    });
    test('chat abierto: sin unread', () {
      final p = run(
        [mk(idA, flow: 'inbound')],
        ev(idA, 'm1', 'inbound', t1),
        open: idA,
      );
      expect(p.items!.first.unreadCount, 0);
    });
    test('saliente: sin unread', () {
      final p = run([mk(idA)], ev(idA, 'm1', 'outbound', t1));
      expect(p.items!.first.unreadCount, 0);
      expect(p.needsReload, isFalse);
    });
    test('duplicado (mismo message_id): sin cambio', () {
      final p = run([mk(idA, mid: 'm1')], ev(idA, 'm1', 'inbound', t1));
      expect(p.items, isNull);
      expect(p.needsReload, isFalse);
    });
    test('más viejo que el último: sin cambio', () {
      final p = run([mk(idA, at: t1)], ev(idA, 'm0', 'inbound', t0));
      expect(p.items, isNull);
    });
    test('desconocido: needsReload', () {
      final p = run([mk(idA)], ev(idB, 'm1', 'inbound', t1));
      expect(p.needsReload, isTrue);
      expect(p.items, isNull);
    });
    test('identifica por teléfono', () {
      final p = run(
        [mk(idA)],
        {
          ...ev(idA, 'm1', 'outbound', t1)..remove('chat'),
          'phone': '+56911111111',
        },
      );
      expect(p.items, isNotNull);
    });
    test('Pendientes + saliente: parche y recarga', () {
      final p = run(
        [mk(idA)],
        ev(idA, 'm1', 'outbound', t1),
        tab: ChatTab.pending,
      );
      expect(p.items, isNotNull);
      expect(p.needsReload, isTrue);
    });
    test('Pendientes + entrante a chat ya pendiente: sin recarga', () {
      final p = run(
        [mk(idA, flow: 'inbound')],
        ev(idA, 'm1', 'inbound', t1),
        tab: ChatTab.pending,
      );
      expect(p.needsReload, isFalse);
    });
    test('Pendientes + entrante a chat no pendiente: recarga', () {
      final p = run(
        [mk(idA)],
        ev(idA, 'm1', 'inbound', t1),
        tab: ChatTab.pending,
      );
      expect(p.needsReload, isTrue);
    });
    test('Resueltos/Archivados + entrante: recarga; saliente no', () {
      for (final t in [ChatTab.resolved, ChatTab.archived]) {
        expect(run([mk(idA)], ev(idA, 'm1', 'inbound', t1), tab: t).needsReload,
            isTrue);
        expect(run([mk(idA)], ev(idA, 'm1', 'outbound', t1), tab: t).needsReload,
            isFalse);
      }
    });
    test('Todos/Asignados/Problemas + entrante: sin recarga', () {
      for (final t in [ChatTab.all, ChatTab.assigned, ChatTab.issues]) {
        expect(run([mk(idA)], ev(idA, 'm1', 'inbound', t1), tab: t).needsReload,
            isFalse);
      }
    });
    test('filtros avanzados o búsqueda: recarga', () {
      final p = applyNewMessages(
        [mk(idA)],
        [ev(idA, 'm1', 'outbound', t1)],
        parse: parse,
        isOpen: (_) => false,
        tab: ChatTab.all,
        advancedActive: true,
      );
      expect(p.needsReload, isTrue);
    });
  });

  group('applyStatusToChats', () {
    test('estado del último mensaje: actualiza ticks', () {
      final r = applyStatusToChats(
        [mk(idA, mid: 'm1')],
        [
          {'message_id': 'm1', 'status': 'read'},
        ],
      );
      expect(r!.first.lastMessage!.ack, 'read');
    });
    test('mensaje que no es el último: null', () {
      expect(
        applyStatusToChats(
          [mk(idA, mid: 'm1')],
          [
            {'message_id': 'otro', 'status': 'read'},
          ],
        ),
        isNull,
      );
    });
    test('no degrada ticks', () {
      expect(
        applyStatusToChats(
          [
            Chat(
              id: idA,
              phone: '1',
              lastMessage: const ChatLastMessage(ack: 'read', messageId: 'm1'),
            ),
          ],
          [
            {'message_id': 'm1', 'status': 'sent'},
          ],
        ),
        isNull,
      );
    });
  });

  group('applyClientChange', () {
    Map<String, dynamic> d(Map<String, dynamic> x) => {'id': 'c-$idA', ...x};
    test('modo de operación: parche sin recarga', () {
      final p = applyClientChange(
        [mk(idA)],
        'client_updated',
        d({'operation_mode': 'automatic'}),
        tab: ChatTab.all,
      );
      expect(p.items!.first.client!.operationMode, 'automatic');
      expect(p.items!.first.client!.juliaOn, isTrue);
      expect(p.needsReload, isFalse);
    });
    test('resuelto cambia: recarga', () {
      final p = applyClientChange(
        [mk(idA)],
        'client_updated',
        d({'is_chat_resolved': true}),
        tab: ChatTab.all,
      );
      expect(p.items!.first.client!.isChatResolved, isTrue);
      expect(p.needsReload, isTrue);
    });
    test('responsable en Asignados: recarga; en Todos no', () {
      final ev = d({'responsible_id': 'u1', 'responsible_first_name': 'Ana'});
      expect(
        applyClientChange(
          [mk(idA)],
          'client_updated',
          ev,
          tab: ChatTab.assigned,
        ).needsReload,
        isTrue,
      );
      final p = applyClientChange(
        [mk(idA)],
        'client_updated',
        ev,
        tab: ChatTab.all,
      );
      expect(p.needsReload, isFalse);
      expect(p.items!.first.client!.responsible!.firstName, 'Ana');
    });
    test('chat desconocido: nada', () {
      final p = applyClientChange(
        [mk(idB)],
        'client_updated',
        d({'is_chat_resolved': true}),
        tab: ChatTab.all,
      );
      expect(p.items, isNull);
      expect(p.needsReload, isFalse);
    });
    test('client_tags_updated de chat cargado: recarga', () {
      final p = applyClientChange(
        [mk(idA)],
        'client_tags_updated',
        d({}),
        tab: ChatTab.all,
      );
      expect(p.needsReload, isTrue);
    });
  });
}
