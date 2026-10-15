import 'package:serverpod/serverpod.dart';

import '../web_apps.dart';

/// `/` always redirects to Wonky Drive's home, `/drive/` (specs/01 §2.4,
/// v2 review B4): a predictable landing page with every file; the other
/// apps are one click away in every home's left menu. The v1
/// `wonky_last_app` cookie is ignored.
class RootRedirectRoute extends Route {
  @override
  Future<Result> handleCall(Session session, Request request) async =>
      Response.found(Uri.parse(rootRedirectTarget));
}
