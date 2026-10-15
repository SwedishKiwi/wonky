import 'package:serverpod/serverpod.dart';

import '../../platform/board/board_service.dart';
import '../../platform/common/models.dart';

/// Signature of the screenshot URL lookup (tests replace it).
typedef BoardScreenshotUrl =
    Future<String?> Function(Session session, int postNumber);

/// `/improvements` and `/improvements/**` (specs/16 §4.3): links in emails,
/// PRs and task prompts point at the site; they open in Wonky Drive,
/// `/drive/improvements/…`, keeping the rest of the path and the query.
///
/// `/improvements/p/<n>/screenshot` is the stable screenshot link used in
/// task prompts (specs/16 §10.1): it redirects to a fresh signed URL of the
/// post's screenshot, or answers 404 when the post has none or isn't
/// public.
class ImprovementsRedirectRoute extends Route {
  ImprovementsRedirectRoute({BoardScreenshotUrl? screenshotUrl})
    : _screenshotUrl = screenshotUrl ?? BoardService.getScreenshotUrl;

  final BoardScreenshotUrl _screenshotUrl;

  static final _screenshot = RegExp(r'^/improvements/p/(\d+)/screenshot/?$');

  @override
  Future<Result> handleCall(Session session, Request request) async {
    final path = request.url.path;
    final shot = _screenshot.firstMatch(path);
    if (shot != null) {
      final number = int.tryParse(shot[1]!);
      String? url;
      if (number != null) {
        try {
          url = await _screenshotUrl(session, number);
        } on WonkyException {
          url = null;
        }
      }
      if (url == null) return Response.notFound();
      return Response.found(Uri.parse(url));
    }
    return Response.found(Uri.parse(improvementsTarget(request.url)));
  }
}

/// `/improvements/p/12?x=1` → `/drive/improvements/p/12?x=1`.
String improvementsTarget(Uri url) {
  var path = url.path;
  if (!path.startsWith('/')) path = '/$path';
  final target = '/drive$path';
  return url.hasQuery ? '$target?${url.query}' : target;
}
