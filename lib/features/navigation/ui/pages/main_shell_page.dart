import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/features/dashboard/ui/pages/dashboard_page.dart';
import 'package:gastos_app/features/navigation/provider/navigation_provider.dart';
import 'package:gastos_app/features/reports/ui/pages/reports_page.dart';
import 'package:gastos_app/features/settings/ui/pages/settings_page.dart';
import 'package:gastos_app/features/shopping/ui/pages/shopping_page.dart';

/// Main application shell.
///
/// The four primary screens live inside an [IndexedStack] so their state and
/// scroll position are preserved while the user switches tabs. Only the
/// selected index changes, which keeps rebuilds scoped to the shell and the
/// active tab.
class MainShellPage extends ConsumerWidget {
  const MainShellPage({super.key});

  static const List<Widget> _pages = [
    DashboardPage(),
    ReportsPage(),
    ShoppingPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(bottomNavIndexProvider);

    return PopScope(
      // On secondary tabs, back returns to the home tab before exiting.
      canPop: selectedIndex == AppTab.home,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(bottomNavIndexProvider.notifier).state = AppTab.home;
      },
      child: Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            if (index == selectedIndex) return;
            ref.read(bottomNavIndexProvider.notifier).state = index;
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Início',
              tooltip: 'Início',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Relatórios',
              tooltip: 'Relatórios',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Compras',
              tooltip: 'Lista de Compras',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Configurações',
              tooltip: 'Configurações',
            ),
          ],
        ),
      ),
    );
  }
}
