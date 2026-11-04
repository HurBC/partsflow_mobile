import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/errors/failure.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';
import 'package:partsflow_mobile/core/utils/result.dart';
import 'package:partsflow_mobile/features/auth/domain/entities/api_user.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/chats.dart';
import 'package:partsflow_mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_actions_service.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_actions_sheet.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_tile.dart';

class _Repo implements ChatRepository {
  final patches = <(String, Map<String, Object?>)>[];
  final unread = <String>[];
  Result<bool> next = Result.ok(true);

  @override
  Future<Result<bool>> updateClient(
    String clientId,
    Map<String, Object?> fields,
  ) async {
    patches.add((clientId, fields));
    return next;
  }

  @override
  Future<Result<bool>> markUnread(String chatId) async {
    unread.add(chatId);
    return next;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

const _me = ApiUser(
  id: 'u1',
  firstName: 'Ana',
  lastName: 'Paz',
  email: 'a@b.c',
);

Chat _chat({ChatClient? client}) => Chat(
  id: 'c1',
  phone: '5691',
  client: client ?? const ChatClient(id: 'k1'),
);

void main() {
  late _Repo repo;
  late bool userMissing;
  ApiUser? user;
  late ChatActionsService svc;

  setUp(() {
    repo = _Repo();
    userMissing = false;
    user = _me;
    svc = ChatActionsService(
      repository: repo,
      currentUser: () async => user,
      onUserMissing: () => userMissing = true,
    );
  });

  test('assign: PATCH responsible=me y actualiza el chat', () async {
    final o = await svc.perform(ChatAction.assign, _chat());
    expect(repo.patches.single.$1, 'k1');
    expect(repo.patches.single.$2, {'responsible': 'u1'});
    expect(o!.ok, isTrue);
    expect(o.chat!.client!.responsible!.id, 'u1');
  });

  test('assign sin usuario: no llama al servidor', () async {
    user = null;
    final o = await svc.perform(ChatAction.assign, _chat());
    expect(repo.patches, isEmpty);
    expect(o!.ok, isFalse);
    expect(userMissing, isTrue);
  });

  test(
    'release / resolve / unresolve / archive / unarchive / important',
    () async {
      var o = await svc.perform(
        ChatAction.release,
        _chat(
          client: const ChatClient(
            id: 'k1',
            responsible: ChatResponsible(
              id: 'u1',
              firstName: 'A',
              lastName: 'B',
            ),
          ),
        ),
      );
      expect(repo.patches.last.$2, {'responsible': null});
      expect(o!.chat!.client!.responsible, isNull);

      o = await svc.perform(ChatAction.resolve, _chat());
      expect(repo.patches.last.$2, {'is_chat_resolved': true});
      expect(o!.chat!.client!.isChatResolved, isTrue);

      o = await svc.perform(
        ChatAction.unresolve,
        _chat(client: const ChatClient(id: 'k1', isChatResolved: true)),
      );
      expect(repo.patches.last.$2, {'is_chat_resolved': false});
      expect(o!.chat!.client!.isChatResolved, isFalse);

      o = await svc.perform(ChatAction.archive, _chat());
      expect(repo.patches.last.$2, {'is_active': false});
      expect(o!.chat!.client!.isActive, isFalse);

      o = await svc.perform(
        ChatAction.unarchive,
        _chat(client: const ChatClient(id: 'k1', isActive: false)),
      );
      expect(repo.patches.last.$2, {'is_active': true});
      expect(o!.chat!.client!.isActive, isTrue);

      o = await svc.perform(ChatAction.important, _chat());
      expect(repo.patches.last.$2, {'importance_level': 'high'});
      expect(o!.chat!.client!.isImportant, isTrue);

      o = await svc.perform(
        ChatAction.important,
        _chat(client: const ChatClient(id: 'k1', isImportant: true)),
      );
      expect(repo.patches.last.$2, {'importance_level': 'none'});
      expect(o!.chat!.client!.isImportant, isFalse);
    },
  );

  test('markUnread llama chat/mark_unread y marca isUnread', () async {
    final o = await svc.perform(ChatAction.markUnread, _chat());
    expect(repo.unread, ['c1']);
    expect(repo.patches, isEmpty);
    expect(o!.ok, isTrue);
    expect(o.chat!.isUnread, isTrue);
  });

  test('error del servidor: ok=false y no hay chat nuevo', () async {
    repo.next = Result.err(Failure.server());
    for (final a in [ChatAction.resolve, ChatAction.markUnread]) {
      final o = await svc.perform(a, _chat());
      expect(o!.ok, isFalse);
      expect(o.chat, isNull);
      expect(o.message, 'No se pudo completar la acción');
    }
    repo.next = Result.err(Failure.network());
    final o = await svc.perform(ChatAction.archive, _chat());
    expect(o!.message, startsWith('Sin conexión'));
  });

  test('sin client.id no se llama al servidor', () async {
    final o = await svc.perform(
      ChatAction.resolve,
      const Chat(id: 'c1', phone: '1'),
    );
    expect(o!.ok, isFalse);
    expect(repo.patches, isEmpty);
  });

  test('acciones de UI (notas, copiar) no pasan por el servicio', () async {
    expect(await svc.perform(ChatAction.notes, _chat()), isNull);
    expect(await svc.perform(ChatAction.copyPhone, _chat()), isNull);
    expect(repo.patches, isEmpty);
  });

  group('chatLeavesTab', () {
    Chat c({bool resolved = false, bool active = true, String? resp}) => Chat(
      id: 'c',
      phone: 'c',
      client: ChatClient(
        id: 'k',
        isChatResolved: resolved,
        isActive: active,
        responsible: resp == null
            ? null
            : ChatResponsible(id: resp, firstName: 'x', lastName: 'y'),
      ),
    );

    test('resolver saca de Pendientes/Todos/Problemas, no de Resueltos', () {
      for (final t in [ChatTab.pending, ChatTab.all, ChatTab.issues]) {
        expect(chatLeavesTab(t, c(resolved: true)), isTrue);
        expect(chatLeavesTab(t, c()), isFalse);
      }
      expect(chatLeavesTab(ChatTab.resolved, c(resolved: true)), isFalse);
      expect(chatLeavesTab(ChatTab.resolved, c()), isTrue);
    });

    test('archivar / desarchivar', () {
      expect(chatLeavesTab(ChatTab.pending, c(active: false)), isTrue);
      expect(chatLeavesTab(ChatTab.archived, c(active: false)), isFalse);
      expect(chatLeavesTab(ChatTab.archived, c()), isTrue);
    });

    test('Asignados exige ser mío', () {
      expect(
        chatLeavesTab(ChatTab.assigned, c(resp: 'u1'), userId: 'u1'),
        isFalse,
      );
      expect(chatLeavesTab(ChatTab.assigned, c(), userId: 'u1'), isTrue);
      expect(
        chatLeavesTab(ChatTab.assigned, c(resp: 'u2'), userId: 'u1'),
        isTrue,
      );
    });
  });

  testWidgets('long-press en ChatTab dispara el callback con háptico', (
    t,
  ) async {
    final haptics = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var taps = 0;
    var longs = 0;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChatTile(
            chat: _chat(),
            onTap: () => taps++,
            onLongPress: () => longs++,
          ),
        ),
      ),
    );
    await t.longPress(find.byType(ChatTile));
    expect(longs, 1);
    expect(taps, 0);
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));
    await t.tap(find.byType(ChatTile));
    expect(taps, 1);
  });
}
