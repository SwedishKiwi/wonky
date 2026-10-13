import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';

/// The pseudo-locale of specs/11 §4.
const pseudoLocale = Locale('en', 'XA');

/// Pumps a shell screen with the harness services, in [brightness] and,
/// with [locale], under that locale (e.g. [pseudoLocale]; the test app
/// itself only resolves `en`, so the screen gets a locale override).
Future<void> pumpScreen(
  WidgetTester tester,
  CommandTestHarness h,
  Widget screen, {
  Brightness brightness = Brightness.light,
  Locale? locale,
  Size size = const Size(1440, 900),
}) async {
  await pumpWonky(
    tester,
    screen,
    brightness: brightness,
    size: size,
    extraDelegates: const [WonkyAppLocalizations.delegate],
    wrap: (context, child) => Provider<ShellServices>.value(
      value: h.services,
      child: locale == null
          ? child!
          : Localizations.override(
              context: context,
              locale: locale,
              child: child,
            ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The screen-level accessibility checks of suite 15 §7: text contrast and
/// labeled tap targets. [contrast] false skips the contrast check for a
/// known, reported theme issue.
Future<void> expectAccessible(
  WidgetTester tester, {
  bool contrast = true,
}) async {
  if (contrast) {
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}
