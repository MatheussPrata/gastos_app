import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/sharing/models/sharing_models.dart';
import 'package:gastos_app/features/transactions/repository/transactions_repository.dart';

final sharingRepositoryProvider = Provider<SharingRepository>((ref) {
  return SharingRepository();
});

/// Cliente do compartilhamento entre duas contas/dispositivos.
class SharingRepository {
  SharingRepository({
    DioClient? dioClient,
    db.AppDatabase? database,
    FlutterSecureStorage? storage,
  })  : _dioClient = dioClient ?? DioClient(),
        _db = database ?? db.AppDatabase(),
        _storage = storage ?? const FlutterSecureStorage();

  static const String _cacheKey = 'sharing_connection';

  final DioClient _dioClient;
  final db.AppDatabase _db;
  final FlutterSecureStorage _storage;

  /// Busca a conexao no servidor. Se estiver offline, usa o cache local.
  Future<SharingConnection?> getConnection() async {
    if (await _isGuestMode()) return null;

    try {
      final response = await _dioClient.dio.get(ApiEndpoints.connections);
      final data = response.data is Map ? response.data['data'] : null;
      final connectionJson = data is Map ? data['connection'] : null;

      final prefs = await SharedPreferences.getInstance();
      if (connectionJson is Map<String, dynamic>) {
        final connection = SharingConnection.fromJson(connectionJson);
        await prefs.setString(_cacheKey, jsonEncode(connection.toJson()));
        return connection;
      }

      await prefs.remove(_cacheKey);
      return null;
    } on DioException catch (e) {
      final cached = await getCachedConnection();
      if (cached != null) return cached;
      throw SharingException(_messageFor(e));
    }
  }

  Future<SharingConnection?> getCachedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SharingConnection.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<SharingInvite> createInvite() async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiEndpoints.connections}/invite',
      );
      final data = response.data is Map ? response.data['data'] : null;
      if (data is! Map<String, dynamic>) {
        throw const SharingException('Resposta invalida do servidor');
      }
      return SharingInvite.fromJson(data);
    } on DioException catch (e) {
      throw SharingException(_messageFor(e));
    }
  }

  Future<SharingConnection> join(String code) async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiEndpoints.connections}/join',
        data: {'inviteCode': code.trim().toUpperCase()},
      );
      final data = response.data is Map ? response.data['data'] : null;
      final connectionJson = data is Map ? data['connection'] : null;
      if (connectionJson is! Map<String, dynamic>) {
        throw const SharingException('Resposta invalida do servidor');
      }
      final connection = SharingConnection.fromJson(connectionJson);
      await _cacheConnection(connection);
      return connection;
    } on DioException catch (e) {
      throw SharingException(_messageFor(e));
    }
  }

  Future<SharingConnection> updateSharing(
    SharingConnection connection, {
    bool? shareTransactions,
  }) async {
    try {
      final response = await _dioClient.dio.patch(
        '${ApiEndpoints.connections}/${connection.id}',
        data: {
          if (shareTransactions != null) 'shareTransactions': shareTransactions,
        },
      );
      final data = response.data is Map ? response.data['data'] : null;
      final connectionJson = data is Map ? data['connection'] : null;
      if (connectionJson is! Map<String, dynamic>) {
        throw const SharingException('Resposta invalida do servidor');
      }
      final updated = SharingConnection.fromJson(connectionJson);
      await _cacheConnection(updated);
      return updated;
    } on DioException catch (e) {
      throw SharingException(_messageFor(e));
    }
  }

  Future<void> disconnect(SharingConnection connection) async {
    try {
      await _dioClient.dio.delete(
        '${ApiEndpoints.connections}/${connection.id}',
      );
      await _cleanupPartnerData(connection);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } on DioException catch (e) {
      throw SharingException(_messageFor(e));
    }
  }

  /// Envia os dados locais e baixa o que o parceiro compartilha.
  Future<SharingSyncResult> syncNow({DateTime? planMonth}) async {
    if (await _isGuestMode()) {
      return const SharingSyncResult();
    }

    // Envia transacoes pendentes mesmo quando ainda nao existe parceiro.
    await TransactionsRepository().syncPendingTransactions();

    final connection = await getConnection();
    if (connection == null) {
      return const SharingSyncResult();
    }

    final result = await _pullPartnerData(connection, planMonth: planMonth);
    if (result.hasPartner) {
      await _cacheConnection(
        connection.copyWith(lastSyncedAt: DateTime.now()),
      );
    }
    return result;
  }

  Future<SharingSyncResult> _pullPartnerData(
    SharingConnection connection, {
    DateTime? planMonth,
  }) async {
    try {
      final monthQuery = planMonth == null
          ? ''
          : '?month=${planMonth.year}-'
              '${planMonth.month.toString().padLeft(2, '0')}';
      final response =
          await _dioClient.dio.get('${ApiEndpoints.syncPartner}$monthQuery');
      final data = response.data is Map ? response.data['data'] : null;
      if (data is! Map<String, dynamic>) {
        return SharingSyncResult(partnerUsername: connection.partnerUsername);
      }

      final sharing =
          data['sharing'] is Map ? data['sharing'] as Map : const {};
      final shareTransactions = sharing['transactions'] as bool? ?? true;

      if (!shareTransactions) {
        await _removePartnerTransactions(connection.partnerUserId);
      }

      final transactions = data['transactions'] as List? ?? const [];

      var pulledTransactions = 0;
      for (final item in transactions) {
        if (item is! Map) continue;
        await _mergePartnerTransaction(
          Map<String, dynamic>.from(item),
          connection.partnerUserId,
        );
        pulledTransactions++;
      }

      final budgetPlanJson = data['budgetPlan'];
      if (budgetPlanJson is Map) {
        try {
          final remote = BudgetPlan.fromJson(
            Map<String, dynamic>.from(budgetPlanJson),
          );
          await PlanningRepository(database: _db).mergeRemotePlan(remote);
        } catch (_) {
          // Plano remoto invalido nao impede o resto da sincronizacao.
        }
      }

      return SharingSyncResult(
        partnerUsername: connection.partnerUsername,
        pulledTransactions: pulledTransactions,
        shareTransactions: shareTransactions,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // O parceiro desconectou. Limpa o cache para a tela refletir.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cacheKey);
        await _cleanupPartnerData(connection);
        return const SharingSyncResult();
      }
      throw SharingException(_messageFor(e));
    }
  }

  Future<void> _mergePartnerTransaction(
    Map<String, dynamic> json,
    String partnerUserId,
  ) async {
    final id = json['id'] as String?;
    if (id == null) return;

    final date = DateTime.tryParse(json['date']?.toString() ?? '');
    if (date == null) return;

    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.now();
    final updatedAt =
        DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt;

    await _db.into(_db.transactions).insertOnConflictUpdate(
          db.TransactionsCompanion(
            id: Value(id),
            userId: Value(json['userId'] as String? ?? partnerUserId),
            amount: Value(_toDouble(json['amount'])),
            description: Value(json['description'] as String? ?? ''),
            date: Value(date),
            categoryId: Value(json['categoryId'] as String?),
            subcategoryId: Value(json['subcategoryId'] as String?),
            creditCardId: Value(json['creditCardId'] as String?),
            paymentMethod: Value(json['paymentMethod'] as String? ?? ''),
            isExpense: Value(json['isExpense'] as bool? ?? true),
            isInstallment: Value(json['isInstallment'] as bool? ?? false),
            installmentNumber: Value(json['installmentNumber'] as int? ?? 1),
            totalInstallments: Value(json['totalInstallments'] as int? ?? 1),
            installmentGroupId: Value(json['installmentGroupId'] as String?),
            notes: Value(json['notes'] as String?),
            ownerId: Value(json['ownerId'] as String? ?? partnerUserId),
            partnerSynced: const Value(true),
            createdAt: Value(createdAt),
            updatedAt: Value(updatedAt),
            isSynced: const Value(true),
          ),
        );
  }

  Future<void> _cacheConnection(SharingConnection connection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(connection.toJson()));
  }

  Future<void> _cleanupPartnerData(SharingConnection connection) async {
    try {
      await _removePartnerTransactions(connection.partnerUserId);
    } catch (_) {}
  }

  Future<void> _removePartnerTransactions(String partnerUserId) async {
    await (_db.delete(_db.transactions)
          ..where((t) => t.userId.equals(partnerUserId)))
        .go();
  }

  Future<bool> _isGuestMode() async {
    try {
      final value = await _storage.read(key: StorageKeys.isGuestMode);
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tempo de conexao esgotado. Tente novamente.';
      case DioExceptionType.connectionError:
        return 'Sem conexao com o servidor.';
      default:
        return e.message ?? 'Erro inesperado';
    }
  }
}

class SharingException implements Exception {
  const SharingException(this.message);
  final String message;
  @override
  String toString() => message;
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
