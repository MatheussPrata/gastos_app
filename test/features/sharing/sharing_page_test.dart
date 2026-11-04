import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/features/auth/models/auth_models.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/sharing/models/sharing_models.dart';
import 'package:gastos_app/features/sharing/repository/sharing_repository.dart';
import 'package:gastos_app/features/sharing/ui/pages/sharing_page.dart';
import 'package:mocktail/mocktail.dart';

class FakePlanningRepository extends Mock implements PlanningRepository {}

class FakeSharingRepository extends SharingRepository {
  FakeSharingRepository({this.connection});

  SharingConnection? connection;
  bool disconnected = false;
  final List<Map<String, bool?>> updateCalls = [];

  @override
  Future<SharingConnection?> getConnection() async => connection;

  @override
  Future<SharingConnection?> getCachedConnection() async => connection;

  @override
  Future<SharingInvite> createInvite() async => SharingInvite(
        code: 'ABCD2345',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

  @override
  Future<SharingConnection> join(String code) async {
    return connection ??= SharingConnection(
      id: 'conn-1',
      partnerUserId: 'partner-1',
      partnerUsername: 'Maria',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<SharingConnection> updateSharing(
    SharingConnection connection, {
    bool? shareTransactions,
  }) async {
    updateCalls.add({
      'shareTransactions': shareTransactions,
    });
    return this.connection = connection.copyWith(
      shareTransactions: shareTransactions,
    );
  }

  @override
  Future<void> disconnect(SharingConnection connection) async {
    disconnected = true;
    this.connection = null;
  }

  @override
  Future<SharingSyncResult> syncNow({DateTime? planMonth}) async {
    if (connection == null) return const SharingSyncResult();
    return SharingSyncResult(
      partnerUsername: connection!.partnerUsername,
      pulledTransactions: 2,
    );
  }
}

User _user() => User(
      id: 'u1',
      email: 'fulano@exemplo.com',
      username: 'Fulano',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Widget _wrap(SharingRepository repository) {
  final planning = FakePlanningRepository();
  when(
    () => planning.checkAndCreateAlerts(
      month: any(named: 'month'),
      scope: any(named: 'scope'),
    ),
  ).thenAnswer((_) async => const <BudgetAlert>[]);

  return ProviderScope(
    overrides: [
      sharingRepositoryProvider.overrideWithValue(repository),
      planningRepositoryProvider.overrideWithValue(planning),
      currentUserProvider.overrideWithValue(_user()),
    ],
    child: const MaterialApp(home: SharingPage()),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(BudgetScope.individual);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('sem conexao mostra o fluxo de convite', (tester) async {
    await tester.pumpWidget(_wrap(FakeSharingRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Conecte dois dispositivos'), findsOneWidget);
    expect(find.text('Gerar codigo de convite'), findsOneWidget);

    await tester.tap(find.text('Gerar codigo de convite'));
    await tester.pumpAndSettle();

    final selectable =
        tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectable.data, 'ABCD2345');
    expect(find.text('Copiar codigo'), findsOneWidget);
  });

  testWidgets('conectado mostra parceiro e switches', (tester) async {
    final repository = FakeSharingRepository(
      connection: SharingConnection(
        id: 'conn-1',
        partnerUserId: 'partner-1',
        partnerUsername: 'Maria',
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Dispositivos conectados'), findsOneWidget);

    final gastosSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Compartilhar gastos'),
    );
    expect(gastosSwitch.value, isTrue);

    await tester.tap(find.text('Compartilhar gastos'));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, hasLength(1));
    expect(repository.updateCalls.single['shareTransactions'], isFalse);

    final updatedSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Compartilhar gastos'),
    );
    expect(updatedSwitch.value, isFalse);
  });

  testWidgets('desconectar remove a conexao', (tester) async {
    final repository = FakeSharingRepository(
      connection: SharingConnection(
        id: 'conn-1',
        partnerUserId: 'partner-1',
        partnerUsername: 'Maria',
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Desconectar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desconectar'));
    await tester.pumpAndSettle();

    // Confirma o dialogo.
    await tester.tap(find.widgetWithText(FilledButton, 'Desconectar'));
    await tester.pumpAndSettle();

    expect(repository.disconnected, isTrue);
    expect(find.text('Conecte dois dispositivos'), findsOneWidget);

    // Deixa o snackbar expirar para nao sobrar timer pendente.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('sincronizar mostra o resumo do parceiro', (tester) async {
    final repository = FakeSharingRepository(
      connection: SharingConnection(
        id: 'conn-1',
        partnerUserId: 'partner-1',
        partnerUsername: 'Maria',
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sincronizar agora'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 gasto(s)'), findsOneWidget);

    // Deixa o snackbar expirar para nao sobrar timer pendente.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
