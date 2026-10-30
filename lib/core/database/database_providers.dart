import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/database/app_database.dart';

/// AppDatabase provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// Database dispose on app close (optional)
final databaseDisposerProvider = Provider<void>((ref) {
  final database = ref.watch(databaseProvider);
  ref.onDispose(() {
    database.close();
  });
});