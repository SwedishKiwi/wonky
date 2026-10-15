import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  const options = CodeLayoutOptions(fontSize: 20, lineHeight: 1.5, tabSize: 4);

  group('Given three lines of code', () {
    late CodeLayout layout;
    setUp(
      () => layout = CodeLayout.layout('int a;\n\tb();\nlonger line', options),
    );

    test('when laid out then lines, rows and the widest line are known', () {
      expect(layout.lineCount, 3);
      expect(layout.rowCount, 3);
      expect(layout.maxColumns, 11);
    });

    test('when converting the cell size then it follows the font metrics', () {
      expect(layout.columnWidth, closeTo(12, 1e-9));
      expect(layout.rowHeight, 30);
      expect(layout.width, closeTo(132, 1e-9));
      expect(layout.height, 90);
    });

    test('when locating an offset after a tab then its column is past the '
        'tab stop', () {
      // "\tb" starts at offset 7; "b" is at offset 8.
      expect(layout.posOf(8), const GridPos(1, 4));
    });

    for (final offset in [0, 3, 6, 7, 8, 12, 13, 18, 24]) {
      test('when round-tripping offset $offset then posOf and offsetAt '
          'agree', () {
        expect(layout.offsetAt(layout.posOf(offset)), offset);
      });
    }

    test('when asking for a range over two lines then there is one rect per '
        'row', () {
      final rects = layout.rectsOfRange(4, 9);

      expect(rects, hasLength(2));
      expect(rects.first.left, closeTo(4 * 12, 1e-9));
      expect(rects.first.top, 0);
      expect(rects.last.top, 30);
    });

    test('when asking for an empty range then it is a caret rect', () {
      final r = layout.rectOfRange(2, 2);

      expect(r.width, 0);
      expect(r.left, closeTo(24, 1e-9));
    });

    test('when asking for lines 2 to 3 then the rect spans both rows', () {
      final r = layout.rectOfLines(1, 2);

      expect(r.top, 30);
      expect(r.height, 60);
    });

    test('when finding the baseline then it lies inside the row', () {
      final b = layout.baselineOf(0);

      expect(b, greaterThan(0));
      expect(b, lessThan(30));
    });
  });

  group('Given wide characters', () {
    test('when locating the character after two CJK ideographs then it is at '
        'column 4', () {
      final layout = CodeLayout.layout('漢字x', options);

      expect(layout.posOf(2).column, 4);
      expect(layout.maxColumns, 5);
    });
  });

  group('Given wrapping at 10 columns', () {
    final wrapped = options.copyWith(wrapColumns: 10);

    test('when a line is longer then it wraps after the last space', () {
      final layout = CodeLayout.layout('let ab = cd + ef;', wrapped);

      expect(layout.lineCount, 1);
      expect(layout.rowCount, 2);
      expect(layout.rows[0].end, 9); // after "let ab = "
      expect(layout.rows[1].continuation, isTrue);
      expect(layout.maxColumns, lessThanOrEqualTo(10));
    });

    test('when a word is longer than a row then it is broken inside', () {
      final layout = CodeLayout.layout('a' * 25, wrapped);

      expect(layout.rowCount, 3);
      expect(layout.rows.map((r) => r.columns), [10, 10, 5]);
    });

    test('when locating an offset at a wrap point then it starts the next '
        'row', () {
      final layout = CodeLayout.layout('a' * 25, wrapped);

      expect(layout.posOf(10), const GridPos(1, 0));
    });

    test('when the next line follows a wrapped one then its rows come '
        'after', () {
      final layout = CodeLayout.layout('${'a' * 25}\nb', wrapped);

      expect(layout.lines[1].firstRow, 3);
      expect(layout.rowOf(26), 3);
    });
  });

  test('when laying out an empty text then there is one empty line', () {
    final layout = CodeLayout.layout('');

    expect(layout.lineCount, 1);
    expect(layout.maxColumns, 0);
    expect(layout.posOf(0), const GridPos(0, 0));
  });

  test('when a line ends with CRLF then the CR is not a column', () {
    final layout = CodeLayout.layout('ab\r\ncd');

    expect(layout.lines[0].end, 2);
    expect(layout.maxColumns, 2);
  });
}
