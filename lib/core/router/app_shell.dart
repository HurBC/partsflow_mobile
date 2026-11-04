import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:partsflow_mobile/core/router/tab_visibility.dart';
import 'package:partsflow_mobile/core/theme/pf_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final pf = PfColors.of(context);

    return Scaffold(
      body: TabVisibility(
        activeIndex: navigationShell.currentIndex,
        child: navigationShell,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: pf.divider)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          // Volver a tocar la tab activa regresa a su raíz.
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
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
}
