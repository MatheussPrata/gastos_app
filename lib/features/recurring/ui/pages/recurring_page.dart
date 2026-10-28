import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_flutter/core/router/app_router.dart';
import 'package:gastos_flutter/core/theme/app_theme.dart';

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorrentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go(RouteNames.recurringForm, extra: {'isEditing': false}),
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.repeat_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Transações Recorrentes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Lista de recorrentes (implementar)', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(RouteNames.recurringForm, extra: {'isEditing': false}),
        child: const Icon(Icons.add),
      ),
    );
  }
}