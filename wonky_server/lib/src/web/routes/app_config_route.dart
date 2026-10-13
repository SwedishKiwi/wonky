import 'package:serverpod/serverpod.dart';

/// Serves `assets/config.json` of the web apps (specs/01 §2.4):
/// `{apiUrl, apps: {write, sheets}, cookieAuth}` with the API URL, the base
/// URL of each app on this web server (for cross-app links) and whether the
/// API accepts cookie auth (specs/01 §2.5).
class AppConfigWidget extends JsonWidget {
  AppConfigWidget({
    required String apiUrl,
    required String writeUrl,
    required String sheetsUrl,
    required bool cookieAuth,
  }) : super(
         object: {
           'apiUrl': apiUrl,
           'apps': {'write': writeUrl, 'sheets': sheetsUrl},
           'cookieAuth': cookieAuth,
         },
       );
}

class AppConfigRoute extends WidgetRoute {
  /// [cookieAuth] is whether the server is configured for cookie auth
  /// (`authCookie` + `allowedOrigins`). Without it (e.g. Serverpod Cloud's
  /// generated config) the API answers CORS with `*`, which browsers reject
  /// for credentialed requests, so the apps must use token auth instead.
  AppConfigRoute({
    required ServerConfig apiConfig,
    required ServerConfig webConfig,
    required bool cookieAuth,
  }) : widget = AppConfigWidget(
         apiUrl: apiConfig.publicUrl.toString(),
         writeUrl: webConfig.publicUrl.resolve('/write/').toString(),
         sheetsUrl: webConfig.publicUrl.resolve('/sheets/').toString(),
         cookieAuth: cookieAuth,
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
