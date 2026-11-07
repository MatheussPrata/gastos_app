import 'package:flutter/material.dart';

/// Categorizador inteligente de itens de cupom fiscal baseado em dicionário
/// pré-definido, abreviações de supermercado e aproximação de palavras.
class ReceiptItemCategorizer {
  static const String acougue = 'Açougue';
  static const String alimentacao = 'Alimentação';
  static const String limpeza = 'Limpeza';
  static const String higiene = 'Higiene & Beleza';
  static const String hortifruti = 'Hortifruti';
  static const String bebidas = 'Bebidas';
  static const String padaria = 'Padaria & Laticínios';
  static const String cozinha = 'Cozinha & Casa';
  static const String outros = 'Outros';

  /// Compatibilidade com versões anteriores que usavam 'Mercearia'
  static const String mercearia = alimentacao;

  static const List<String> availableCategories = [
    acougue,
    alimentacao,
    limpeza,
    higiene,
    hortifruti,
    bebidas,
    padaria,
    cozinha,
    outros,
  ];

  /// Palavras-chave completas por categoria (ordem de prioridade e match exato).
  static final Map<String, List<String>> _fullKeywords = {
    acougue: [
      'carne', 'bovino', 'bovina', 'frango', 'peito', 'coxa', 'sobrecoxa',
      'asa', 'tulipa', 'suino', 'suina', 'porco', 'bife', 'alcatra', 'picanha',
      'contra file', 'costela', 'linguica', 'salchicha', 'salsicha',
      'file mignon', 'maminha', 'patinho', 'acem', 'musculo', 'coxao mole',
      'coxao duro', 'cupim', 'pernil', 'lombo', 'bacon', 'peixe', 'tilapia',
      'salmao', 'sardinha fresca', 'camarao', 'hamburguer', 'nugget',
      'empanado', 'moida', 'costelinha', 'paleta', 'figado', 'moela', 'coracao',
      'cordeiro', 'carne seca', 'charque', 'churrasco',
    ],
    alimentacao: [
      'arroz', 'feijao', 'macarrao', 'massa', 'espaguete', 'parafuso', 'penne',
      'molho', 'extrato', 'oleo', 'azeite', 'vinagre', 'acucar', 'sal',
      'farinha', 'farofa', 'amido', 'maizena', 'fermento', 'milho', 'ervilha',
      'azeitona', 'palmito', 'sardinha lata', 'atum lata', 'sardinha', 'atum',
      'biscoito', 'bolacha', 'wafer', 'cookies', 'rosquinha', 'recheado',
      'chocolate', 'achocolatado', 'toddy', 'nescau', 'cereal', 'aveia',
      'granola', 'maionese', 'ketchup', 'mostarda', 'tempero', 'caldo',
      'gelatina', 'pudim', 'leite condensado', 'creme de leite', 'doce de leite',
      'goiabada', 'geleia', 'mel', 'pipoca', 'polvilho', 'canjica', 'lentilha',
      'grao de bico', 'sopa', 'miojo', 'lasanha', 'passata', 'shoyu',
      'molho tomate', 'molho ingles', 'cremogema', 'cacau', 'barra cereal',
      'biskoito', 'bolaxa', 'feijaoo',
    ],
    limpeza: [
      'detergente', 'sabao', 'sabao em po', 'sabao liquido', 'amaciante',
      'desinfetante', 'agua sanitaria', 'alvejante', 'cloro', 'multiuso',
      'limpador', 'lava louca', 'lava roupa', 'lustra moveis', 'cera',
      'inseticida', 'odorizador', 'desodorizador', 'esponja de aco', 'bombril',
      'assolan', 'saponaceo', 'alcool', 'desengordurante', 'limpa vidro',
      'tira manchas', 'vanish', 'pastilha sanitaria', 'pedra sanitaria',
      'vassoura', 'rodo', 'balde',
    ],
    cozinha: [
      'papel toalha', 'guardanapo', 'papel aluminio', 'filme pvc',
      'plastico filme', 'saco lixo', 'saco para lixo', 'saco de lixo',
      'sacola', 'fosforo', 'acendedor', 'esponja', 'pano de prato',
      'pano multiuso', 'flanela', 'filtro papel', 'copo descartavel',
      'prato descartavel', 'talher descartavel', 'filtro cafe',
    ],
    higiene: [
      'shampoo', 'xampu', 'condicionador', 'sabonete', 'sabonete liquido',
      'creme dental', 'pasta de dente', 'escova dental', 'escova de dente',
      'fio dental', 'enxaguante', 'antisseptico', 'desodorante',
      'antitranspirante', 'papel higienico', 'absorvente', 'protetor diario',
      'fralda', 'fralda descartavel', 'lenco umedecido', 'algodao',
      'hastes flexiveis', 'cotonete', 'lamina', 'aparelho de barbear',
      'creme de barbear', 'espuma de barbear', 'hidratante', 'protetor solar',
      'bloqueador', 'locao', 'gel cabelo', 'pomada capilar', 'tintura',
      'esmalte', 'removedor esmalte', 'acetona', 'talco',
    ],
    hortifruti: [
      'banana', 'maca', 'laranja', 'limao', 'uva', 'manga', 'abacaxi',
      'melancia', 'melao', 'mamao', 'morango', 'pera', 'pessego', 'maracuja',
      'kiwi', 'ameixa', 'goiaba', 'tangerina', 'mexerica', 'bergamota',
      'tomate', 'cebola', 'alho', 'batata', 'cenoura', 'chuchu', 'abobora',
      'abobrinha', 'alface', 'couve', 'espinafre', 'rucula', 'repolho',
      'brocolis', 'couve flor', 'pepino', 'pimentao', 'beterraba', 'mandioca',
      'aipim', 'macaxeira', 'cheiro verde', 'salsa', 'cebolinha', 'hortela',
      'coentro', 'alecrim', 'manjericao', 'gengibre', 'inhame', 'milho verde',
    ],
    bebidas: [
      'agua mineral', 'agua de coco', 'refrigerante', 'coca cola', 'pepsi',
      'guarana', 'fanta', 'sprite', 'suco', 'nectar', 'cha', 'cafe',
      'cafe em po', 'cafe soluvel', 'capsula cafe', 'cerveja', 'chopp',
      'vinho', 'espumante', 'prosecco', 'vodka', 'whisky', 'gin', 'cachaca',
      'licor', 'energetico', 'red bull', 'monster', 'isotonico', 'gatorade',
    ],
    padaria: [
      'pao', 'pao frances', 'pao de forma', 'bisnaguinha', 'torrada',
      'croissant', 'bolo', 'torta', 'leite', 'leite integral',
      'leite desnatado', 'queijo', 'presunto', 'mussarela', 'mozarela', 'prato',
      'parmesao', 'provolone', 'requeijao', 'manteiga', 'margarina', 'iogurte',
      'coalhada', 'ricota', 'mortadela', 'salame', 'peito peru',
      'cream cheese', 'nata', 'chantilly',
    ],
  };

  /// Abreviações comuns de cupom fiscal NFC-e por categoria.
  static final Map<String, List<String>> _abbreviations = {
    acougue: [
      'bov', 'suin', 'frang', 'acem', 'coxao', 'patin', 'alcat', 'mign',
      'pican', 'peit', 'cost', 'costel', 'ling', 'linguic', 'sals', 'salsich',
      'hamb', 'nugg', 'empan', 'peix', 'tilap', 'salm', 'camar', 'pern',
      'lomb', 'moec', 'carn', 'churras',
    ],
    alimentacao: [
      'bisc', 'bol', 'rech', 'rechead', 'arr', 'feij', 'mac', 'marr', 'espag',
      'ext', 'molh', 'oleo', 'azeit', 'vinag', 'acuc', 'far', 'farin',
      'farof', 'maiz', 'ferment', 'ervilh', 'azeiton', 'palmit', 'choc',
      'achoc', 'nesc', 'todd', 'cere', 'gran', 'maion', 'ketch', 'most',
      'temp', 'gelat', 'leite cond', 'lt cond', 'crm leite', 'cr leite',
      'doce leit', 'pipoc', 'polv', 'lent', 'grao bic', 'passat', 'sard l',
      'atum l', 'sardin',
    ],
    limpeza: [
      'det', 'limp', 'sab', 'sb', 'amac', 'desinf', 'ag sanit', 'ag san',
      'sanit', 'alvej', 'clor', 'mult', 'multius', 'lav louc', 'lav roup',
      'lustr', 'inset', 'odoriz', 'esp aco', 'bombr', 'sapon', 'alc',
      'deseng', 'tira manch', 'vanis', 'past sanit', 'pedr sanit',
    ],
    cozinha: [
      'pap toalh', 'guard', 'pap alum', 'film pvc', 'sc lixo', 'saco lix',
      'sacol', 'fofs', 'esponj', 'pan prat', 'pan multius', 'flan', 'filt pap',
      'cop desc', 'prat desc',
    ],
    higiene: [
      'shamp', 'sh', 'cond', 'sabon', 'sab liq', 'cr dent', 'cr dental',
      'past dent', 'esc dent', 'fio dent', 'enxag', 'desod', 'antitransp',
      'pap hig', 'papel hig', 'absorv', 'prot diar', 'frald', 'fral',
      'lenc umed', 'algod', 'hast flex', 'coton', 'lamin', 'ap barb',
      'cr barb', 'esp barb', 'hidr', 'prot sol', 'bloq', 'loc', 'tint',
      'esmalt', 'acet',
    ],
    hortifruti: [
      'ban', 'maca', 'lar', 'lim', 'abac', 'melanc', 'mel', 'mam', 'morang',
      'pesseg', 'marac', 'tang', 'mexer', 'tom', 'tomat', 'ceb', 'cebol',
      'bat', 'cen', 'cenour', 'chuch', 'abob', 'abobr', 'alf', 'couv',
      'espin', 'ruc', 'repolh', 'broc', 'pepin', 'piment', 'beterr', 'mand',
      'aip', 'cheir verd', 'sals', 'cebolin', 'hortel',
    ],
    bebidas: [
      'ag miner', 'ag min', 'ag coc', 'refr', 'ref', 'coca', 'peps', 'guar',
      'fant', 'sprit', 'suc', 'nect', 'cerv', 'cervej', 'vinh', 'espum',
      'vodk', 'whisk', 'cach', 'energ', 'isot',
    ],
    padaria: [
      'bisnag', 'torrad', 'croiss', 'leite int', 'leite desn', 'queij',
      'muss', 'moz', 'queij prat', 'parmes', 'provol', 'requeij', 'mant',
      'margar', 'iog', 'ricot', 'mortad', 'salam',
    ],
  };

  /// Categoriza um produto pelo nome usando aproximação de palavras e abreviações.
  static String categorize(String productName) {
    if (productName.trim().isEmpty) return outros;

    final normalized = _normalize(productName);
    final words = normalized.split(' ').where((w) => w.isNotEmpty).toList();

    // 1. Frases compostas completas (da mais longa para a mais curta)
    for (final entry in _fullKeywords.entries) {
      for (final keyword in entry.value) {
        if (keyword.contains(' ')) {
          final normKw = _normalize(keyword);
          if (normalized.contains(normKw)) {
            return entry.key;
          }
        }
      }
    }

    // 2. Frases compostas abreviadas
    for (final entry in _abbreviations.entries) {
      for (final keyword in entry.value) {
        if (keyword.contains(' ')) {
          final normKw = _normalize(keyword);
          if (normalized.contains(normKw)) {
            return entry.key;
          }
        }
      }
    }

    // 3. Match de palavra exata completa
    for (final word in words) {
      if (word.length < 2) continue;
      for (final entry in _fullKeywords.entries) {
        for (final keyword in entry.value) {
          if (!keyword.contains(' ') && word == _normalize(keyword)) {
            return entry.key;
          }
        }
      }
    }

    // 4. Match de abreviação exata ou prefixo de palavra da NFC-e
    for (final word in words) {
      if (word.length < 2) continue;
      for (final entry in _abbreviations.entries) {
        for (final abbr in entry.value) {
          if (abbr.contains(' ')) continue;
          final normAbbr = _normalize(abbr);

          // Ex: "bisc" == "bisc"
          if (word == normAbbr) {
            return entry.key;
          }

          // Se a palavra na nota fiscal tem prefixo da abreviação (ex: "bolachas" começa com "bol")
          if (normAbbr.length >= 3 && word.length >= 3) {
            if (word.startsWith(normAbbr) || normAbbr.startsWith(word)) {
              return entry.key;
            }
          }
        }
      }
    }

    // 5. Match por aproximação fonética / Levenshtein (distância <= 1)
    for (final word in words) {
      if (word.length < 4) continue;
      for (final entry in _fullKeywords.entries) {
        for (final keyword in entry.value) {
          if (keyword.contains(' ') || keyword.length < 4) continue;
          final normKw = _normalize(keyword);

          if (_levenshteinDistance(word, normKw) <= 1) {
            return entry.key;
          }
        }
      }
    }

    return outros;
  }

  /// Calcula a distância de Levenshtein entre duas strings.
  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i <= t.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        final a = v1[j] + 1;
        final b = v0[j + 1] + 1;
        final c = v0[j] + cost;
        v1[j + 1] = a < b ? (a < c ? a : c) : (b < c ? b : c);
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
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
      case alimentacao:
      case 'Mercearia':
        return Icons.shopping_basket;
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
      case alimentacao:
      case 'Mercearia':
        return const Color(0xFF3949AB); // Índigo
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
      case bebidas:
        return const Color(0xFF1E88E5); // Azul
      default:
        return const Color(0xFF757575); // Cinza
    }
  }
}
