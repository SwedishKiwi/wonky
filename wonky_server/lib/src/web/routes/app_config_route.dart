import 'package:serverpod/serverpod.dart';

/// Serves `assets/config.json` of the web apps (specs/01 §2.4):
/// `{apiUrl, apps: {write, sheets}}` with the API URL and the base URL of
/// each app on this web server (for cross-app links).
class AppConfigWidget extends JsonWidget {
  AppConfigWidget({
    required String apiUrl,
    required String writeUrl,
    required String sheetsUrl,
  }) : super(
         object: {
           'apiUrl': apiUrl,
           'apps': {'write': writeUrl, 'sheets': sheetsUrl},
         },
       );
}

class AppConfigRoute extends WidgetRoute {
  AppConfigRoute({
    required ServerConfig apiConfig,
    required ServerConfig webConfig,
  }) : widget = AppConfigWidget(
         apiUrl: apiConfig.publicUrl.toString(),
         writeUrl: webConfig.publicUrl.resolve('/write/').toString(),
         sheetsUrl: webConfig.publicUrl.resolve('/sheets/').toString(),
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
