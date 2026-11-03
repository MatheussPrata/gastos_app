import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/theme/app_theme.dart';

/// Dialog to choose the app's primary color.
class ThemeColorPickerDialog extends ConsumerWidget {
  const ThemeColorPickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeColorProvider);

    return AlertDialog(
      title: const Text('Cor principal'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final color in kThemeSeedColors)
            InkWell(
              onTap: () {
                ref.read(themeColorProvider.notifier).setColor(color);
                Navigator.of(context).pop();
              },
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == selected
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: color == selected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
