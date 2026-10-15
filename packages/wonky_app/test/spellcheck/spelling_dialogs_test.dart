import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/spellcheck.dart';
import 'package:wonky_ui/testing.dart';

/// A [SpellingSession] over a list of flagged words that records the calls.
class _FakeSession implements SpellingSession {
  _FakeSession(this.issues, {this.isAvailable = true, this.startOffset = 0});

  @override
  List<SpellingIssue> issues;

  @override
  final bool isAvailable;

  @override
  final int startOffset;

  final calls = <String>[];
  final selected = <SpellingIssue>[];

  @override
  List<String> suggestionsFor(String word) => switch (word) {
    'teh' => const ['the', 'tea'],
    'borwn' => const ['brown'],
    _ => const [],
  };

  @override
  void select(SpellingIssue issue) => selected.add(issue);

  @override
  void change(SpellingIssue issue, String replacement) {
    calls.add('change ${issue.word}@${issue.start} → $replacement');
    issues = [
      for (final i in issues)
        if (i != issue) i,
    ];
  }

  @override
  void changeAll(String word, String replacement) {
    calls.add('changeAll $word → $replacement');
    issues = [
      for (final i in issues)
        if (i.word != word) i,
    ];
  }

  @override
  void ignoreAll(String word) {
    calls.add('ignoreAll $word');
    issues = [
      for (final i in issues)
        if (i.word != word) i,
    ];
  }

  @override
  Future<void> addToDictionary(String word) async {
    calls.add('add $word');
    issues = [
      for (final i in issues)
        if (i.word != word) i,
    ];
  }

  @override
  void recheck() => calls.add('recheck');
}

Future<void> _pumpDialog(
  WidgetTester tester,
  SpellingSession session, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpWonky(
    tester,
    Builder(
      builder: (context) => ShadButton(
        key: const ValueKey('open'),
        onPressed: () => showSpellingDialog(context, session: session),
        child: const Text('Open'),
      ),
    ),
    brightness: brightness,
    center: true,
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

String _shownWord(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(SpellingKeys.word)).data!;

void main() {
  const teh = SpellingIssue('teh', 0, 3);
  const borwn = SpellingIssue('borwn', 10, 15);
  const teh2 = SpellingIssue('teh', 20, 23);

  for (final brightness in Brightness.values) {
    group('Given the spelling dialog (${brightness.name})', () {
      testWidgets('when opened then the first flagged word is selected with '
          'its suggestions', (tester) async {
        final session = _FakeSession([teh, borwn]);

        await _pumpDialog(tester, session, brightness: brightness);

        expect(find.byKey(SpellingKeys.dialog), findsOneWidget);
        expect(_shownWord(tester), 'teh');
        expect(session.selected, [teh]);
        expect(find.byKey(SpellingKeys.suggestion(0)), findsOneWidget);
        expect(find.byKey(SpellingKeys.suggestion(1)), findsOneWidget);
      });
    });
  }

  group('Given the spelling dialog', () {
    testWidgets('when the caret is after the first word then the walk starts '
        'at the caret', (tester) async {
      final session = _FakeSession([teh, borwn], startOffset: 5);

      await _pumpDialog(tester, session);

      expect(_shownWord(tester), 'borwn');
    });

    testWidgets('when choosing Change then the chosen suggestion replaces the '
        'word and the next word is shown', (tester) async {
      final session = _FakeSession([teh, borwn]);
      await _pumpDialog(tester, session);

      await tester.tap(find.byKey(SpellingKeys.suggestion(1)));
      // Suggestions also take a double tap (Change), so a single tap
      // resolves after the double-tap timeout.
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      await tester.tap(find.byKey(SpellingKeys.change));
      await tester.pumpAndSettle();

      expect(session.calls, ['change teh@0 → tea', 'recheck']);
      expect(_shownWord(tester), 'borwn');
    });

    testWidgets('when choosing Change all then every occurrence is replaced', (
      tester,
    ) async {
      final session = _FakeSession([teh, borwn, teh2]);
      await _pumpDialog(tester, session);

      await tester.tap(find.byKey(SpellingKeys.changeAll));
      await tester.pumpAndSettle();

      expect(session.calls, ['changeAll teh → the', 'recheck']);
      expect(_shownWord(tester), 'borwn');
    });

    testWidgets('when choosing Ignore then only this occurrence is skipped', (
      tester,
    ) async {
      final session = _FakeSession([teh, teh2]);
      await _pumpDialog(tester, session);

      await tester.tap(find.byKey(SpellingKeys.ignore));
      await tester.pumpAndSettle();

      expect(session.calls, isEmpty);
      expect(_shownWord(tester), 'teh');
      expect(session.selected, [teh, teh2]);
    });

    testWidgets('when choosing Ignore all and Add then the session is told', (
      tester,
    ) async {
      final session = _FakeSession([teh, borwn]);
      await _pumpDialog(tester, session);

      await tester.tap(find.byKey(SpellingKeys.ignoreAll));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SpellingKeys.add));
      await tester.pumpAndSettle();

      expect(session.calls, ['ignoreAll teh', 'add borwn']);
      expect(find.text('No spelling errors found.'), findsOneWidget);
    });

    testWidgets('when a word has no suggestions then Change is disabled', (
      tester,
    ) async {
      final session = _FakeSession([const SpellingIssue('qzx', 0, 3)]);
      await _pumpDialog(tester, session);

      expect(find.text('No suggestions'), findsOneWidget);
      await tester.tap(find.byKey(SpellingKeys.change));
      await tester.pumpAndSettle();
      expect(session.calls, isEmpty);
    });

    testWidgets('when no dictionary is available then the dialog says so', (
      tester,
    ) async {
      await _pumpDialog(tester, _FakeSession([], isAvailable: false));

      expect(
        find.text('Spellcheck isn’t available for this document’s language.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(SpellingKeys.done));
      await tester.pumpAndSettle();
      expect(find.byKey(SpellingKeys.dialog), findsNothing);
    });
  });

  group('Given the personal dictionary dialog', () {
    for (final brightness in Brightness.values) {
      testWidgets('(${brightness.name}) when adding and removing words then '
          'the callbacks run and the list updates', (tester) async {
        final words = <String>['Wonky'];
        await pumpWonky(
          tester,
          Builder(
            builder: (context) => ShadButton(
              key: const ValueKey('open'),
              onPressed: () => showPersonalDictionaryDialog(
                context,
                words: () => words,
                onAdd: (w) async => words.add(w),
                onRemove: (w) async => words.remove(w),
              ),
              child: const Text('Open'),
            ),
          ),
          brightness: brightness,
          center: true,
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        expect(find.byKey(SpellingKeys.dictionary), findsOneWidget);
        expect(find.text('Wonky'), findsOneWidget);

        await tester.enterText(
          find.descendant(
            of: find.byType(ShadInput),
            matching: find.byType(EditableText),
          ),
          'Serverpod',
        );
        await tester.tap(find.text('Add'));
        await tester.pumpAndSettle();
        expect(words, ['Wonky', 'Serverpod']);
        expect(find.text('Serverpod'), findsOneWidget);

        await tester.tap(find.byKey(SpellingKeys.remove('Wonky')));
        await tester.pumpAndSettle();
        expect(words, ['Serverpod']);
        expect(find.text('Wonky'), findsNothing);
      });
    }
  });
}
