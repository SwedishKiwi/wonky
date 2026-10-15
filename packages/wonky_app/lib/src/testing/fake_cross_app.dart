import '../bootstrap/app_urls.dart';
import '../bootstrap/cross_app.dart';

/// A [CrossAppNavigator] that records instead of navigating (no page loads,
/// no `url_launcher` in tests). `CommandTestHarness` installs one.
class FakeCrossApp extends CrossAppNavigator {
  FakeCrossApp(super.urls, {this.browser = 'Chrome 131'});

  /// The browser label [browserLabel] reports.
  final String? browser;

  /// Cross-app navigations, in order: `(app, path)`.
  final List<(WonkyAppKind, String)> opened = [];

  /// External links opened in the system browser.
  final List<String> external = [];

  /// The apps remembered as last used.
  final List<WonkyAppKind> remembered = [];

  int reloads = 0;

  @override
  Future<void> open(WonkyAppKind app, String path) async =>
      opened.add((app, path));

  @override
  Future<void> openExternal(String url) async => external.add(url);

  @override
  void reload() => reloads++;

  /// Whether [historyBack] finds a previous browser page.
  bool hasHistory = false;

  /// Browser history steps back.
  int historyBacks = 0;

  @override
  bool historyBack() {
    if (!hasHistory) return false;
    historyBacks++;
    return true;
  }

  @override
  void rememberLastApp(WonkyAppKind app) => remembered.add(app);

  @override
  String? browserLabel() => browser;
}
