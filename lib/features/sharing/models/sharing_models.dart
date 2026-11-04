/// Modelos do compartilhamento entre dois dispositivos/contas.
class SharingConnection {
  const SharingConnection({
    required this.id,
    required this.partnerUserId,
    required this.partnerUsername,
    required this.createdAt,
    this.lastSyncedAt,
    this.shareTransactions = true,
  });

  final String id;
  final String partnerUserId;
  final String partnerUsername;
  final DateTime createdAt;
  final DateTime? lastSyncedAt;

  /// O que EU compartilho com o parceiro.
  final bool shareTransactions;

  factory SharingConnection.fromJson(Map<String, dynamic> json) {
    return SharingConnection(
      id: json['id'] as String,
      partnerUserId: json['partnerUserId'] as String,
      partnerUsername: json['partnerUsername'] as String? ?? 'Parceiro',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      lastSyncedAt: _parseDate(json['lastSyncedAt']),
      shareTransactions: json['shareTransactions'] as bool? ?? true,
    );
  }

  SharingConnection copyWith({
    DateTime? lastSyncedAt,
    bool? shareTransactions,
  }) {
    return SharingConnection(
      id: id,
      partnerUserId: partnerUserId,
      partnerUsername: partnerUsername,
      createdAt: createdAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      shareTransactions: shareTransactions ?? this.shareTransactions,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'partnerUserId': partnerUserId,
        'partnerUsername': partnerUsername,
        'createdAt': createdAt.toIso8601String(),
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'shareTransactions': shareTransactions,
      };

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

class SharingInvite {
  const SharingInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  factory SharingInvite.fromJson(Map<String, dynamic> json) {
    return SharingInvite(
      code: json['code'] as String,
      expiresAt:
          DateTime.tryParse(json['expiresAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now().add(const Duration(hours: 24)),
    );
  }
}

class SharingSyncResult {
  const SharingSyncResult({
    this.partnerUsername,
    this.pulledTransactions = 0,
    this.shareTransactions = true,
  });

  final String? partnerUsername;
  final int pulledTransactions;
  final bool shareTransactions;

  bool get hasPartner => partnerUsername != null;

  String get summary {
    if (!hasPartner) return 'Nenhum parceiro conectado.';
    final parts = <String>[];
    if (shareTransactions) {
      parts.add('$pulledTransactions gasto(s)');
    }
    if (parts.isEmpty) {
      return 'Seu parceiro não está compartilhando nenhum tipo de dado.';
    }
    return 'Sincronizado com $partnerUsername: ${parts.join(' e ')}.';
  }
}
