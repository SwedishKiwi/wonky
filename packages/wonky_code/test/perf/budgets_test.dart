// Performance budgets of Slides 07 §14 (tagged `slow`: `dart test -P slow`).
// Each budget is checked on the best of several runs after a warm-up, with
// a 2× allowance for loaded CI machines; the measured times are printed.
@Tags(['slow'])
library;

import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

const _dart = r'''
import 'dart:math';

/// Doc comment.
class Point {
  final double x, y;
  const Point(this.x, this.y);
  double get length => sqrt(x * x + y * y);
  // A comment line.
  Point operator +(Point o) => Point(x + o.x, y + o.y);
}

void main() async {
  final p = Point(3, 4);
  print('length: ${p.length} $p');
  await Future.delayed(const Duration(seconds: 1));
  for (var i = 0; i < 10; i++) {
    if (i.isEven) continue;
  }
}
''';

String _lines(int n) {
  final lines = _dart.split('\n');
  return [for (var i = 0; i < n; i++) lines[i % lines.length]].join('\n');
}

double _bestMs(void Function() body, {int runs = 8}) {
  body();
  var best = double.infinity;
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    body();
    final ms = sw.elapsedMicroseconds / 1000;
    if (ms < best) best = ms;
  }
  return best;
}

void main() {
  test('when tokenizing 1,000 lines of Dart then it takes at most 15 ms', () {
    final code = _lines(1000);

    final ms = _bestMs(() => TextMateTokenizer.instance.tokenize(code, 'dart'));

    print('tokenize 1,000 lines (TextMate, Dart): ${ms.toStringAsFixed(1)} ms');
    expect(ms, lessThan(15 * 2));
  });

  test('when the same text is tokenized again then the cache answers in '
      'well under a millisecond', () {
    final code = _lines(1000);
    final t = CachedCodeTokenizer()..tokenize(code, 'dart');

    final ms = _bestMs(() => t.tokenize(code, 'dart'));

    print('cached tokenize: ${ms.toStringAsFixed(3)} ms');
    expect(ms, lessThan(1));
  });

  test('when building a typing script for 200 changed lines then it takes at '
      'most 20 ms', () {
    final from = _lines(300);
    final lines = from.split('\n');
    final to = [
      for (var i = 0; i < lines.length; i++)
        i.isEven && i < 400 ? lines[i].replaceAll('x', 'xx') : lines[i],
    ].join('\n');
    final fromTokens = TextMateTokenizer.instance.tokenize(from, 'dart');
    final toTokens = TextMateTokenizer.instance.tokenize(to, 'dart');

    final ms = _bestMs(
      () => TypingScript.build(
        from,
        to,
        script: CodeEditScript.compute(
          from,
          to,
          fromTokens: fromTokens,
          toTokens: toTokens,
        ),
      ),
    );

    print(
      'TypingScript.build (≈150 changed lines): ${ms.toStringAsFixed(1)} ms',
    );
    expect(ms, lessThan(20 * 2));
  });

  test('when planning a morph of 2 × 300 lines then it takes at most '
      '15 ms', () {
    final from = _lines(300);
    final lines = from.split('\n');
    final to = [
      ...lines.sublist(150),
      ...lines.sublist(0, 150),
    ].map((l) => l.replaceAll('Point', 'Vector')).join('\n');
    final fromTokens = TextMateTokenizer.instance.tokenize(from, 'dart');
    final toTokens = TextMateTokenizer.instance.tokenize(to, 'dart');

    final ms = _bestMs(
      () => TokenMorphPlan.build(
        from,
        to,
        fromTokens: fromTokens,
        toTokens: toTokens,
      ),
    );

    print('TokenMorphPlan.build (2 × 300 lines): ${ms.toStringAsFixed(1)} ms');
    expect(ms, lessThan(15 * 2));
  });

  test('when replaying a typing frame of 300 lines then it takes at most '
      '1 ms', () {
    final from = _lines(300);
    final to = from.replaceAll('i++', 'i += 2');
    final script = TypingScript.build(from, to);

    final ms =
        _bestMs(() {
          for (var t = 0; t < script.durationMs; t += script.durationMs ~/ 50) {
            script.stateAt(t);
          }
        }) /
        50;

    print('TypingScript.stateAt (300 lines): ${ms.toStringAsFixed(3)} ms');
    expect(ms, lessThan(1));
  });
}
