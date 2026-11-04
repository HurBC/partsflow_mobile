import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Router mínimo con la misma estructura que la app: StatefulShellRoute con
// ramas chat=0, orders=1, profile=2 y detalles `:id` sobre el navegador raíz.
void main() {
  late GlobalKey<NavigatorState> rootKey;
  late StatefulNavigationShell? shell;
  late GoRouter router;

  Widget page(String t) => Scaffold(body: Text(t));

  Future<void> pump(
    WidgetTester tester, {
    required bool topLevelDetails,
  }) async {
    rootKey = GlobalKey<NavigatorState>();
    shell = null;
    GoRoute detail(String name) => GoRoute(
      path: ':id',
      parentNavigatorKey: rootKey,
      builder: (_, s) => page('$name-${s.pathParameters['id']}'),
    );
    router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/chat',
      routes: [
        if (topLevelDetails) ...[
          GoRoute(
            path: '/chat/:id',
            parentNavigatorKey: rootKey,
            builder: (_, s) => page('chat-${s.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/orders/:id',
            parentNavigatorKey: rootKey,
            builder: (_, s) => page('order-${s.pathParameters['id']}'),
          ),
        ],
        StatefulShellRoute.indexedStack(
          builder: (_, _, s) {
            shell = s;
            return s;
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chat',
                  builder: (_, _) => page('chat-list'),
                  routes: [if (!topLevelDetails) detail('chat')],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/orders',
                  builder: (_, _) => page('orders-list'),
                  routes: [if (!topLevelDetails) detail('order')],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/profile', builder: (_, _) => page('profile')),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  for (final top in [false, true]) {
    testWidgets('push de detalle de otra rama no cambia la rama activa '
        '(detalles ${top ? "de nivel superior" : "hijos de rama"})', (
      tester,
    ) async {
      await pump(tester, topLevelDetails: top);
      router.go('/orders');
      await tester.pumpAndSettle();
      router.push('/orders/5');
      await tester.pumpAndSettle();
      expect(shell!.currentIndex, 1);

      router.push('/chat/7');
      await tester.pumpAndSettle();
      expect(find.text('chat-7'), findsOneWidget);
      expect(shell!.currentIndex, 1, reason: 'índice tras push');

      router.pop();
      await tester.pumpAndSettle();
      expect(shell!.currentIndex, 1, reason: 'índice tras pop');
      expect(find.text('order-5'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(shell!.currentIndex, 1);
      expect(find.text('orders-list'), findsOneWidget);
    });
  }
}
