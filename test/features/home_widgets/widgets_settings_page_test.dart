import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/core/notifications/notification_permission_service.dart';
import 'package:gastos_app/core/notifications/notification_permissions_provider.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/repository/categories_repository.dart';
import 'package:gastos_app/features/home_widgets/services/home_widget_service.dart';
import 'package:gastos_app/features/home_widgets/ui/pages/widgets_settings_page.dart';
import 'package:gastos_app/features/transactions/ui/pages/transaction_form_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockCategoriesRepository extends Mock implements CategoriesRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.kuanto.gastos/widgets');

  late bool hideValues;
  late List<Map<String, Object>> activeCharts;
  late List<MethodCall> recordedCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    hideValues = false;
    activeCharts = [
      {
        'widgetId': 42,
        'chartType': 'categories',
        'period': 'month',
      },
    ];
    recordedCalls = [];
    HomeWidgetService.instance.setAllowNonAndroidForTesting(enabled: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      recordedCalls.add(call);
      switch (call.method) {
        case 'getHideValues':
          return hideValues;
        case 'setHideValues':
          final args = call.arguments as Map<Object?, Object?>;
          hideValues = args['hide'] as bool? ?? false;
          return true;
        case 'isPinWidgetSupported':
          return true;
        case 'getActiveChartWidgets':
          return activeCharts;
        case 'configureChartWidget':
          final args = call.arguments as Map<Object?, Object?>;
          final id = args['widgetId'] as int;
          activeCharts = [
            for (final item in activeCharts)
              if (item['widgetId'] == id)
                {
                  'widgetId': id,
                  'chartType': args['chartType'] as String,
                  'period': args['period'] as String,
                }
              else
                item,
          ];
          return true;
        case 'requestPinWidget':
          return true;
        case 'updateWidgetData':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    HomeWidgetService.instance.setAllowNonAndroidForTesting(enabled: false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('WidgetsSettingsPage', () {
    testWidgets(
        'exibe os 4 widgets, alterna privacidade e reconfigura grafico ativo',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: WidgetsSettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gráficos ativos na tela inicial'), findsOneWidget);
      expect(find.text('Widget #42 • Mês atual'), findsOneWidget);

      // Alterna privacidade
      await tester.tap(find.text('Ocultar valores nos widgets'));
      await tester.pumpAndSettle();
      expect(hideValues, isTrue);

      // Abre editor do widget #42 e troca grafico + periodo
      await tester.tap(find.text('Trocar gráfico'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Comparativo mensal'));
      await tester.tap(find.text('Comparativo mensal'));
      await tester.pump();
      await tester.ensureVisible(find.text('3 meses'));
      await tester.tap(find.text('3 meses'));
      await tester.pump();
      await tester.ensureVisible(find.text('Aplicar no widget'));
      await tester.tap(find.text('Aplicar no widget'));
      await tester.pumpAndSettle();

      expect(find.text('Comparativo mensal'), findsOneWidget);
      expect(find.text('Widget #42 • 3 meses'), findsOneWidget);

      // Verifica os 4 widgets do catalogo rolando a lista
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Lançamento Rápido'),
        250,
        scrollable: scrollable,
      );
      expect(find.text('Lançamento Rápido'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Gráfico Financeiro'),
        250,
        scrollable: scrollable,
      );
      expect(find.text('Gráfico Financeiro'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Resumo do Mês'),
        250,
        scrollable: scrollable,
      );
      expect(find.text('Resumo do Mês'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Próximos Vencimentos'),
        250,
        scrollable: scrollable,
      );
      expect(find.text('Próximos Vencimentos'), findsOneWidget);
    });
  });

  group('TransactionFormPage initialIsExpense', () {
    testWidgets('abre com Entrada selecionada quando initialIsExpense = false',
        (tester) async {
      final catRepo = _MockCategoriesRepository();
      when(catRepo.seedDefaultCategories).thenAnswer((_) async {});
      when(
        () => catRepo.getCategories(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => const <Category>[]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesRepositoryProvider.overrideWithValue(catRepo),
            notificationPermissionsProvider.overrideWith(
              (ref) async => const NotificationPermissions(
                status: NotificationPermissionStatus.granted,
                canScheduleExact: true,
                exactAlarmsSupported: false,
              ),
            ),
          ],
          child: const MaterialApp(
            home: TransactionFormPage(
              isEditing: false,
              initialIsExpense: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final segmented = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(segmented.selected, {false});
    });
  });
}
