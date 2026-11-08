import 'package:flutter/material.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;

/// Model for a credit card entity in the application.
class CreditCardItem {
  final String id;
  final String name;
  final int color;
  final String lastFourDigits;
  final String brand;
  final double limitAmount;
  final int closingDay;
  final int dueDay;
  final bool isActive;
  final int sortOrder;

  const CreditCardItem({
    required this.id,
    required this.name,
    required this.color,
    this.lastFourDigits = '',
    this.brand = '',
    this.limitAmount = 0.0,
    this.closingDay = 1,
    this.dueDay = 1,
    this.isActive = true,
    this.sortOrder = 0,
  });

  Color get cardColor => color == 0 ? const Color(0xFF6200EE) : Color(color);

  String get displayName =>
      lastFourDigits.isNotEmpty ? '$name (*$lastFourDigits)' : name;

  double availableLimit(double spent) {
    if (limitAmount <= 0) return 0;
    final remaining = limitAmount - spent;
    return remaining < 0 ? 0 : remaining;
  }

  double limitUsedPercent(double spent) {
    if (limitAmount <= 0) return 0;
    return (spent / limitAmount * 100).clamp(0.0, 1000.0);
  }

  bool isOverLimit(double spent) => spent > limitAmount && limitAmount > 0;

  factory CreditCardItem.fromDb(db.CreditCard entry) {
    return CreditCardItem(
      id: entry.id,
      name: entry.name,
      color: entry.color,
      lastFourDigits: entry.lastFourDigits,
      brand: entry.brand,
      limitAmount: entry.limitAmount,
      closingDay: entry.closingDay,
      dueDay: entry.dueDay,
      isActive: entry.isActive,
      sortOrder: entry.sortOrder,
    );
  }

  CreditCardItem copyWith({
    String? id,
    String? name,
    int? color,
    String? lastFourDigits,
    String? brand,
    double? limitAmount,
    int? closingDay,
    int? dueDay,
    bool? isActive,
    int? sortOrder,
  }) {
    return CreditCardItem(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      brand: brand ?? this.brand,
      limitAmount: limitAmount ?? this.limitAmount,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
