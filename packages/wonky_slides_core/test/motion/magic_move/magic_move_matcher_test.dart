import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

MagicMoveElement _el(
  String id, {
  ElementKind kind = ElementKind.shape,
  String key = '',
  String? name,
  String? signature,
  double x = 0,
  double y = 0,
  int z = 0,
  List<MagicMoveElement> children = const [],
}) => MagicMoveElement(
  id: id,
  kind: kind,
  matchKey: key,
  name: name,
  signature: signature,
  frame: SuRect(x, y, 100, 100),
  z: z,
  children: children,
);

List<(String, String, String)> _pairs(MagicMoveMatches m) => [
  for (final p in m.pairs) (p.from.id, p.to.id, p.pass.name),
];

void main() {
  group('Given pass 1 — match keys (06 §8.3)', () {
    test('when keys are equal then the elements pair regardless of kind and '
        'content', () {
      final m = MagicMoveMatcher.match(
        [_el('a1', key: 'k1'), _el('a2', key: 'k2')],
        [
          _el('b2', key: 'k2', kind: ElementKind.text),
          _el('b1', key: 'k1'),
          _el('b3', key: 'k3'),
        ],
      );

      expect(_pairs(m), [('a2', 'b2', 'key'), ('a1', 'b1', 'key')]);
      expect(m.outgoing, isEmpty);
      expect(m.incoming.map((e) => e.id), ['b3']);
    });

    test('when a key occurs twice on both sides then they pair by z-order '
        'rank', () {
      final m = MagicMoveMatcher.match(
        [_el('aTop', key: 'k', z: 5), _el('aLow', key: 'k', z: 1)],
        [_el('bLow', key: 'k', z: 0), _el('bTop', key: 'k', z: 3)],
      );

      expect(_pairs(m), [('aLow', 'bLow', 'key'), ('aTop', 'bTop', 'key')]);
    });

    test('when a key occurs twice on one side only then the extra element '
        'is unmatched', () {
      final m = MagicMoveMatcher.match(
        [_el('a1', key: 'k', z: 0), _el('a2', key: 'k', z: 1)],
        [_el('b1', key: 'k')],
      );

      expect(_pairs(m), [('a1', 'b1', 'key')]);
      expect(m.outgoing.map((e) => e.id), ['a2']);
    });
  });

  group('Given pass 2 — content signatures', () {
    test('when unkeyed elements of the same kind show the same content then '
        'they pair, nearest centers first', () {
      final m = MagicMoveMatcher.match(
        [
          _el('aLeft', signature: 'image:x', kind: ElementKind.image),
          _el('aRight', signature: 'image:x', kind: ElementKind.image, x: 900),
        ],
        [
          _el('bRight', signature: 'image:x', kind: ElementKind.image, x: 1000),
          _el('bLeft', signature: 'image:x', kind: ElementKind.image, x: 50),
        ],
      );

      expect(_pairs(m), [
        ('aRight', 'bRight', 'content'),
        ('aLeft', 'bLeft', 'content'),
      ]);
    });

    test('when the kinds differ then equal signatures do not pair', () {
      final m = MagicMoveMatcher.match(
        [_el('a', signature: 'x')],
        [_el('b', signature: 'x', kind: ElementKind.icon)],
      );

      expect(m.pairs, isEmpty);
    });

    test('when matching by content is off then only keys and names pair', () {
      final m = MagicMoveMatcher.match(
        [_el('a', signature: 'x')],
        [_el('b', signature: 'x')],
        options: const MagicMoveOptions(matchByContent: false),
      );

      expect(m.pairs, isEmpty);
    });

    test('when an element already matched by key then it is not reused by '
        'content', () {
      final m = MagicMoveMatcher.match(
        [_el('a', key: 'k', signature: 'x')],
        [_el('b1', key: 'k'), _el('b2', signature: 'x')],
      );

      expect(_pairs(m), [('a', 'b1', 'key')]);
      expect(m.incoming.map((e) => e.id), ['b2']);
    });
  });

  group('Given pass 3 — kind and name', () {
    test('when unkeyed elements share a non-empty name then they pair', () {
      final m = MagicMoveMatcher.match(
        [_el('a', name: 'Logo'), _el('a2', name: ' ')],
        [_el('b', name: 'Logo'), _el('b2', name: ' ')],
      );

      expect(_pairs(m), [('a', 'b', 'name')]);
    });
  });

  group('Given element groups', () {
    test('when two groups pair then their children are matched by the same '
        'passes', () {
      final m = MagicMoveMatcher.match(
        [
          _el(
            'ga',
            key: 'g',
            kind: ElementKind.group,
            children: [
              _el('a1', key: 'c'),
              _el('a2', name: 'n'),
            ],
          ),
        ],
        [
          _el(
            'gb',
            key: 'g',
            kind: ElementKind.group,
            children: [
              _el('b2', name: 'n'),
              _el('b1', key: 'c'),
              _el('b3'),
            ],
          ),
        ],
      );

      expect(_pairs(m.pairs.single.children), [
        ('a2', 'b2', 'name'),
        ('a1', 'b1', 'key'),
      ]);
      expect(m.pairs.single.children.incoming.map((e) => e.id), ['b3']);
      expect(m.pairOf('b1')!.from.id, 'a1');
      expect(m.allPairs.map((p) => p.to.id), ['gb', 'b2', 'b1']);
    });
  });

  group('Given code elements with two states of one snippet (06 §18 AC 6)', () {
    MagicMoveElement code(String id, String source) => MagicMoveElement(
      id: id,
      kind: ElementKind.code,
      matchKey: 'code',
      frame: const SuRect(100, 100, 800, 400),
      contentKey: 'code:$source',
      code: MagicMoveCode(code: source, language: 'dart'),
    );

    test('when the code changed then the pair crossfades with a token '
        'morph that keeps the unchanged tokens', () {
      const before = 'final a = 1;\nprint(a);';
      const after = 'final a = 1;\nfinal b = a + 1;\nprint(b);';
      final plan = MagicMovePlan.compile(
        MagicMoveSlide(slideId: 'A', elements: [code('ca', before)]),
        MagicMoveSlide(slideId: 'B', elements: [code('cb', after)]),
      );
      final pair = plan.pairs.single;

      expect(pair.mode, MorphMode.crossfade);
      expect(
        pair.code!.matched.map((l) => l.text).join(' '),
        contains('print'),
      );
      expect(pair.code!.added.map((l) => l.text), containsAll(['b', '+']));
      expect(plan.frameAt(400).pairs['cb']!.codeProgress, closeTo(0.4, 1e-9));
    });

    test('when the code is the same then the box only moves', () {
      final plan = MagicMovePlan.compile(
        MagicMoveSlide(slideId: 'A', elements: [code('ca', 'x = 1')]),
        MagicMoveSlide(slideId: 'B', elements: [code('cb', 'x = 1')]),
      );

      expect(plan.pairs.single.mode, MorphMode.replace);
      expect(plan.pairs.single.code!.removed, isEmpty);
    });
  });
}
