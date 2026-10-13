import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_app/wonky_app.dart' show WonkyAppLocalizations;
import 'package:wonky_ui/testing.dart';
import 'package:wonky_write/features/suggestions/suggestion_card.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../document/support/session_harness.dart';
import '../sync/support/fake_document_server.dart';

const _other = '00000000-0000-7000-8000-000000000002';
const _me = '00000000-0000-7000-8000-000000000001';

Delta _withSuggestion(String by) => Delta()
  ..insert('Hello')
  ..insert(' there', {
    'sug_s1': {'t': 'ins', 'by': by, 'at': 5},
  })
  ..insert('\n');

Future<SessionHarness> _open(
  WidgetTester tester,
  Delta doc, {
  AccessRole role = AccessRole.editor,
}) async {
  final server = FakeDocumentServer(initial: doc);
  final h = SessionHarness(server, role: role);
  server.setRole(1, role);
  await tester.runAsync(() => h.open());
  addTearDown(() => tester.runAsync(h.dispose));
  return h;
}

void main() {
  for (final brightness in Brightness.values) {
    group(
      'Given an editor and a collaborator\'s suggestion (${brightness.name})',
      () {
        testWidgets(
          'when the card is shown then it summarizes the change with Accept and Reject',
          (tester) async {
            final h = await _open(tester, _withSuggestion(_other));
            final s = h.session.suggestions.pending.single;

            await pumpWonky(
              tester,
              SizedBox(
                width: 300,
                child: SuggestionCard(session: h.session, suggestion: s),
              ),
              brightness: brightness,
            );

            expect(find.text('Add: ‘there’'), findsOneWidget);
            expect(
              find.byKey(const ValueKey('write.suggestion.s1.accept')),
              findsOneWidget,
            );
            expect(
              find.byKey(const ValueKey('write.suggestion.s1.reject')),
              findsOneWidget,
            );
          },
        );

        testWidgets('when accepting then the suggestion is applied', (
          tester,
        ) async {
          final h = await _open(tester, _withSuggestion(_other));
          final s = h.session.suggestions.pending.single;
          await pumpWonky(
            tester,
            SizedBox(
              width: 300,
              child: SuggestionCard(session: h.session, suggestion: s),
            ),
            brightness: brightness,
          );

          await tester.tap(
            find.byKey(const ValueKey('write.suggestion.s1.accept')),
          );
          await tester.pump();

          expect(h.session.suggestions.pending, isEmpty);
          expect(DeltaUtils.text(h.doc), 'Hello there\n');
        });
      },
    );
  }

  group('Given a commenter and their own suggestion', () {
    testWidgets('when the card is shown then only Withdraw is offered', (
      tester,
    ) async {
      final h = await _open(
        tester,
        _withSuggestion(_me),
        role: AccessRole.commenter,
      );
      final s = h.session.suggestions.pending.single;

      await pumpWonky(
        tester,
        SizedBox(
          width: 300,
          child: SuggestionCard(session: h.session, suggestion: s),
        ),
      );

      expect(
        find.byKey(const ValueKey('write.suggestion.s1.accept')),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Withdraw suggestion'), findsOneWidget);
    });
  });

  group('Given a suggestion with a reply in its thread', () {
    testWidgets('when the card is shown then the reply is on the card', (
      tester,
    ) async {
      final server = FakeDocumentServer(initial: _withSuggestion(_other));
      final h = SessionHarness(server);
      final threadUuid = UuidValue.fromString(
        '00000000-0000-7000-8000-0000000000aa',
      );
      h.comments.threads[threadUuid.uuid] = CommentThreadView(
        uuid: threadUuid,
        itemUuid: h.session.itemUuid,
        anchorKind: CommentAnchorKind.textRange,
        anchorJson: '{"v":1,"suggestionId":"s1"}',
        suggestionId: 's1',
        status: CommentStatus.open,
        createdBy: userSummary(2),
        createdAt: DateTime.utc(2026),
        comments: [
          CommentView(
            id: 1,
            threadUuid: threadUuid,
            author: userSummary(1),
            authorKind: ActorKind.user,
            body: 'Shorter is better here',
            mentions: const [],
            reactions: const {},
            createdAt: DateTime.utc(2026),
            deleted: false,
          ),
        ],
      );
      await tester.runAsync(() => h.open(withComments: true));
      addTearDown(() => tester.runAsync(h.dispose));
      final s = h.session.suggestions.pending.single;

      await pumpWonky(
        tester,
        SizedBox(
          width: 300,
          child: SuggestionCard(session: h.session, suggestion: s),
        ),
        extraDelegates: const [WonkyAppLocalizations.delegate],
      );

      expect(find.text('Add: ‘there’'), findsOneWidget);
      expect(find.text('Shorter is better here'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('write.suggestion.s1.thread')),
        findsOneWidget,
      );
    });
  });
}
