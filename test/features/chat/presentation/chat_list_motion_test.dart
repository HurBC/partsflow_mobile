import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partsflow_mobile/core/theme/app_theme.dart';
import 'package:partsflow_mobile/core/ui/pf_shimmer.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat_query.dart';
import 'package:partsflow_mobile/features/chat/presentation/pages/chat_list_page.dart';
import 'package:partsflow_mobile/features/chat/presentation/providers/chat_providers.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_list_motion.dart';
import 'package:partsflow_mobile/features/chat/presentation/widgets/chat_tab_strip.dart';

class _FakeList extends ChatListController {
  _FakeList(this.initial);
  final ChatListState initial;

  @override
  ChatListState build() => initial;

  void set(ChatListState s) => state = s;
}

Chat mk(String id, {int day = 1, int unread = 0}) => Chat(
  id: id,
  phone: id,
  name: 'Chat $id',
  unreadCount: unread,
  lastMessageAt: DateTime(2020, 1, day),
);

ChatListState st(List<Chat> items, {ChatTab tab = ChatTab.all}) =>
    ChatListState(tab: tab, items: items, status: ListStatus.data);

Map<String, Chat> byId(List<Chat> l) => {for (final c in l) c.id: c};

void main() {
  group('ChatRiseDetector', () {
    final a = mk('a', day: 5);
    final b = mk('b', day: 4);
    final c = mk('c', day: 3);

    test('carga inicial no dispara', () {
      expect(ChatRiseDetector().update(['a', 'b', 'c'], byId([a, b, c])), null);
    });

    test('chat visible con actividad nueva que llega a la cima dispara', () {
      final d = ChatRiseDetector()..update(['a', 'b', 'c'], byId([a, b, c]));
      final c2 = mk('c', day: 9);
      expect(d.update(['c', 'a', 'b'], byId([a, b, c2])), 'c');
    });

    test('reorden sin actividad nueva (pestaña/búsqueda) no dispara', () {
      final d = ChatRiseDetector()..update(['a', 'b', 'c'], byId([a, b, c]));
      expect(d.update(['c', 'b'], byId([a, b, c])), null);
    });

    test('chat que no estaba en el snapshot (otra pestaña) no dispara', () {
      final d = ChatRiseDetector()..update(['a', 'b'], byId([a, b]));
      final c2 = mk('c', day: 9);
      expect(d.update(['c', 'a', 'b'], byId([a, b, c2])), null);
    });

    test('reset (cambio de pestaña/búsqueda/filtros) solo siembra', () {
      final d = ChatRiseDetector()..update(['a', 'b', 'c'], byId([a, b, c]));
      d.reset();
      expect(d.update(['c', 'a', 'b'], byId([a, b, mk('c', day: 9)])), null);
      // Y después sí vuelve a detectar actividad nueva real.
      expect(d.update(['b', 'c', 'a'], byId([a, mk('b', day: 20), c])), 'b');
    });

    test('mensaje propio (saliente) no dispara', () {
      final d = ChatRiseDetector()..update(['a', 'b', 'c'], byId([a, b, c]));
      final mine = Chat(
        id: 'c',
        phone: 'c',
        lastMessageAt: DateTime(2020, 1, 9),
        lastMessage: ChatLastMessage(flow: 'outbound', body: 'hola'),
      );
      expect(d.update(['c', 'a', 'b'], byId([a, b, mine])), null);
    });

    test('paginación (cima intacta) no dispara', () {
      final d = ChatRiseDetector()..update(['a', 'b'], byId([a, b]));
      expect(d.update(['a', 'b', 'c'], byId([a, b, c])), null);
    });

    test('la cima que sigue siendo cima no dispara', () {
      final d = ChatRiseDetector()..update(['a', 'b'], byId([a, b]));
      expect(d.update(['a', 'b'], byId([mk('a', day: 20), b])), null);
    });
  });

  group('lista', () {
    late _FakeList fake;
    final items = [
      mk('c0', day: 5),
      mk('c1', day: 4),
      mk('c2', day: 3),
      mk('c3', day: 2),
    ];

    Future<void> pump(WidgetTester t, ChatListState initial) async {
      fake = _FakeList(initial);
      final container = ProviderContainer(
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
    }

    double flashAlpha(WidgetTester t) {
      final box = t.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(ChatRowRise).first,
              matching: find.byKey(const ValueKey('chat-row-flash')),
            )
            .first,
      );
      return ((box.decoration as BoxDecoration).color?.a ?? 0);
    }

    testWidgets('actividad nueva que sube un chat anima la fila y se apaga', (
      t,
    ) async {
      await pump(t, st(items));
      expect(flashAlpha(t), 0);

      fake.set(
        st([
          mk('c2', day: 25),
          ...[items[0], items[1], items[3]],
        ]),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(flashAlpha(t), greaterThan(0));
      await t.pump(const Duration(seconds: 2));
      expect(flashAlpha(t), 0);
    });

    testWidgets('reorden sin actividad nueva no anima', (t) async {
      await pump(t, st(items));
      fake.set(st([items[2], items[0], items[1], items[3]]));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(flashAlpha(t), 0);
    });

    testWidgets('cambio de pestaña con otro chat en la cima no anima', (
      t,
    ) async {
      await pump(t, st(items));
      fake.set(st([items[3], items[1]], tab: ChatTab.issues));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(flashAlpha(t), 0);
    });

    testWidgets('cambio de pestaña con chat de actividad nueva no anima', (
      t,
    ) async {
      await pump(t, st(items));
      fake.set(
        st([
          mk('c2', day: 25),
          items[0],
          items[1],
          items[3],
        ], tab: ChatTab.issues),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(flashAlpha(t), 0);
    });

    testWidgets('animaciones desactivadas: sin destello', (t) async {
      await pump(t, st(items));
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await t.pump();
      fake.set(st([mk('c2', day: 25), items[0], items[1], items[3]]));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(flashAlpha(t), 0);
    });

    testWidgets('badge: pop al aumentar los no leídos, no al montarse', (
      t,
    ) async {
      await pump(t, st([mk('c0', unread: 2), items[1]]));
      Transform popOf() => t.widget<Transform>(
        find
            .descendant(
              of: find.byType(CountPop).first,
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(popOf().transform.storage[0], 1);
      fake.set(st([mk('c0', unread: 3), items[1]]));
      await t.pump();
      await t.pump(); // el ticker arranca en el siguiente frame
      await t.pump(const Duration(milliseconds: 50));
      expect(popOf().transform.storage[0], lessThan(0.95));
      await t.pump(const Duration(seconds: 1));
      expect(popOf().transform.storage[0], 1);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('badge: pop también en 0 -> 1', (t) async {
      await pump(t, st([mk('c0'), items[1]]));
      fake.set(st([mk('c0', unread: 1), items[1]]));
      await t.pump();
      await t.pump(); // el ticker arranca en el siguiente frame
      await t.pump(const Duration(milliseconds: 50));
      final tr = t.widget<Transform>(
        find
            .descendant(
              of: find.byType(CountPop).first,
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(tr.transform.storage[0], isNot(1));
      await t.pump(const Duration(seconds: 1));
    });
  });

  group('ChatTabStrip', () {
    testWidgets('el indicador se desliza a la pestaña elegida', (t) async {
      var tab = ChatTab.all;
      late StateSetter set;
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, s) {
                set = s;
                return SizedBox(
                  height: 48,
                  child: ChatTabStrip(
                    tab: tab,
                    assignedEnabled: true,
                    onTab: (v) => s(() => tab = v),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      final ind = find.byKey(const ValueKey('chat-tab-indicator'));
      final x0 = t.getTopLeft(ind).dx;

      set(() => tab = ChatTab.values.last);
      await t.pump();
      await t.pump(); // medición post-frame + arranque del ticker
      await t.pump(const Duration(milliseconds: 80));
      final xMid = t.getTopLeft(ind).dx;
      await t.pump(const Duration(seconds: 1));
      final x1 = t.getTopLeft(ind).dx;

      expect(x1, greaterThan(x0));
      expect(xMid, greaterThan(x0));
      expect(xMid, isNot(x1));
    });
  });

  testWidgets('ancho de las pestañas estable al cambiar la selección', (
    t,
  ) async {
    var tab = ChatTab.all;
    late StateSetter set;
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, s) {
              set = s;
              return SizedBox(
                height: 48,
                child: ChatTabStrip(
                  tab: tab,
                  assignedEnabled: true,
                  onTab: (_) {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    final first = find.text(ChatTab.values.first.label);
    final w0 = t.getSize(first).width;
    final last = find.text(ChatTab.values.last.label);
    final x0 = t.getTopLeft(last).dx;
    set(() => tab = ChatTab.values.first);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(t.getSize(first).width, w0);
    expect(t.getTopLeft(last).dx, x0);
  });

  testWidgets(
    'badge: solo un Text con el conteo en semántica durante el cambio',
    (t) async {
      final h = t.ensureSemantics();
      var n = 1;
      late StateSetter set;
      await t.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (c, s) {
              set = s;
              return SlideUpSwitcher(value: '$n', child: Text('$n'));
            },
          ),
        ),
      );
      set(() => n = 2);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('1').hitTestable(), findsOneWidget);
      expect(find.bySemanticsLabel('1'), findsNothing);
      expect(find.bySemanticsLabel('2'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      h.dispose();
    },
  );

  group('PfShimmer', () {
    testWidgets('anima y se libera sin dejar ticks', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PfShimmer(child: SizedBox(width: 50))),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(ShaderMask), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('animaciones desactivadas: estático', (t) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PfShimmer(child: SizedBox(width: 50))),
        ),
      );
      expect(find.byType(ShaderMask), findsNothing);
    });
  });
}
