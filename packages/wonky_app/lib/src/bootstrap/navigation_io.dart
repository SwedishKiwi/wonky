import 'package:url_launcher/url_launcher.dart';

/// Desktop: another Wonky app is a separate binary; launch it through its
/// URL scheme and fall back to the web URL (suite 03 §6).
Future<void> openOtherApp(String schemeUrl, String webUrl) async {
  final scheme = Uri.parse(schemeUrl);
  if (await canLaunchUrl(scheme) && await launchUrl(scheme)) return;
  await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
}

/// Opens an external link in the system browser.
Future<void> openExternal(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Desktop has no page reload; restart is handled by the shell.
void reloadPage() {}

/// Sets the `wonky_last_app` cookie (web only).
void rememberLastApp(String app) {}
