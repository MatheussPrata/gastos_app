import 'package:flutter/material.dart';

/// Estado vazio reutilizável com visual moderno (ícone em círculo + CTA).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    super.key,
    this.message,
    this.actionLabel,
    this.onAction,
    this.height = 180,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: scheme.primary),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
