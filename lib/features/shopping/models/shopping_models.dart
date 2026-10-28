import 'package:freezed_annotation/freezed_annotation.dart';

part 'shopping_models.freezed.dart';
part 'shopping_models.g.dart';

@freezed
class ShoppingItem with _$ShoppingItem {
  const factory ShoppingItem({
    required String id,
    required String userId,
    required String name,
    String? category,
    @Default(false) bool isChecked,
    required DateTime createdAt,
    DateTime? checkedAt,
    String? checkedBy,
  }) = _ShoppingItem;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => _$ShoppingItemFromJson(json);
}