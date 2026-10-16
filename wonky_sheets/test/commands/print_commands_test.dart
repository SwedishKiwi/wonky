import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/features/print/print_controller.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() async {
    s = SheetsHarness.open();
    for (var r = 1; r <= 120; r++) {
      await s.type('A$r', 'Row $r');
    }
  });
  tearDown(() => s.dispose());

  PrintSettings stored() =>
      PrintSettings.parse(s.sheet.record?.printSettingsJson);

  group('Given the print settings of a sheet', () {
    test('when a patch is applied then it is stored and one undo restores '
        'the defaults', () async {
      final r = await s.run('sheets.print.updateSettings', {
        'patch': {
          'orientation': 'landscape',
          'scale': {'mode': 'fitWidth'},
          'gridlines': true,
        },
      });

      expect(r.isOk, isTrue);
      expect(stored().orientation, PageOrientation.landscape);
      expect(stored().scaleMode, PrintScaleMode.fitWidth);
      expect(stored().gridlines, isTrue);

      await s.undo();
      expect(stored().orientation, PageOrientation.portrait);
      expect(stored().gridlines, isFalse);
    });

    test('when page breaks are set by row number then they are stored as '
        'row ids and the pages break there', () async {
      final c = PrintController(s.editor);
      addTearDown(c.dispose);
      c.repaginate(immediate: true);
      final before = c.pages.length;

      await s.run('sheets.print.setPageBreaks', {
        'rows': [11],
      });

      expect(stored().rowBreaks, [s.sheet.rows.idAt(10)]);
      c.repaginate(immediate: true);
      expect(c.pages.first.rows.last, 9);
      expect(c.pages.length, greaterThan(before));
    });

    test('when resetting then the stored settings are cleared', () async {
      await s.run('sheets.print.updateSettings', {
        'patch': {'notes': true},
      });

      await s.run('sheets.print.resetSettings');

      expect(s.sheet.record?.printSettingsJson, isNull);
    });
  });

  group('Given the print controller', () {
    test('when paginating 120 rows then the job has several pages with page '
        'numbers in the footer', () {
      final c = PrintController(s.editor);
      addTearDown(c.dispose);
      c.repaginate(immediate: true);

      expect(c.pages.length, greaterThan(1));
      expect(c.pages.first.totalPages, c.pages.length);
      expect(c.settings.headerFooter.effectiveFooter.right, '{page}');
    });

    test('when printing the selection then only those cells are paginated', () {
      s.editor.goTo('A5:A7');
      final c = PrintController(s.editor, scope: PrintScope.selection);
      addTearDown(c.dispose);
      c.repaginate(immediate: true);

      expect(c.pages.single.rows, [4, 5, 6]);
    });

    test(
      'when building the PDF then a document with every page results',
      () async {
        final c = PrintController(s.editor);
        addTearDown(c.dispose);

        final pdf = await c.buildPdf();

        expect(ascii.decode(pdf.sublist(0, 5)), '%PDF-');
        expect(c.pdfFileName, 'Budget - Sheet1.pdf');
      },
    );
  });

  group('Given a viewer', () {
    late SheetsHarness v;
    setUp(() => v = SheetsHarness.open(role: Role.viewer));
    tearDown(() => v.dispose());

    test(
      'when changing settings then they apply locally and are not stored',
      () async {
        final c = PrintController(v.editor);
        addTearDown(c.dispose);

        await c.update({'orientation': 'landscape'});

        expect(c.settings.orientation, PageOrientation.landscape);
        expect(v.sheet.record?.printSettingsJson, isNull);
        await expectLater(
          v.run('sheets.print.updateSettings', {
            'patch': {'gridlines': true},
          }),
          throwsA(isA<CommandException>()),
        );
      },
    );
  });
}
