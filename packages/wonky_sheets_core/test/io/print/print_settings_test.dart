import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given no stored print settings', () {
    test('when parsing for en_US then Letter portrait defaults are used', () {
      final s = PrintSettings.parse(null);
      expect(s.paper, PaperSize.letter);
      expect(s.orientation, PageOrientation.portrait);
      expect(s.scaleMode, PrintScaleMode.normal);
      expect(s.margins.preset, MarginPreset.normal);
      expect(s.repeatFrozen, isTrue);
      expect(s.headerFooter.flags.pageNumbers, isTrue);
      expect((s.pageWidthPt, s.pageHeightPt), (612, 792));
    });

    for (final (locale, paper) in [
      ('de_DE', PaperSize.a4),
      ('en_CA', PaperSize.letter),
      ('es_MX', PaperSize.letter),
      ('en_GB', PaperSize.a4),
    ]) {
      test('when parsing for $locale then the paper is ${paper.label}', () {
        expect(PrintSettings.parse('', locale: locale).paper, paper);
      });
    }

    test('when the JSON is malformed then defaults are used', () {
      expect(PrintSettings.parse('{nope', locale: 'de_DE').paper, PaperSize.a4);
      expect(PrintSettings.parse('[1,2]'), const PrintSettings());
    });
  });

  group('Given settings with every field set', () {
    final full = PrintSettings(
      paper: PaperSize.custom,
      customSize: const CustomPaperSize(20, 30, unit: 'cm'),
      orientation: PageOrientation.landscape,
      scaleMode: PrintScaleMode.custom,
      scalePercent: 85,
      margins: const PrintMargins(
        preset: MarginPreset.custom,
        top: 1,
        bottom: 2,
        left: 0.5,
        right: 0.5,
        unit: 'cm',
      ),
      gridlines: true,
      notes: true,
      pageOrder: PageOrder.overThenDown,
      hAlign: PrintHAlign.center,
      vAlign: PrintVAlign.bottom,
      repeatFrozen: false,
      headings: true,
      repeatRows: const IdSpan('r1', 'r2'),
      headerFooter: const HeaderFooter(
        header: HeaderFooterSections(left: '{title}'),
        footer: HeaderFooterSections(center: 'Page {page} of {pages}'),
        flags: HeaderFooterFlags(pageNumbers: false, date: true),
      ),
      rowBreaks: const ['r10'],
      colBreaks: const ['c3'],
      printArea: const GridRange(
        sheetId: 's1',
        r1: 'r1',
        r2: 'r9',
        c1: 'c1',
        c2: 'c4',
      ),
    );

    test('when encoding and parsing then the settings are equal', () {
      final back = PrintSettings.parse(full.encode());
      expect(back, full);
      expect(back.toJson()['v'], 1);
    });

    test('when computing the page size then the custom size is rotated', () {
      expect(full.pageWidthPt, closeTo(30 * 72 / 2.54, 1e-9));
      expect(full.pageHeightPt, closeTo(20 * 72 / 2.54, 1e-9));
      expect(full.margins.bottomPt, closeTo(2 * 72 / 2.54, 1e-9));
    });

    test('when applying a merge patch then only the patched fields change', () {
      final p = full.mergePatch({
        'scale': {'mode': 'fitWidth'},
        'printArea': null,
        'headerFooter': {
          'flags': {'time': true},
        },
      });
      expect(p.scaleMode, PrintScaleMode.fitWidth);
      expect(p.printArea, isNull);
      expect(p.headerFooter.flags.time, isTrue);
      expect(p.headerFooter.flags.date, isTrue);
      expect(p.headerFooter.header.left, '{title}');
      expect(p.gridlines, isTrue);
    });
  });

  group('Given out-of-range values', () {
    test('when parsing then the scale percent is clamped to 10–400', () {
      expect(
        PrintSettings.parse(
          '{"scale":{"mode":"custom","percent":1000}}',
        ).scalePercent,
        400,
      );
      expect(
        PrintSettings.parse(
          '{"scale":{"mode":"custom","percent":2}}',
        ).scalePercent,
        10,
      );
    });

    test('when parsing unknown enum values then defaults are used', () {
      final s = PrintSettings.parse(
        '{"paper":"x","orientation":"diagonal","pageOrder":7}',
        locale: 'fr_FR',
      );
      expect(s.paper, PaperSize.a4);
      expect(s.orientation, PageOrientation.portrait);
      expect(s.pageOrder, PageOrder.downThenOver);
    });
  });

  group('Given the margin presets', () {
    for (final (preset, top, left) in [
      (MarginPreset.normal, 54.0, 50.4),
      (MarginPreset.narrow, 18.0, 18.0),
      (MarginPreset.wide, 72.0, 72.0),
    ]) {
      test(
        'when using ${preset.name} then top is $top pt and left $left pt',
        () {
          final m = PrintMargins.preset(preset);
          expect(m.topPt, closeTo(top, 1e-9));
          expect(m.leftPt, closeTo(left, 1e-9));
        },
      );
    }
  });
}
