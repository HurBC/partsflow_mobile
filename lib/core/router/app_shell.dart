import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/router/app_routes.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required Widget child}) : _child = child;

  final Widget _child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) =>
            _onDestinationSelected(index, context),
        destinations: [
          Icon(Icons.list_alt_outlined),
          Icon(Icons.chat_bubble_outlined),
          Icon(Icons.person_outlined),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    if (location.startsWith(AppRoutes.chat)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 2;

    return 0;
  }

  void _onDestinationSelected(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.orders);
      case 1:
        context.go(AppRoutes.chat);
      case 2:
        context.go(AppRoutes.profile);
    }
  }
}
