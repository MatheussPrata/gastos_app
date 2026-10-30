import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_flutter/core/router/app_router.dart';
import 'package:gastos_flutter/core/theme/app_theme.dart';
import 'package:gastos_flutter/features/auth/provider/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
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
                  user?.username?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(user?.username ?? 'Usuário'),
              subtitle: Text(user?.email ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Appearance section
          const Text('Aparência', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.brightness_6),
                  title: const Text('Tema'),
                  subtitle: Text(
                    themeMode == ThemeMode.light ? 'Claro' :
                    themeMode == ThemeMode.dark ? 'Escuro' : 'Sistema',
                  ),
                  trailing: PopupMenuButton<ThemeMode>(
                    initialValue: themeMode,
                    onSelected: (mode) => ref.read(themeModeProvider.notifier).state = mode,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: ThemeMode.system, child: Text('Sistema')),
                      const PopupMenuItem(value: ThemeMode.light, child: Text('Claro')),
                      const PopupMenuItem(value: ThemeMode.dark, child: Text('Escuro')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.color_lens),
                  title: const Text('Cor principal'),
                  subtitle: const Text('Personalizar cores (implementar)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Data section
          const Text('Dados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  subtitle: const Text('Forçar sincronização com o servidor'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Compartilhamento'),
                  subtitle: const Text('Conectar com parceiro'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Account section
          const Text('Conta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  title: const Text('Excluir conta', style: TextStyle(color: Colors.red)),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.primary),
                  title: const Text('Sair', style: TextStyle(color: AppColors.primary)),
                  onTap: () async {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // About section
          const Text('Sobre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Versão do app'),
              subtitle: const Text('1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}