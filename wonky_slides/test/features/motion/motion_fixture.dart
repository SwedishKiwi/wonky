import 'dart:convert';

import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';

/// A deck with builds and transitions for the player, present mode and
/// stage tests (Slides 06 §6, §12; SL-29):
///
/// - [a]: a shape that fades in on click (500 ms) and a 3-bullet text box
///   that rises by bullet (one click each, after-build dim) — 4 clicks;
/// - [b]: entered with a 700 ms `push`, a step-0 `fade` (300 ms) of a
///   shape, then one click: a typewriter text and a `wipe`;
/// - [c]: entered with Magic Move from [b] (the shape [moved] keeps its
///   match key, moved and recolored);
/// - [d]: a 3D `cube` transition, no builds.
class MotionDeck {
  MotionDeck._(this.builder, this.rows);

  factory MotionDeck({
    Map<String, Object?>? presentJson,
    Map<String, Object?>? defaults,
  }) {
    final b = DeckBuilder(title: 'Motion');
    final d = MotionDeck._(b, const []);
    d.a = b.slide(layoutKey: 'blank');
    d.aShape = b.shape(d.a, x: 100, y: 100);
    d.aText = b.textBox(d.a, 'One\nTwo\nThree', x: 100, y: 400, height: 300);
    b.build_(d.a, d.aShape, durationMs: 500, easing: 'linear');
    b.build_(
      d.a,
      d.aText,
      effect: 'rise',
      durationMs: 600,
      optionsJson: jsonEncode({
        'v': 1,
        'delivery': {'by': 'paragraph', 'partTrigger': 'onClick'},
        'afterBuild': {'mode': 'dim', 'dimOpacity': 0.35},
      }),
    );
    d.b = b.slide(layoutKey: 'blank');
    d.moved = b.shape(d.b, x: 200, y: 200, width: 300, height: 300);
    d.bText = b.textBox(d.b, 'Typed text', x: 600, y: 100);
    b.build_(
      d.b,
      d.moved,
      trigger: SlideBuildTrigger.withPrevious,
      durationMs: 300,
      easing: 'linear',
    );
    b.build_(d.b, d.bText, effect: 'typewriter', easing: 'linear');
    b.build_(
      d.b,
      d.bText,
      kind: SlideBuildKind.emphasis,
      effect: 'pulse',
      trigger: SlideBuildTrigger.withPrevious,
    );
    d.c = b.slide(layoutKey: 'blank');
    d.cMoved = b.shape(
      d.c,
      x: 900,
      y: 500,
      width: 500,
      height: 300,
      fillJson: jsonEncode({'type': 'solid', 'color': '#ff0000'}),
    );
    d.d = b.slide(layoutKey: 'blank');
    b.shape(d.d);
    var rows = b.rows;
    rows = _patch(rows, d.b, {
      'transitionJson': jsonEncode({
        'v': 1,
        'type': 'push',
        'durationMs': 700,
        'easing': 'linear',
      }),
    });
    rows = _patch(rows, d.c, {
      'transitionJson': jsonEncode({
        'v': 1,
        'type': 'magicMove',
        'durationMs': 1000,
        'easing': 'linear',
      }),
    });
    rows = _patch(rows, d.d, {
      'transitionJson': jsonEncode({
        'v': 1,
        'type': 'cube',
        'durationMs': 1000,
        'easing': 'linear',
      }),
    });
    // The Magic Move pair: the same match key on B and C.
    rows = _patch(rows, d.cMoved, {'matchKey': _matchKey(rows, d.moved)});
    if (presentJson != null || defaults != null) {
      rows = [
        for (final r in rows)
          r.$1 == 'deck'
              ? (
                  r.$1,
                  {
                    ...r.$2,
                    if (presentJson != null)
                      'presentJson': jsonEncode({'v': 1, ...presentJson}),
                    if (defaults != null) 'defaultsJson': jsonEncode(defaults),
                  },
                )
              : r,
      ];
    }
    return MotionDeck._(b, rows)
      ..a = d.a
      ..aShape = d.aShape
      ..aText = d.aText
      ..b = d.b
      ..moved = d.moved
      ..bText = d.bText
      ..c = d.c
      ..cMoved = d.cMoved
      ..d = d.d;
  }

  final DeckBuilder builder;
  final List<SlidesRow> rows;
  late String a, aShape, aText, b, moved, bText, c, cMoved, d;

  /// The deck model.
  DeckModel model() => DeckModel.fromRows(builder.deckId, rows);

  /// [rows] with the columns of row [id] patched.
  static List<SlidesRow> _patch(
    List<SlidesRow> rows,
    String id,
    Map<String, Object?> cols,
  ) => [
    for (final r in rows) r.$2['id'] == id ? (r.$1, {...r.$2, ...cols}) : r,
  ];

  static Object? _matchKey(List<SlidesRow> rows, String id) =>
      rows.firstWhere((r) => r.$2['id'] == id).$2['matchKey'];

  /// This deck with [slideId]'s columns patched.
  MotionDeck patched(String slideId, Map<String, Object?> cols) =>
      MotionDeck._(builder, _patch(rows, slideId, cols))
        ..a = a
        ..aShape = aShape
        ..aText = aText
        ..b = b
        ..moved = moved
        ..bText = bText
        ..c = c
        ..cMoved = cMoved
        ..d = d;
}
