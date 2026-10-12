import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

void main() {
  group('Given the role order viewer < commenter < editor < owner', () {
    test('when comparing then >= and < follow the order', () {
      expect(Role.owner >= Role.editor, isTrue);
      expect(Role.editor >= Role.editor, isTrue);
      expect(Role.commenter >= Role.editor, isFalse);
      expect(Role.viewer < Role.commenter, isTrue);
      expect(Role.owner > Role.owner, isFalse);
      expect(Role.viewer <= Role.viewer, isTrue);
    });

    for (final (role, comment, edit, owner) in [
      (Role.viewer, false, false, false),
      (Role.commenter, true, false, false),
      (Role.editor, true, true, false),
      (Role.owner, true, true, true),
    ]) {
      test('when asking capabilities of $role then they match the matrix', () {
        expect((
          role.canComment,
          role.canEdit,
          role.isOwner,
        ), equals((comment, edit, owner)));
      });
    }

    test('when taking the highest of several roles then the max wins', () {
      expect(Role.highest([Role.viewer, null, Role.editor]), Role.editor);
      expect(Role.highest(const []), isNull);
    });

    test('when parsing names then unknown names yield null', () {
      expect(Role.tryParse('editor'), Role.editor);
      expect(Role.tryParse('admin'), isNull);
    });
  });

  test('Given an unknown actor kind name when parsing then it is user', () {
    expect(ActorKind.parse('mcp'), ActorKind.mcp);
    expect(ActorKind.parse('robot'), ActorKind.user);
  });
}
