import 'package:flutter/material.dart';

/// Categorizador inteligente de itens de cupom fiscal baseado em palavras-chave.
class ReceiptItemCategorizer {
  static const String acougue = 'Açougue';
  static const String hortifruti = 'Hortifruti';
  static const String limpeza = 'Limpeza';
  static const String cozinha = 'Cozinha & Casa';
  static const String higiene = 'Higiene & Beleza';
  static const String padaria = 'Padaria & Laticínios';
  static const String mercearia = 'Mercearia';
  static const String bebidas = 'Bebidas';
  static const String outros = 'Outros';

  static const List<String> availableCategories = [
    acougue,
    hortifruti,
    limpeza,
    cozinha,
    higiene,
    padaria,
    mercearia,
    bebidas,
    outros,
  ];

  static final Map<String, List<String>> _keywords = {
    acougue: [
      'carne', 'bov', 'bovino', 'bovina', 'frango', 'peito', 'coxa', 'asa',
      'suino', 'suina', 'porco', 'bife', 'alcatra', 'picanha', 'contra file',
      'costela', 'linguica', 'salchicha', 'salsicha', 'file mign', 'maminha',
      'patinho', 'acem', 'musculo', 'coxao', 'cupim', 'pernil', 'lombo',
      'bacon', 'peixe', 'tilapia', 'salmao', 'sardinha', 'camarao', 'hamburg',
      'nugget', 'empanado', 'moida',
    ],
    hortifruti: [
      'banana', 'maca', 'laranja', 'limao', 'uva', 'manga', 'abacaxi',
      'melancia', 'melao', 'mamao', 'morango', 'pera', 'pessego', 'maracuja',
      'tomate', 'cebola', 'alho', 'batata', 'cenoura', 'chuchu', 'abobora',
      'alface', 'couve', 'espinafre', 'rucula', 'repolho', 'brocolis',
      'pepino', 'pimentao', 'beterraba', 'mandioca', 'aipim', 'cheiro verde',
      'salsa', 'cebolinha', 'hortel', 'fruta', 'legum', 'verdura',
    ],
    limpeza: [
      'detergente', 'sabao', 'amaciante', 'desinfetante', 'agua sanitaria',
      'alvejante', 'cloro', 'multiuso', 'limpador', 'lava louca', 'lava roupa',
      'lustra', 'cera', 'inseticida', 'odorizador', 'desodorizador',
      'esponja de aco', 'bombril', 'assolan', 'saponaceo',
    ],
    cozinha: [
      'papel toalha', 'guardanapo', 'papel aluminio', 'filme pvc', 'plastico',
      'saco lixo', 'saco p/ lixo', 'sacola', 'fosforo', 'acendedor', 'esponja',
      'pano', 'flanela', 'filtro papel', 'copo desc', 'prato desc',
    ],
    higiene: [
      'shampoo', 'xampu', 'condicionador', 'sabonete', 'creme dental',
      'pasta de dente', 'escova dental', 'fio dental', 'enxaguante',
      'desodorante', 'antitranspirante', 'papel higienico', 'absorvente',
      'fralda', 'lenco umedecido', 'algodao', 'hastes flex', 'cotonete',
      'lamina', 'aparelho barbear', 'creme barbear', 'hidratante', 'protetor',
    ],
    padaria: [
      'pao', 'bisnaguinha', 'torrada', 'croissant', 'bolo', 'torta',
      'leite', 'queijo', 'presunto', 'mussarela', 'mozarela', 'prato',
      'requeijao', 'manteiga', 'margarina', 'iogurte', 'coalhada', 'ricota',
      'mortadela', 'salame', 'peito peru', 'cream cheese',
    ],
    bebidas: [
      'agua mineral', 'refrigerante', 'coca cola', 'pepsi', 'guarana',
      'fanta', 'sprite', 'suco', 'nectar', 'cha', 'cafe', 'cerveja',
      'chopp', 'vinho', 'espumante', 'vodka', 'whisky', 'gin', 'energetico',
      'red bull', 'monster', 'isotônico', 'gatorade',
    ],
    mercearia: [
      'arroz', 'feijao', 'macarrao', 'massa', 'molho', 'extrato', 'oleo',
      'azeite', 'vinagre', 'acucar', 'sal', 'farinha', 'farofa', 'amido',
      'fermento', 'milho', 'ervilha', 'azeitona', 'palmito', 'sardinha lata',
      'atum lata', 'biscoito', 'bolacha', 'chocolate', 'achocolatado', 'toddy',
      'nescau', 'cereal', 'aveia', 'granola', 'maionese', 'ketchup', 'mostarda',
      'tempero', 'caldo', 'gelatina',
    ],
  };

  /// Categoriza um produto pelo nome.
  static String categorize(String productName) {
    if (productName.trim().isEmpty) return outros;

    final normalized = _normalize(productName);

    // Varre as palavras-chave de cada categoria
    for (final entry in _keywords.entries) {
      for (final keyword in entry.value) {
        if (_matchesKeyword(normalized, keyword)) {
          return entry.key;
        }
      }
    }

    return outros;
  }

  static bool _matchesKeyword(String text, String keyword) {
    final kw = _normalize(keyword);
    // Se a palavra-chave contém espaço (ex: "agua sanitaria", "papel toalha")
    if (kw.contains(' ')) {
      return text.contains(kw);
    }
    // Palavra individual: verifica se ocorre como palavra ou pedaço representativo
    final words = text.split(' ');
    for (final word in words) {
      if (word == kw || (word.length >= 4 && word.startsWith(kw))) {
        return true;
      }
    }
    return text.contains(kw);
  }

  static String _normalize(String input) {
    var s = input.toLowerCase();
    s = s.replaceAll(RegExp(r'[áàâãä]'), 'a');
    s = s.replaceAll(RegExp(r'[éèêë]'), 'e');
    s = s.replaceAll(RegExp(r'[íìîï]'), 'i');
    s = s.replaceAll(RegExp(r'[óòôõö]'), 'o');
    s = s.replaceAll(RegExp(r'[úùûü]'), 'u');
    s = s.replaceAll(RegExp(r'[ç]'), 'c');
    s = s.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static IconData getIcon(String category) {
    switch (category) {
      case acougue:
        return Icons.restaurant;
      case hortifruti:
        return Icons.eco;
      case limpeza:
        return Icons.cleaning_services;
      case cozinha:
        return Icons.kitchen;
      case higiene:
        return Icons.spa;
      case padaria:
        return Icons.bakery_dining;
      case mercearia:
        return Icons.shopping_basket;
      case bebidas:
        return Icons.local_drink;
      default:
        return Icons.inventory_2;
    }
  }

  static Color getColor(String category) {
    switch (category) {
      case acougue:
        return const Color(0xFFE53935); // Vermelho
      case hortifruti:
        return const Color(0xFF43A047); // Verde
      case limpeza:
        return const Color(0xFF00ACC1); // Ciano
      case cozinha:
        return const Color(0xFFFB8C00); // Laranja
      case higiene:
        return const Color(0xFF8E24AA); // Roxo
      case padaria:
        return const Color(0xFFF9A825); // Âmbar
      case mercearia:
        return const Color(0xFF3949AB); // Índigo
      case bebidas:
        return const Color(0xFF1E88E5); // Azul
      default:
        return const Color(0xFF757575); // Cinza
    }
  }
}
