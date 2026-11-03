import 'package:flutter/material.dart';

import 'package:gastos_app/features/planning/models/planning_models.dart';

/// Dialog to edit the alert thresholds of the current plan.
///
/// Pops with the new [NotificationSettings], or null when cancelled. Persisting
/// is the caller's responsibility, so it works both from the planning page and
/// from the setup screen (which saves everything at once).
class NotificationSettingsDialog extends StatefulWidget {
  const NotificationSettingsDialog({super.key, required this.settings});

  final NotificationSettings settings;

  @override
  State<NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<NotificationSettingsDialog> {
  static const _availableThresholds = [50, 80, 90, 100];

  late bool _enabled;
  late bool _push;
  late bool _inApp;
  late Set<int> _thresholds;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.enabled;
    _push = widget.settings.pushNotification;
    _inApp = widget.settings.inAppNotification;
    _thresholds = widget.settings.thresholds.toSet();
  }

  void _save() {
    final sorted = _thresholds.toList()..sort();
    Navigator.of(context).pop(
      NotificationSettings(
        enabled: _enabled,
        thresholds: sorted,
        pushNotification: _push,
        inAppNotification: _inApp,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Alertas de limite'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativar alertas'),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 4),
            Text(
              'Avisar quando a categoria atingir:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final threshold in _availableThresholds)
                  FilterChip(
                    label: Text('$threshold%'),
                    selected: _thresholds.contains(threshold),
                    onSelected: !_enabled
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected) {
                                _thresholds.add(threshold);
                              } else {
                                _thresholds.remove(threshold);
                              }
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Aviso no aplicativo'),
              value: _inApp,
              onChanged:
                  !_enabled ? null : (value) => setState(() => _inApp = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notificação push'),
              subtitle: const Text('Disponível na próxima atualização'),
              value: _push,
              onChanged:
                  !_enabled ? null : (value) => setState(() => _push = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
