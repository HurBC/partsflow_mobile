import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/api_user.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/cancel_signal.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_key.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/reminder.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/reminders_controller.dart';

import '../../_fixtures.dart';

class _Repo implements ChatRepository {
  _Repo(this.items);

  List<Reminder> items;
  bool fail = false;
  final calls = <String>[];

  @override
  Future<Result<List<Message>>> history(
    String phone,
    int page,
    int limit,
  ) async => Result.ok([]);

  @override
  Future<Result<ChatPage>> searchChats(
    ChatQuery q, {
    CancelSignal? cancel,
  }) async => Result.ok(const ChatPage(chats: [], hasMore: false));

  @override
  Future<Result<List<Reminder>>> pendingReminders(String chatId) async {
    calls.add('list:$chatId');
    return Result.ok(List.of(items));
  }

  @override
  Future<Result<bool>> resolveReminder(String id) async {
    calls.add('resolve:$id');
    if (fail) return Result.err(Failure.network());
    items = [
      for (final r in items)
        if (r.id != id) r,
    ];
    return Result.ok(true);
  }

  @override
  Future<Result<bool>> extendReminder({
    required Reminder reminder,
    required String userId,
    required int minutes,
  }) async {
    calls.add('extend:${reminder.id}:$userId:$minutes');
    if (fail) return Result.err(Failure.network());
    return Result.ok(true);
  }

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

Reminder rem(String id, {String? responsible = '5'}) => Reminder(
  id: id,
  chatId: '569@c.us',
  dueAt: DateTime(2026, 1, 1, 10),
  comment: 'c$id',
  responsibleId: responsible,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final now = DateTime(2026, 1, 1, 9);
  late _Repo repo;
  late ProviderContainer c;
  final theChat = chat('569@c.us');
  final key = ChatKey(theChat);

  Future<void> boot(List<Reminder> items) async {
    repo = _Repo(items);
    c = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        realtimeProvider.overrideWith(_FakeRealtime.new),
        reminderClockProvider.overrideWithValue(() => now),
        apiUserProvider.overrideWith(
          (_) async => const ApiUser(
            id: '99',
            firstName: 'a',
            lastName: 'b',
            email: 'e',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(remindersControllerProvider(key), (_, _) {});
    c.listen(chatThreadProvider(key), (_, _) {});
    await c.read(remindersControllerProvider(key).future);
  }

  test('loads pending reminders for the chat id', () async {
    await boot([rem('1'), rem('2')]);
    expect(c.read(remindersControllerProvider(key)).value, [
      rem('1'),
      rem('2'),
    ]);
    expect(repo.calls, ['list:569@c.us']);
  });

  test('resolve calls the endpoint and removes the item', () async {
    await boot([rem('1'), rem('2')]);
    final ok = await c
        .read(remindersControllerProvider(key).notifier)
        .resolve(rem('1'));
    expect(ok, isTrue);
    expect(repo.calls, contains('resolve:1'));
    expect(c.read(remindersControllerProvider(key)).value, [rem('2')]);
  });

  test(
    'resolving the last one clears hasPendingReminder on the chat',
    () async {
      await boot([rem('1')]);
      c
          .read(chatThreadProvider(key).notifier)
          .applyClientExtras(hasPendingReminder: true);
      expect(c.read(chatThreadProvider(key)).chat.hasPendingReminder, isTrue);
      await c.read(remindersControllerProvider(key).notifier).resolve(rem('1'));
      expect(c.read(remindersControllerProvider(key)).value, isEmpty);
      expect(c.read(chatThreadProvider(key)).chat.hasPendingReminder, isFalse);
    },
  );

  test('error leaves state unchanged', () async {
    await boot([rem('1')]);
    repo.fail = true;
    final n = c.read(remindersControllerProvider(key).notifier);
    expect(await n.resolve(rem('1')), isFalse);
    expect(
      await n.extend(rem('1'), now.add(const Duration(hours: 1))),
      isFalse,
    );
    expect(c.read(remindersControllerProvider(key)).value, [rem('1')]);
  });

  test('extend sends minutes until target; past target is rejected', () async {
    await boot([rem('1'), rem('2', responsible: null)]);
    final n = c.read(remindersControllerProvider(key).notifier);
    expect(await n.extend(rem('1'), now.add(const Duration(hours: 3))), isTrue);
    expect(repo.calls, contains('extend:1:5:180'));
    expect(
      await n.extend(
        rem('2', responsible: null),
        now.add(const Duration(minutes: 30)),
      ),
      isTrue,
    );
    expect(repo.calls, contains('extend:2:99:30'));
    final before = repo.calls.length;
    expect(
      await n.extend(rem('1'), now.subtract(const Duration(minutes: 1))),
      isFalse,
    );
    expect(repo.calls.length, before);
  });
}
