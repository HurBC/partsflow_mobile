import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/open_chat_provider.dart';

class _Repo implements ChatRepository {
  int searchCalls = 0;
  Completer<void>? gate;
  final List<Chat> chats = [
    Chat(
      id: '56911111111@c.us',
      phone: '56911111111',
      lastMessageAt: DateTime.utc(2026, 1, 1, 9),
      lastMessage: ChatLastMessage(
        flow: 'inbound',
        date: DateTime.utc(2026, 1, 1, 9),
      ),
    ),
    Chat(
      id: '56922222222@c.us',
      phone: '56922222222',
      lastMessageAt: DateTime.utc(2026, 1, 1, 8),
      lastMessage: ChatLastMessage(
        flow: 'inbound',
        date: DateTime.utc(2026, 1, 1, 8),
      ),
    ),
  ];

  @override
  Future<Result<ChatPage>> searchChats(ChatQuery query) async {
    searchCalls++;
    final g = gate;
    if (g != null) {
      final snapshot = [...chats];
      await g.future;
      return Result.ok(ChatPage(chats: snapshot, hasMore: false));
    }
    return Result.ok(ChatPage(chats: chats, hasMore: false));
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeRealtime extends Realtime {
  static final ctrl = StreamController<RealtimeEvent>.broadcast();
  @override
  Stream<RealtimeEvent> get events => ctrl.stream;
  @override
  bool build() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repo repo;
  late ProviderContainer c;

  Future<void> settle([int ms = 0]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo();
    c = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        realtimeProvider.overrideWith(_FakeRealtime.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(chatListControllerProvider, (_, _) {});
    await settle(20);
    expect(repo.searchCalls, 1);
  });

  test('mensaje de chat conocido: parche local sin requests', () async {
    c.read(openChatRegistryProvider).open('56922222222@c.us');
    _FakeRealtime.ctrl.add(
      RealtimeNewMessages([
        {
          'message': 'hola',
          'type': 'text',
          'flow': 'inbound',
          'message_id': 'm9',
          'date': '2026-01-01T10:00:00Z',
          'chat': {'id': '56922222222@c.us'},
        },
      ]),
    );
    await settle(50);
    final items = c.read(chatListControllerProvider).items;
    expect(items.first.id, '56922222222@c.us');
    expect(items.first.lastMessage!.body, 'hola');
    expect(items.first.unreadCount, 0); // chat abierto
    expect(repo.searchCalls, 1);
  });

  test('chat desconocido: una recarga coalescida', () async {
    final e = RealtimeNewMessages([
      {
        'message': 'hola',
        'type': 'text',
        'flow': 'inbound',
        'message_id': 'm9',
        'date': '2026-01-01T10:00:00Z',
        'chat': {'id': '56933333333@c.us'},
      },
    ]);
    _FakeRealtime.ctrl.add(e);
    _FakeRealtime.ctrl.add(e);
    await settle(50);
    expect(repo.searchCalls, 1); // dentro del signalGap (3 s)
    await settle(3100);
    expect(repo.searchCalls, 2);
  });

  test('evento durante una recarga en vuelo sobrevive a su respuesta', () async {
    repo.gate = Completer<void>();
    final ctl = c.read(chatListControllerProvider.notifier);
    final f = ctl.poll(); // la respuesta no incluirá el mensaje de abajo
    await settle(10);
    _FakeRealtime.ctrl.add(
      RealtimeNewMessages([
        {
          'message': 'nuevo',
          'type': 'text',
          'flow': 'outbound',
          'message_id': 'm77',
          'date': '2026-01-01T11:00:00Z',
          'chat': {'id': '56922222222@c.us'},
        },
      ]),
    );
    await settle(10);
    expect(
      c.read(chatListControllerProvider).items.first.lastMessage!.body,
      'nuevo',
    );
    repo.gate!.complete();
    await f;
    final items = c.read(chatListControllerProvider).items;
    expect(items.first.id, '56922222222@c.us');
    expect(items.first.lastMessage!.body, 'nuevo');
  });
}
