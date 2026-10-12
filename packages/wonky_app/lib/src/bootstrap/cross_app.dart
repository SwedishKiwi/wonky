import 'app_urls.dart';
import 'navigation_io.dart'
    if (dart.library.js_interop) 'navigation_web.dart'
    as nav;

/// Cross-app navigation (suite 03 §1, §6): Write ⇄ Sheets in the same window.
class CrossAppNavigator {
  const CrossAppNavigator(this.urls);

  final AppUrls urls;

  /// Opens [path] (e.g. `/s/<uuid>`, `/`) in [app].
  Future<void> open(WonkyAppKind app, String path) {
    final web = urls.urlFor(app, path);
    final p = path.startsWith('/') ? path.substring(1) : path;
    final scheme = app == WonkyAppKind.sheets
        ? 'wonkysheets://$p'
        : 'wonkywrite://$p';
    return nav.openOtherApp(scheme, web);
  }

  /// Opens an external URL in the system browser (after the confirm popover).
  Future<void> openExternal(String url) => nav.openExternal(url);

  /// Reloads the web page.
  void reload() => nav.reloadPage();

  /// Remembers [app] as the last used app (web cookie).
  void rememberLastApp(WonkyAppKind app) => nav.rememberLastApp(app.name);
}
