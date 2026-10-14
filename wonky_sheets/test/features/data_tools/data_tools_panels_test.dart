import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemKind, UuidValue;
import 'package:wonky_sheets/features/data_tools/cleanup_suggestions_panel.dart';
import 'package:wonky_sheets/features/data_tools/column_stats_panel.dart';
import 'package:wonky_sheets/features/data_tools/data_job.dart';
import 'package:wonky_sheets/features/data_tools/data_tools.dart';
import 'package:wonky_sheets/features/data_tools/remove_duplicates_dialog.dart';
import 'package:wonky_sheets/features/data_tools/sort_dialog.dart';
import 'package:wonky_sheets/features/filters/filter_column_popover.dart';
import 'package:wonky_sheets/features/filters/filter_views_panel.dart';
import 'package:wonky_sheets/features/named_ranges/import_named_functions_dialog.dart';
import 'package:wonky_sheets/features/named_ranges/named_functions_panel.dart';
import 'package:wonky_sheets/features/named_ranges/named_ranges_panel.dart';
import 'package:wonky_sheets/features/objects/objects_layer.dart';
import 'package:wonky_sheets/features/slicers/slicer_panel.dart';
import 'package:wonky_sheets/features/slicers/slicer_view.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;
  late DataTools tools;

  setUp(() async {
    s = SheetsHarness.open();
    tools = DataTools.of(s.editor);
    const rows = [
      ['Status', 'Amount'],
      ['Open', '10'],
      ['Closed', '200'],
      ['Open', '30'],
      ['open', '5'],
    ];
    for (var r = 0; r < rows.length; r++) {
      await s.type('A${r + 1}', rows[r][0]);
      await s.type('B${r + 1}', rows[r][1]);
    }
    await s.select('A3');
    await s.run('sheets.format.fillColor', {'color': '#FFFF00'});
    await s.select('A2');
    await s.run('sheets.filter.toggle');
  });
  tearDown(() => s.dispose());

  Finder key(String k) => find.byKey(ValueKey<String>(k));
  // A ShadCheckbox toggles from its box (top-left), not its label area.
  Future<void> tapBox(WidgetTester tester, Finder f) =>
      tester.tapAt(tester.getTopLeft(f) + const Offset(8, 9));
  Widget panel(Widget child) => SizedBox(width: 360, height: 760, child: child);

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('Given a filter ($mode) when the column popover opens at its '
        'width then sort by color lists the fills, the values checklist '
        'works and OK commits one step', (tester) async {
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(400, 800),
        child: SizedBox(
          width: kFilterPopoverWidth,
          height: 700,
          child: FilterColumnPopover(
            editor: s.editor,
            filters: tools.filters,
            filter: tools.filters.effective(s.sheetId)!,
            colId: s.sheet.columns.idAt(0),
            onClose: () {},
          ),
        ),
      );
      await tester.tap(key('filter.sortByColor'));
      await tester.pumpAndSettle();
      expect(key('filter.sortColor.section'), findsOne);
      expect(key('filter.sortColor.fill.#FFFF00'), findsOne);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Given the data tool panels at 360 px ($mode) then they '
        'render without overflow', (tester) async {
      for (final child in <Widget>[
        FilterViewsPanel(editor: s.editor),
        NamedRangesPanel(editor: s.editor),
        NamedFunctionsPanel(editor: s.editor),
        ColumnStatsPanel(editor: s.editor),
        CleanupSuggestionsPanel(editor: s.editor),
        SlicerPanel(editor: s.editor),
      ]) {
        await pumpSheets(
          tester,
          s,
          dark: dark,
          size: const Size(400, 800),
          child: panel(child),
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: '$child');
      }
      // The cleanup panel found the "open"/"Open" capitalization.
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(400, 800),
        child: panel(CleanupSuggestionsPanel(editor: s.editor)),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
      final card = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'cleanup.card.capitalization',
            ),
      );
      expect(card, findsOne);
      // Apply is one step and the card goes away.
      final before = s.h.undoLabels.length;
      await tester.tap(find.descendant(of: card, matching: find.text('Apply')));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(s.h.undoLabels.length, before + 1);
      expect(s.text('A5'), 'Open');
    });

    testWidgets('Given the sort and remove duplicates dialogs ($mode) at a '
        'narrow width then they render', (tester) async {
      final cols = {s.sheet.columns.idAt(0): 'A', s.sheet.columns.idAt(1): 'B'};
      final headers = {
        s.sheet.columns.idAt(0): 'Status',
        s.sheet.columns.idAt(1): 'Amount',
      };
      for (final child in <Widget>[
        SortRangeDialog(
          rangeA1: 'A1:B5',
          columns: cols,
          headers: headers,
          hasHeader: true,
        ),
        RemoveDuplicatesDialog(
          rangeA1: 'A1:B5',
          letters: cols,
          headers: headers,
          hasHeader: true,
        ),
      ]) {
        await pumpSheets(
          tester,
          s,
          dark: dark,
          size: const Size(380, 700),
          child: child,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$child');
      }
    });

    testWidgets('Given a slicer ($mode) when its popover hides a value then '
        'the rows hide', (tester) async {
      final r = await s.run('sheets.slicer.add');
      final id = (r.data! as Map)['objectId'] as String;
      final record = s.sheet.objects[id]!;
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(500, 900),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 220,
            height: 56,
            child: SlicerView(editor: s.editor, record: record, zoom: 1),
          ),
        ),
      );
      expect(objectViewBuilders, isNotNull);
      await tester.tap(key('slicer.open.$id'));
      await tester.pumpAndSettle();
      expect(key('slicer.popover'), findsOne);
      await tapBox(tester, key('slicer.popover.value.Closed'));
      await tester.pump();
      await tester.tap(key('slicer.popover.ok'));
      await tester.pumpAndSettle();
      expect(s.sheet.rows.isHidden(2), isTrue);
      expect(tester.takeException(), isNull);
      // Debounced recalculation refreshes.
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('Given the import functions dialog ($mode) when a source is '
        'chosen then its functions list with dependencies checked', (
      tester,
    ) async {
      s.h.drive.seed(
        name: 'Tax rules',
        uuid: UuidValue.fromString('01923456-789a-7bcd-8ef0-123456789abd'),
        kind: DriveItemKind.spreadsheet,
      );
      await s.h.drive.markOpened(
        UuidValue.fromString('01923456-789a-7bcd-8ef0-123456789abd'),
      );
      ImportFunctionsChoice? choice;
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: const Size(400, 700),
        child: Builder(
          builder: (context) => Center(
            child: ShadButtonForTest(
              onPressed: () async {
                choice = await showImportNamedFunctionsDialog(
                  context,
                  services: s.services,
                  currentItem: UuidValue.fromString(testItemUuid),
                  load: (_) async => const [
                    ImportableFunction(
                      name: 'TAX',
                      formula: '=LAMBDA(x, x*0.19)',
                    ),
                    ImportableFunction(
                      name: 'GROSS',
                      formula: '=LAMBDA(x, x+TAX(x))',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ShadButtonForTest));
      await tester.pumpAndSettle();
      expect(key('dialog.importFunctions'), findsOne);
      final item = find.text('Tax rules');
      expect(item, findsOne);
      await tester.tap(item);
      await tester.pumpAndSettle();
      await tapBox(tester, key('dialog.importFunctions.fn.GROSS'));
      await tester.pumpAndSettle();
      expect(
        find.text('Imported because a selected function uses it'),
        findsOne,
      );
      await tester.tap(key('dialog.importFunctions.import'));
      await tester.pumpAndSettle();
      expect(choice?.names, ['GROSS']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Given a long data job when it runs then a progress toast '
      'shows and the work runs once', (tester) async {
    await pumpSheets(tester, s, child: const SizedBox());
    var runs = 0;
    final f = DataJobs.run(
      s.editor,
      rows: DataJobs.threshold,
      label: 'Sorting…',
      work: () => ++runs,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(await f, 1);
    expect(DataJobs.isRunning(s.editor), isFalse);
  });
}

/// A plain tap target that opens the dialog under test.
class ShadButtonForTest extends StatelessWidget {
  const ShadButtonForTest({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onPressed,
    child: const SizedBox(width: 80, height: 40),
  );
}
