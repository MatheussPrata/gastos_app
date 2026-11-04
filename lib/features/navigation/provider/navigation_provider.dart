import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Index of the tab currently selected in the main bottom navigation bar.
///
/// Keeping the selection in a provider lets any screen jump to another tab
/// without rebuilding the whole widget tree or pushing a new route.
final bottomNavIndexProvider = StateProvider<int>((ref) => AppTab.home);

/// Stable indexes for the bottom navigation destinations, left to right.
abstract final class AppTab {
  static const int home = 0;
  static const int reports = 1;
  static const int planning = 2;
}
