import 'package:gastos_app/features/reports/ui/pages/reports_page.dart';

/// Gráficos disponíveis para exibição no widget configurável da tela inicial.
enum HomeWidgetChartType {
  categories(
    key: 'categories',
    label: 'Gastos por categoria',
    description: 'Gráfico de rosca com top categorias e percentuais',
  ),
  balance(
    key: 'balance',
    label: 'Saldo ao longo do tempo',
    description: 'Evolução acumulada ou mensal do seu saldo líquido',
  ),
  monthly(
    key: 'monthly',
    label: 'Comparativo mensal',
    description: 'Barras lado a lado de entradas e saídas por mês',
  ),
  paymentMethods(
    key: 'payment_methods',
    label: 'Formas de pagamento',
    description: 'Distribuição entre Pix, cartão, dinheiro e boleto',
  ),
  cards(
    key: 'cards',
    label: 'Gastos por cartão',
    description: 'Faturas e uso sobre o limite individual de cada cartão',
  );

  const HomeWidgetChartType({
    required this.key,
    required this.label,
    required this.description,
  });

  final String key;
  final String label;
  final String description;

  /// Converte a chave salva no Android para o enum correspondente.
  static HomeWidgetChartType fromKey(String? raw) {
    for (final value in HomeWidgetChartType.values) {
      if (value.key == raw) return value;
    }
    return HomeWidgetChartType.categories;
  }
}

/// Períodos suportados pelos widgets de gráfico.
enum HomeWidgetPeriod {
  month(key: 'month', label: 'Mês atual'),
  quarter(key: 'quarter', label: '3 meses'),
  year(key: 'year', label: 'Ano');

  const HomeWidgetPeriod({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;

  /// Converte a chave salva no Android para o enum correspondente.
  static HomeWidgetPeriod fromKey(String? raw) {
    for (final value in HomeWidgetPeriod.values) {
      if (value.key == raw) return value;
    }
    return HomeWidgetPeriod.month;
  }

  /// Converte para o período correspondente da tela de Relatórios.
  ReportPeriod toReportPeriod() {
    return switch (this) {
      HomeWidgetPeriod.month => ReportPeriod.month,
      HomeWidgetPeriod.quarter => ReportPeriod.quarter,
      HomeWidgetPeriod.year => ReportPeriod.year,
    };
  }
}

/// Tipos de widget disponíveis para fixação na tela inicial Android.
enum HomeWidgetKind {
  quickAdd(
    key: 'quick_add',
    title: 'Lançamento Rápido',
    subtitle: 'Botões diretos para novo gasto, nova entrada e leitor de cupom NFC-e.',
    sizeBadge: '4×1',
  ),
  chart(
    key: 'chart',
    title: 'Gráfico Financeiro',
    subtitle: 'Escolha qualquer um dos 5 gráficos e o período; aceita vários widgets.',
    sizeBadge: '4×3',
  ),
  summary(
    key: 'summary',
    title: 'Resumo do Mês',
    subtitle: 'Saldo líquido, entradas, saídas, barra do orçamento e botão de ocultar valores.',
    sizeBadge: '4×2',
  ),
  upcomingBills(
    key: 'upcoming_bills',
    title: 'Próximos Vencimentos',
    subtitle: 'Contas recorrentes, faturas de cartão e lembretes nos próximos 15 dias.',
    sizeBadge: '4×2',
  );

  const HomeWidgetKind({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.sizeBadge,
  });

  final String key;
  final String title;
  final String subtitle;
  final String sizeBadge;
}

/// Configuração de uma instância ativa do widget de gráfico na tela inicial.
class ActiveChartWidgetConfig {
  /// Cria a configuração de uma instância do widget de gráfico.
  const ActiveChartWidgetConfig({
    required this.widgetId,
    required this.chartType,
    required this.period,
  });

  final int widgetId;
  final HomeWidgetChartType chartType;
  final HomeWidgetPeriod period;
}

/// Ação disparada ao tocar em algum elemento de um widget Android.
class WidgetLaunchAction {
  /// Cria uma ação de navegação recebida do widget Android.
  const WidgetLaunchAction({
    required this.route,
    this.chartType,
    this.period,
  });

  /// Converte o mapa recebido via `MethodChannel` em [WidgetLaunchAction].
  factory WidgetLaunchAction.fromMap(Map<Object?, Object?> raw) {
    final route = raw['route'] as String? ?? 'dashboard';
    final chartRaw = raw['chartType'] as String?;
    final periodRaw = raw['period'] as String?;
    return WidgetLaunchAction(
      route: route,
      chartType: chartRaw == null ? null : HomeWidgetChartType.fromKey(chartRaw),
      period: periodRaw == null ? null : HomeWidgetPeriod.fromKey(periodRaw),
    );
  }

  final String route;
  final HomeWidgetChartType? chartType;
  final HomeWidgetPeriod? period;
}
