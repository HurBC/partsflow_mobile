import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/presentation/pages/chat_list_page.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_list_view_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_tile.dart';

class _FakeList extends ChatListController {
  _FakeList(this.initial);
  final ChatListState initial;

  @override
  ChatListState build() => initial;

  void set(ChatListState s) => state = s;
}

Chat mk(String id, {int unread = 0}) => Chat(
  id: id,
  phone: id,
  name: 'Chat $id',
  unreadCount: unread,
  lastMessageAt: DateTime(2020, 1, 1),
);

ChatListState st(List<Chat> items, {ChatTab tab = ChatTab.all}) =>
    ChatListState(tab: tab, items: items, status: ListStatus.data);

void main() {
  late _FakeList fake;
  late ProviderContainer container;
  late Map<String, int> builds;

  Future<void> pump(WidgetTester t, ChatListState initial) async {
    builds = {};
    chatTileBuildProbe = (id) => builds[id] = (builds[id] ?? 0) + 1;
    addTearDown(() => chatTileBuildProbe = null);
    fake = _FakeList(initial);
    container = ProviderContainer(
      overrides: [chatListControllerProvider.overrideWith(() => fake)],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChatListBody(
              scroll: ScrollController(),
              onRefresh: () async {},
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 2));
    builds.clear();
  }

  testWidgets('parche en 1 chat reconstruye solo su tile', (t) async {
    final items = [for (var i = 0; i < 5; i++) mk('c$i')];
    await pump(t, st(items));
    expect(find.byType(ChatTile), findsNWidgets(5));

    fake.set(
      st([
        for (final c in items) c.id == 'c2' ? c.copyWith(unreadCount: 3) : c,
      ]),
    );
    await t.pump();
    expect(builds, {'c2': 1});
  });

  testWidgets('tick del reloj sin cambio de resultado no reconstruye', (
    t,
  ) async {
    final items = [for (var i = 0; i < 4; i++) mk('c$i')];
    await pump(t, st(items, tab: ChatTab.pending));
    expect(find.byType(ChatTile), findsNWidgets(4));

    container.read(chatClockProvider.notifier).tick(DateTime(2026, 6, 1));
    await t.pump();
    expect(builds, isEmpty);
  });

  test('visible memoizado: misma igualdad si solo cambia un chat', () {
    final items = [for (var i = 0; i < 3; i++) mk('c$i')];
    final c = ProviderContainer(
      overrides: [
        chatListControllerProvider.overrideWith(() => _FakeList(st(items))),
      ],
    );
    addTearDown(c.dispose);
    var notified = 0;
    c.listen(chatVisibleIdsProvider, (_, _) => notified++);
    final first = c.read(chatVisibleIdsProvider);
    expect(first.ids, ['c0', 'c1', 'c2']);
    (c.read(chatListControllerProvider.notifier) as _FakeList).set(
      st([items[0], items[1].copyWith(unreadCount: 2), items[2]]),
    );
    c.read(chatVisibleIdsProvider);
    expect(notified, 0);
  });
}
