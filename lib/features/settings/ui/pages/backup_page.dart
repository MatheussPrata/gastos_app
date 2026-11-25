import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import 'package:gastos_app/core/sync/sync_provider.dart';
import 'package:gastos_app/features/settings/services/backup_service.dart';

/// Tela para exportar/compartilhar backups completos em JSON e restaurar dados.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  List<BackupFileInfo> _backups = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(backupServiceProvider).listLocalBackups();
      if (!mounted) return;
      setState(() {
        _backups = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _exportAndShare() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).exportAndShareBackup();
      await _loadBackups();
      if (!mounted) return;
      _showSnack('Backup gerado e pronto para salvar ou enviar.');
    } catch (e) {
      if (mounted) _showSnack('Falha ao exportar backup: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLocalOnly() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await ref.read(backupServiceProvider).createLocalBackupFile();
      await _loadBackups();
      if (!mounted) return;
      _showSnack('Cópia salva em ${p.basename(file.path)}.');
    } catch (e) {
      if (mounted) _showSnack('Falha ao salvar cópia: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareBackup(BackupFileInfo item) async {
    try {
      await Share.shareXFiles(
        [XFile(item.file.path, mimeType: 'application/json')],
        subject: 'Backup Kuanto',
        text: 'Backup completo dos dados do Kuanto',
        fileNameOverrides: [item.fileName],
      );
    } catch (e) {
      if (mounted) _showSnack('Falha ao compartilhar: $e', isError: true);
    }
  }

  Future<void> _confirmRestoreFile(BackupFileInfo item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: Text(
          'Os dados locais atuais serão substituídos pelo conteúdo de '
          '"${item.fileName}". Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(backupServiceProvider).restoreFromFile(item.file);
      if (!mounted) return;
      invalidateSyncedData(ref);
      _showSnack(result.summary);
    } catch (e) {
      if (mounted) _showSnack('Erro ao restaurar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRestoreFromJsonDialog() async {
    final controller = TextEditingController();
    final rawJson = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar colando JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cole abaixo o conteúdo completo do arquivo de backup (.json). '
                'Os dados locais atuais serão substituídos.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 7,
                decoration: const InputDecoration(
                  hintText: '{"app":"kuanto","version":1,...}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (rawJson == null || rawJson.trim().isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(backupServiceProvider).restoreFromJsonString(rawJson);
      if (!mounted) return;
      invalidateSyncedData(ref);
      _showSnack(result.summary);
    } catch (e) {
      if (mounted) _showSnack('Erro ao restaurar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBackup(BackupFileInfo item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir backup local?'),
        content: Text('Remover "${item.fileName}" deste aparelho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(backupServiceProvider).deleteLocalBackup(item.file);
    await _loadBackups();
    if (mounted) _showSnack('Backup removido.');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup e restauração'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Seus dados em formato JSON',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inclui transações, cupons fiscais, cartões, faturas, '
                    'recorrências, planejamento, alertas, categorias e metas.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _exportAndShare,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Exportar e compartilhar backup (.json)'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _saveLocalOnly,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar cópia no aparelho'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _showRestoreFromJsonDialog,
                    icon: const Icon(Icons.restore_page_outlined),
                    label: const Text('Restaurar colando JSON'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Backups salvos no aparelho',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              IconButton(
                tooltip: 'Atualizar lista',
                onPressed: _loading ? null : _loadBackups,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_backups.isEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Nenhum backup salvo localmente ainda. Toque em '
                  '"Salvar cópia no aparelho" ou "Exportar" acima.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else
            for (final item in _backups)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${_formatDateTime(item.modifiedAt)} • '
                    '${_formatSize(item.sizeBytes)}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'share') _shareBackup(item);
                      if (action == 'restore') _confirmRestoreFile(item);
                      if (action == 'delete') _deleteBackup(item);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'share', child: Text('Compartilhar')),
                      PopupMenuItem(
                          value: 'restore', child: Text('Restaurar')),
                      PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
