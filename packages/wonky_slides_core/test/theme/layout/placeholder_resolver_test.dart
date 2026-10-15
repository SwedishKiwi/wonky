import 'package:test/test.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  const master = PlaceholderNode(
    id: 'm-title',
    placeholderType: SlidePlaceholderType.title,
    x: 120,
    y: 72,
    width: 1680,
    height: 144,
    textStyle: BoxTextStyle(
      anchor: 'bottom',
      autofit: 'shrink',
      defaults: {'style': 'heading'},
    ),
    fill: {'v': 1, 'type': 'none'},
  );
  const layout = PlaceholderNode(
    id: 'l-title',
    placeholderType: SlidePlaceholderType.title,
    placeholderOf: 'm-title',
    x: 120,
    y: 360,
    width: 1680,
    height: 240,
    textStyle: BoxTextStyle(defaults: {'style': 'title'}),
  );
  final nodes = {
    for (final n in [master, layout]) n.id: n,
  };
  final resolver = PlaceholderResolver(
    lookup: (id) => nodes[id],
    slideBounds: SlideSize.widescreen.bounds,
    masterFallback: (type) =>
        type == SlidePlaceholderType.title ? master : null,
  );

  group('Given an empty instance of a layout title', () {
    const instance = PlaceholderNode(
      id: 'i',
      placeholderType: SlidePlaceholderType.title,
      placeholderOf: 'l-title',
    );

    test('when resolving then the frame comes from the layout', () {
      final e = resolver.resolve(instance);
      expect(e.frame, const SuRect(120, 360, 1680, 240));
      expect(e.chain, ['i', 'l-title', 'm-title']);
      expect(e.dangling, isFalse);
    });

    test('when resolving then box text merges master ▸ layout', () {
      final e = resolver.resolve(instance);
      expect(e.textStyle.anchor, 'bottom');
      expect(e.textStyle.autofit, 'shrink');
      expect(e.styleKey, 'title');
      expect(e.fill, {'v': 1, 'type': 'none'});
      expect(e.rotation, 0);
      expect(e.opacity, 1);
    });

    test('when the layout title moves then the instance follows (05 AC 4)', () {
      final moved = {
        ...nodes,
        'l-title': const PlaceholderNode(
          id: 'l-title',
          placeholderOf: 'm-title',
          x: 0,
          y: 0,
          width: 800,
          height: 100,
        ),
      };
      final r = PlaceholderResolver(
        lookup: (id) => moved[id],
        slideBounds: SlideSize.widescreen.bounds,
      );
      expect(r.resolve(instance).frame, const SuRect(0, 0, 800, 100));
    });
  });

  group('Given an instance with a materialized frame', () {
    const instance = PlaceholderNode(
      id: 'i',
      placeholderType: SlidePlaceholderType.title,
      placeholderOf: 'l-title',
      x: 10,
      y: 20,
      width: 300,
      height: 40,
      textStyle: BoxTextStyle(defaults: {'align': 'center'}),
    );

    test('when resolving then its own frame wins and styles still inherit', () {
      final e = resolver.resolve(instance);
      expect(e.frame, const SuRect(10, 20, 300, 40));
      expect(e.textStyle.defaults, {'style': 'title', 'align': 'center'});
      expect(e.textStyle.anchor, 'bottom');
    });
  });

  group('Given an instance whose layout placeholder was deleted (02 §10)', () {
    const instance = PlaceholderNode(
      id: 'i',
      placeholderType: SlidePlaceholderType.title,
      placeholderOf: 'gone',
    );

    test('when resolving then the master placeholder of the type is used', () {
      final e = resolver.resolve(instance);
      expect(e.dangling, isTrue);
      expect(e.frame, const SuRect(120, 72, 1680, 144));
      expect(e.styleKey, 'heading');
    });

    test(
      'when no master placeholder exists then a 10 % inset frame is used',
      () {
        final e = resolver.resolve(
          const PlaceholderNode(
            id: 'j',
            placeholderType: SlidePlaceholderType.quote,
            placeholderOf: 'gone',
          ),
        );
        expect(e.frame, const SuRect(192, 108, 1536, 864));
        expect(e.styleKey, 'quote', reason: 'the type default (05 §5.3)');
      },
    );
  });

  group('Given a cyclic chain', () {
    test('when resolving then it stops', () {
      final cyc = {
        'a': const PlaceholderNode(
          id: 'a',
          placeholderOf: 'b',
          placeholderType: SlidePlaceholderType.body,
        ),
        'b': const PlaceholderNode(
          id: 'b',
          placeholderOf: 'a',
          x: 1,
          y: 2,
          width: 3,
          height: 4,
        ),
      };
      final r = PlaceholderResolver(
        lookup: (id) => cyc[id],
        slideBounds: SlideSize.widescreen.bounds,
      );
      final e = r.resolve(cyc['a']!);
      expect(e.chain, ['a', 'b']);
      expect(e.styleKey, 'body');
    });
  });
}
