import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/main.dart';

void main() {
  testWidgets('App smoke test - initial startup', (WidgetTester tester) async {
    // Pump the app wrapped in ProviderScope
    // Use pump only (not pumpAndSettle) to avoid timeout on network/async init
    await tester.pumpWidget(const ProviderScope(child: GastosApp()));

    // Verify no exception was thrown during widget tree build
    expect(tester.takeException(), isNull);
  });
}