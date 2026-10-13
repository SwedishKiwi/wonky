import 'package:serverpod/serverpod.dart';

/// Serves `assets/config.json` of the web apps (specs/01 §2.4):
/// `{apiUrl, webUrl, apps: {write, sheets}, cookieAuth, google?}` with the
/// API URL, the public web origin (`wonky.work` in production; legal pages),
/// the base URL of each app on it (for cross-app links), whether the API
/// accepts cookie auth (specs/01 §2.5) and, when Google sign-in is
/// configured, `{clientId, redirectUri}` for the web OAuth flow (specs/04
/// §1.6).
class AppConfigWidget extends JsonWidget {
  AppConfigWidget({
    required String apiUrl,
    required String webUrl,
    required String writeUrl,
    required String sheetsUrl,
    required bool cookieAuth,
    String? googleClientId,
  }) : super(
         object: {
           'apiUrl': apiUrl,
           'webUrl': webUrl,
           'apps': {'write': writeUrl, 'sheets': sheetsUrl},
           'cookieAuth': cookieAuth,
           if (googleClientId != null)
             'google': {
               'clientId': googleClientId,
               'redirectUri': Uri.parse(
                 webUrl,
               ).resolve('/auth/callback').toString(),
             },
         },
       );
}

class AppConfigRoute extends WidgetRoute {
  /// [cookieAuth] is whether the server is configured for cookie auth
  /// (`authCookie` + `allowedOrigins`). Without it (e.g. Serverpod Cloud's
  /// generated config) the API answers CORS with `*`, which browsers reject
  /// for credentialed requests, so the apps must use token auth instead.
  ///
  /// [webOrigin] is where users reach the apps (`WonkyConfig.webOrigin`:
  /// `https://wonky.work` in production, not the generated Serverpod Cloud
  /// host).
  AppConfigRoute({
    required ServerConfig apiConfig,
    required Uri webOrigin,
    required bool cookieAuth,
    String? googleClientId,
  }) : widget = AppConfigWidget(
         apiUrl: apiConfig.publicUrl.toString(),
         webUrl: webOrigin.resolve('/').toString(),
         writeUrl: webOrigin.resolve('/write/').toString(),
         sheetsUrl: webOrigin.resolve('/sheets/').toString(),
         cookieAuth: cookieAuth,
         googleClientId: googleClientId,
       );

  final AppConfigWidget widget;

  @override
  Future<WebWidget> build(Session session, Request request) async => widget;
}

extension ServerConfigPublicUrl on ServerConfig {
  Uri get publicUrl => Uri(
    scheme: publicScheme,
    host: publicHost,
    port: publicPort,
  );
}
