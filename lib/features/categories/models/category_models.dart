import 'package:freezed_annotation/freezed_annotation.dart';

part 'category_models.freezed.dart';
part 'category_models.g.dart';

@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required int color,
    required String icon,
    @Default(false) bool isDefault,
    @Default(true) bool isExpenseDefault,
    @Default(0) int sortOrder,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
}

@freezed
class Subcategory with _$Subcategory {
  const factory Subcategory({
    required String id,
    required String categoryId,
    required String name,
    @Default(0) int sortOrder,
  }) = _Subcategory;

  factory Subcategory.fromJson(Map<String, dynamic> json) => _$SubcategoryFromJson(json);
}