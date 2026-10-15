import 'package:serverpod/serverpod.dart';

import '../common/models.dart';
import '../users/user_service.dart';
import 'board_config.dart';

/// Who is a board admin (specs/16 §9.1): a user whose account email is in
/// `board.adminEmailDomains` or `board.adminEmails`. Never stored, so a
/// config change takes effect at the next request.
///
/// The profile email is trustworthy: email/password accounts exist only
/// after the verification code, Google sign-in rejects unverified emails
/// (`GoogleIdpConfig.validateGoogleAccountDetails`, the package default),
/// and there is no email-change endpoint. A server test guards these.
abstract final class BoardAdmins {
  /// Whether [email] belongs to an admin under [config].
  static bool isAdminEmail(String email, [BoardConfig? config]) {
    final c = config ?? BoardConfig.current;
    final e = email.trim().toLowerCase();
    if (c.adminEmails.contains(e)) return true;
    final at = e.lastIndexOf('@');
    if (at < 0) return false;
    return c.adminEmailDomains.contains(e.substring(at + 1));
  }

  /// Whether the profile [userId] is an admin.
  static Future<bool> isAdminUser(Session session, int userId) async {
    final profile = await UserProfile.db.findById(session, userId);
    return profile != null && isAdminEmail(profile.email);
  }

  /// Admin status of many users at once (for author badges).
  static Future<Set<int>> adminsAmong(
    Session session,
    Iterable<int?> userIds,
  ) async {
    final ids = userIds.whereType<int>().toSet();
    if (ids.isEmpty) return const {};
    final profiles = await UserProfile.db.find(
      session,
      where: (t) => t.id.inSet(ids),
    );
    return {
      for (final p in profiles)
        if (isAdminEmail(p.email)) p.id!,
    };
  }

  /// The signed-in caller's profile id and admin status, or null when
  /// signed out.
  static Future<({int userId, bool isAdmin})?> caller(Session session) async {
    if (session.authenticated == null) return null;
    final actor = await UserService.actorOf(session);
    return (
      userId: actor.userId,
      isAdmin: await isAdminUser(session, actor.userId),
    );
  }
}
