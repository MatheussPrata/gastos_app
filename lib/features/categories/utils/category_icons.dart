import 'package:flutter/material.dart';

/// Mapeia o nome do ícone salvo na categoria para um [IconData] do Material.
IconData categoryIcon(String name) {
  switch (name) {
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_bus':
      return Icons.directions_bus;
    case 'home':
      return Icons.home;
    case 'movie':
      return Icons.movie;
    case 'local_hospital':
      return Icons.local_hospital;
    case 'payments':
      return Icons.payments;
    case 'shopping_basket':
      return Icons.shopping_basket;
    case 'school':
      return Icons.school;
    case 'pets':
      return Icons.pets;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'flight':
      return Icons.flight;
    case 'work':
      return Icons.work;
    default:
      return Icons.category;
  }
}

/// Lista de ícones disponíveis no formulário de categoria.
const List<String> kCategoryIcons = [
  'category',
  'restaurant',
  'directions_bus',
  'home',
  'movie',
  'local_hospital',
  'payments',
  'shopping_basket',
  'school',
  'pets',
  'fitness_center',
  'flight',
  'work',
];

/// Paleta de cores disponíveis no formulário de categoria.
const List<int> kCategoryColors = [
  0xFFFF6B6B,
  0xFF4ECDC4,
  0xFFFFB347,
  0xFF6BCB77,
  0xFFFF8E8E,
  0xFFA8E6CF,
  0xFFB8B8B8,
  0xFF6750A4,
  0xFF1E88E5,
  0xFFFFB300,
];
