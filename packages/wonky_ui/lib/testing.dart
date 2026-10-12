/// Test helpers for widgets built on `wonky_ui` (suite 15 §7). Never import
/// from `lib/` code.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'src/preview/wonky_preview_app.dart';
import 'wonky_ui.dart';

export 'src/preview/wonky_preview_app.dart';

/// Pumps [child] inside a `ShadApp` with the Wonky theme, localizations and
/// a desktop-sized surface.
///
/// ```dart
/// for (final b in Brightness.values) {
///   testWidgets('… ${b.name}', (tester) async {
///     await pumpWonky(tester, const MyWidget(), brightness: b);
///   });
/// }
/// ```
Future<void> pumpWonky(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  WonkyDensity density = WonkyDensity.comfortable,
  String? accent,
  Locale locale = const Locale('en'),
  Size size = const Size(1280, 800),
  bool center = false,
  List<LocalizationsDelegate<dynamic>> extraDelegates = const [],
  TransitionBuilder? wrap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final config = WonkyThemeConfig(accent: accent, density: density);
  await tester.pumpWidget(
    WonkyTestApp(
      brightness: brightness,
      config: config,
      locale: locale,
      extraDelegates: extraDelegates,
      wrap: wrap,
      child: center ? Center(child: child) : child,
    ),
  );
  await tester.pump();
}

/// Lets pending tooltip/hover timers fire so a test ends without pending
/// timers (call after tapping controls with tooltips).
Future<void> settleTooltips(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}
