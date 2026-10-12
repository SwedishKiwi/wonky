/// Test helpers for widgets built on `wonky_ui` (suite 15 §7). Never import
/// from `lib/` code.
library;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';

import 'wonky_ui.dart';

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

/// The app wrapper used by [pumpWonky] (also handy for widget previews).
class WonkyTestApp extends StatelessWidget {
  const WonkyTestApp({
    super.key,
    required this.child,
    this.brightness = Brightness.light,
    this.config = const WonkyThemeConfig(),
    this.locale = const Locale('en'),
    this.extraDelegates = const [],
    this.wrap,
  });

  final Widget child;
  final Brightness brightness;
  final WonkyThemeConfig config;
  final Locale locale;
  final List<LocalizationsDelegate<dynamic>> extraDelegates;
  final TransitionBuilder? wrap;

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      debugShowCheckedModeBanner: false,
      theme: WonkyTheme.light(config),
      darkTheme: WonkyTheme.dark(config),
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      supportedLocales: const [Locale('en')],
      localizationsDelegates: [
        WonkyUiLocalizations.delegate,
        ...extraDelegates,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: WonkyThemeScope(
        data: WonkyThemeExtension(density: config.density),
        child: wrap == null ? child : Builder(builder: (c) => wrap!(c, child)),
      ),
    );
  }
}

/// Lets pending tooltip/hover timers fire so a test ends without pending
/// timers (call after tapping controls with tooltips).
Future<void> settleTooltips(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}
