import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets/features/collab/presence/presence_cursor.dart';
import 'package:wonky_sheets/features/formatting/sheets_user_defaults.dart';
import 'package:wonky_sheets/features/scripts/conflict_dialog.dart';
import 'package:wonky_sheets/features/scripts/editor/script_assist.dart';
import 'package:wonky_sheets/features/scripts/editor/script_editor_screen.dart';
import 'package:wonky_sheets/features/scripts/editor/script_history_dialog.dart';
import 'package:wonky_sheets/features/scripts/local/script_local_store.dart';
import 'package:wonky_sheets/features/scripts/script_api_reference.dart';
import 'package:wonky_sheets/features/scripts/script_project.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';
import 'script_test_support.dart';

const _main = r'''
import 'package:wonky/wonky.dart';

void hello() {
  SpreadsheetApp.active.toast('Hi');
}
''';

Future<ScriptHarness> _open(
  WidgetTester tester, [
  Map<String, String>? files,
]) async {
  final h = (await tester.runAsync(
    () => ScriptHarness.open(files ?? {'main.dart': _main}),
  ))!;
  addTearDown(() => tester.runAsync(h.dispose));
  return h;
}

/// Opens a dialog from a button (the dialog needs a navigator context).
Future<T?> _show<T>(
  WidgetTester tester,
  ScriptHarness h,
  Future<T?> Function(BuildContext context) open, {
  Size size = const Size(1200, 800),
  bool dark = false,
}) async {
  T? result;
  await pumpSheets(
    tester,
    h.s,
    size: size,
    dark: dark,
    child: Builder(
      builder: (context) => Center(
        child: ShadButton(
          key: const ValueKey('open'),
          onPressed: () async => result = await open(context),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('Given script completion in the editor (09 §14.4)', () {
    test('when the prompts builder runs after a dot then API members are '
        'proposed with the typed prefix', () {
      final c = CodeLineEditingController.fromText(
        'void f() {\n  SpreadsheetApp.active.getR\n}',
      );
      final b = ScriptPromptsBuilder(
        controller: () => c,
        completion: ScriptCompletion.new,
      );
      final v = b.build(
        _FakeContext(),
        c.codeLines[1],
        const CodeLineSelection.collapsed(index: 1, offset: 28),
      )!;
      expect(v.input, 'getR');
      final labels = [
        for (final p in v.prompts) (p as ScriptCodePrompt).item.label,
      ];
      expect(labels, containsAll(['getRange', 'getRangeList']));
      final r = v.autocomplete;
      expect(r.word, 'getRange()');
    });

    for (final dark in [false, true]) {
      testWidgets('when the popup shows in ${dark ? 'dark' : 'light'} mode '
          'then it lists icons, names, signatures and the doc', (tester) async {
        final h = await _open(tester);
        final r = ScriptCompletion().complete(
          'void f() { SpreadsheetApp.active.get }',
          36,
        )!;
        final notifier = ValueNotifier(
          CodeAutocompleteEditingValue(
            input: r.prefix,
            prompts: [for (final i in r.items) ScriptCodePrompt(i)],
            index: 0,
          ),
        );
        CodeAutocompleteResult? picked;
        await pumpSheets(
          tester,
          h.s,
          dark: dark,
          child: Align(
            alignment: Alignment.topLeft,
            child: ScriptCompletionView(
              notifier: notifier,
              onSelected: (x) => picked = x,
            ),
          ),
        );
        expect(find.byKey(const ValueKey('script.completion')), findsOneWidget);
        expect(find.text('getRange'), findsOneWidget);
        notifier.value = notifier.value.copyWith(index: 1);
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('script.completion.getRange')),
        );
        expect(picked?.word, 'getRange()');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Given the span decorator', () {
    testWidgets('when a line has a diagnostic then it gets a wavy underline '
        'and API names become hover targets', (tester) async {
      final h = await _open(tester);
      late TextSpan out;
      await pumpSheets(
        tester,
        h.s,
        child: Builder(
          builder: (context) {
            final deco = ScriptSpanDecorator(
              colors: () => ShadTheme.of(context).colorScheme,
              problems: () => {
                0: const [
                  ScriptDiagnostic(
                    severity: DiagnosticSeverity.error,
                    code: 'x',
                    message: 'bad',
                    line: 1,
                    column: 7,
                  ),
                ],
              },
              onHoverEnter: (_, _, _) {},
              onHoverExit: () {},
            );
            const line = 'final sheet = SpreadsheetApp.activeSheet;';
            out = deco.build(
              context: context,
              index: 0,
              codeLine: const CodeLine(line),
              textSpan: const TextSpan(text: line),
              style: const TextStyle(),
            );
            return const SizedBox();
          },
        ),
      );
      final leaves = out.children!.cast<TextSpan>();
      final wavy = leaves.where(
        (s) => s.style?.decorationStyle == TextDecorationStyle.wavy,
      );
      expect(wavy.map((s) => s.text), ['sheet']);
      final hovers = leaves.whereType<MouseTrackerAnnotationTextSpan>();
      expect(
        hovers.map((s) => s.text),
        containsAll(['SpreadsheetApp', 'activeSheet']),
      );
      expect(
        leaves.map((s) => s.text).join(),
        'final sheet = SpreadsheetApp.activeSheet;',
      );
    });
  });

  group('Given the conflict dialog (09 §14.3)', () {
    for (final (size, dark) in [
      (const Size(1200, 800), false),
      (const Size(360, 760), true),
    ]) {
      testWidgets('when Compare is pressed at ${size.width.toInt()} px '
          '(${dark ? 'dark' : 'light'}) then the diff shows and Merge '
          'answers merge', (tester) async {
        final h = await _open(tester);
        ScriptConflictChoice? choice;
        await _show(tester, h, size: size, dark: dark, (context) async {
          return choice = await showScriptConflictDialog(
            context,
            fileName: 'utils.dart',
            mine: 'a\nmine\nc',
            theirs: 'a\ntheirs\nc',
            updatedBy: 'Bo',
            updatedAt: DateTime.utc(2026, 10, 14, 10),
          );
        });
        expect(
          find.byKey(const ValueKey('dialog.scriptConflict')),
          findsOneWidget,
        );
        expect(find.textContaining('Bo saved a newer version'), findsOneWidget);
        final d = h.s.services.openDialogs.last;
        expect(
          [for (final b in d.describe()['buttons']! as List) (b as Map)['id']],
          ['cancel', 'compare', 'merge', 'discard', 'overwrite'],
        );
        expect(d.press('compare'), isTrue);
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey(
              size.width >= 1000
                  ? 'script.diff.sideBySide'
                  : 'script.diff.unified',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('mine'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(d.press('merge'), isTrue);
        await tester.pumpAndSettle();
        expect(choice, ScriptConflictChoice.merge);
      });
    }
  });

  group('Given a save conflict in the service', () {
    testWidgets('when Merge is chosen then the merged text becomes a draft '
        'with conflict markers', (tester) async {
      final h = await _open(tester);
      final main = ScriptProjectRows.fileNamed(h.s.model, 'main.dart')!;
      h.svc.markLoaded(main.id);
      final base = ScriptProjectRows.sourceOf(main);
      // Bo saves a newer version.
      h.s.model.upsertRow(main.table, main.id, {
        ...main.columns,
        'source': base.replaceFirst("'Hi'", "'Hej'"),
        'contentHash': 'bo',
        'updatedBy': 'bo-user',
      });
      h.svc.setDraft(main.id, base.replaceFirst("'Hi'", "'Hello'"));
      await pumpSheets(tester, h.s, child: const SizedBox());
      final saving = h.svc.save(
        main.id,
        context: tester.element(find.byType(SizedBox).first),
        compileAfter: false,
      );
      await tester.pumpAndSettle();
      expect(h.s.services.openDialogs.last.press('merge'), isTrue);
      await tester.pumpAndSettle();
      expect(await saving, isFalse);
      final draft = h.svc.drafts[main.id]!;
      expect(draft, contains('<<<<<<< yours'));
      expect(draft, contains("'Hello'"));
      expect(draft, contains("'Hej'"));
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('Given the local history dialog', () {
    testWidgets('when a version is selected and restored then its source is '
        'returned', (tester) async {
      final h = await _open(tester);
      String? restored;
      await _show(tester, h, size: const Size(360, 760), (context) async {
        return restored = await showScriptHistoryDialog(
          context,
          fileName: 'main.dart',
          current: 'v3',
          versions: [
            ScriptHistoryEntry(
              fileId: 'f',
              savedAt: DateTime.utc(2026, 1, 2),
              source: 'v2',
            ),
            ScriptHistoryEntry(
              fileId: 'f',
              savedAt: DateTime.utc(2026),
              source: 'v1',
              note: 'discarded',
            ),
          ],
        );
      });
      final d = h.s.services.openDialogs.last;
      expect(d.setField('version', '1'), isTrue);
      await tester.pump();
      expect(find.textContaining('Discarded in a conflict'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(d.press('restore'), isTrue);
      await tester.pumpAndSettle();
      expect(restored, 'v1');
    });
  });

  group('Given Help › Script API reference', () {
    for (final (size, dark) in [
      (const Size(1200, 800), false),
      (const Size(360, 760), true),
    ]) {
      testWidgets('when it opens at ${size.width.toInt()} px '
          '(${dark ? 'dark' : 'light'}) then classes and members show and '
          'search filters', (tester) async {
        final h = await _open(tester);
        await _show(
          tester,
          h,
          size: size,
          dark: dark,
          (context) => showScriptApiReference(context),
        );
        expect(
          find.byKey(const ValueKey('dialog.scriptApiReference')),
          findsOneWidget,
        );
        expect(find.text('class SpreadsheetApp'), findsOneWidget);
        final d = h.s.services.openDialogs.last;
        expect(d.setField('search', 'newChart'), isTrue);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('script.api.class.Sheet')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('script.api.class.Ui')), findsNothing);
        expect(d.setField('class', 'Sheet'), isTrue);
        await tester.pump();
        expect(
          d.describe()['content'],
          contains('EmbeddedChartBuilder newChart()'),
        );
        expect(
          find.byKey(const ValueKey('script.api.member.Sheet.id')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(d.press('close'), isTrue);
        await tester.pumpAndSettle();
      });
    }

    testWidgets('when the command runs headless then it lists the classes', (
      tester,
    ) async {
      final h = await _open(tester);
      final r = (await tester.runAsync(
        () => h.s.run('sheets.help.scriptApiReference'),
      ))!;
      expect(r.isOk, isTrue);
      expect(((r.data! as Map)['classes']! as List), contains('Spreadsheet'));
    });
  });

  group('Given the script editor screen', () {
    Future<void> pumpEditor(
      WidgetTester tester,
      ScriptHarness h, {
      bool dark = false,
    }) async {
      await pumpSheets(
        tester,
        h.s,
        dark: dark,
        size: const Size(1280, 800),
        child: ScriptEditorScreen(
          services: h.s.services,
          itemUuid: testItemUuid,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('when a draft has merge markers then Problems lists them', (
      tester,
    ) async {
      final h = await _open(tester);
      await pumpEditor(tester, h);
      final main = ScriptProjectRows.fileNamed(h.s.model, 'main.dart')!;
      h.svc.setDraft(
        main.id,
        '<<<<<<< yours\nvoid a() {}\n=======\nvoid b() {}\n>>>>>>> theirs\n',
      );
      await tester.pump();
      expect(find.text('Problems 1'), findsOneWidget);
      expect(find.textContaining('Merge conflict'), findsOneWidget);
      // The editor follows the new draft.
      expect(find.byType(CodeEditor), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('when scripts are turned off then a banner offers to turn '
        'them on', (tester) async {
      final h = await _open(tester);
      await tester.runAsync(
        () => SheetsUserDefaults.of(
          h.s.services,
        ).set(SheetsUserDefaults.keyScriptsEnabled, false),
      );
      await pumpEditor(tester, h, dark: true);
      expect(
        find.byKey(const ValueKey('script.disabledBanner')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('script.enableScripts')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('script.disabledBanner')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('when a file row is dragged then the files are reordered in '
        'one undo step', (tester) async {
      final h = await _open(tester, {
        'main.dart': _main,
        'utils.dart': 'void util() {}\n',
      });
      await pumpEditor(tester, h);
      List<String> names() => [
        for (final f in ScriptProjectRows.files(h.s.model))
          ScriptProjectRows.nameOf(f),
      ];
      expect(names(), ['main.dart', 'utils.dart']);
      final from = tester.getCenter(
        find.byKey(const ValueKey('script.file.utils.dart')),
      );
      final g = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 50));
      await g.moveBy(const Offset(0, -20));
      await tester.pump();
      await g.moveBy(const Offset(0, -40));
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(names(), ['utils.dart', 'main.dart']);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('when the history button is pressed then the local history '
        'of the file opens', (tester) async {
      final h = await _open(tester);
      final main = ScriptProjectRows.fileNamed(h.s.model, 'main.dart')!;
      await tester.runAsync(() async {
        h.svc.setDraft(main.id, '$_main\nvoid v2() {}\n');
        await h.svc.save(main.id, compileAfter: false);
      });
      await pumpEditor(tester, h);
      await tester.tap(find.byKey(const ValueKey('script.history')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('dialog.scriptHistory')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('script.history.version.0')),
        findsOneWidget,
      );
      h.s.services.openDialogs.last.press('close');
      await tester.pumpAndSettle();
    });
  });

  group('Given presence in the script editor', () {
    test('when a cursor names a script file then it round-trips', () {
      const c = SheetsPresenceCursor(route: 'script', sheetId: 's', file: 'f1');
      final back = SheetsPresenceCursor.tryParse(c.encode())!;
      expect(back.route, 'script');
      expect(back.file, 'f1');
      expect(back, c);
    });
  });
}

class _FakeContext extends Fake implements BuildContext {}
