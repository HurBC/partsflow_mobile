import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_key.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/send_outcome.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';

import '../../_fixtures.dart';

class _Repo implements ChatRepository {
  Result<bool> patchResult = Result.ok(true);
  Future<Result<bool>> Function(String phone)? onTrigger;
  final patches = <Map<String, Object?>>[];
  final triggers = <String>[];

  @override
  Future<Result<List<Message>>> history(String p, int page, int l) async =>
      Result.ok(const <Message>[]);

  @override
  Future<Result<OrderStrip?>> activeOrder(String clientId) async =>
      Result.ok(null);

  @override
  Future<Result<bool>> markRead(String chatId) async => Result.ok(true);

  @override
  Future<Result<bool>> updateClient(
    String clientId,
    Map<String, Object?> fields,
  ) async {
    patches.add(fields);
    return patchResult;
  }

  @override
  Future<Result<bool>> triggerOrderTaker(String phone) {
    triggers.add(phone);
    return onTrigger?.call(phone) ?? Future.value(Result.ok(true));
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

class _Ctl extends ChatListController {
  @override
  ChatListState build() =>
      const ChatListState(tab: ChatTab.all, status: ListStatus.data);

  @override
  Future<void> poll() async {}
}

const _warn =
    'Julia quedó activa, pero no pudo atender ahora; responderá cuando el '
    'cliente vuelva a escribir.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  late _Repo repo;
  late ProviderContainer c;
  final theChat = chat(
    '56911111111',
    client: const ChatClient(id: 'c1', operationMode: 'manual'),
  );
  ChatKey key() => ChatKey(theChat);
  ThreadState st() => c.read(chatThreadProvider(key()));
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  ProviderContainer make() {
    final k = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        realtimeProvider.overrideWith(_FakeRealtime.new),
        chatListControllerProvider.overrideWith(_Ctl.new),
        apiUserProvider.overrideWith((_) async => null),
      ],
    );
    addTearDown(k.dispose);
    k.listen(chatThreadProvider(key()), (_, _) {});
    return k;
  }

  setUp(() async {
    repo = _Repo();
    c = make();
    await settle();
  });

  test('activar: PATCH OK -> un POST con el phone', () async {
    final r = await c.read(chatThreadProvider(key()).notifier).setJulia(true);
    await settle();
    expect(r.ok, isTrue);
    expect(repo.patches, hasLength(1));
    expect(repo.triggers, ['56911111111']);
    expect(st().notes.map((n) => n.text), isNot(contains(_warn)));
  });

  test('PATCH falla: no hay POST', () async {
    repo.patchResult = Result.err(Failure.server());
    final r = await c.read(chatThreadProvider(key()).notifier).setJulia(true);
    await settle();
    expect(r.ok, isFalse);
    expect(repo.triggers, isEmpty);
  });

  test('POST falla: modo sigue automatico y se avisa', () async {
    repo.onTrigger = (_) async => Result.err(Failure.server());
    await c.read(chatThreadProvider(key()).notifier).setJulia(true);
    await settle();
    expect(st().chat.client!.operationMode, 'automatic');
    expect(st().notes.map((n) => n.text), contains(_warn));
  });

  test('desactivar: solo PATCH, sin POST', () async {
    final r = await c.read(chatThreadProvider(key()).notifier).setJulia(false);
    await settle();
    expect(r.ok, isTrue);
    expect(repo.patches, hasLength(1));
    expect(repo.triggers, isEmpty);
  });

  test('POST que nunca responde: no bloquea y no avisa al expirar', () {
    fakeAsync((fa) {
      repo.onTrigger = (_) => Completer<Result<bool>>().future;
      late ProviderContainer k;
      ActionResult? res;
      k = make();
      fa.flushMicrotasks();
      k.read(chatThreadProvider(key()).notifier).setJulia(true).then((v) {
        res = v;
      });
      fa.flushMicrotasks();
      expect(res?.ok, isTrue);
      expect(repo.triggers, hasLength(1));
      fa.elapse(const Duration(seconds: 60));
      fa.flushMicrotasks();
      final notes = k.read(chatThreadProvider(key())).notes.map((n) => n.text);
      expect(notes, isNot(contains(_warn)));
      expect(
        k.read(chatThreadProvider(key())).chat.client!.operationMode,
        'automatic',
      );
    });
  });

  test('on -> POST pendiente -> off -> POST falla: sin aviso', () async {
    final cmp = Completer<Result<bool>>();
    repo.onTrigger = (_) => cmp.future;
    final n = c.read(chatThreadProvider(key()).notifier);
    await n.setJulia(true);
    await n.setJulia(false);
    cmp.complete(Result.err(Failure.server()));
    await settle();
    expect(st().chat.client!.operationMode, 'manual');
    expect(st().notes.map((x) => x.text), isNot(contains(_warn)));
  });

  test('on, off, on con POST pendiente: un solo POST', () async {
    final cmp = Completer<Result<bool>>();
    repo.onTrigger = (_) => cmp.future;
    final n = c.read(chatThreadProvider(key()).notifier);
    await n.setJulia(true);
    await n.setJulia(false);
    await n.setJulia(true);
    await settle();
    expect(repo.triggers, hasLength(1));
    cmp.complete(Result.ok(true));
    await settle();
  });

  test('hilo desmontado antes de la respuesta: sin excepcion', () async {
    final cmp = Completer<Result<bool>>();
    repo.onTrigger = (_) => cmp.future;
    await c.read(chatThreadProvider(key()).notifier).setJulia(true);
    c.dispose();
    cmp.complete(Result.err(Failure.server()));
    await settle();
    expect(repo.triggers, hasLength(1));
  });
}
