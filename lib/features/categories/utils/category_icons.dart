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
    case 'help_outline':
      return Icons.help_outline;
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
/// Variada e bem contrastada para evitar categorias com a mesma cor.
const List<int> kCategoryColors = [
  0xFFFF6B6B, // Coral Red (Alimentação)
  0xFF4ECDC4, // Turquesa / Ciano (Transporte)
  0xFFFFB347, // Laranja suave (Moradia)
  0xFF6BCB77, // Verde esmeralda (Lazer)
  0xFF7E57C2, // Roxo / Violeta
  0xFF29B6F6, // Azul celeste
  0xFFFFD93D, // Amarelo vibrante
  0xFFEC407A, // Rosa / Magenta
  0xFFFF7043, // Laranja escuro / Tangerina
  0xFF26A69A, // Verde menta / Ciano escuro
  0xFF9CCC65, // Verde lima
  0xFF5C6BC0, // Índigo
  0xFF8D6E63, // Marrom / Café
  0xFF00ACC1, // Ciano profundo
  0xFFD81B60, // Cereja / Vinho
  0xFF3949AB, // Azul real
  0xFF78909C, // Cinza ardósia / Aço
  0xFFFF8E8E, // Salmão suave (Saúde)
  0xFFA8E6CF, // Verde água suave
  0xFFB8B8B8, // Cinza neutro (Outros)
];
