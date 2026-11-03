import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Real app version read from the installed package (pubspec / CI build).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final build = info.buildNumber.isEmpty ? '' : ' (${info.buildNumber})';
  return '${info.version}$build';
});
