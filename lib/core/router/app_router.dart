import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/router/app_shell.dart';
import 'package:partsflow_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:partsflow_mobile/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:partsflow_mobile/features/chat/presentation/pages/chat_list_page.dart';
import 'package:partsflow_mobile/features/orders/presentation/pages/order_detail_page.dart';
import 'package:partsflow_mobile/features/orders/presentation/pages/orders_page.dart';
import 'package:partsflow_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.orders,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      return authState.when(
        data: (isAuthenticated) {
          final isOnLogin = state.matchedLocation == AppRoutes.login;

          if (!isAuthenticated && !isOnLogin) return AppRoutes.login;
          if (isAuthenticated && isOnLogin) return AppRoutes.orders;

          return null;
        },
        error: (_, _) => AppRoutes.login,
        loading: () => null,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.orders,
            builder: (context, state) => const OrdersPage(),
            routes: [
              GoRoute(
                path: ":id",
                builder: (context, state) =>
                    OrderDetailPage(id: state.pathParameters["id"]!),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.chat,
            builder: (context, state) => const ChatListPage(),
            routes: [
              GoRoute(
                path: ":id",
                builder: (context, state) =>
                    ChatDetailPage(id: state.pathParameters["id"]!),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
}
