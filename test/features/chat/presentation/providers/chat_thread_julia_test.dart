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
  Future<Result<bool>> Function(Map<String, Object?> f)? onPatch;
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
    return onPatch?.call(fields) ?? patchResult;
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
  static StreamController<RealtimeEvent> rt = StreamController.broadcast();
  @override
  Stream<RealtimeEvent> get events => rt.stream;
  @override
  bool build() => false;
}

Chat _listChat = chat('56911111111');

class _Ctl extends ChatListController {
  @override
  ChatListState build() => ChatListState(
    tab: ChatTab.all,
    status: ListStatus.data,
    items: [_listChat],
  );

  @override
  Future<void> poll() async {}
}

const _warn = 'Julia no pudo atender';

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
    _listChat = theChat;
    _FakeRealtime.rt = StreamController.broadcast();
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
    expect(st().notice?.text, isNot(_warn));
  });

  test('activar y pausar no dejan notas en el hilo', () async {
    final n = c.read(chatThreadProvider(key()).notifier);
    expect((await n.setJulia(true)).ok, isTrue);
    expect((await n.setJulia(false)).ok, isTrue);
    await settle();
    expect(st().notes, isEmpty);
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
    expect(st().notice?.text, _warn);
    expect(st().notice?.kind, ThreadNoticeKind.warning);
    expect(st().notice?.action, ThreadNoticeAction.retryJulia);
  });

  group('optimista', () {
    String mode() => st().chat.client!.operationMode!;

    test('se aplica al instante, antes de la red', () async {
      final cmp = Completer<Result<bool>>();
      repo.onPatch = (_) => cmp.future;
      final f = c.read(chatThreadProvider(key()).notifier).setJulia(true);
      expect(mode(), 'automatic');
      expect(st().chat.client!.juliaOn, isTrue);
      expect(repo.triggers, isEmpty);
      cmp.complete(Result.ok(true));
      expect((await f).ok, isTrue);
      await settle();
      expect(mode(), 'automatic');
      expect(repo.triggers, hasLength(1));
    });

    test('fallo: revierte y devuelve el error; sin order_taker', () async {
      repo.patchResult = Result.err(Failure.server());
      final r = await c.read(chatThreadProvider(key()).notifier).setJulia(true);
      await settle();
      expect(r.ok, isFalse);
      expect(r.message, isNotEmpty);
      expect(mode(), 'manual');
      expect(st().chat.client!.juliaOn, isFalse);
      expect(repo.triggers, isEmpty);
    });

    test('toque posterior: no revierte lo que el usuario ya cambió', () async {
      final first = Completer<Result<bool>>();
      var n = 0;
      repo.onPatch = (_) =>
          n++ == 0 ? first.future : Future.value(Result.ok(true));
      final ctl = c.read(chatThreadProvider(key()).notifier);
      final a = ctl.setJulia(true);
      final b = ctl.setJulia(false);
      expect(mode(), 'manual');
      first.complete(Result.err(Failure.server()));
      expect((await a).ok, isTrue); // superado: sin error que mostrar
      expect((await b).ok, isTrue);
      await settle();
      expect(mode(), 'manual');
      expect(repo.triggers, isEmpty);
    });

    test('coalescencia on/off/on: <= 2 PATCH y el último deja ON', () async {
      final first = Completer<Result<bool>>();
      var n = 0;
      repo.onPatch = (_) =>
          n++ == 0 ? first.future : Future.value(Result.ok(true));
      final ctl = c.read(chatThreadProvider(key()).notifier);
      final a = ctl.setJulia(true);
      final b = ctl.setJulia(false);
      final d = ctl.setJulia(true);
      await settle();
      expect(repo.patches, hasLength(1)); // nunca dos en vuelo
      first.complete(Result.ok(true));
      await Future.wait([a, b, d]);
      await settle();
      expect(repo.patches.length, lessThanOrEqualTo(2));
      expect(repo.patches.last['operation_mode'], 'automatic');
      expect(mode(), 'automatic');
      expect(repo.triggers, hasLength(1));
    });

    test('order_taker solo tras PATCH OK con valor aún ON', () async {
      final first = Completer<Result<bool>>();
      var n = 0;
      repo.onPatch = (_) =>
          n++ == 0 ? first.future : Future.value(Result.ok(true));
      final ctl = c.read(chatThreadProvider(key()).notifier);
      final a = ctl.setJulia(true);
      final b = ctl.setJulia(false);
      first.complete(Result.ok(true));
      await Future.wait([a, b]);
      await settle();
      expect(repo.patches, hasLength(2));
      expect(mode(), 'manual');
      expect(repo.triggers, isEmpty);
    });
  });

  group('robustez', () {
    String listMode(ProviderContainer k) =>
        k.read(chatListControllerProvider).items.single.client!.operationMode!;

    test('fallo tras desmontar: revierte la entrada de la lista', () async {
      final gate = Completer<Result<bool>>();
      repo.onPatch = (_) => gate.future;
      final k = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          realtimeProvider.overrideWith(_FakeRealtime.new),
          chatListControllerProvider.overrideWith(_Ctl.new),
          apiUserProvider.overrideWith((_) async => null),
        ],
      );
      addTearDown(k.dispose);
      final sub = k.listen(chatThreadProvider(key()), (_, _) {});
      await settle();
      unawaited(k.read(chatThreadProvider(key()).notifier).setJulia(true));
      expect(listMode(k), 'automatic');
      sub.close();
      await settle();
      gate.complete(Result.err(Failure.server()));
      await settle();
      expect(listMode(k), 'manual');
      expect(repo.triggers, isEmpty);
    });

    test('on -> off y desmontar al instante: igual se envía OFF', () async {
      final first = Completer<Result<bool>>();
      var n = 0;
      repo.onPatch = (_) =>
          n++ == 0 ? first.future : Future.value(Result.ok(true));
      final k = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          realtimeProvider.overrideWith(_FakeRealtime.new),
          chatListControllerProvider.overrideWith(_Ctl.new),
          apiUserProvider.overrideWith((_) async => null),
        ],
      );
      addTearDown(k.dispose);
      final sub = k.listen(chatThreadProvider(key()), (_, _) {});
      await settle();
      final ctl = k.read(chatThreadProvider(key()).notifier);
      unawaited(ctl.setJulia(true));
      unawaited(ctl.setJulia(false));
      sub.close();
      await settle();
      first.complete(Result.ok(true));
      await settle();
      expect(repo.patches, hasLength(2));
      expect(repo.patches.last['operation_mode'], 'manual');
      expect(repo.triggers, isEmpty);
    });

    test('cambio por realtime durante un PATCH que falla no se pisa', () async {
      final gate = Completer<Result<bool>>();
      repo.onPatch = (_) => gate.future;
      final f = c.read(chatThreadProvider(key()).notifier).setJulia(true);
      _FakeRealtime.rt.add(
        const RealtimeClientChanged('client', {
          'id': 'c1',
          'operation_mode': 'automatic',
          'is_ai_active': true,
        }),
      );
      await settle();
      gate.complete(Result.err(Failure.server()));
      expect((await f).ok, isFalse);
      await settle();
      expect(st().chat.client!.operationMode, 'automatic');
    });
  });

  group('retryOrderTaker', () {
    test('solo reintenta si el chat sigue en automatic', () async {
      final n = c.read(chatThreadProvider(key()).notifier);
      expect(await n.retryOrderTaker(), OrderTakerOutcome.skipped);
      expect(repo.triggers, isEmpty);
    });

    test('OK: un POST y sin aviso nuevo', () async {
      final n = c.read(chatThreadProvider(key()).notifier);
      await n.setJulia(true);
      await settle();
      expect(repo.triggers, hasLength(1));
      expect(await n.retryOrderTaker(), OrderTakerOutcome.ok);
      expect(repo.triggers, hasLength(2));
      expect(st().notice?.text, isNot(_warn));
    });

    test('Err: vuelve a emitir el aviso con Reintentar', () async {
      final n = c.read(chatThreadProvider(key()).notifier);
      await n.setJulia(true);
      await settle();
      repo.onTrigger = (_) async => Result.err(Failure.server());
      final before = st().notice;
      expect(await n.retryOrderTaker(), OrderTakerOutcome.failed);
      expect(st().notice, isNot(same(before)));
      expect(st().notice?.action, ThreadNoticeAction.retryJulia);
    });

    test('respeta la petición en curso (guard in-flight)', () async {
      final cmp = Completer<Result<bool>>();
      repo.onTrigger = (_) => cmp.future;
      final n = c.read(chatThreadProvider(key()).notifier);
      await n.setJulia(true);
      expect(await n.retryOrderTaker(), OrderTakerOutcome.busy);
      expect(repo.triggers, hasLength(1));
      cmp.complete(Result.ok(true));
      await settle();
    });

    test('timeout: sin aviso', () {
      fakeAsync((fa) {
        late ProviderContainer k;
        k = make();
        fa.flushMicrotasks();
        final n = k.read(chatThreadProvider(key()).notifier);
        n.setJulia(true);
        fa.flushMicrotasks();
        repo.onTrigger = (_) => Completer<Result<bool>>().future;
        fa.elapse(const Duration(seconds: 1));
        OrderTakerOutcome? out;
        n.retryOrderTaker().then((v) => out = v);
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 60));
        fa.flushMicrotasks();
        expect(out, OrderTakerOutcome.timeout);
        expect(k.read(chatThreadProvider(key())).notice?.text, isNot(_warn));
      });
    });
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
      final notice = k.read(chatThreadProvider(key())).notice?.text;
      expect(notice, isNot(_warn));
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
    expect(st().notice?.text, isNot(_warn));
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

  group('juliaWorking', () {
    test('true durante el POST y false al terminar OK', () async {
      final cmp = Completer<Result<bool>>();
      repo.onTrigger = (_) => cmp.future;
      final n = c.read(chatThreadProvider(key()).notifier);
      expect(st().juliaWorking, isFalse);
      await n.setJulia(true);
      expect(st().juliaWorking, isTrue);
      cmp.complete(Result.ok(true));
      await settle();
      expect(st().juliaWorking, isFalse);
    });

    test('false si el POST falla', () async {
      final cmp = Completer<Result<bool>>();
      repo.onTrigger = (_) => cmp.future;
      await c.read(chatThreadProvider(key()).notifier).setJulia(true);
      expect(st().juliaWorking, isTrue);
      cmp.complete(Result.err(Failure.server()));
      await settle();
      expect(st().juliaWorking, isFalse);
    });

    test('false al expirar el timeout', () {
      fakeAsync((fa) {
        final k = make();
        fa.flushMicrotasks();
        repo.onTrigger = (_) => Completer<Result<bool>>().future;
        k.read(chatThreadProvider(key()).notifier).setJulia(true);
        fa.flushMicrotasks();
        expect(k.read(chatThreadProvider(key())).juliaWorking, isTrue);
        fa.elapse(const Duration(seconds: 60));
        fa.flushMicrotasks();
        expect(k.read(chatThreadProvider(key())).juliaWorking, isFalse);
      });
    });

    test('retryOrderTaker también lo marca', () async {
      final n = c.read(chatThreadProvider(key()).notifier);
      await n.setJulia(true);
      await settle();
      final cmp = Completer<Result<bool>>();
      repo.onTrigger = (_) => cmp.future;
      final f = n.retryOrderTaker();
      expect(st().juliaWorking, isTrue);
      cmp.complete(Result.ok(true));
      await f;
      expect(st().juliaWorking, isFalse);
    });

    test('desmontar con POST pendiente no lanza', () async {
      final cmp = Completer<Result<bool>>();
      repo.onTrigger = (_) => cmp.future;
      await c.read(chatThreadProvider(key()).notifier).setJulia(true);
      c.dispose();
      cmp.complete(Result.ok(true));
      await settle();
    });
  });
}
