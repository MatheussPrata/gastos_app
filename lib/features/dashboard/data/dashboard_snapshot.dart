import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/features/transactions/models/transaction_models.dart';

const _prefsKey = 'dashboard_snapshot_v2';
const _maxItems = 800;

/// Ultimo estado da tela inicial, guardado para abrir instantaneamente.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.monthKey,
    required this.transactions,
    required this.savedAt,
  });

  final String monthKey;
  final List<Transaction> transactions;
  final DateTime savedAt;
}

String monthKeyOf(DateTime month) =>
    '${month.year}-${month.month.toString().padLeft(2, '0')}';

Future<DashboardSnapshot?> loadDashboardSnapshot() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final monthKey = map['monthKey'] as String?;
    final items = map['transactions'] as List?;
    if (monthKey == null || items == null) return null;

    final transactions = <Transaction>[];
    for (final item in items.take(_maxItems)) {
      try {
        transactions.add(
          Transaction.fromJson(Map<String, dynamic>.from(item as Map)),
        );
      } catch (_) {
        // Item antigo/incompativel: ignora o snapshot inteiro? Melhor seguir
        // com os que decodificaram; a consulta real substitui logo em seguida.
      }
    }

    return DashboardSnapshot(
      monthKey: monthKey,
      transactions: transactions,
      savedAt: DateTime.tryParse(map['savedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  } catch (_) {
    return null;
  }
}

Future<void> saveDashboardSnapshot(
  DateTime month,
  List<Transaction> transactions,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'monthKey': monthKeyOf(month),
      'savedAt': DateTime.now().toIso8601String(),
      'transactions': [
        for (final transaction in transactions.take(_maxItems))
          transaction.toJson(),
      ],
    };
    await prefs.setString(_prefsKey, jsonEncode(payload));
  } catch (_) {
    // Snapshot e so uma otimizacao: nunca impede o app de funcionar.
  }
}

final dashboardSnapshotProvider =
    FutureProvider<DashboardSnapshot?>((ref) => loadDashboardSnapshot());
