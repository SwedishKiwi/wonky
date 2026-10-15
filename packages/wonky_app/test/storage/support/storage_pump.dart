import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';

/// The pseudo-locale of specs/11 §4.
const pseudoLocale = Locale('en', 'XA');

/// 50 MB (the default quota) and 1 MB.
const quota = 50 * 1024 * 1024;
const mb = 1024 * 1024;

/// A harness with [storage] and a router that knows the routes the storage
/// UI opens (Drive's Storage page, cross-app from the other apps).
CommandTestHarness storageHarness({
  StorageController? storage,
  WonkyAppKind app = WonkyAppKind.write,
}) {
  final h = CommandTestHarness(
    config: TestAppConfig(app: app),
    storage: storage,
  );
  h.services.router = GoRouter(
    routes: [
      for (final p in const ['/', '/storage', '/trash'])
        GoRoute(path: p, builder: (_, _) => const SizedBox()),
    ],
  );
  return h;
}

/// Pumps [child] like the shell does: the services are provided above the
/// app's navigator and `services.navigatorKey` is attached, so the dialogs
/// the storage UI shows (`services.navigatorContext`) register as
/// MCP-describable dialogs. With [locale] the screen (not the dialogs) gets
/// that locale.
Future<void> pumpWithShell(
  WidgetTester tester,
  CommandTestHarness h,
  Widget child, {
  Brightness brightness = Brightness.light,
  Size size = const Size(1280, 800),
  Locale? locale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // A fresh navigator (its initial route is built once per navigator).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    Provider<ShellServices>.value(
      value: h.services,
      child: WonkyTestApp(
        brightness: brightness,
        extraDelegates: const [WonkyAppLocalizations.delegate],
        child: Navigator(
          key: h.services.navigatorKey,
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            pageBuilder: (context, _, _) => locale == null
                ? child
                : Localizations.override(
                    context: context,
                    locale: locale,
                    child: child,
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
