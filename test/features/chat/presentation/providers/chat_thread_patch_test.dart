import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_key.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';

import '../../_fixtures.dart';

class _Repo implements ChatRepository {
  int historyCalls = 0;

  @override
  Future<Result<List<Message>>> history(
    String phone,
    int page,
    int limit,
  ) async {
    historyCalls++;
    return Result.ok([msg('h1', DateTime(2026, 1, 1), flow: 'inbound')]);
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
  late _Repo repo;
  late ProviderContainer c;
  final theChat = chat('56911111111@c.us');

  Future<void> settle([int ms = 0]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Map<String, dynamic> item(Map<String, dynamic> extra) => {
    'message': 'hola',
    'type': 'text',
    'flow': 'inbound',
    'date': '2026-01-02T10:00:00Z',
    'chat': {'id': '56911111111@c.us'},
    ...extra,
  };

  setUp(() async {
    repo = _Repo();
    c = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        realtimeProvider.overrideWith(_FakeRealtime.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(chatThreadProvider(ChatKey(theChat)), (_, _) {});
    await settle(10);
    expect(repo.historyCalls, 1);
  });

  test('mensaje mapeable se aplica sin llamar al repositorio', () async {
    _FakeRealtime.ctrl.add(
      RealtimeNewMessages([
        item({'message_id': 'm2'}),
      ]),
    );
    await settle(600);
    expect(repo.historyCalls, 1);
    expect(
      c
          .read(chatThreadProvider(ChatKey(theChat)))
          .messages
          .map((m) => m.messageId),
      [null, 'm2'],
    );
  });

  test('evento repetido no duplica', () async {
    final e = RealtimeNewMessages([
      item({'message_id': 'm2'}),
    ]);
    _FakeRealtime.ctrl.add(e);
    _FakeRealtime.ctrl.add(e);
    await settle(600);
    expect(c.read(chatThreadProvider(ChatKey(theChat))).messages, hasLength(2));
  });

  test('mensaje sin message_id/websocket_id cae a recarga', () async {
    _FakeRealtime.ctrl.add(RealtimeNewMessages([item({})]));
    await settle(600);
    expect(repo.historyCalls, 2);
  });

  test('mensaje de otro chat se ignora', () async {
    _FakeRealtime.ctrl.add(
      RealtimeNewMessages([
        item({
          'message_id': 'm9',
          'chat': {'id': '56900000000@c.us'},
        }),
      ]),
    );
    await settle(600);
    expect(repo.historyCalls, 1);
    expect(c.read(chatThreadProvider(ChatKey(theChat))).messages, hasLength(1));
  });

  test('message_update reemplaza el mensaje pendiente sin recargar', () async {
    _FakeRealtime.ctrl.add(
      RealtimeNewMessages([
        item({
          'message_id': 'm2',
          'type': 'image',
          'media': {'id': 'x', 'pending': true},
        }),
      ]),
    );
    await settle(50);
    final k = ChatKey(theChat);
    expect(c.read(chatThreadProvider(k)).messages.last.mediaPending, isTrue);
    _FakeRealtime.ctrl.add(
      RealtimeMessageUpdates([
        item({
          'message_id': 'm2',
          'type': 'image',
          'media': {'id': 'x', 'url': 'http://u', 'pending': false},
        }),
      ]),
    );
    await settle(50);
    final last = c.read(chatThreadProvider(k)).messages.last;
    expect(last.mediaPending, isFalse);
    expect(last.mediaUrl, 'http://u');
    expect(repo.historyCalls, 1);
  });

  test('media pendiente mas de N s dispara una sola recarga', () async {
    ChatThread.mediaPendingTimeout = const Duration(milliseconds: 100);
    addTearDown(
      () => ChatThread.mediaPendingTimeout = const Duration(seconds: 10),
    );
    _FakeRealtime.ctrl.add(
      RealtimeNewMessages([
        item({
          'message_id': 'm2',
          'type': 'image',
          'media': {'id': 'x', 'pending': true},
        }),
      ]),
    );
    await settle(700);
    expect(repo.historyCalls, 2);
    await settle(700);
    expect(repo.historyCalls, 2);
  });

  test('dos snapshots del mismo chat comparten un único notifier', () {
    final a = ChatKey(theChat);
    final b = ChatKey(chat('56911111111@c.us', unreadCount: 7));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(
      identical(
        c.read(chatThreadProvider(a).notifier),
        c.read(chatThreadProvider(b).notifier),
      ),
      isTrue,
    );
    expect(repo.historyCalls, 1);
    expect(ChatKey(chat('otro@c.us')), isNot(a));
  });
}
