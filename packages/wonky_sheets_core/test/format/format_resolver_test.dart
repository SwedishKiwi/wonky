import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/format/attributes.dart';
import 'package:wonky_sheets_core/src/format/banding.dart';
import 'package:wonky_sheets_core/src/format/format_resolver.dart';
import 'package:wonky_sheets_core/src/model/grid_range.dart';
import 'package:wonky_sheets_core/src/model/schema.dart';
import 'package:wonky_sheets_core/src/model/workbook_model.dart';
import 'package:wonky_sheets_core/src/testing/workbook_builder.dart';

void main() {
  group('Given a sheet with formats, banding and a theme', () {
    late WorkbookBuilder b;
    late String sid;
    late WorkbookModel m;
    late EffectiveFormatResolver resolver;

    setUp(() {
      b = WorkbookBuilder();
      b.themeJson =
          '{"v":1,"name":"Mine","fonts":{"text":"Lora"},'
          '"colors":{"accent1":"#112233"}}';
      sid = b.sheet('Sheet1', rows: 10, cols: 4);
      b.value(
        'A1',
        1,
        format: {
          FormatAttr.numberFormat: '0.00',
          FormatAttr.fillColor: '#FF0000',
          FormatAttr.bold: false,
        },
      );
      b.value('B2', 2);
      b.row(SheetsTables.banding, 'band-1', {
        Cols.sheetId: sid,
        Cols.rangeJson: GridRange(
          sheetId: sid,
          r1: b.rowId(0),
          r2: b.rowId(4),
          c1: b.colId(0),
          c2: b.colId(1),
        ).encode(),
        'styleJson': const BandingStyle(header: '#000080').toJson(),
      });
      m = b.build();
      resolver = EffectiveFormatResolver(m);
    });

    test('when a cell has an explicit format then it wins over banding', () {
      final f = resolver.resolve(sid, 0, 0);

      expect(f.numberFormat, '0.00');
      expect(f.numberFormatExplicit, isTrue);
      expect(f.fillColor, '#FF0000');
      expect(f.bold, isFalse, reason: 'explicit bold=false beats the header');
    });

    test('when a cell has no format then banding and theme defaults apply', () {
      final header = resolver.resolve(sid, 0, 1);
      final band1 = resolver.resolve(sid, 1, 1);
      final band2 = resolver.resolve(sid, 2, 1);

      expect((header.fillColor, header.bold), ('#000080', true));
      expect(band1.fillColor, '#FFFFFF');
      expect(band2.fillColor, '#E8F0FE');
      expect(band1.fontFamily, 'Lora');
      expect(band1.isAutomatic, isTrue);
      expect(band1.numberFormatExplicit, isFalse);
    });

    test('when banding is excluded then no fill comes from it', () {
      expect(
        resolver.resolve(sid, 1, 1, includeBanding: false).fillColor,
        isNull,
      );
    });

    test('when a CF overlay is given then it wins per attribute', () {
      final f = resolver.resolve(
        sid,
        0,
        0,
        conditional: CellFormat({
          FormatAttr.fillColor: '#00FF00',
          FormatAttr.italic: true,
        }),
      );

      expect(f.fillColor, '#00FF00');
      expect(f.italic, isTrue);
      expect(f.numberFormat, '0.00');
    });

    test('when resolving theme colors then theme references map to the '
        'theme', () {
      expect(resolver.color('theme:accent1'), '#112233');
      expect(resolver.color('#abc'), '#AABBCC');
      expect(resolver.color('auto'), isNull);
    });
  });

  group('Given a banding style with header and footer', () {
    const style = BandingStyle(
      header: '#111111',
      footer: '#222222',
      showFooter: true,
    );
    final cases = <(int, int, String?, bool)>[
      (0, 5, '#111111', true),
      (1, 5, '#FFFFFF', false),
      (2, 5, '#E8F0FE', false),
      (3, 5, '#FFFFFF', false),
      (4, 5, '#222222', false),
      (5, 5, null, false),
    ];
    for (final (i, n, fill, bold) in cases) {
      test('when reading row $i of $n then the fill is $fill', () {
        expect(style.contributionAt(i, n), (fill, bold));
      });
    }

    test('when encoding and parsing then the style round-trips', () {
      expect(BandingStyle.parse(style.toJson()), style);
      expect(BandingStyle.parse('nope'), const BandingStyle());
    });
  });
}
