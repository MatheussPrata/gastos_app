import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/app_info.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/navigation/provider/navigation_provider.dart';
import 'package:gastos_app/features/settings/ui/widgets/theme_color_picker.dart';
import 'package:gastos_app/features/sharing/provider/sharing_provider.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_cards_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User section
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Text(
                  user?.username.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(user?.username ?? 'Usuário'),
              subtitle: Text(user?.email ?? ''),
            ),
          ),
          const SizedBox(height: 16),

          // Appearance section
          const Text('Aparência',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Tema'),
                  subtitle: Text(
                    themeMode == ThemeMode.light
                        ? 'Claro'
                        : themeMode == ThemeMode.dark
                            ? 'Escuro'
                            : 'Sistema',
                  ),
                  trailing: PopupMenuButton<ThemeMode>(
                    initialValue: themeMode,
                    onSelected: (mode) =>
                        ref.read(themeModeProvider.notifier).state = mode,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: ThemeMode.system, child: Text('Sistema')),
                      const PopupMenuItem(
                          value: ThemeMode.light, child: Text('Claro')),
                      const PopupMenuItem(
                          value: ThemeMode.dark, child: Text('Escuro')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.color_lens),
                  title: const Text('Cor principal'),
                  subtitle: const Text('Toque para escolher'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: ref.watch(themeColorProvider),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ThemeColorPickerDialog(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Organization section
          const Text('Organização',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.credit_card_outlined),
                  title: const Text('Cartões de crédito'),
                  subtitle: const Text('Gerenciar faturas, limites e datas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreditCardsPage()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Categorias de gastos'),
                  subtitle: const Text('Alimentação, Transporte, Moradia…'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RouteNames.categories),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Todas as transações'),
                  subtitle: const Text('Histórico completo de lançamentos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RouteNames.transactions),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.repeat),
                  title: const Text('Transações recorrentes'),
                  subtitle: const Text('Contas fixas e assinaturas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RouteNames.recurring),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data section
          const Text('Dados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('Backup no Google Drive'),
                  subtitle: const Text('Fazer backup dos dados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync),
                  title: const Text('Sincronizar agora'),
                  subtitle:
                      const Text('Enviar dados locais e receber do parceiro'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final result = await runSharingSync(ref);
                      messenger.showSnackBar(
                        SnackBar(content: Text(result.summary)),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Compartilhamento'),
                  subtitle: const Text(
                      'Conectar com parceiro e escolher o que compartilhar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RouteNames.sharing),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account section
          const Text('Conta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Alterar senha'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Excluir conta',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.primary),
                  title: const Text('Sair',
                      style: TextStyle(color: AppColors.primary)),
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    ref.read(bottomNavIndexProvider.notifier).state =
                        AppTab.home;
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About section
          const Text('Sobre',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Versão do app'),
              subtitle: Text(
                ref.watch(appVersionProvider).valueOrNull ?? 'Carregando...',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
