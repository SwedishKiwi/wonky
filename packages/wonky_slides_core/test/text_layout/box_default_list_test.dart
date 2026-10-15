import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  final theme = DeckThemeResolver().resolve(
    BuiltInThemes.package(BuiltInThemes.defaultKey)!.theme,
    SlideAppearance.light,
  );
  final bulleted = TextStyleResolver().resolve(
    theme,
    box: const BoxTextStyle(defaults: {'list': 'bullet'}),
    defaultStyle: 'body',
  );

  TextBody body(List<Map<String, Object?>> blocks) => TextBody([
    for (final (i, b) in blocks.indexed) ...[
      {'insert': 'p$i'},
      {'insert': '\n', if (b.isNotEmpty) 'attributes': b},
    ],
  ]);

  group('Given a box whose text defaults name a bulleted list (a body '
      'placeholder)', () {
    test('when a paragraph has no list attribute then it is bulleted', () {
      final paras = TextParagraphs.build(body([{}]), bulleted);

      expect(paras.single.list, 'bullet');
      expect(paras.single.marker?.text, isNotEmpty);
      expect(paras.single.textIndent, greaterThan(0));
    });

    test(
      'when a paragraph sets listStyle none then the default list is off',
      () {
        final paras = TextParagraphs.build(
          body([
            {'listStyle': 'none'},
          ]),
          bulleted,
        );

        expect(paras.single.list, isNull);
        expect(paras.single.marker, isNull);
        expect(paras.single.textIndent, 0);
      },
    );

    test('when a paragraph names a style or its own list then the default '
        'does not apply', () {
      final paras = TextParagraphs.build(
        body([
          {'style': 'heading'},
          {'list': 'ordered'},
        ]),
        bulleted,
      );

      expect(paras[0].list, isNull);
      expect(paras[1].list, 'ordered');
      expect(paras[1].marker?.text, '1.');
    });

    test('when the core engine lays it out then the marker line is there '
        '(same model as the Flutter engine)', () {
      final layout = SlideTextLayout().layout(
        body([{}, {}]),
        bulleted,
        width: 800,
      );
      final plain = SlideTextLayout().layout(
        body([{}, {}]),
        TextStyleResolver().resolve(theme, defaultStyle: 'body'),
        width: 800,
      );

      expect(layout.lines.first.left, greaterThan(plain.lines.first.left));
    });
  });
}
