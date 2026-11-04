import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/cancel_signal.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_list_view_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';

class _Repo implements ChatRepository {
  var auto = false;
  final calls = <Completer<Result<ChatPage>>>[];

  @override
  Future<Result<ChatPage>> searchChats(
    ChatQuery query, {
    CancelSignal? cancel,
  }) {
    final c = Completer<Result<ChatPage>>();
    calls.add(c);
    if (auto) c.complete(Result.ok(const ChatPage(chats: [], hasMore: false)));
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Ctl extends ChatListController {
  @override
  ChatListState build() {
    super.build();
    return const ChatListState(
      status: ListStatus.data,
      searchMode: SearchMode.client,
    );
  }
}

class _FakeRealtime extends Realtime {
  @override
  Stream<RealtimeEvent> get events => const Stream.empty();
  @override
  bool build() => false;
}

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  test(
    'refine en vuelo + refresh que falla: refining queda en false',
    () async {
      final repo = _Repo();
      final c = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          chatListControllerProvider.overrideWith(_Ctl.new),
          realtimeProvider.overrideWith(_FakeRealtime.new),
        ],
      );
      addTearDown(c.dispose);
      c.listen(chatListControllerProvider, (_, _) {});
      final ctl = c.read(chatListControllerProvider.notifier);

      await settle();
      repo.calls.single.complete(
        Result.ok(const ChatPage(chats: [], hasMore: false)),
      );
      await settle();
      ctl.setSearch('abc');
      await settle();
      expect(c.read(chatListControllerProvider).refining, isTrue);

      final r = ctl.refresh();
      await settle();
      expect(c.read(chatListControllerProvider).refining, isFalse);
      repo.calls.last.complete(Result.err(Failure.network()));
      await r;
      expect(c.read(chatListControllerProvider).refining, isFalse);

      repo.auto = true;
      final before = repo.calls.length;
      await ctl.poll();
      expect(repo.calls.length, greaterThan(before));
    },
  );

  test('chatClock: now fresco al pasar thresholdApplies false -> true', () {
    var t = DateTime(2024, 1, 1, 10);
    chatNow = () => t;
    addTearDown(() => chatNow = DateTime.now);
    final c = ProviderContainer(
      overrides: [
        chatListControllerProvider.overrideWith(_Ctl.new),
        realtimeProvider.overrideWith(_FakeRealtime.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(chatListControllerProvider, (_, _) {});
    c.read(chatListControllerProvider.notifier).setTab(ChatTab.all);
    expect(c.read(chatClockProvider), t);
    t = t.add(const Duration(minutes: 10));
    c.read(chatListControllerProvider.notifier).setTab(ChatTab.pending);
    expect(c.read(chatClockProvider), t);
  });
}
