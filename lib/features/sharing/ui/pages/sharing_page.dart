import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/sharing/models/sharing_models.dart';
import 'package:gastos_app/features/sharing/provider/sharing_provider.dart';
import 'package:gastos_app/features/sharing/repository/sharing_repository.dart';

class SharingPage extends ConsumerStatefulWidget {
  const SharingPage({super.key});

  @override
  ConsumerState<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends ConsumerState<SharingPage> {
  final TextEditingController _codeController = TextEditingController();

  SharingConnection? _connection;
  SharingInvite? _invite;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final connection =
          await ref.read(sharingRepositoryProvider).getConnection();
      if (!mounted) return;
      setState(() {
        _connection = connection;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generateInvite() async {
    setState(() => _busy = true);
    try {
      final invite = await ref.read(sharingRepositoryProvider).createInvite();
      if (!mounted) return;
      setState(() => _invite = invite);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      _showError('Digite o codigo de 8 caracteres do outro dispositivo.');
      return;
    }

    setState(() => _busy = true);
    try {
      final connection = await ref.read(sharingRepositoryProvider).join(code);
      if (!mounted) return;
      setState(() {
        _connection = connection;
        _invite = null;
      });
      _codeController.clear();
      _showSuccess('Dispositivos conectados!');
      _syncNow(silent: true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateSharing({
    bool? shareTransactions,
  }) async {
    final connection = _connection;
    if (connection == null) return;

    setState(() => _busy = true);
    try {
      final updated = await ref.read(sharingRepositoryProvider).updateSharing(
            connection,
            shareTransactions: shareTransactions,
          );
      if (!mounted) return;
      setState(() => _connection = updated);
      ref.invalidate(sharingConnectionProvider);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow({bool silent = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await runSharingSync(ref);
      if (!mounted) return;
      if (result.hasPartner) {
        final connection = _connection;
        if (connection != null) {
          setState(() {
            _connection = connection.copyWith(lastSyncedAt: DateTime.now());
          });
        }
      }
      if (!silent) _showSuccess(result.summary);
    } catch (e) {
      if (!silent) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final connection = _connection;
    if (connection == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desconectar parceiro?'),
        content: const Text(
          'Os dados compartilhados pelo parceiro serao removidos deste '
          'dispositivo. Voces podem se conectar de novo com um novo codigo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(sharingRepositoryProvider).disconnect(connection);
      if (!mounted) return;
      setState(() {
        _connection = null;
        _invite = null;
      });
      ref.invalidate(sharingConnectionProvider);
      _showSuccess('Parceiro desconectado.');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.income),
    );
  }

  bool get _isGuest {
    final email = ref.watch(currentUserProvider)?.email ?? '';
    return email.endsWith('@local');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compartilhamento')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isGuest)
                    const _GuestWarning()
                  else if (_connection != null)
                    ..._buildConnected(context, _connection!)
                  else
                    ..._buildDisconnected(context),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorCard(message: _error!, onRetry: _load),
                  ],
                ],
              ),
            ),
    );
  }

  List<Widget> _buildConnected(
    BuildContext context,
    SharingConnection connection,
  ) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.people, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                connection.partnerUsername,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Dispositivos conectados',
                style: TextStyle(color: Colors.green),
              ),
              const SizedBox(height: 8),
              Text(
                connection.lastSyncedAt == null
                    ? 'Ainda nao sincronizado'
                    : 'Ultima sincronizacao: ${_formatDateTime(connection.lastSyncedAt!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        'O que voce compartilha',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Text(
        'Estas opcoes valem para os dados que saem deste dispositivo. '
        'O que voce recebe depende das escolhas do seu parceiro.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.receipt_long_outlined),
              title: const Text('Compartilhar gastos'),
              subtitle: const Text('Lancamentos e despesas'),
              value: connection.shareTransactions,
              onChanged: _busy
                  ? null
                  : (value) => _updateSharing(shareTransactions: value),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _busy ? null : () => _syncNow(),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        label: const Text('Sincronizar agora'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _busy ? null : _disconnect,
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        icon: const Icon(Icons.link_off),
        label: const Text('Desconectar'),
      ),
    ];
  }

  List<Widget> _buildDisconnected(BuildContext context) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.devices, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'Conecte dois dispositivos',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Compartilhe gastos e/ou a lista de compras com outra pessoa. '
                'Cada dispositivo precisa de uma conta propria.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '1. Gere o codigo neste dispositivo',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_invite == null)
                const Text(
                  'O codigo vale por 24 horas e pode ser usado uma vez.',
                  textAlign: TextAlign.center,
                )
              else ...[
                SelectableText(
                  _invite!.code,
                  style: const TextStyle(
                    fontSize: 32,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Valido ate ${_formatDateTime(_invite!.expiresAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _invite!.code),
                    );
                    if (!mounted) return;
                    _showSuccess('Codigo copiado.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar codigo'),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _generateInvite,
                icon: const Icon(Icons.qr_code),
                label: Text(
                  _invite == null
                      ? 'Gerar codigo de convite'
                      : 'Gerar novo codigo',
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '2. Ou insira o codigo do outro dispositivo',
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 8,
                onChanged: (value) {
                  final upper = value.toUpperCase();
                  if (upper != value) {
                    _codeController.value = TextEditingValue(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Codigo do parceiro',
                  hintText: 'ABCD1234',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _join,
                  icon: const Icon(Icons.link),
                  label: const Text('Conectar com parceiro'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Dica: os dois dispositivos precisam estar logados em contas diferentes. '
        'Depois de conectar, escolha acima o que deseja compartilhar.',
        style: TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ];
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _GuestWarning extends StatelessWidget {
  const _GuestWarning();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.withOpacity(0.12),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Voce esta no modo convidado (offline). Para conectar dois '
                'dispositivos, crie uma conta ou entre com uma conta existente.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
