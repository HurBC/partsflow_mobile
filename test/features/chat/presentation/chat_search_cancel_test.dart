import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/chat/domain/cancel_signal.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_search_provider.dart';

class _Call {
  _Call(this.query, this.cancel);
  final ChatQuery query;
  final CancelSignal? cancel;
  final done = Completer<Result<ChatPage>>();
}

class _Repo implements ChatRepository {
  final calls = <_Call>[];

  @override
  Future<Result<ChatPage>> searchChats(
    ChatQuery query, {
    CancelSignal? cancel,
  }) {
    final c = _Call(query, cancel);
    calls.add(c);
    // Como Dio: al cancelar, el request termina en error.
    cancel?.whenCancelled.then((_) {
      if (!c.done.isCompleted) c.done.complete(Result.err(Failure.network()));
    });
    return c.done.future;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Chat _chat(String id) => Chat(id: id, phone: id);
Result<ChatPage> _ok(String id) =>
    Result.ok(ChatPage(chats: [_chat(id)], hasMore: false));

void main() {
  late _Repo repo;
  late ProviderContainer c;

  setUp(() {
    repo = _Repo();
    c = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(chatSearchControllerProvider, (_, _) {});
  });

  Future<void> run(String t) => c
      .read(chatSearchControllerProvider.notifier)
      .run(text: t, tab: ChatTab.all, advanced: const AdvancedFilters());
  ChatSearchState st() => c.read(chatSearchControllerProvider);

  test('nueva búsqueda cancela la anterior y ignora su respuesta', () async {
    final a = run('juan');
    final b = run('pedro');
    expect(repo.calls.length, 4); // 2 por búsqueda (cliente + mensajes)
    expect(repo.calls[0].cancel!.isCancelled, isTrue);
    expect(repo.calls[1].cancel!.isCancelled, isTrue);
    expect(repo.calls[2].cancel!.isCancelled, isFalse);
    repo.calls[2].done.complete(_ok('b'));
    repo.calls[3].done.complete(_ok('bm'));
    await Future.wait([a, b]);
    expect(st().query, 'pedro');
    expect(st().clients.status, SectionStatus.data);
    expect(st().clients.items.single.id, 'b');
  });

  test('misma query en vuelo se reutiliza', () async {
    final a = run('juan');
    final b = run('juan');
    expect(repo.calls.length, 2);
    expect(identical(a, b), isTrue);
    for (final k in repo.calls) {
      k.done.complete(_ok('x'));
    }
    await a;
    final again = run('juan'); // ya terminó: lanza de nuevo
    expect(repo.calls.length, 4);
    for (final k in repo.calls.skip(2)) {
      k.done.complete(_ok('x'));
    }
    await again;
  });

  test('texto vacío cancela y limpia', () async {
    final a = run('juan');
    run('  ');
    expect(repo.calls.every((k) => k.cancel!.isCancelled), isTrue);
    await a;
    expect(st(), const ChatSearchState());
  });

  test('cancelar no genera estado de error', () async {
    final a = run('juan');
    c.read(chatSearchControllerProvider.notifier).clear();
    await a;
    expect(st().clients.status, isNot(SectionStatus.error));
    expect(st().messages.status, isNot(SectionStatus.error));
  });

  test('resultados previos se mantienen hasta que llega la nueva', () async {
    final a = run('juan');
    for (final k in repo.calls) {
      k.done.complete(_ok('old'));
    }
    await a;
    final b = run('pedro');
    expect(st().clients.status, SectionStatus.data);
    expect(st().clients.refreshing, isTrue);
    expect(st().clients.items.single.id, 'old');
    expect(st().messages.items.single.id, 'old');
    repo.calls[2].done.complete(_ok('new'));
    repo.calls[3].done.complete(_ok('newm'));
    await b;
    expect(st().clients.refreshing, isFalse);
    expect(st().clients.items.single.id, 'new');
  });

  test('loadMoreMessages se cancela al cambiar de query', () async {
    final a = run('juan');
    repo.calls[0].done.complete(_ok('c'));
    repo.calls[1].done.complete(
      Result.ok(ChatPage(chats: [_chat('m1')], hasMore: true, cursor: 'cur')),
    );
    await a;
    final n = c.read(chatSearchControllerProvider.notifier);
    final more = n.loadMoreMessages();
    expect(repo.calls.length, 3);
    final moreCall = repo.calls[2];
    run('pedro');
    expect(moreCall.cancel!.isCancelled, isTrue);
    await more;
    expect(st().messages.moreFailed, isFalse);
  });
}
