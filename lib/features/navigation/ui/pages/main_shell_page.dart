import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/sync/sync_provider.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_cards_page.dart';
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
    CreditCardsPage(),
    PlanningPage(),
    ReportsPage(),
  ];

  @override
  ConsumerState<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends ConsumerState<MainShellPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Deixa a UI ler o banco local primeiro (offline-first).
      // O sync roda depois, sem competir com a primeira renderizacao.
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _silentSync();
      });
    });
  }

  Future<void> _silentSync() async {
    try {
      // Restaura num aparelho vazio e envia o que ficou pendente.
      await runStartupSync(ref);
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
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  height: 68,
                  selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            if (index == selectedIndex) return;
            ref.read(bottomNavIndexProvider.notifier).state = index;
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Início',
              tooltip: 'Início',
            ),
            const NavigationDestination(
              icon: Icon(Icons.credit_card_outlined),
              selectedIcon: Icon(Icons.credit_card),
              label: 'Cartões',
              tooltip: 'Cartões de crédito',
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
            const NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Relatórios',
              tooltip: 'Relatórios',
            ),
          ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
