/// Logica pura do comparador de precos (custo-beneficio entre embalagens).
///
/// Normaliza massas, volumes e unidades para uma base comum e calcula qual
/// opcao e mais vantajosa, alem do percentual de economia.

/// Grandeza fisica da unidade.
enum UnitType { mass, volume, count }

/// Metadados de uma unidade normalizada.
class UnitInfo {
  const UnitInfo({
    required this.type,
    required this.factorToBase,
    required this.baseUnit,
  });

  final UnitType type;

  /// Multiplicador para converter a quantidade para a unidade base.
  final double factorToBase;

  /// Unidade base usada na comparacao (kg, L ou un).
  final String baseUnit;
}

/// Mapa de unidades conhecidas (chave em minusculo).
const Map<String, UnitInfo> _unitMap = {
  'g': UnitInfo(type: UnitType.mass, factorToBase: 0.001, baseUnit: 'kg'),
  'kg': UnitInfo(type: UnitType.mass, factorToBase: 1.0, baseUnit: 'kg'),
  'mg': UnitInfo(type: UnitType.mass, factorToBase: 0.000001, baseUnit: 'kg'),
  'ml': UnitInfo(type: UnitType.volume, factorToBase: 0.001, baseUnit: 'L'),
  'l': UnitInfo(type: UnitType.volume, factorToBase: 1.0, baseUnit: 'L'),
  'un': UnitInfo(type: UnitType.count, factorToBase: 1.0, baseUnit: 'un'),
  'unid': UnitInfo(type: UnitType.count, factorToBase: 1.0, baseUnit: 'un'),
  'unidade': UnitInfo(type: UnitType.count, factorToBase: 1.0, baseUnit: 'un'),
};

/// Normaliza um texto de unidade para os metadados correspondentes.
UnitInfo? normalizeUnit(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return _unitMap[raw.trim().toLowerCase()];
}

/// Entrada de um produto para a comparacao.
class ProductEntry {
  const ProductEntry({
    required this.name,
    required this.price,
    required this.quantity,
    required this.unit,
  });

  final String name;
  final double price;
  final double quantity;
  final String unit;
}

/// Resultado da comparacao entre dois produtos.
class PriceComparison {
  const PriceComparison({
    required this.winner,
    required this.cheaperPricePerBase,
    required this.expensivePricePerBase,
    required this.savingsPercent,
    required this.baseUnit,
  });

  /// 'A' ou 'B'.
  final String winner;

  final double cheaperPricePerBase;
  final double expensivePricePerBase;
  final double savingsPercent;
  final String baseUnit;
}

/// Compara dois produtos e retorna qual e mais vantajoso.
///
/// Retorna null quando as unidades nao sao conhecidas ou sao de grandezas
/// diferentes (ex: massa vs volume).
PriceComparison? compareProducts(ProductEntry a, ProductEntry b) {
  final unitA = normalizeUnit(a.unit);
  final unitB = normalizeUnit(b.unit);

  if (unitA == null || unitB == null) return null;
  if (unitA.type != unitB.type) return null;

  final quantityA = a.quantity * unitA.factorToBase;
  final quantityB = b.quantity * unitB.factorToBase;

  if (quantityA <= 0 || quantityB <= 0 || a.price < 0 || b.price < 0) {
    return null;
  }

  final pricePerA = a.price / quantityA;
  final pricePerB = b.price / quantityB;

  final aWins = pricePerA <= pricePerB;
  final cheaper = aWins ? pricePerA : pricePerB;
  final expensive = aWins ? pricePerB : pricePerA;

  final savings = expensive <= 0
      ? 0.0
      : ((expensive - cheaper) / expensive) * 100;

  return PriceComparison(
    winner: aWins ? 'A' : 'B',
    cheaperPricePerBase: cheaper,
    expensivePricePerBase: expensive,
    savingsPercent: savings,
    baseUnit: unitA.baseUnit,
  );
}
