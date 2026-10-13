import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

void main() {
  testWidgets('Given an avatar with initials then they are centered and not '
      'spaced', (tester) async {
    await pumpWonky(
      tester,
      const DefaultTextStyle(
        // A host style with letter spacing must not shift the initials.
        style: TextStyle(letterSpacing: 4),
        child: WonkyAvatar(name: 'Viktor', color: Color(0xff3b82f6), size: 40),
      ),
      center: true,
    );

    final avatar = tester.getRect(find.byType(WonkyAvatar));
    final text = find.text('V');
    expect(tester.widget<Text>(text).style!.letterSpacing, 0);
    expect(tester.getCenter(text).dx, closeTo(avatar.center.dx, 0.5));
  });

  testWidgets('Given the presence stack then a ringed avatar fits inside it '
      '(the ring is not clipped)', (tester) async {
    await pumpWonky(
      tester,
      const PresenceAvatarStack(
        participants: [
          PresenceParticipant(
            sessionId: 's1',
            userKey: 'u1',
            displayName: 'Viktor',
            colorIndex: 2,
          ),
        ],
      ),
      center: true,
    );

    final stack = tester.getRect(find.byType(PresenceAvatarStack));
    final avatar = tester.getRect(
      find.byKey(const ValueKey('presence.avatar.u1')),
    );
    expect(stack.contains(avatar.topLeft), isTrue);
    expect(avatar.bottom, lessThanOrEqualTo(stack.bottom));
    expect(avatar.right, lessThanOrEqualTo(stack.right));
    await settleTooltips(tester);
  });
}
