import 'package:meta/meta.dart';
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/common/models.dart';

import 'test_drive.dart';
import 'test_users.dart';
import 'wonky_serverpod.dart';

/// The item and people of one permission-matrix case.
class RoleCase {
  RoleCase(this.owner, this.item);
  final TestUser owner;
  final DriveItemView item;
}

/// Generates one test per role (owner, editor, commenter, viewer, no
/// access) plus unauthenticated, asserting that [act] succeeds exactly for
/// [allowed] (specs/15 §6). Denied calls must throw a [WonkyException]
/// (`forbidden` or `notFound`) or, unauthenticated, a
/// [ServerpodUnauthenticatedException].
@isTestGroup
void forEachRole(
  String given,
  TestEndpoints endpoints,
  TestSessionBuilder sessionBuilder, {
  required Set<AccessRole?> allowed,
  required Future<void> Function(TestSessionBuilder caller, RoleCase c) act,
  Future<DriveItemView> Function(TestUser owner)? setup,
}) {
  group(given, () {
    for (final role in allRoles) {
      final label = role?.name ?? 'no access';
      final expectAllowed = allowed.contains(role);
      test(
        'when called with ${role == null ? 'no access' : 'role $label'} then it '
        '${expectAllowed ? 'succeeds' : 'is refused'}',
        () async {
          final owner = await TestUsers.create(sessionBuilder, name: 'Owner');
          final item = setup != null
              ? await setup(owner)
              : await TestDrive.document(endpoints, owner);
          final c = RoleCase(owner, item);
          TestUser caller;
          if (role == AccessRole.owner) {
            caller = owner;
          } else {
            caller = await TestUsers.create(sessionBuilder, name: 'Caller');
            if (role != null) {
              await TestDrive.share(endpoints, item, owner, caller, role);
            }
          }
          final call = act(caller.endpointSession, c);
          if (expectAllowed) {
            await call;
          } else {
            await expectLater(
              call,
              throwsA(
                isA<WonkyException>().having(
                  (e) => e.code,
                  'code',
                  anyOf(WonkyErrorCode.forbidden, WonkyErrorCode.notFound),
                ),
              ),
            );
          }
        },
      );
    }
    test('when called unauthenticated then it is refused', () async {
      final owner = await TestUsers.create(sessionBuilder, name: 'Owner');
      final item = setup != null
          ? await setup(owner)
          : await TestDrive.document(endpoints, owner);
      await expectLater(
        act(TestUsers.unauthenticated(sessionBuilder), RoleCase(owner, item)),
        throwsA(
          anyOf(
            isA<ServerpodUnauthenticatedException>(),
            isA<WonkyException>(),
          ),
        ),
      );
    });
  });
}
