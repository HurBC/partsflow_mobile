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
import 'package:partsflow_mobile/features/chat/presentation/providers/thread_view_providers.dart';

import '../../_fixtures.dart';

class _Repo implements ChatRepository {
  @override
  Future<Result<List<Message>>> history(String p, int page, int l) async =>
      Result.ok([msg('h1', DateTime(2026, 1, 1), flow: 'inbound')]);

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

void main() {
  final theChat = chat('56911111111@c.us');
  final key = ChatKey(theChat);
  late ProviderContainer c;

  setUp(() async {
    c = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(_Repo()),
        realtimeProvider.overrideWith(_FakeRealtime.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(chatThreadProvider(key), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });

  test('timeline no se recalcula con loadingOlder/replyTo/error', () {
    var inputs = 0;
    c.listen(threadTimelineInputProvider(key), (_, _) => inputs++);
    final first = c.read(threadTimelineProvider(key));
    expect(first, isNotEmpty);
    final n = c.read(chatThreadProvider(key).notifier);

    n.state = n.state.copyWith(loadingOlder: true);
    n.state = n.state.copyWith(replyTo: msg('h1', DateTime(2026, 1, 1)));
    n.state = n.state.copyWith(error: 'x', hasMoreOlder: true);
    expect(identical(c.read(threadTimelineProvider(key)), first), isTrue);
    expect(inputs, 0);
  });

  test('cambio de status de un mensaje (ticks) recalcula timeline pero no '
      'el chat del header', () {
    var headerBuilds = 0;
    var replyBuilds = 0;
    c.listen(chatThreadProvider(key).select((s) => s.chat), (_, _) {
      headerBuilds++;
    });
    c.listen(chatThreadProvider(key).select((s) => s.replyTo), (_, _) {
      replyBuilds++;
    });
    final first = c.read(threadTimelineProvider(key));
    final n = c.read(chatThreadProvider(key).notifier);
    n.state = n.state.copyWith(
      messages: [
        for (final m in n.state.messages)
          msg(m.id, m.date, flow: 'inbound', status: 'read'),
      ],
    );
    expect(headerBuilds, 0);
    expect(replyBuilds, 0);
    expect(identical(c.read(threadTimelineProvider(key)), first), isFalse);
  });

  test('misma lista por valor no recalcula', () {
    final first = c.read(threadTimelineProvider(key));
    final n = c.read(chatThreadProvider(key).notifier);
    n.state = n.state.copyWith(messages: [...n.state.messages]);
    expect(identical(c.read(threadTimelineProvider(key)), first), isTrue);
  });
}
