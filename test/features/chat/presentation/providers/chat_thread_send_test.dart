import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/realtime/realtime_event.dart';
import 'package:partsflow_mobile/core/realtime/realtime_provider.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:partsflow_mobile/features/chat/data/mappers/chat_mapper.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_key.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/message.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/outgoing_attachment.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/send_outcome.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_thread_controller.dart';
import 'package:partsflow_mobile/features/chat/presentation/utils/timeline.dart';

import '../../_fixtures.dart';

/// Repo con POST controlable: cada send queda en [calls] hasta que el test lo
/// completa con [finish].
class _Repo implements ChatRepository {
  final calls =
      <({String text, String? ws, Completer<Result<SendOutcome>> c})>[];
  final history$ = <Message>[];
  bool returnDoc = true;
  Future<Result<UploadedFile>> Function()? onUpload;

  @override
  Future<Result<UploadedFile>> uploadFile({
    required Chat chat,
    required OutgoingAttachment file,
    void Function(double progress)? onProgress,
  }) => onUpload!();

  @override
  Future<Result<List<Message>>> history(String p, int page, int l) async =>
      Result.ok([...history$]);

  @override
  Future<Result<bool>> markRead(String chatId) async => Result.ok(true);

  @override
  Future<Result<SendOutcome>> sendMessage({
    required Chat chat,
    required String text,
    String? userId,
    String? quoteId,
    String? quoteBody,
    String? mediaFileId,
    String? mediaFileName,
    String? websocketId,
  }) {
    final c = Completer<Result<SendOutcome>>();
    calls.add((text: text, ws: websocketId, c: c));
    return c.future;
  }

  Message doc(int i, {String status = 'pending'}) => messageFromJson({
    'id': 'oid$i',
    'message_id': 'wamid$i',
    'websocket_id': calls[i].ws,
    'message': calls[i].text,
    'type': 'text',
    'flow': 'outbound',
    'date': '2026-01-02T10:00:0${i}Z',
    'status_code': 1,
    if (status != 'pending') 'status': status,
  })!;

  void finish(int i, {bool created = true}) => calls[i].c.complete(
    Result.ok(
      SendOutcome(SendStatus.sent, null, created && returnDoc ? doc(i) : null),
    ),
  );

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

class _Ctl extends ChatListController {
  @override
  ChatListState build() =>
      ChatListState(tab: ChatTab.all, status: ListStatus.data, items: []);
  @override
  Future<void> poll() async {}
}

void main() {
  late _Repo repo;
  late ProviderContainer c;
  final theChat = chat('56911111111@c.us');
  ChatKey key() => ChatKey(theChat);
  ThreadState st() => c.read(chatThreadProvider(key()));
  ChatThread ctl() => c.read(chatThreadProvider(key()).notifier);
  Future<void> settle([int ms = 5]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Textos que ve el usuario en orden cronológico (todo pending y real).
  List<String> shown() => [
    for (final e in buildTimeline(
      st().messages,
      st().pending,
      const [],
    ).reversed)
      if (e is MsgEntry) e.message.text ?? '',
  ];

  Map<String, dynamic> rtItem(int i, {String? ws}) => {
    'message_id': 'wamid$i',
    'websocket_id': ws ?? repo.calls[i].ws,
    'message': repo.calls[i].text,
    'type': 'text',
    'flow': 'outbound',
    'date': '2026-01-02T10:00:0${i}Z',
    'status_code': 1,
    'chat': {'id': '56911111111@c.us'},
  };

  setUp(() async {
    _FakeRealtime.rt = StreamController.broadcast();
    repo = _Repo();
    c = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        realtimeProvider.overrideWith(_FakeRealtime.new),
        chatListControllerProvider.overrideWith(_Ctl.new),
        apiUserProvider.overrideWith((_) async => null),
      ],
    );
    addTearDown(c.dispose);
    c.listen(chatThreadProvider(key()), (_, _) {});
    await settle(20);
  });

  test(
    '1..5 rapido: un POST en vuelo, en orden, con websocket_id local',
    () async {
      for (var i = 1; i <= 5; i++) {
        unawaited(ctl().send('$i'));
      }
      await settle();
      expect(repo.calls, hasLength(1));
      expect(shown(), ['1', '2', '3', '4', '5']);
      for (var i = 0; i < 5; i++) {
        expect(repo.calls, hasLength(i + 1), reason: 'solo uno en vuelo');
        expect(repo.calls[i].text, '${i + 1}');
        expect(repo.calls[i].ws, startsWith('local-'));
        repo.finish(i);
        await settle();
        expect(shown(), ['1', '2', '3', '4', '5']);
      }
      expect(st().pending, isEmpty);
      expect(st().messages.map((m) => m.text), ['1', '2', '3', '4', '5']);
    },
  );

  test('respuesta HTTP: swap atomico, nunca dos burbujas, misma id', () async {
    final seen = <List<String>>[];
    c.listen(chatThreadProvider(key()), (_, n) {
      seen.add([
        for (final e in buildTimeline(n.messages, n.pending, const []))
          if (e is MsgEntry) e.message.id,
      ]);
    });
    unawaited(ctl().send('hola'));
    await settle();
    final localId = st().pending.single.id;
    repo.finish(0);
    await settle();
    expect(st().pending, isEmpty);
    expect(st().messages.single.id, localId); // key estable
    expect(st().messages.single.status, 'pending'); // reloj, no vacio
    expect(seen.every((ids) => ids.length == 1), isTrue);
  });

  test('realtime antes que la respuesta HTTP: nunca dos burbujas', () async {
    unawaited(ctl().send('hola'));
    await settle();
    _FakeRealtime.rt.add(RealtimeNewMessages([rtItem(0)]));
    await settle();
    expect(shown(), ['hola']);
    expect(st().pending, isEmpty);
    expect(st().messages.single.id, repo.calls[0].ws);
    repo.finish(0);
    await settle();
    expect(shown(), ['hola']);
    expect(st().messages, hasLength(1));
  });

  test('respuesta HTTP antes que realtime: igual', () async {
    unawaited(ctl().send('hola'));
    await settle();
    repo.finish(0);
    await settle();
    _FakeRealtime.rt.add(RealtimeNewMessages([rtItem(0)]));
    await settle(600);
    expect(shown(), ['hola']);
    expect(st().messages, hasLength(1));
  });

  test('respuesta null/gate: camino por recarga, sin duplicar', () async {
    unawaited(ctl().send('hola'));
    await settle();
    // El historial ya trae el real (con websocket_id local).
    repo.history$.add(repo.doc(0));
    repo.finish(0, created: false);
    await settle(50);
    expect(shown(), ['hola']);
    expect(st().pending, isEmpty);
    expect(st().messages, hasLength(1));
  });

  test(
    'un fallo no bloquea la cola y el reintento se encola al final',
    () async {
      unawaited(ctl().send('1'));
      unawaited(ctl().send('2'));
      await settle();
      repo.calls[0].c.complete(
        Result.ok(const SendOutcome(SendStatus.conflict)),
      );
      await settle();
      expect(repo.calls, hasLength(2)); // el 2 siguio
      final failed = st().pending.firstWhere((m) => m.status == 'error');
      unawaited(ctl().send('3'));
      unawaited(ctl().retrySend(failed.id));
      await settle();
      repo.finish(1);
      await settle();
      expect(repo.calls.map((x) => x.text), [
        '1',
        '2',
        '3',
      ]); // 3 antes del reintento
      repo.finish(2);
      await settle();
      expect(repo.calls.map((x) => x.text), ['1', '2', '3', '1']);
      expect(repo.calls[3].ws, failed.id);
    },
  );

  test('subida estancada: falla ese mensaje y libera la cola', () async {
    ChatThread.uploadStallTimeout = const Duration(milliseconds: 40);
    ChatThread.uploadStallCheck = const Duration(milliseconds: 10);
    addTearDown(() {
      ChatThread.uploadStallTimeout = const Duration(seconds: 30);
      ChatThread.uploadStallCheck = const Duration(seconds: 5);
    });
    repo.onUpload = () => Completer<Result<UploadedFile>>().future; // nunca
    unawaited(
      ctl().sendAttachments(const [
        OutgoingAttachment(
          path: '/x.jpg',
          name: 'x.jpg',
          mime: 'image/jpeg',
          kind: AttachmentKind.image,
        ),
      ], ''),
    );
    unawaited(ctl().send('2'));
    await settle();
    expect(repo.calls, isEmpty); // el texto espera su turno
    await settle(150);
    expect(st().pending.first.status, 'error');
    expect(repo.calls.map((x) => x.text), ['2']);
  });

  test(
    'real que entra sin websocket_id y luego lo recibe libera su pendiente',
    () async {
      unawaited(ctl().send('hola'));
      await settle();
      final ws = repo.calls[0].ws!;
      final noWs = rtItem(0)..remove('websocket_id');
      _FakeRealtime.rt.add(RealtimeNewMessages([noWs]));
      await settle();
      expect(st().pending, hasLength(1)); // aun sin vinculo
      _FakeRealtime.rt.add(RealtimeMessageUpdates([rtItem(0, ws: ws)]));
      await settle();
      expect(st().pending, isEmpty);
      expect(shown(), ['hola']);
    },
  );

  test(
    'pendiente absorbido (POST sin respuesta): libera turno y job',
    () async {
      unawaited(ctl().send('1'));
      unawaited(ctl().send('2'));
      await settle();
      expect(repo.calls, hasLength(1));
      _FakeRealtime.rt.add(RealtimeNewMessages([rtItem(0)]));
      await settle();
      expect(repo.calls, hasLength(2)); // el 2 sigue sin esperar el HTTP del 1
      expect(st().pending.map((m) => m.text), ['2']);
    },
  );
}
