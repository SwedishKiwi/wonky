import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';

/// `/invite/:token` (specs/06 §2.2): redirects to the invite landing route
/// of the item's app (`/write/invite/:token` or `/sheets/invite/:token`),
/// which resolves it with `sharing.resolveInvite` after sign-in.
class InviteRoute extends Route {
  static const _token = PathParam<String>(#token, _id);
  static String _id(String s) => s;

  @override
  Future<Result> handleCall(Session session, Request request) async {
    final token = request.pathParameters.get(_token);
    final link = await ShareLink.db.findFirstRow(
      session,
      where: (t) => t.token.equals(token),
    );
    final item = link == null
        ? null
        : await DriveItem.db.findById(session, link.itemId);
    final app = item?.kind == DriveItemKind.spreadsheet ? 'sheets' : 'write';
    final encoded = Uri.encodeComponent(token);
    return Response.found(Uri.parse('/$app/invite/$encoded'));
  }
}
