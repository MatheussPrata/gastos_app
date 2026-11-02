import 'package:flutter/material.dart';

/// Maps the icon name persisted in the database to a Material [IconData].
///
/// Keep the keys stable: they are stored in the local database and sent to the
/// API during sync.
class CategoryIcons {
  static const Map<String, IconData> _icons = {
    // Default expense categories
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'home': Icons.home,
    'sports_esports': Icons.sports_esports,
    'medical_services': Icons.medical_services,
    'shopping_bag': Icons.shopping_bag,
    'school': Icons.school,
    'more_horiz': Icons.more_horiz,
    // Default income categories
    'payments': Icons.payments,
    'work': Icons.work,
    'trending_up': Icons.trending_up,
    'redeem': Icons.redeem,
    'attach_money': Icons.attach_money,
    // Additional options for the icon picker
    'category': Icons.category,
    'directions_bus': Icons.directions_bus,
    'local_hospital': Icons.local_hospital,
    'movie': Icons.movie,
    'shopping_cart': Icons.shopping_cart,
    'fastfood': Icons.fastfood,
    'coffee': Icons.coffee,
    'pets': Icons.pets,
    'fitness_center': Icons.fitness_center,
    'flight': Icons.flight,
    'phone_android': Icons.phone_android,
    'wifi': Icons.wifi,
    'bolt': Icons.bolt,
    'water_drop': Icons.water_drop,
    'savings': Icons.savings,
    'account_balance': Icons.account_balance,
    'card_giftcard': Icons.card_giftcard,
    'celebration': Icons.celebration,
    'subscriptions': Icons.subscriptions,
    'build': Icons.build,
    'child_care': Icons.child_care,
    'local_gas_station': Icons.local_gas_station,
    'park': Icons.park,
    'music_note': Icons.music_note,
  };

  static IconData resolve(String name) => _icons[name] ?? Icons.category;

  static List<String> get available => _icons.keys.toList(growable: false);

  static List<MapEntry<String, IconData>> get entries =>
      _icons.entries.toList(growable: false);
}
