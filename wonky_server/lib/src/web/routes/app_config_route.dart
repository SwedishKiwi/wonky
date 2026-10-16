import 'package:serverpod/serverpod.dart';

import '../web_apps.dart';

/// Serves `assets/config.json` of the web apps (specs/01 §2.4):
/// `{apiUrl, webUrl, apps: {drive, write, sheets, slides}, cookieAuth,
/// google?}` with the API URL, the public web origin (`wonky.work` in
/// production; legal pages), the base URL of each app on it (for cross-app
/// links; all four apps, also before one is built), whether the API
/// accepts cookie auth (specs/01 §2.5) and, when Google sign-in is
/// configured, `{clientId, redirectUri}` for the web OAuth flow (specs/04
/// §1.6), and `board: false` when Bugs & improvements is turned off
/// (`board.enabled`, specs/16 §4.1; the apps then link to GitHub issues).
class AppConfigWidget extends JsonWidget {
  AppConfigWidget({
    required String apiUrl,
    required String webUrl,
    required Map<String, String> apps,
    required bool cookieAuth,
    String? googleClientId,
    bool board = true,
  }) : super(
         object: {
           'apiUrl': apiUrl,
           'webUrl': webUrl,
           'apps': apps,
           'cookieAuth': cookieAuth,
           if (googleClientId != null)
             'google': {
               'clientId': googleClientId,
               'redirectUri': Uri.parse(
                 webUrl,
               ).resolve('/auth/callback').toString(),
             },
           if (!board) 'board': false,
         },
       );
}

class AppConfigRoute extends WidgetRoute {
  /// [cookieAuth] is whether the server is configured for cookie auth
  /// (`authCookie` + `allowedOrigins`). Without it (e.g. Serverpod Cloud's
  /// generated config) the API answers CORS with `*`, which browsers reject
  /// for credentialed requests, so the apps must use token auth instead.
  ///
  /// [apiUrl] is where the apps call the API (`WonkyConfig.apiUrl`:
  /// `https://api.wonky.work` in production) and [webOrigin] where users
  /// reach the apps (`WonkyConfig.webOrigin`: `https://wonky.work`), not
  /// the generated Serverpod Cloud hosts.
  AppConfigRoute({
    required Uri apiUrl,
    required Uri webOrigin,
    required bool cookieAuth,
    String? googleClientId,
    bool board = true,
  }) : widget = AppConfigWidget(
         apiUrl: apiUrl.toString(),
         webUrl: webOrigin.resolve('/').toString(),
         apps: {
           for (final app in webApps)
             app: webOrigin.resolve('/$app/').toString(),
         },
         cookieAuth: cookieAuth,
         googleClientId: googleClientId,
         board: board,
       );

  final AppConfigWidget widget;

  @override
  Future<WebWidget> build(Session session, Request request) async => widget;
}
