import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required Widget child}) : _child = child;

  final Widget _child;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return Scaffold(
      body: _child,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: pf.divider)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex(context),
          onDestinationSelected: (index) =>
              _onDestinationSelected(index, context),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Pedidos',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location.startsWith(AppRoutes.orders)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 2;

    return 0;
  }

  void _onDestinationSelected(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.chat);
      case 1:
        context.go(AppRoutes.orders);
      case 2:
        context.go(AppRoutes.profile);
    }
  }
}
