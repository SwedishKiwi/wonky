import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/banding/banding_controller.dart';
import 'package:wonky_sheets/features/formatting/formatting_features.dart';
import 'package:wonky_sheets_core/model.dart';

import '../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  setUp(() {
    s = SheetsHarness.open();
    FormattingFeatures.install(s.editor);
  });
  tearDown(() async {
    FormattingFeatures.maybeOf(s.editor)?.dispose();
    await s.dispose();
  });

  CellDisplay? display(String a1) {
    final r = s.model.parseA1(a1, contextSheetId: s.sheetId);
    return s.editor.cells.displayAt(s.sheetId, r.rect.top, r.rect.left);
  }

  const style = BandingStyle(
    header: '#5B95F9',
    firstBand: '#FFFFFF',
    secondBand: '#E8F0FE',
  );

  group('Given an empty sheet', () {
    test('when adding alternating colors to A1:B5 then the header is bold '
        'and the bands alternate, in one undo step', () async {
      final before = s.h.undoLabels.length;
      await s.run('sheets.banding.add', {
        'range': 'A1:B5',
        'style': style.toJson(),
      });

      expect(display('A1')!.fillColor, '#5B95F9');
      expect(display('A1')!.format.bold, isTrue);
      expect(display('A2')!.fillColor, '#FFFFFF');
      expect(display('B3')!.fillColor, '#E8F0FE');
      expect(s.h.undoLabels.length, before + 1);
      await s.undo();
      expect(s.sheet.bandings, isEmpty);
    });

    test(
      'when updating and removing the banding then rendering follows',
      () async {
        await s.run('sheets.banding.add', {
          'range': 'A1:B5',
          'style': style.toJson(),
        });
        final id = s.sheet.bandings.keys.single;
        await s.run('sheets.banding.update', {
          'bandingId': id,
          'style': style.copyWith(secondBand: '#FCE8B2').toJson(),
        });
        expect(display('B3')!.fillColor, '#FCE8B2');
        await s.run('sheets.banding.remove', {'bandingId': id});
        expect(display('B3')?.fillColor, isNull);
      },
    );

    test('when a draft is previewed then it renders without being stored, '
        'and an explicit fill stays on top', () async {
      await s.select('A2');
      await s.run('sheets.format.fillColor', {'color': '#FF0000'});
      final banding = FormattingFeatures.of(s.editor).banding;
      banding.setDraft(
        BandingDraft(
          sheetId: s.sheetId,
          range: s.model.parseA1('A1:A4').rect,
          style: style,
        ),
      );
      expect(display('A1')!.fillColor, '#5B95F9');
      expect(display('A2')!.fillColor, '#FF0000');
      expect(display('A3')!.fillColor, '#E8F0FE');
      expect(s.sheet.bandings, isEmpty);
      banding.setDraft(null);
      expect(display('A1')?.fillColor, isNull);
    });
  });

  group('Given a cell filled with theme:accent1', () {
    setUp(() async {
      await s.select('A1');
      await s.run('sheets.format.fillColor', {'color': 'theme:accent1'});
    });

    test('when switching from Standard to Ocean then the cell recolors in '
        'one undo step (AC-F12)', () async {
      expect(display('A1')!.fillColor, '#4285F4');
      final before = s.h.undoLabels.length;
      await s.run('sheets.theme.set', {'presetName': 'Ocean'});
      expect(display('A1')!.fillColor, '#023E8A');
      expect(s.model.theme.textFont, 'Montserrat');
      expect(s.h.undoLabels.length, before + 1);
      await s.undo();
      expect(display('A1')!.fillColor, '#4285F4');
    });

    test('when previewing a theme then cells render it until the preview '
        'ends; nothing is written', () async {
      final theme = FormattingFeatures.of(s.editor).theme;
      theme.preview(SpreadsheetTheme.preset('Forest'));
      expect(display('A1')!.fillColor, '#2E7D32');
      expect(s.model.spreadsheet.themeJson, isNot(contains('Forest')));
      theme.preview(null);
      expect(display('A1')!.fillColor, '#4285F4');
    });
  });

  group('Given 1000.123 formatted as currency', () {
    setUp(() async {
      await s.type('A1', '1000.123');
      await s.select('A1');
      await s.run('sheets.format.numberFormat', {'preset': 'currency'});
    });

    test('when the locale changes to de_DE then the cell shows euros without '
        'writing it (AC-F6), one undo step', () async {
      expect(s.text('A1'), r'$1,000.12');
      final content = s.content('A1');
      await s.run('sheets.settings.update', {'locale': 'de_DE'});
      expect(s.model.spreadsheet.locale, 'de_DE');
      expect(s.text('A1'), '1.000,12 €');
      expect(s.content('A1'), content);
      await s.undo();
      expect(s.text('A1'), r'$1,000.12');
    });

    test('when setting calculation settings then they are stored', () async {
      await s.run('sheets.settings.update', {
        'iterativeCalc': true,
        'maxIterations': 100,
        'convergenceThreshold': 0.001,
      });
      final sp = s.model.spreadsheet;
      expect(sp.iterativeCalc, isTrue);
      expect(sp.maxIterations, 100);
      expect(sp.convergenceThreshold, 0.001);
    });

    test('when applying an invalid custom pattern then the command fails '
        'with invalid_number_format', () async {
      final r = await s.run('sheets.format.numberFormat', {'pattern': '0.00"'});
      expect(r.isOk, isFalse);
      expect(r.message, contains('invalid_number_format'));
    });
  });
}
