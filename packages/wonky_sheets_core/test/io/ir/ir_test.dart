import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given IR ranges', () {
    const vectors = [
      ('A1', 'A1'),
      (r"'Q3 plan'!$B$2:C9", 'B2:C9'),
      ('C:A', 'A:C'),
      ('3:1', '1:3'),
    ];
    for (final (text, a1) in vectors) {
      test('when parsing "$text" then it formats as $a1', () {
        expect(IrRange.parseA1(text)!.$2.toA1(), a1);
      });
    }

    test('when a range reaches the XLSX grid limit then it opens', () {
      expect(
        IrRange(0, 0, 1048575, 0).openAt(maxRows: 1048576, maxCols: 16384),
        IrRange.columns(0, 0),
      );
    });

    test('when formatting with a sheet then the name is quoted as needed', () {
      expect(
        IrRange(0, 0, 1, 1).toA1(sheet: 'Q3 plan', absolute: true),
        r"'Q3 plan'!$A$1:$B$2",
      );
    });
  });

  group('Given a sparse grid', () {
    test('when setting cells out of order then rows iterate sorted', () {
      final g = SparseGrid<String>()
        ..set(5, 3, 'c')
        ..set(0, 9, 'b')
        ..set(0, 1, 'a')
        ..set(5, 3, 'd');
      expect(g.entries.toList(), [(0, 1, 'a'), (0, 9, 'b'), (5, 3, 'd')]);
      expect((g.length, g.maxRow, g.maxCol), (3, 5, 9));
    });

    test('when removing the last cell of a row then the row disappears', () {
      final g = SparseGrid<String>()
        ..set(2, 2, 'x')
        ..set(2, 2, null);
      expect(g.isEmpty, isTrue);
      expect(g.rowIndices, isEmpty);
    });
  });

  group('Given repeated warnings', () {
    test('when adding the same warning then it is counted once', () {
      final w = ImportWarnings()
        ..add('x', 'Same', sheet: 'S')
        ..add('x', 'Same', sheet: 'S', count: 2)
        ..add('x', 'Same', sheet: 'T');
      expect([for (final e in w) (e.sheet, e.count)], [('S', 3), ('T', 1)]);
    });
  });

  group('Given format inheritance', () {
    late WorkbookDocument doc;
    late IrSheet s;
    setUp(() {
      doc = WorkbookDocument()..defaultFontFamily = 'Calibri';
      s = IrSheet('S')
        ..defaultFormat = doc.formats.internAttrs(
          CellFormat({FormatAttr.fontFamily: 'Lato'}),
        );
      s.columns[0] = IrDim(
        format: doc.formats.internAttrs(CellFormat({FormatAttr.bold: true})),
      );
      s.rows[1] = IrDim(
        format: doc.formats.internAttrs(
          CellFormat({FormatAttr.fillColor: '#EEEEEE'}),
        ),
      );
    });

    test('when computing the effective format then rows win over columns', () {
      expect(IrFormats.effective(doc, s, 1, 0).toMap(), {
        'fontFamily': 'Lato',
        'bold': true,
        'fillColor': '#EEEEEE',
      });
    });

    test('when making a complete format relative then inherited attributes '
        'are dropped or reset', () {
      final inherited = IrFormats.inherited(doc, s, 1, 0);
      final complete = CellFormat({
        FormatAttr.fontFamily: 'Lato',
        FormatAttr.italic: true,
      });
      expect(IrFormats.relative(complete, inherited, doc).toMap(), {
        'italic': true,
        'bold': false,
        'fillColor': 'theme:background',
      });
    });
  });
}
