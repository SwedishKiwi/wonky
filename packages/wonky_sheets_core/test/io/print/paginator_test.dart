import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';

import 'support/print_support.dart';

// Letter portrait, normal margins, page-number footer: 681.6 × 883.2 px of
// printable area at 100 % → 6 columns of 100 px and 42 rows of 21 px.

void main() {
  group('Given 60 rows × 10 columns on Letter with default settings', () {
    late WorkbookBuilder b;
    late WorkbookModel m;
    setUp(() => (b, m) = numberGrid());

    test('when paginating then pages go down, then over', () {
      final r = Paginator.paginate(m, const PrintJob());
      expect(describe(r), [
        'Sheet1 1/4 cells r0-41 c0-5 rr[] rc[] s1.00',
        'Sheet1 2/4 cells r42-59 c0-5 rr[] rc[] s1.00',
        'Sheet1 3/4 cells r0-41 c6-9 rr[] rc[] s1.00',
        'Sheet1 4/4 cells r42-59 c6-9 rr[] rc[] s1.00',
      ]);
      expect(r.warnings, isEmpty);
      expect(r.pages.first.rowStartId, b.rowId(0));
      expect(r.pages.first.colEndId, b.colId(5));
    });

    test('when the page order is over, then down then rows advance last', () {
      setPrintSettings(m, b, 'Sheet1', {'pageOrder': 'overThenDown'});
      expect(describe(Paginator.paginate(m, const PrintJob())), [
        'Sheet1 1/4 cells r0-41 c0-5 rr[] rc[] s1.00',
        'Sheet1 2/4 cells r0-41 c6-9 rr[] rc[] s1.00',
        'Sheet1 3/4 cells r42-59 c0-5 rr[] rc[] s1.00',
        'Sheet1 4/4 cells r42-59 c6-9 rr[] rc[] s1.00',
      ]);
    });

    test('when the orientation is landscape then pages are wider', () {
      setPrintSettings(m, b, 'Sheet1', {'orientation': 'landscape'});
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.pages.first.pageWidth, 792);
      expect(r.pages.first.pageHeight, 612);
      expect(describe(r), [
        'Sheet1 1/4 cells r0-29 c0-8 rr[] rc[] s1.00',
        'Sheet1 2/4 cells r30-59 c0-8 rr[] rc[] s1.00',
        'Sheet1 3/4 cells r0-29 c9-9 rr[] rc[] s1.00',
        'Sheet1 4/4 cells r30-59 c9-9 rr[] rc[] s1.00',
      ]);
    });

    test('when fitting to width then all columns share one page width', () {
      setPrintSettings(m, b, 'Sheet1', {
        'scale': {'mode': 'fitWidth'},
      });
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.pages.single.scale, closeTo(511.2 / 750, 1e-9));
      expect(r.pages.single.cols, List.generate(10, (i) => i));
      expect(r.pages.single.contentWidth, closeTo(511.2, 1e-6));
    });

    test('when fitting to the page then the smaller ratio wins', () {
      setPrintSettings(m, b, 'Sheet1', {
        'scale': {'mode': 'fitPage'},
      });
      expect(
        Paginator.paginate(m, const PrintJob()).pages.single.scale,
        closeTo(511.2 / 750, 1e-9),
      );
    });

    test('when fitting to height then columns still break', () {
      setPrintSettings(m, b, 'Sheet1', {
        'scale': {'mode': 'fitHeight'},
      });
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.pages.first.scale, closeTo(662.4 / (60 * 21 * 0.75), 1e-9));
      expect(describe(r), [
        'Sheet1 1/2 cells r0-59 c0-8 rr[] rc[] s0.70',
        'Sheet1 2/2 cells r0-59 c9-9 rr[] rc[] s0.70',
      ]);
    });

    test('when the scale is a custom 50 % then one page holds everything', () {
      setPrintSettings(m, b, 'Sheet1', {
        'scale': {'mode': 'custom', 'percent': 50},
      });
      expect(describe(Paginator.paginate(m, const PrintJob())), [
        'Sheet1 1/1 cells r0-59 c0-9 rr[] rc[] s0.50',
      ]);
    });

    test('when the first row is frozen then it repeats on every page', () {
      patchSheet(m, b, 'Sheet1', {SheetCols.frozenRows: 1});
      final r = Paginator.paginate(m, const PrintJob());
      expect(describe(r), [
        'Sheet1 1/4 cells r1-41 c0-5 rr[0] rc[] s1.00',
        'Sheet1 2/4 cells r42-59 c0-5 rr[0] rc[] s1.00',
        'Sheet1 3/4 cells r1-41 c6-9 rr[0] rc[] s1.00',
        'Sheet1 4/4 cells r42-59 c6-9 rr[0] rc[] s1.00',
      ]);
      expect(r.pages.first.repeatRowHeightsPx, [21]);
    });

    test('when repeating frozen rows is off then nothing repeats', () {
      patchSheet(m, b, 'Sheet1', {SheetCols.frozenRows: 1});
      setPrintSettings(m, b, 'Sheet1', {'repeatFrozen': false});
      expect(
        Paginator.paginate(m, const PrintJob()).pages.first.repeatRows,
        isEmpty,
      );
    });

    test('when frozen rows exceed half the page then they print once', () {
      patchSheet(m, b, 'Sheet1', {SheetCols.frozenRows: 30});
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.hasWarning(PrintWarningKind.repeatRowsTooTall), isTrue);
      expect(r.pages.first.repeatRows, isEmpty);
      expect(r.pages.first.rows.first, 0);
    });

    test('when explicit print titles are set then those rows repeat', () {
      setPrintSettings(m, b, 'Sheet1', {
        'repeatRows': {'start': b.rowId(0), 'end': b.rowId(1)},
      });
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.pages.first.repeatRows, [0, 1]);
      expect(r.pages.first.rows.first, 2);
    });

    test(
      'when custom row and column breaks are set then pages break there',
      () {
        setPrintSettings(m, b, 'Sheet1', {
          'pageBreaks': {
            'rows': [b.rowId(10), 'deleted-row'],
            'cols': [b.colId(3)],
          },
        });
        expect(describe(Paginator.paginate(m, const PrintJob())), [
          'Sheet1 1/9 cells r0-9 c0-2 rr[] rc[] s1.00',
          'Sheet1 2/9 cells r10-51 c0-2 rr[] rc[] s1.00',
          'Sheet1 3/9 cells r52-59 c0-2 rr[] rc[] s1.00',
          'Sheet1 4/9 cells r0-9 c3-8 rr[] rc[] s1.00',
          'Sheet1 5/9 cells r10-51 c3-8 rr[] rc[] s1.00',
          'Sheet1 6/9 cells r52-59 c3-8 rr[] rc[] s1.00',
          'Sheet1 7/9 cells r0-9 c9-9 rr[] rc[] s1.00',
          'Sheet1 8/9 cells r10-51 c9-9 rr[] rc[] s1.00',
          'Sheet1 9/9 cells r52-59 c9-9 rr[] rc[] s1.00',
        ]);
      },
    );

    test('when rows are hidden then they are skipped', () {
      hideRow(m, b, 'Sheet1', 5);
      hideRow(m, b, 'Sheet1', 6);
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.pages.first.rows, isNot(contains(5)));
      expect(r.pages.first.rows, isNot(contains(6)));
      expect(r.pages.first.rows.last, 43);
    });

    test(
      'when a row is taller than the page then it is clipped with a warning',
      () {
        setRowHeight(m, b, 'Sheet1', 3, 2000);
        final r = Paginator.paginate(m, const PrintJob());
        expect(r.hasWarning(PrintWarningKind.rowTooTall), isTrue);
        expect(
          r.pages.any((p) => p.rows.length == 1 && p.rows.single == 3),
          isTrue,
        );
      },
    );

    test('when headings are on then they take space on every page', () {
      setPrintSettings(m, b, 'Sheet1', {'headings': true});
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.pages.first.headings, isTrue);
      expect(r.pages.first.rows.last, 40);
      expect(r.pages.first.cols.last, 5);
    });

    test('when centered then the content is placed in the middle', () {
      setPrintSettings(m, b, 'Sheet1', {
        'align': {'h': 'center', 'v': 'middle'},
        'scale': {'mode': 'custom', 'percent': 50},
      });
      final p = Paginator.paginate(m, const PrintJob()).pages.single;
      expect(p.originX, closeTo(p.printableLeft + (511.2 - 375) / 2, 1e-6));
      expect(p.originY, closeTo(p.printableTop + (662.4 - 472.5) / 2, 1e-6));
    });

    test('when printing a selection then only those cells print', () {
      final r = Paginator.paginate(
        m,
        PrintJob(scope: PrintScope.selection, selection: m.parseA1('B2:C5')),
      );
      expect(describe(r), ['Sheet1 1/1 cells r1-4 c1-2 rr[] rc[] s1.00']);
    });

    test('when the settings have a print area then it is used', () {
      setPrintSettings(m, b, 'Sheet1', {
        'printArea': GridRange(
          sheetId: b.sheetId('Sheet1'),
          r1: b.rowId(0),
          r2: b.rowId(9),
          c1: b.colId(0),
          c2: b.colId(1),
        ).toJson(),
      });
      expect(describe(Paginator.paginate(m, const PrintJob())), [
        'Sheet1 1/1 cells r0-9 c0-1 rr[] rc[] s1.00',
      ]);
    });

    test('when the job overrides the settings then the override wins', () {
      final r = Paginator.paginate(
        m,
        const PrintJob(
          settingsOverride: PrintSettings(scaleMode: PrintScaleMode.fitPage),
        ),
      );
      expect(r.pages, hasLength(1));
    });
  });

  group('Given a merge across the automatic page break', () {
    test('when paginating then the merge splits over two pages', () {
      final (b, m) = numberGrid(
        extra: (b) => addMergeA1(b, 'Sheet1', 'A40:A45'),
      );
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.pages[0].rows.last, 41);
      expect(r.pages[1].rows.first, 42);
      expect(b.rowId(0), isNotEmpty);
    });
  });

  group('Given a workbook with two sheets and a hidden one', () {
    late WorkbookModel m;
    setUp(() {
      final b = WorkbookBuilder()
        ..sheet('One', rows: 10, cols: 3)
        ..value('A1', 'one')
        ..sheet('Hidden', rows: 10, cols: 3, hidden: true)
        ..value('A1', 'hidden')
        ..sheet('Two', rows: 10, cols: 3)
        ..value('B2', 'two');
      m = b.build();
    });

    test('when printing the workbook then visible sheets print in order', () {
      final r = Paginator.paginate(
        m,
        const PrintJob(scope: PrintScope.workbook),
      );
      expect(describe(r), [
        'One 1/2 cells r0-0 c0-0 rr[] rc[] s1.00',
        'Two 2/2 cells r0-1 c0-1 rr[] rc[] s1.00',
      ]);
      expect(r.pages.last.pageInSheet, 0);
    });

    test('when printing the current sheet then only that sheet prints', () {
      final r = Paginator.paginate(m, PrintJob(sheetId: m.sheets.last.id));
      expect(describe(r), ['Two 1/1 cells r0-1 c0-1 rr[] rc[] s1.00']);
    });
  });

  group('Given an empty sheet', () {
    test('when it is the only sheet then one blank page prints', () {
      final m = (WorkbookBuilder()..sheet('Empty', rows: 5, cols: 5)).build();
      expect(describe(Paginator.paginate(m, const PrintJob())), [
        'Empty 1/1 blank',
      ]);
    });
  });

  group('Given a sheet with notes and notes printing on', () {
    test('when paginating then an endnotes page follows the cells', () {
      final b = WorkbookBuilder()..sheet('Sheet1', rows: 10, cols: 3);
      b
        ..set('A1', 'n:1', note: 'First note')
        ..set('B3', 's:x', note: 'Second\nnote');
      final m = b.build();
      setPrintSettings(m, b, 'Sheet1', {'notes': true});
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.pages.last.kind, PageKind.notes);
      expect(
        [for (final l in r.pages.last.noteLines) l.toString()],
        ['# Notes · Sheet1', 'A1: First note', 'B3: Second', 'note'],
      );
    });
  });

  group('Given a tiny custom page', () {
    test('when the job exceeds 1,000 pages then it is cut with warnings', () {
      final (b, m) = numberGrid(rows: 40, cols: 26, gridRows: 40);
      setPrintSettings(m, b, 'Sheet1', {
        'paper': 'custom',
        'customSize': {'w': 1, 'h': 1, 'unit': 'in'},
        'margins': {'preset': 'narrow'},
      });
      final r = Paginator.paginate(m, const PrintJob());
      expect(r.requestedPages, 1040);
      expect(r.pages, hasLength(PrintMetrics.maxPages));
      expect(r.pages.last.totalPages, PrintMetrics.maxPages);
      expect(r.hasWarning(PrintWarningKind.pageLimit), isTrue);
      expect(r.hasWarning(PrintWarningKind.manyPages), isTrue);
      expect(r.hasWarning(PrintWarningKind.columnTooWide), isTrue);
      expect(r.hasWarning(PrintWarningKind.rowTooTall), isTrue);
    });
  });

  group('Given a named range scope', () {
    test('when the name does not exist then a warning is returned', () {
      final (_, m) = numberGrid(rows: 2, cols: 2);
      final r = Paginator.paginate(
        m,
        const PrintJob(scope: PrintScope.namedRange, namedRange: 'Nope'),
      );
      expect(r.hasWarning(PrintWarningKind.namedRangeNotFound), isTrue);
      expect(r.hasWarning(PrintWarningKind.empty), isTrue);
      expect(r.pages, isEmpty);
    });
  });
}
