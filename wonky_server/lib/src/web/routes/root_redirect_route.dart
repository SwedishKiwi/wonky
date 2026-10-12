import 'package:serverpod/serverpod.dart';

/// `/` redirects to the last used app (`wonky_last_app` cookie set by the
/// apps: `write` or `sheets`; default `/write/`), specs/01 §2.4.
class RootRedirectRoute extends Route {
  static const cookieName = 'wonky_last_app';

  @override
  Future<Result> handleCall(Session session, Request request) async {
    final last = request.headers.cookie?.getCookie(cookieName)?.value;
    final target = last == 'sheets' ? '/sheets/' : '/write/';
    return Response.found(Uri.parse(target));
  }
}
