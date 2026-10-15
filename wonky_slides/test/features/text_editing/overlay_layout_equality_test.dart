import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides_core/model.dart';

import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import 'text_edit_fixture.dart';

/// Line-break and glyph equality between the editing overlay and the
/// static rendering (03 §6.1, §22; 12 R4; spike SL-4): every character of
/// every paragraph has the same box in the overlay's `RenderParagraph` as
/// in the static engine's `ui.Paragraph` (so line breaks, glyph positions,
/// baselines, spacing, indents and auto-fit agree), the overlay's height is
/// the static content height, and the composited pixels of "static" and
/// "editing" are compared.

const _lorem =
    'Slides keep the text where it was: entering edit mode must not move a '
    'single glyph, break a line differently or shift the baseline.';

Map<String, Object?> _p([Map<String, Object?>? a]) => {
  'insert': '\n',
  'attributes': ?a,
};

final _bodies = <String, List<Map<String, Object?>>>{
  'a wrapped paragraph': [
    {'insert': _lorem},
    _p(),
  ],
  'mixed inline styles': [
    {'insert': 'Plain, '},
    {
      'insert': 'bold',
      'attributes': {'bold': true},
    },
    {'insert': ', '},
    {
      'insert': 'italic big',
      'attributes': {'italic': true, 'size': 72},
    },
    {'insert': ', '},
    {
      'insert': 'spaced caps',
      'attributes': {'caps': 'all', 'letterSpacing': 0.2},
    },
    {'insert': ' E=mc'},
    {
      'insert': '2',
      'attributes': {'script': 'super'},
    },
    {
      'insert': ' marked',
      'attributes': {
        'highlight': '#fde68a',
        'underline': true,
        'color': 'theme:accent1',
      },
    },
    {
      'insert': ' struck',
      'attributes': {'strike': true, 'font': '@mono'},
    },
    _p(),
  ],
  'styles, spacing, alignment': [
    {'insert': 'A title'},
    _p({'style': 'title', 'align': 'center'}),
    {'insert': _lorem},
    _p({'align': 'justify', 'lineHeight': 1.6, 'spaceBefore': 30}),
    {'insert': 'Right aligned caption'},
    _p({'style': 'caption', 'align': 'right', 'spaceAfter': 40}),
    {'insert': 'Last'},
    _p(),
  ],
  'lists and empty paragraphs': [
    {'insert': 'Bullet level 0 with enough words to wrap onto a second line'},
    _p({'list': 'bullet'}),
    {'insert': 'Level 1'},
    _p({'list': 'bullet', 'indent': 1}),
    _p({'list': 'bullet', 'indent': 2}),
    {'insert': 'Numbered from three'},
    _p({'list': 'ordered', 'listStart': 3}),
    {'insert': 'Four'},
    _p({'list': 'ordered'}),
    _p(),
    {'insert': 'Done'},
    _p({'list': 'check'}),
    {'insert': 'Open'},
    _p({'list': 'unchecked', 'listStyle': 'star'}),
  ],
  'soft breaks': [
    {'insert': 'First line second line after a soft break third'},
    _p({'align': 'center'}),
  ],
  'a right-to-left paragraph': [
    {'insert': 'שלום עולם, mixed with English words that wrap around'},
    _p({'dir': 'rtl'}),
    {'insert': 'Left again'},
    _p(),
  ],
  'an empty body': [_p()],
};

void main() {
  for (final MapEntry(key: name, value: ops) in _bodies.entries) {
    testWidgets('Given $name in a text box, when editing starts then every '
        'glyph sits where the static rendering drew it', (tester) async {
      final f = TextEditFixture();
      final id = f.element(ops, w: 1000);
      await f.loadFonts(tester);
      final c = f.controller(id);
      addTearDown(c.dispose);

      await pumpEditing(tester, f, c);

      expectOverlayMatchesStatic(tester, c);
    });
  }

  testWidgets('Given a shape whose long text shrinks to fit, when editing '
      'starts then the overlay uses the auto-fit scale and the middle '
      'anchor of the static text', (tester) async {
    final f = TextEditFixture();
    final id = f.element(
      [
        {'insert': '$_lorem $_lorem $_lorem'},
        _p({'align': 'center'}),
      ],
      kind: ElementKind.shape,
      w: 700,
      h: 260,
      data: {'geometry': 'roundRect'},
      textStyle: {'autofit': 'shrink'},
    );
    await f.loadFonts(tester);
    final c = f.controller(id);
    addTearDown(c.dispose);

    await pumpEditing(tester, f, c);

    expect(c.geometry.spec.scale, lessThan(1));
    expectOverlayMatchesStatic(tester, c);
  });

  for (final (name, title) in [
    ('a filled title placeholder', 'A centered title that wraps'),
    ('an empty title placeholder', null),
  ]) {
    testWidgets('Given $name, when editing starts then the overlay sits on '
        'the placeholder\'s first line with its inherited style', (
      tester,
    ) async {
      final f = TextEditFixture(layoutKey: 'title', title: title);
      final id = f.placeholder(SlidePlaceholderType.title);
      await f.loadFonts(tester);
      final c = f.controller(id);
      addTearDown(c.dispose);

      await pumpEditing(tester, f, c);

      expectOverlayMatchesStatic(tester, c);
      expect(c.geometry.spec.styles.defaultStyle, 'title');
    });
  }

  for (final rotation in [90.0, 30.0]) {
    testWidgets('Given a text box rotated by $rotation°, when editing starts '
        'then the overlay is transformed like the static text', (tester) async {
      final f = TextEditFixture();
      final id = f.element(
        [
          {'insert': _lorem},
          _p({'list': 'bullet'}),
        ],
        x: 700,
        y: 300,
        w: 700,
        rotation: rotation,
      );
      await f.loadFonts(tester);
      final c = f.controller(id);
      addTearDown(c.dispose);

      await pumpEditing(tester, f, c);

      expectOverlayMatchesStatic(tester, c);
      // The first glyph's corner on screen = the static transform of the
      // engine's glyph box.
      final rp = overlayParagraphs(tester).first;
      final box = rp
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1),
          )
          .first;
      final onScreen = rp.localToGlobal(Offset(box.left, box.top));
      final placed = staticParagraphs(c).first;
      final glyph = placed.paragraph.getBoxesForRange(0, 1).first;
      final expected = MatrixUtils.transformPoint(
        Matrix4.diagonal3Values(0.5, 0.5, 1)..multiply(c.geometry.textToSlide),
        Offset(placed.dx + glyph.left, placed.dy + glyph.top),
      );
      expect(onScreen.dx, moreOrLessEquals(expected.dx, epsilon: 0.01));
      expect(onScreen.dy, moreOrLessEquals(expected.dy, epsilon: 0.01));
    });
  }

  group('Given the composited pixels (golden-like paint comparison)', () {
    for (final (name, rotation, zoom) in [
      ('styles, spacing, alignment', 0.0, 0.5),
      ('lists and empty paragraphs', 0.0, 0.75),
      ('mixed inline styles', 90.0, 0.5),
    ]) {
      testWidgets('when "$name" at $rotation° and zoom $zoom is shown '
          'statically and with the overlay then the images match', (
        tester,
      ) async {
        final f = TextEditFixture();
        final id = f.element(
          _bodies[name]!,
          x: 500,
          y: 100,
          w: 1000,
          h: 600,
          rotation: rotation,
        );
        await f.loadFonts(tester);
        final c = f.controller(id);
        addTearDown(c.dispose);

        await pumpEditing(tester, f, c, zoom: zoom, overlay: false);
        final still = await _capture(tester);
        await pumpEditing(
          tester,
          f,
          c,
          zoom: zoom,
          caretColor: const Color(0x00000000),
        );
        final editing = await _capture(tester);

        final diff = _diff(still, editing);
        // Recorded in 03 §6.1 (decision record).
        debugPrint(
          'SL-4 paint diff "$name" $rotation° ×$zoom: ${diff.changed} of '
          '${diff.inked} inked px differ, max channel delta ${diff.max}',
        );
        expect(diff.inked, greaterThan(500));
        expect(diff.changed / diff.inked, lessThan(0.01));
      });
    }

    testWidgets('when the overlay is off by half a pixel (negative control) '
        'then the comparison sees it', (tester) async {
      final f = TextEditFixture();
      final id = f.element(_bodies['a wrapped paragraph']!, x: 500, w: 1000);
      await f.loadFonts(tester);
      final c = f.controller(id);
      addTearDown(c.dispose);

      await pumpEditing(tester, f, c, overlay: false);
      final still = await _capture(tester);
      // 0.5 → 0.5005: the text origin (≈ 700 su) moves by ≈ 0.35 px.
      await pumpEditing(
        tester,
        f,
        c,
        overlayZoom: 0.5005,
        caretColor: const Color(0x00000000),
      );
      final shifted = await _capture(tester);

      final diff = _diff(still, shifted);
      debugPrint(
        'SL-4 paint diff negative control: ${diff.changed} of ${diff.inked} '
        'inked px differ, max channel delta ${diff.max}',
      );
      expect(diff.changed / diff.inked, greaterThan(0.05));
    });
  });
}

Future<ByteData> _capture(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(canvasKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!;
  }))!;
}

/// Pixels with ink in either image, and how many of them differ by more
/// than a channel delta of 24 (antialiasing noise).
({int inked, int changed, int max}) _diff(ByteData x, ByteData y) {
  var inked = 0, changed = 0, max = 0;
  final bg = [x.getUint8(0), x.getUint8(1), x.getUint8(2)];
  for (var i = 0; i < x.lengthInBytes; i += 4) {
    var isInk = false, delta = 0;
    for (var ch = 0; ch < 3; ch++) {
      final p = x.getUint8(i + ch), q = y.getUint8(i + ch);
      if ((p - bg[ch]).abs() > 16 || (q - bg[ch]).abs() > 16) isInk = true;
      delta = math.max(delta, (p - q).abs());
    }
    if (isInk) inked++;
    if (delta > 24) changed++;
    max = math.max(max, delta);
  }
  return (inked: inked, changed: changed, max: max);
}
