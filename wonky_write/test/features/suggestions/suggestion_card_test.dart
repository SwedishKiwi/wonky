import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_write/features/suggestions/suggestion_card.dart';
import 'package:wonky_write/features/suggestions/suggestions_panel.dart';
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

  group('Given a document without suggestions', () {
    testWidgets(
      'when the panel is shown then it offers switching to Suggesting',
      (tester) async {
        final h = await _open(tester, Delta()..insert('Hello\n'));

        await pumpWonky(
          tester,
          SizedBox(
            width: 340,
            height: 500,
            child: WriteSuggestionsPanel(session: h.session),
          ),
        );

        expect(find.text('Switch to Suggesting'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('write.suggestions.switchMode')),
        );
        await tester.pump();
        expect(h.session.suggestions.suggesting, isTrue);
      },
    );
  });

  group('Given several suggestions', () {
    testWidgets('when rejecting all from the panel then they are all removed', (
      tester,
    ) async {
      final h = await _open(
        tester,
        Delta()
          ..insert('A', {
            'sug_a': {'t': 'ins', 'by': _other, 'at': 1},
          })
          ..insert('bc')
          ..insert('d', {
            'sug_b': {'t': 'del', 'by': _other, 'at': 1},
          })
          ..insert('\n'),
      );
      await pumpWonky(
        tester,
        SizedBox(
          width: 340,
          height: 500,
          child: WriteSuggestionsPanel(session: h.session),
        ),
      );
      expect(find.text('2 suggestions'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('write.suggestions.rejectAll')),
      );
      await tester.pump();

      expect(DeltaUtils.text(h.doc), 'bcd\n');
      expect(find.text('No suggestions'), findsWidgets);
    });
  });
}
