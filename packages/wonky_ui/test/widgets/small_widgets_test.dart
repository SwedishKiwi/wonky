import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

void main() {
  for (final b in Brightness.values) {
    group('Given small widgets in ${b.name}', () {
      testWidgets('when stepping a number stepper then values clamp to range', (
        tester,
      ) async {
        num? v;
        await pumpWonky(
          tester,
          WonkyNumberStepper(
            value: 10,
            min: 1,
            max: 11,
            onChanged: (x) => v = x,
          ),
          brightness: b,
          center: true,
        );
        await tester.tap(find.bySemanticsLabel('Increase'));
        expect(v, 11);
        await tester.enterText(find.byType(EditableText), '500');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        expect(v, 11);
        await tester.enterText(find.byType(EditableText), 'abc');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(find.text('10'), findsOneWidget);
        await settleTooltips(tester);
      });

      testWidgets('when hovering the table size picker then the label follows '
          'and tap selects', (tester) async {
        (int, int)? picked;
        await pumpWonky(
          tester,
          WonkyTableSizePicker(onSelected: (r, c) => picked = (r, c)),
          brightness: b,
          center: true,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(find.text('2 × 3'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(picked, (2, 3));
      });

      testWidgets(
        'when rendering presence then at most N avatars plus +N show',
        (tester) async {
          final people = [
            for (var i = 0; i < 6; i++)
              PresenceParticipant(
                sessionId: 's$i',
                userKey: 'u$i',
                displayName: 'Person $i',
                colorIndex: i,
                activity: PresenceActivity.editing,
              ),
            const PresenceParticipant(
              sessionId: 's0b',
              userKey: 'u0',
              displayName: 'Person 0',
              colorIndex: 0,
            ),
            const PresenceParticipant(
              sessionId: 'me',
              userKey: 'me',
              displayName: 'Me',
              colorIndex: 3,
              isSelf: true,
            ),
          ];
          PresenceParticipant? jumped;
          await pumpWonky(
            tester,
            PresenceAvatarStack(
              participants: people,
              onJumpTo: (p) => jumped = p,
            ),
            brightness: b,
            center: true,
          );
          expect(
            find.byKey(const ValueKey('presence.avatar.u0')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('presence.avatar.u4')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('presence.avatar.me')),
            findsNothing,
          );
          expect(find.text('+2'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('presence.avatar.u1')));
          expect(jumped?.sessionId, 's1');
          expect(
            find.bySemanticsLabel(RegExp('Person 0 \\(2 tabs\\)')),
            findsOneWidget,
          );
          await settleTooltips(tester);
        },
      );

      testWidgets('when a remote caret is idle then its flag fades', (
        tester,
      ) async {
        await pumpWonky(
          tester,
          const RemoteCaret(name: 'Bo', color: Color(0xff2563eb), height: 18),
          brightness: b,
          center: true,
        );
        final opacity = find.byType(AnimatedOpacity);
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
      });

      testWidgets(
        'when the sync status is offline then the label shows and the '
        'details dialog offers retry',
        (tester) async {
          var retried = 0;
          await pumpWonky(
            tester,
            SyncStatusIndicator(
              status: SyncStatus(
                state: SyncState.offline,
                pendingChanges: 3,
                log: [
                  SyncLogEntry(
                    at: DateTime.utc(2026),
                    message: 'Connection lost',
                  ),
                ],
              ),
              onRetry: () => retried++,
            ),
            brightness: b,
            center: true,
          );
          // Short in the row; the details explain it.
          expect(find.text('Offline'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('sync.status')));
          await tester.pumpAndSettle();
          // In the dialog (and the tooltip).
          expect(
            find.text('Offline — changes saved on this device'),
            findsWidgets,
          );
          expect(find.text('3 changes waiting to sync'), findsOneWidget);
          expect(find.text('Connection lost'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('sync.retry')));
          await tester.pumpAndSettle();
          expect(retried, 1);
          await settleTooltips(tester);
        },
      );

      testWidgets('when rendering the status bar then the three slots show', (
        tester,
      ) async {
        await pumpWonky(
          tester,
          const Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              StatusBar(
                left: [Text('12 words')],
                center: [Text('Saved')],
                right: [Text('100%')],
              ),
            ],
          ),
          brightness: b,
        );
        expect(find.text('12 words'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
      });

      testWidgets('when showing an empty state then the illustration and texts '
          'render', (tester) async {
        await pumpWonky(
          tester,
          WonkyEmptyState(
            illustration: EmptyIllustration.starred,
            title: 'No starred files yet',
            description: 'Star files to find them here.',
            actions: [
              ShadButton(onPressed: () {}, child: const Text('Browse')),
            ],
          ),
          brightness: b,
        );
        expect(find.text('No starred files yet'), findsOneWidget);
        expect(find.byType(EmptyStateIllustration), findsOneWidget);
      });

      testWidgets('when showing shimmers then the skeletons render', (
        tester,
      ) async {
        await pumpWonky(
          tester,
          ListView(
            children: [
              LoadingShimmer.driveList(rows: 3),
              LoadingShimmer.driveGrid(cards: 2),
              LoadingShimmer.documentPage(),
              LoadingShimmer.grid(rows: 3, columns: 3),
            ],
          ),
          brightness: b,
        );
        expect(find.byType(ShadSkeleton), findsWidgets);
        expect(find.bySemanticsLabel('Loading…'), findsWidgets);
      });
    });
  }

  test(
    'Given every illustration kind when building SVG then it is well-formed',
    () {
      for (final k in EmptyIllustration.values) {
        final svg = EmptyStateIllustration.svgFor(
          k,
          surface: const Color(0xffffffff),
          stroke: const Color(0xff000000),
          accent: const Color(0xff2563eb),
          muted: const Color(0xfff4f4f5),
        );
        expect(svg, startsWith('<svg'));
        expect(svg, endsWith('</svg>'));
      }
    },
  );

  test(
    'Given avatar names when computing initials then up to two letters are used',
    () {
      expect(WonkyAvatar.initialsOf('Anna Berg'), 'AB');
      expect(WonkyAvatar.initialsOf('bo.chen@x.io'), 'BC');
      expect(WonkyAvatar.initialsOf('carl'), 'C');
      expect(WonkyAvatar.initialsOf(''), '?');
    },
  );

  test('Given key names when mapping logical keys then names round-trip', () {
    expect(WonkyKeyNames.nameOf(LogicalKeyboardKey.keyB), 'B');
    expect(WonkyKeyNames.nameOf(LogicalKeyboardKey.slash), '/');
    expect(WonkyKeyNames.nameOf(LogicalKeyboardKey.arrowUp), 'ArrowUp');
    expect(WonkyKeyNames.nameOf(LogicalKeyboardKey.shiftLeft), isNull);
    expect(WonkyKeyNames.keyOf('F2'), LogicalKeyboardKey.f2);
    expect(WonkyKeyNames.keyOf('['), LogicalKeyboardKey.bracketLeft);
  });
}
