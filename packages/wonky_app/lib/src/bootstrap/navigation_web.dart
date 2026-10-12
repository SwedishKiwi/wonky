import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

/// Web: same-tab full page load to the other app (single-window rule).
Future<void> openOtherApp(String schemeUrl, String webUrl) async {
  web.window.location.assign(webUrl);
}

/// External links open in the system browser (a new browser tab is the
/// browser's choice for external content, never for app content).
Future<void> openExternal(String url) =>
    launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');

/// Reloads the page (version mismatch "Reload").
void reloadPage() => web.window.location.reload();

/// Remembers the last used app so `/` on the server redirects to it.
void rememberLastApp(String app) {
  web.document.cookie = 'wonky_last_app=$app; path=/; max-age=31536000; samesite=lax';
}
