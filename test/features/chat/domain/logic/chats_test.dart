import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/domain/logic/chats.dart';

import '../../_fixtures.dart';

void main() {
  final now = DateTime(2025, 6, 1, 12);
  List<String> run(
    List<Chat> items, {
    ChatFilters filters = const ChatFilters(),
    bool threshold = false,
    int minutes = 30,
  }) => visibleChats(
    items: items,
    filters: filters,
    thresholdApplies: threshold,
    pendingThreshold: minutes,
    now: now,
  ).map((c) => c.id).toList();

  test('sin filtros ni umbral devuelve todo', () {
    expect(run([chat('a'), chat('b')]), ['a', 'b']);
  });
  test('filtro unread deja solo los no leídos', () {
    expect(
      run([
        chat('a', unreadCount: 2),
        chat('b'),
      ], filters: const ChatFilters(unread: true)),
      ['a'],
    );
  });
  test('filtro julia usa client.juliaOn', () {
    final on = chat('a', client: const ClientStub(auto: true).build());
    expect(run([on, chat('b')], filters: const ChatFilters(julia: true)), [
      'a',
    ]);
  });
  test('filtros combinados son AND', () {
    final a = chat(
      'a',
      unreadCount: 1,
      client: const ClientStub(auto: true).build(),
    );
    final b = chat('b', unreadCount: 1);
    expect(run([a, b], filters: const ChatFilters(unread: true, julia: true)), [
      'a',
    ]);
  });
  test('umbral oculta chats con actividad reciente', () {
    final recent = chat(
      'r',
      lastMessageAt: now.subtract(const Duration(minutes: 5)),
    );
    final old = chat(
      'o',
      lastMessageAt: now.subtract(const Duration(minutes: 90)),
    );
    expect(run([recent, old], threshold: true), ['o']);
  });
  test('umbral no aplicado muestra los recientes', () {
    final recent = chat(
      'r',
      lastMessageAt: now.subtract(const Duration(minutes: 5)),
    );
    expect(run([recent]), ['r']);
  });
  test('activityAt null no se oculta aunque el umbral aplique', () {
    expect(run([chat('n')], threshold: true), ['n']);
  });
  test('borde exacto del umbral (==) se oculta', () {
    final edge = chat(
      'e',
      lastMessageAt: now.subtract(const Duration(minutes: 30)),
    );
    // comportamiento actual: difference <= limit oculta, así que el borde exacto se oculta.
    expect(run([edge], threshold: true), isEmpty);
  });
  test('un segundo más allá del umbral se muestra', () {
    final past = chat(
      'p',
      lastMessageAt: now.subtract(const Duration(minutes: 30, seconds: 1)),
    );
    expect(run([past], threshold: true), ['p']);
  });
  test('activityAt cae a lastMessage.date', () {
    final c = chat(
      'l',
      lastMessage: ChatLastMessage(
        date: now.subtract(const Duration(minutes: 1)),
      ),
    );
    expect(run([c], threshold: true), isEmpty);
  });
  test('filtro y umbral se combinan', () {
    final a = chat(
      'a',
      unreadCount: 1,
      lastMessageAt: now.subtract(const Duration(hours: 5)),
    );
    final b = chat('b', unreadCount: 1, lastMessageAt: now);
    expect(
      run([a, b], filters: const ChatFilters(unread: true), threshold: true),
      ['a'],
    );
  });
}

class ClientStub {
  const ClientStub({required this.auto});
  final bool auto;
  ChatClient build() =>
      ChatClient(operationMode: auto ? 'automatic' : 'manual');
}
