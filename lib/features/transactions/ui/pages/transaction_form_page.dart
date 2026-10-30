import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';

class TransactionFormPage extends ConsumerWidget {
  final String? transactionId;
  final bool isEditing;

  const TransactionFormPage({
    super.key,
    this.transactionId,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Transação' : 'Nova Transação'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isEditing ? Icons.edit_outlined : Icons.add_outlined,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Editar Transação' : 'Nova Transação',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Formulário de transação (implementar)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}