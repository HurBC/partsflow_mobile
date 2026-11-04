import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/api_user.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/cancel_signal.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_key.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/send_outcome.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_actions_service.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_list_view_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';

import '../_fixtures.dart';

/// PATCH que queda en vuelo hasta que el test lo completa.
class _Repo implements ChatRepository {
  final gate = Completer<Result<bool>>();
  List<Chat> list = [];

  /// Tras la carga inicial, los sondeos quedan en vuelo (no pisan el estado).
  bool hold = false;

  @override
  Future<Result<bool>> updateClient(
    String clientId,
    Map<String, Object?> fields,
  ) => gate.future;

  @override
  Future<Result<List<Message>>> history(
    String phone,
    int page,
    int limit,
  ) async => Result.ok([]);

  @override
  Future<Result<ChatPage>> searchChats(ChatQuery q, {CancelSignal? cancel}) =>
      hold
      ? Completer<Result<ChatPage>>().future
      : Future.value(Result.ok(ChatPage(chats: list, hasMore: false)));

  @override
  Future<Result<OrderStrip?>> activeOrder(String clientId) async =>
      Result.ok(null);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _FakeRealtime extends Realtime {
  @override
  Stream<RealtimeEvent> get events => const Stream.empty();
  @override
  bool build() => false;
}

class _Ctl extends ChatListController {
  @override
  ChatListState build() {
    super.build();
    return ChatListState(
      tab: ChatTab.all,
      status: ListStatus.data,
      items: [_base],
    );
  }
}

final _base = chat('c1', client: const ChatClient(id: 'k1'));

const _user = ApiUser(id: '9', firstName: 'a', lastName: 'b', email: 'e');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  ProviderContainer boot(_Repo repo) {
    repo.list = [_base];
    final c = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        chatListControllerProvider.overrideWith(_Ctl.new),
        realtimeProvider.overrideWith(_FakeRealtime.new),
        apiUserProvider.overrideWith((_) async => _user),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('detalle: un cambio realtime durante el PATCH no se pierde', () async {
    final repo = _Repo();
    final c = boot(repo);
    final key = ChatKey(_base);
    c.listen(chatThreadProvider(key), (_, _) {});
    c.listen(chatListControllerProvider, (_, _) {});
    await settle();
    final n = c.read(chatThreadProvider(key).notifier);

    final fut = n.setImportant(true);
    await settle();
    // Llega por realtime un cambio del chat mientras el PATCH sigue en vuelo.
    n.applyClientExtras(issuesCount: 3, hasPendingReminder: true);
    repo.gate.complete(Result.ok(true));
    final res = await fut;

    expect(res.ok, isTrue);
    final chat = c.read(chatThreadProvider(key)).chat;
    expect(chat.client!.isImportant, isTrue);
    expect(chat.client!.issuesCount, 3);
    expect(chat.hasPendingReminder, isTrue);
  });

  test('listado: un cambio realtime durante el PATCH no se pierde', () async {
    final repo = _Repo();
    final c = boot(repo);
    c.listen(chatListControllerProvider, (_, _) {});
    await settle();
    repo.hold = true;
    final list = c.read(chatListControllerProvider.notifier);

    final svc = c.read(chatActionsServiceProvider);
    final fut = svc.setImportant(_base, true);
    await settle();
    list.replaceChat(_base.copyWith(unreadCount: 5)); // realtime
    repo.gate.complete(Result.ok(true));
    final o = await fut;
    await list.applyLocalChange(_base.id, o.change!);

    final now = c.read(chatsByIdProvider)['c1']!;
    expect(now.client!.isImportant, isTrue);
    expect(now.unreadCount, 5);
  });

  test('listado: si el chat ya no está, no se agrega', () async {
    final repo = _Repo();
    final c = boot(repo);
    c.listen(chatListControllerProvider, (_, _) {});
    await settle();
    final list = c.read(chatListControllerProvider.notifier);
    await list.applyLocalChange('otro', (x) => x.copyWith(unreadCount: 1));
    expect(c.read(chatListControllerProvider).items.map((e) => e.id), ['c1']);
  });
}
