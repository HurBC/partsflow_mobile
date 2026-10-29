import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/providers/auth_state_provider.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/router/app_shell.dart';
import 'package:partsflow_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:partsflow_mobile/features/auth/presentation/pages/new_password_page.dart';
import 'package:partsflow_mobile/features/chat/domain/entities/chat.dart';
import 'package:partsflow_mobile/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:partsflow_mobile/features/chat/presentation/pages/chat_list_page.dart';
import 'package:partsflow_mobile/features/orders/domain/entities/order.dart';
import 'package:partsflow_mobile/features/orders/presentation/pages/order_detail_page.dart';
import 'package:partsflow_mobile/features/orders/presentation/pages/orders_page.dart';
import 'package:partsflow_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

typedef NewPasswordArgs = ({String email, String session});

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final notifier = RouterNotifier(ref);
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.chat,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      return authState.when(
        data: (isAuthenticated) {
          final isOnLogin = state.matchedLocation.startsWith(AppRoutes.login);

          if (!isAuthenticated && !isOnLogin) return AppRoutes.login;
          if (isAuthenticated && isOnLogin) return AppRoutes.chat;

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
        routes: [
          GoRoute(
            path: 'nueva-contrasena',
            // Sin email+session (p. ej. tras reiniciar la app) se vuelve al login.
            redirect: (context, state) =>
                state.extra is NewPasswordArgs ? null : AppRoutes.login,
            builder: (context, state) {
              final args = state.extra as NewPasswordArgs;
              return NewPasswordPage(email: args.email, session: args.session);
            },
          ),
        ],
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
                // Sobre el shell (sin barra inferior) para dejar libre el botón
                // de mover etapa. El pedido en `extra` es opcional (se muestra
                // mientras carga el detalle).
                parentNavigatorKey: rootNavigatorKey,
                redirect: (context, state) =>
                    int.tryParse(state.pathParameters["id"] ?? "") == null
                    ? AppRoutes.orders
                    : null,
                builder: (context, state) => OrderDetailPage(
                  id: int.parse(state.pathParameters["id"]!),
                  initial: state.extra is OrderSummary
                      ? state.extra as OrderSummary
                      : null,
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.chat,
            builder: (context, state) => const ChatListPage(),
            routes: [
              GoRoute(
                path: ":id",
                // Se abre sobre el shell (sin barra inferior) para dejar el
                // compositor libre. Sin el Chat en `extra` (p. ej. tras
                // reiniciar la app) se vuelve a la lista.
                parentNavigatorKey: rootNavigatorKey,
                redirect: (context, state) =>
                    state.extra is Chat ? null : AppRoutes.chat,
                builder: (context, state) =>
                    ChatDetailPage(chat: state.extra as Chat),
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
