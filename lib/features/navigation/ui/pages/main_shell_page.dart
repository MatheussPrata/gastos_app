import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/features/dashboard/ui/pages/dashboard_page.dart';
import 'package:gastos_app/features/navigation/provider/navigation_provider.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/ui/pages/planning_page.dart';
import 'package:gastos_app/features/reports/ui/pages/reports_page.dart';
import 'package:gastos_app/features/sharing/provider/sharing_provider.dart';

/// Main application shell.
///
/// The four primary screens live inside an [IndexedStack] so their state and
/// scroll position are preserved while the user switches tabs. Only the
/// selected index changes, which keeps rebuilds scoped to the shell and the
/// active tab.
class MainShellPage extends ConsumerStatefulWidget {
  const MainShellPage({super.key});

  static const List<Widget> _pages = [
    DashboardPage(),
    ReportsPage(),
    PlanningPage(),
  ];

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _silentSync());
  }

  Future<void> _silentSync() async {
    try {
      await runSharingSync(ref);
    } catch (_) {
      // Offline or not configured: local data continues to work.
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(bottomNavIndexProvider);
    final unreadAlerts = ref.watch(unreadAlertCountProvider);

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
          children: MainShellPage._pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            if (index == selectedIndex) return;
            ref.read(bottomNavIndexProvider.notifier).state = index;
          },
          destinations: [
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
              icon: Badge(
                isLabelVisible: unreadAlerts > 0,
                label: Text('$unreadAlerts'),
                child: const Icon(Icons.savings_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: unreadAlerts > 0,
                label: Text('$unreadAlerts'),
                child: const Icon(Icons.savings),
              ),
              label: 'Planejamento',
              tooltip: 'Planejamento financeiro',
            ),
          ],
        ),
      ),
    );
  }
}
