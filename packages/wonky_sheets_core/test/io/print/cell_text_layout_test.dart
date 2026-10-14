import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

/// Every glyph is half the font size wide; lines are 1.2 × the size.
final class _FixedMeasurer implements CellTextMeasurer {
  const _FixedMeasurer();

  @override
  double width(String text, CellTextStyle style) =>
      text.runes.length * style.size / 2;

  @override
  double ascent(CellTextStyle style) => style.size * 0.8;

  @override
  double descent(CellTextStyle style) => style.size * 0.2;

  @override
  double lineHeight(CellTextStyle style) => style.size * 1.2;
}

const _style = CellTextStyle(family: 'Inter', size: 10);
const _m = _FixedMeasurer();

CellTextLayoutResult _layout(
  String text, {
  double width = 100,
  double height = 21,
  WrapStrategy wrap = WrapStrategy.overflow,
  HorizontalAlign align = HorizontalAlign.left,
  VerticalAlign vAlign = VerticalAlign.bottom,
  int rotation = 0,
  bool numberLike = false,
  OverflowNeighbour? left,
  OverflowNeighbour? right,
}) => CellTextLayout.layout(
  text: text,
  style: _style,
  measurer: _m,
  cellWidth: width,
  cellHeight: height,
  wrap: wrap,
  align: align,
  vAlign: vAlign,
  rotation: rotation,
  numberLike: numberLike,
  leftNeighbour: left,
  rightNeighbour: right,
);

List<String> _lines(CellTextLayoutResult r) => [
  for (final l in r.lines) r.lineText(l),
];

void main() {
  group('Given a single line of text', () {
    test('when left aligned then it starts after the padding', () {
      final r = _layout('Hello');
      expect(r.lines.single.x, 3);
      expect(r.lines.single.width, 25);
      // bottom aligned: 21 − 2 − 12 + baseline offset 9.
      expect(r.lines.single.baseline, 16);
    });

    test('when right aligned then it ends before the padding', () {
      expect(_layout('Hello', align: HorizontalAlign.right).lines.single.x, 72);
    });

    test(
      'when centered vertically and horizontally then it is in the middle',
      () {
        final r = _layout(
          'Hello',
          align: HorizontalAlign.center,
          vAlign: VerticalAlign.middle,
        );
        expect(r.lines.single.x, 37.5);
        expect(r.lines.single.baseline, closeTo((21 - 12) / 2 + 9, 1e-9));
      },
    );
  });

  group('Given text wider than the cell', () {
    test('when wrapping then lines break between words', () {
      final r = _layout('aaa bbb ccc', width: 41, wrap: WrapStrategy.wrap);
      expect(_lines(r), ['aaa bbb ', 'ccc']);
      expect(r.requiredHeight, 2 * 12 + 4);
    });

    test('when a word is longer than the line then it breaks by character', () {
      final r = _layout('abcdefghij', width: 31, wrap: WrapStrategy.wrap);
      expect(_lines(r), ['abcde', 'fghij']);
    });

    test('when it has line breaks then every paragraph is a line', () {
      final r = _layout('one\r\ntwo\nthree');
      expect(_lines(r), ['one', 'two', 'three']);
    });

    test(
      'when overflowing to the right then empty neighbours extend the clip',
      () {
        final r = _layout('x' * 30, right: (step) => step <= 1 ? 100 : null);
        expect(r.clipRight, 200);
        expect(r.overflowCellsRight, 1);
      },
    );

    test('when the neighbour has content then the text is clipped', () {
      final r = _layout('x' * 30, right: (_) => null);
      expect((r.clipLeft, r.clipRight), (0, 100));
    });

    test('when centered then it overflows to both sides', () {
      final r = _layout(
        'x' * 30,
        align: HorizontalAlign.center,
        left: (_) => 100,
        right: (_) => 100,
      );
      expect((r.clipLeft, r.clipRight), (-100, 200));
    });

    test('when clipping then neighbours are ignored', () {
      final r = _layout('x' * 30, wrap: WrapStrategy.clip, right: (_) => 100);
      expect(r.clipRight, 100);
    });

    test('when it is a number then hash signs replace it', () {
      final r = _layout('123456789012345678901', numberLike: true);
      expect(r.hashes, isTrue);
      expect(r.text, '#' * 18);
    });
  });

  group('Given rotated text', () {
    test('when rotated by 90° then the frame is rotated and centered', () {
      final r = _layout('Up', rotation: 90, height: 40);
      expect(r.angle, 90);
      expect(r.frameX, closeTo(3 + 6, 1e-9));
      expect(r.requiredHeight, closeTo(10 + 4, 1e-9));
    });

    test('when stacked then every glyph is its own line', () {
      final r = _layout('abc', rotation: 255, height: 60);
      expect(_lines(r), ['a', 'b', 'c']);
      expect(r.angle, 0);
      expect(r.requiredHeight, 3 * 12 + 4);
    });
  });

  group('Given the approximate measurer', () {
    test('when measuring wide glyphs then they are one em', () {
      const m = ApproximateTextMeasurer();
      expect(m.width('漢', _style), 10);
      expect(m.width('1', _style), closeTo(5.56, 1e-9));
    });
  });
}
