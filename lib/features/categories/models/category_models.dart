// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'category_models.freezed.dart';
part 'category_models.g.dart';

/// Type of a category. Categories are strictly separated by transaction type.
enum CategoryType {
  income,
  expense;

  String get label => this == CategoryType.income ? 'Entrada' : 'Saída';

  bool get isIncome => this == CategoryType.income;
}

DateTime _categoryDateFromJson(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}

String _categoryDateToJson(DateTime value) => value.toIso8601String();

@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    @Default(CategoryType.expense) CategoryType type,
    @Default('category') String icon,
    @Default(0xFFB8B8B8) int color,
    @Default(false) bool isDefault,
    @Default(0) int sortOrder,
    @JsonKey(fromJson: _categoryDateFromJson, toJson: _categoryDateToJson)
    required DateTime createdAt,
    @JsonKey(fromJson: _categoryDateFromJson, toJson: _categoryDateToJson)
    required DateTime updatedAt,
    @Default(false) bool isSynced,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}

@freezed
class Subcategory with _$Subcategory {
  const factory Subcategory({
    required String id,
    required String categoryId,
    required String name,
    @Default(0) int sortOrder,
  }) = _Subcategory;

  factory Subcategory.fromJson(Map<String, dynamic> json) =>
      _$SubcategoryFromJson(json);
}
