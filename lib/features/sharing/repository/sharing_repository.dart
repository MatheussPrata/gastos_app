import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/shopping_list/data/models/shopping_item.dart';
import 'package:gastos_app/features/shopping_list/data/repositories/shopping_list_repository.dart';
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
    ShoppingListRepository? shoppingListRepository,
    FlutterSecureStorage? storage,
  })  : _dioClient = dioClient ?? DioClient(),
        _db = database ?? db.AppDatabase(),
        _shoppingListRepository =
            shoppingListRepository ?? ShoppingListRepository(),
        _storage = storage ?? const FlutterSecureStorage();

  static const String _cacheKey = 'sharing_connection';
  static const String _sharedShoppingIdsKey = 'shared_shopping_item_ids';

  final DioClient _dioClient;
  final db.AppDatabase _db;
  final ShoppingListRepository _shoppingListRepository;
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
    bool? shareShopping,
  }) async {
    try {
      final response = await _dioClient.dio.patch(
        '${ApiEndpoints.connections}/${connection.id}',
        data: {
          if (shareTransactions != null) 'shareTransactions': shareTransactions,
          if (shareShopping != null) 'shareShopping': shareShopping,
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
  Future<SharingSyncResult> syncNow() async {
    if (await _isGuestMode()) {
      return const SharingSyncResult();
    }

    // Envia transacoes pendentes e a lista de compras local mesmo quando
    // ainda nao existe um parceiro conectado.
    await TransactionsRepository().syncPendingTransactions();
    await _pushShoppingItems();

    final connection = await getConnection();
    if (connection == null) {
      return const SharingSyncResult();
    }

    final result = await _pullPartnerData(connection);
    if (result.hasPartner) {
      await _cacheConnection(
        connection.copyWith(lastSyncedAt: DateTime.now()),
      );
    }
    return result;
  }

  Future<void> _pushShoppingItems() async {
    try {
      final items = await _shoppingListRepository.loadItems();
      if (items.isEmpty) return;

      final sharedIds = await _loadSharedShoppingIds();
      final ownItems = items.where((item) => !sharedIds.contains(item.id));
      if (ownItems.isEmpty) return;

      final payload = ownItems
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'quantity': item.quantity,
              'unit': item.unit,
              'estimatedPrice': item.estimatedPrice,
              'actualPrice': item.actualPrice,
              'isChecked': item.isPurchased,
              'category': item.category,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              'checkedAt': item.isPurchased
                  ? DateTime.now().toUtc().toIso8601String()
                  : null,
            },
          )
          .toList();

      await _dioClient.dio.post(
        ApiEndpoints.sync,
        data: {'shoppingItems': payload},
      );
    } catch (_) {
      // Offline ou erro do servidor: tenta de novo na proxima sincronizacao.
    }
  }

  Future<SharingSyncResult> _pullPartnerData(
    SharingConnection connection,
  ) async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.syncPartner);
      final data = response.data is Map ? response.data['data'] : null;
      if (data is! Map<String, dynamic>) {
        return SharingSyncResult(partnerUsername: connection.partnerUsername);
      }

      final sharing =
          data['sharing'] is Map ? data['sharing'] as Map : const {};
      final shareTransactions = sharing['transactions'] as bool? ?? true;
      final shareShopping = sharing['shopping'] as bool? ?? true;

      if (!shareTransactions) {
        await _removePartnerTransactions(connection.partnerUserId);
      }
      if (!shareShopping) {
        await _removeSharedShoppingItems();
      }

      final transactions = data['transactions'] as List? ?? const [];
      final shoppingItems = data['shoppingItems'] as List? ?? const [];

      var pulledTransactions = 0;
      for (final item in transactions) {
        if (item is! Map) continue;
        await _mergePartnerTransaction(
          Map<String, dynamic>.from(item),
          connection.partnerUserId,
        );
        pulledTransactions++;
      }

      final pulledShopping = await _mergePartnerShopping(
        shoppingItems.whereType<Map>().map(Map<String, dynamic>.from).toList(),
      );

      return SharingSyncResult(
        partnerUsername: connection.partnerUsername,
        pulledTransactions: pulledTransactions,
        pulledShoppingItems: pulledShopping,
        shareTransactions: shareTransactions,
        shareShopping: shareShopping,
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

  Future<int> _mergePartnerShopping(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return 0;

    final local = await _shoppingListRepository.loadItems();
    final merged = {for (final item in local) item.id: item};
    final sharedIds = await _loadSharedShoppingIds();

    for (final json in items) {
      final id = json['id'] as String?;
      if (id == null) continue;

      merged[id] = ShoppingItem(
        id: id,
        name: json['name'] as String? ?? 'Item',
        quantity: _toDouble(json['quantity'] ?? 1),
        unit: json['unit'] as String?,
        estimatedPrice: _toDoubleOrNull(json['estimatedPrice']),
        actualPrice: _toDoubleOrNull(json['actualPrice']),
        isPurchased:
            json['isPurchased'] as bool? ?? json['isChecked'] as bool? ?? false,
        category: json['category'] as String?,
      );
      sharedIds.add(id);
    }

    await _shoppingListRepository.saveItems(merged.values.toList());
    await _saveSharedShoppingIds(sharedIds);
    return items.length;
  }

  Future<void> _cacheConnection(SharingConnection connection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(connection.toJson()));
  }

  Future<Set<String>> _loadSharedShoppingIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sharedShoppingIdsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveSharedShoppingIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sharedShoppingIdsKey, jsonEncode(ids.toList()));
  }

  Future<void> _cleanupPartnerData(SharingConnection connection) async {
    try {
      await _removePartnerTransactions(connection.partnerUserId);
      await _removeSharedShoppingItems();
    } catch (_) {}
  }

  Future<void> _removePartnerTransactions(String partnerUserId) async {
    await (_db.delete(_db.transactions)
          ..where((t) => t.userId.equals(partnerUserId)))
        .go();
  }

  Future<void> _removeSharedShoppingItems() async {
    final sharedIds = await _loadSharedShoppingIds();
    if (sharedIds.isEmpty) return;

    final items = await _shoppingListRepository.loadItems();
    await _shoppingListRepository.saveItems(
      items.where((item) => !sharedIds.contains(item.id)).toList(),
    );
    await _saveSharedShoppingIds({});
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

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class SharingException implements Exception {
  const SharingException(this.message);
  final String message;
  @override
  String toString() => message;
}
