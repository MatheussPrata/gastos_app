import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/navigation/provider/navigation_provider.dart';

void main() {
  test('bottom navigation starts on the home tab', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(bottomNavIndexProvider), AppTab.home);
  });

  test('bottom navigation index can be changed programmatically', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(bottomNavIndexProvider.notifier).state = AppTab.reports;

    expect(container.read(bottomNavIndexProvider), AppTab.reports);
  });
}
