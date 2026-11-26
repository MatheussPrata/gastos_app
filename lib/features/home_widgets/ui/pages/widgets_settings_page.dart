import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/home_widgets/models/home_widget_models.dart';
import 'package:gastos_app/features/home_widgets/services/home_widget_service.dart';

/// Tela para configurar, pré-visualizar e adicionar os widgets da tela inicial.
class WidgetsSettingsPage extends ConsumerStatefulWidget {
  /// Cria a tela de gerenciamento de widgets da tela inicial.
  const WidgetsSettingsPage({super.key});

  @override
  ConsumerState<WidgetsSettingsPage> createState() =>
      _WidgetsSettingsPageState();
}

class _WidgetsSettingsPageState extends ConsumerState<WidgetsSettingsPage> {
  final HomeWidgetService _service = HomeWidgetService.instance;

  bool _loading = true;
  bool _syncing = false;
  bool _hideValues = false;
  bool _pinSupported = false;
  List<ActiveChartWidgetConfig> _activeCharts = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadState());
  }

  Future<void> _loadState() async {
    final results = await Future.wait([
      _service.getHideValues(),
      _service.isPinWidgetSupported(),
      _service.getActiveChartWidgets(),
    ]);
    if (!mounted) return;
    setState(() {
      _hideValues = results[0] as bool;
      _pinSupported = results[1] as bool;
      _activeCharts = results[2] as List<ActiveChartWidgetConfig>;
      _loading = false;
    });
  }

  Future<void> _togglePrivacy(bool value) async {
    setState(() => _hideValues = value);
    await _service.setHideValues(hide: value);
  }

  Future<void> _forceSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final themeMode = ref.read(themeModeProvider);
    final primaryColor = ref.read(themeColorProvider);
    await _service.syncNow(
      themeMode: themeMode,
      primaryColor: primaryColor,
    );
    await _loadState();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Widgets atualizados com os dados atuais.')),
    );
  }

  Future<void> _pinWidget(HomeWidgetKind kind) async {
    final themeMode = ref.read(themeModeProvider);
    final primaryColor = ref.read(themeColorProvider);
    await _service.syncNow(
      themeMode: themeMode,
      primaryColor: primaryColor,
    );
    final requested = await _service.requestPinWidget(kind);
    if (!mounted) return;

    if (requested) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Confirme no sistema para adicionar "${kind.title}" à tela inicial.',
          ),
        ),
      );
      await _loadState();
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adicionar "${kind.title}"'),
        content: const Text(
          'Pressione e segure uma área vazia da tela inicial do aparelho, '
          'toque em "Widgets", procure por "Kuanto" e arraste o widget desejado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _editChartWidget(ActiveChartWidgetConfig config) async {
    var selectedType = config.chartType;
    var selectedPeriod = config.period;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Gráfico #${config.widgetId}',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Escolha qual gráfico e período exibir neste widget.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final type in HomeWidgetChartType.values)
                            RadioListTile<HomeWidgetChartType>(
                              value: type,
                              groupValue: selectedType,
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(type.label),
                              subtitle: Text(
                                type.description,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onChanged: (value) {
                                if (value == null) return;
                                setSheetState(() => selectedType = value);
                              },
                            ),
                          const SizedBox(height: 10),
                          const Text(
                            'Período',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<HomeWidgetPeriod>(
                            showSelectedIcon: false,
                            segments: [
                              for (final period in HomeWidgetPeriod.values)
                                ButtonSegment(
                                  value: period,
                                  label: Text(period.label),
                                ),
                            ],
                            selected: {selectedPeriod},
                            onSelectionChanged: (selection) {
                              setSheetState(
                                () => selectedPeriod = selection.first,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Aplicar no widget'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (saved != true || !mounted) return;
    await _service.configureChartWidget(
      widgetId: config.widgetId,
      chartType: selectedType,
      period: selectedPeriod,
    );
    await _loadState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Widget atualizado para "${selectedType.label}" (${selectedPeriod.label}).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widgets da tela inicial'),
        actions: [
          IconButton(
            tooltip: 'Atualizar widgets agora',
            onPressed: _syncing ? null : _forceSync,
            icon: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 28),
              children: [
                Card(
                  child: SwitchListTile(
                    secondary: Icon(
                      _hideValues
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    title: const Text('Ocultar valores nos widgets'),
                    subtitle: const Text(
                      r'Substitui valores em R$ por •••• na tela inicial. '
                      'Você também pode alternar direto pelo widget de resumo.',
                    ),
                    value: _hideValues,
                    onChanged: _togglePrivacy,
                  ),
                ),
                if (_activeCharts.isNotEmpty) ...[
                  const _SectionHeader('Gráficos ativos na tela inicial'),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < _activeCharts.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.pie_chart_outline),
                            ),
                            title: Text(_activeCharts[i].chartType.label),
                            subtitle: Text(
                              'Widget #${_activeCharts[i].widgetId} • '
                              '${_activeCharts[i].period.label}',
                            ),
                            trailing: TextButton(
                              onPressed: () =>
                                  _editChartWidget(_activeCharts[i]),
                              child: const Text('Trocar gráfico'),
                            ),
                            onTap: () => _editChartWidget(_activeCharts[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const _SectionHeader('Widgets disponíveis'),
                for (final kind in HomeWidgetKind.values)
                  _WidgetCatalogCard(
                    kind: kind,
                    hideValues: _hideValues,
                    pinSupported: _pinSupported,
                    onAdd: () => _pinWidget(kind),
                  ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _WidgetCatalogCard extends StatelessWidget {
  const _WidgetCatalogCard({
    required this.kind,
    required this.hideValues,
    required this.pinSupported,
    required this.onAdd,
  });

  final HomeWidgetKind kind;
  final bool hideValues;
  final bool pinSupported;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    kind.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    kind.sizeBadge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              kind.subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            _WidgetPreviewBox(kind: kind, hideValues: hideValues),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: Icon(
                  pinSupported ? Icons.add_to_home_screen : Icons.info_outline,
                  size: 18,
                ),
                label: Text(
                  pinSupported
                      ? 'Adicionar à tela inicial'
                      : 'Como adicionar à tela inicial',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetPreviewBox extends StatelessWidget {
  const _WidgetPreviewBox({
    required this.kind,
    required this.hideValues,
  });

  final HomeWidgetKind kind;
  final bool hideValues;

  String _money(String sample) => hideValues ? r'R$ ••••' : sample;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A1220) : const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.5),
        ),
      ),
      child: switch (kind) {
        HomeWidgetKind.quickAdd => Row(
            children: [
              _previewPill(Icons.remove, 'Gasto', AppColors.expense),
              const SizedBox(width: 6),
              _previewPill(Icons.add, 'Entrada', AppColors.income),
              const SizedBox(width: 6),
              _previewPill(Icons.qr_code_scanner, 'Cupom', scheme.primary),
            ],
          ),
        HomeWidgetKind.chart => Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendLine(
                      AppColors.categoryColors[0],
                      'Alimentação',
                      hideValues ? '42%' : r'R$ 920',
                    ),
                    const SizedBox(height: 6),
                    _legendLine(
                      AppColors.categoryColors[1],
                      'Transporte',
                      hideValues ? '24%' : r'R$ 540',
                    ),
                    const SizedBox(height: 6),
                    _legendLine(
                      AppColors.categoryColors[2],
                      'Compras',
                      hideValues ? '18%' : r'R$ 390',
                    ),
                  ],
                ),
              ),
            ],
          ),
        HomeWidgetKind.summary => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saldo do mês',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    '+ ${_money(r'R$ 5.200')}  •  - ${_money(r'R$ 2.750')}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _money(r'R$ 2.450,00'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.income,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.68,
                  minHeight: 5,
                  color: AppColors.income,
                  backgroundColor: AppColors.income.withOpacity(0.18),
                ),
              ),
            ],
          ),
        HomeWidgetKind.upcomingBills => Column(
            children: [
              _billPreviewRow(
                AppColors.expense,
                'Fatura Cartão',
                'Hoje',
                _money(r'R$ 850,00'),
              ),
              const SizedBox(height: 6),
              _billPreviewRow(
                AppColors.warning,
                'Internet Fibra',
                'Em 2d',
                _money(r'R$ 120,00'),
              ),
            ],
          ),
      },
    );
  }

  Widget _previewPill(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendLine(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _billPreviewRow(
    Color dotColor,
    String title,
    String due,
    String amount,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          due,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        Text(
          amount,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
