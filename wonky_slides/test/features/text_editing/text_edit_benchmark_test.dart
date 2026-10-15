@Tags(['slow'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:wonky_slides/features/text_editing/text_edit_geometry.dart';

import 'text_edit_fixture.dart';

/// Spike SL-4 measurements (03 §18: enter text editing < 50 ms, typing
/// < 16 ms p95). Run in the widget-test VM (debug JIT, software
/// rendering), which is slower than a release web build, so the asserted
/// bounds are loose and the printed numbers are what 03 §6.1 records.

const _body = [
  {'insert': 'Quarterly results'},
  {
    'insert': '\n',
    'attributes': {'style': 'title'},
  },
  {
    'insert':
        'Revenue grew in every region, with the strongest growth in the '
        'new markets we entered last year.',
  },
  {
    'insert': '\n',
    'attributes': {'list': 'bullet'},
  },
  {'insert': 'Costs stayed flat while the team doubled.'},
  {
    'insert': '\n',
    'attributes': {'list': 'bullet'},
  },
  {'insert': 'Next: hire, ship, repeat.'},
  {
    'insert': '\n',
    'attributes': {'list': 'ordered'},
  },
];

double _percentile(List<int> micros, double p) {
  final s = [...micros]..sort();
  return s[((s.length - 1) * p).round()] / 1000;
}

void main() {
  testWidgets('Given a 4-paragraph text box, when editing starts repeatedly '
      'then the overlay is ready quickly', (tester) async {
    final f = TextEditFixture();
    final id = f.element(_body, w: 1200, h: 400);
    await f.loadFonts(tester);
    await pumpEditing(tester, f, null);
    final runs = <int>[];
    for (var i = 0; i < 12; i++) {
      final sw = Stopwatch()..start();
      final c = f.controller(id);
      await pumpEditing(tester, f, c);
      sw.stop();
      runs.add(sw.elapsedMicroseconds);
      c.dispose();
      await pumpEditing(tester, f, null);
    }
    final warm = runs.skip(2).toList();
    final median = _percentile(warm, 0.5);
    debugPrint(
      'SL-4 enter editing: median ${median.toStringAsFixed(1)} ms, '
      'max ${_percentile(warm, 1).toStringAsFixed(1)} ms (first '
      '${(runs.first / 1000).toStringAsFixed(1)} ms)',
    );
    expect(median, lessThan(250));
  });

  testWidgets('Given the overlay, when 100 characters are typed then each '
      'keystroke is laid out and painted quickly', (tester) async {
    final f = TextEditFixture();
    final id = f.element(_body, w: 1200, h: 400);
    await f.loadFonts(tester);
    final c = f.controller(id);
    addTearDown(c.dispose);
    await pumpEditing(tester, f, c);
    final keys = <int>[];
    final geometry = <int>[];
    for (var i = 0; i < 100; i++) {
      final sw = Stopwatch()..start();
      await tester.typeImeText(i % 7 == 6 ? ' ' : 'x');
      await tester.pump();
      sw.stop();
      keys.add(sw.elapsedMicroseconds);
      final g = Stopwatch()..start();
      TextEditGeometry.of(
        slide: f.slide,
        element: f.slide.element(id)!,
        engine: f.renderer.textLayout,
        deck: f.session.model,
        textJson: c.json,
      );
      g.stop();
      geometry.add(g.elapsedMicroseconds);
    }
    final warm = keys.skip(10).toList();
    debugPrint(
      'SL-4 typing: p50 ${_percentile(warm, 0.5).toStringAsFixed(1)} ms, '
      'p95 ${_percentile(warm, 0.95).toStringAsFixed(1)} ms per keystroke '
      '(IME delta → document → style phase → layout → paint); geometry '
      'rebuild p50 ${_percentile(geometry, 0.5).toStringAsFixed(2)} ms',
    );
    expect(_percentile(warm, 0.95), lessThan(60));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
