import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  group('Given two swapped lines', () {
    const from = 'final a = 1;\nfinal b = 2;';
    const to = 'final b = 2;\nfinal a = 1;';
    late TokenMorphPlan plan;
    setUp(() => plan = TokenMorphPlan.build(from, to, language: 'dart'));

    test('when planning then every lexeme is matched (nothing fades)', () {
      expect(plan.removed, isEmpty);
      expect(plan.added, isEmpty);
      expect(plan.matched, hasLength(10));
    });

    test('when planning then the lexemes of the moved line change rows', () {
      final b = plan.matched.firstWhere((l) => l.text == 'b');

      expect(b.fromPos!.row, 1);
      expect(b.toPos!.row, 0);
    });
  });

  group('Given an added and a removed lexeme', () {
    const from = 'print(count);';
    const to = 'print(total, count);';
    late TokenMorphPlan plan;
    setUp(() => plan = TokenMorphPlan.build(from, to, language: 'dart'));

    test('when planning then the new lexemes are added and old ones '
        'kept', () {
      expect(plan.added.map((l) => l.text), ['total', ',']);
      expect(plan.removed, isEmpty);
    });

    test('when halfway then added lexemes are still invisible', () {
      final glyphs = plan.frameAt(plan.durationMs * 0.3);

      expect(glyphs.where((g) => g.lexeme.isAdded), isEmpty);
    });

    test('when finished then every glyph sits at its new position', () {
      final glyphs = plan.frameAt(plan.totalDurationMs);
      final count = glyphs.firstWhere((g) => g.lexeme.text == 'count');

      expect(count.x, closeTo(plan.toLayout.xOf(13), 1e-9));
      expect(count.opacity, 1);
    });
  });

  group('Given removed lexemes', () {
    test('when past the first half then they are gone', () {
      final plan = TokenMorphPlan.build('a + b', 'a');

      expect(plan.removed.map((l) => l.text), ['+', 'b']);
      expect(
        plan.frameAt(plan.durationMs * 0.6).where((g) => g.lexeme.isRemoved),
        isEmpty,
      );
    });

    test('when fading out then they drift upward', () {
      final plan = TokenMorphPlan.build('a + b', 'a');

      final g = plan
          .frameAt(plan.durationMs * 0.25)
          .firstWhere((g) => g.lexeme.text == 'b');

      expect(g.y, lessThan(0));
      expect(g.opacity, closeTo(0.5, 1e-9));
    });
  });

  group('Given a refactoring (07 AC-7)', () {
    const from = '''
void main() {
  final list = [1, 2, 3];
  for (final x in list) {
    print(x);
  }
}''';
    const to = '''
void main() {
  final list = [1, 2, 3];
  list.forEach(print);
  print('done');
}''';

    test('when sampling frames then every matched lexeme moves '
        'monotonically from its old to its new position', () {
      final plan = TokenMorphPlan.build(from, to, language: 'dart');
      final frames = [
        for (var ms = 0; ms <= plan.totalDurationMs; ms += 20) plan.frameAt(ms),
      ];

      for (final l in plan.matched) {
        final xs = [
          for (final f in frames) f.firstWhere((g) => identical(g.lexeme, l)).x,
        ];
        final ys = [
          for (final f in frames) f.firstWhere((g) => identical(g.lexeme, l)).y,
        ];
        expect(_monotonic(xs), isTrue, reason: 'x of $l: $xs');
        expect(_monotonic(ys), isTrue, reason: 'y of $l: $ys');
        expect(xs.first, closeTo(plan.fromLayout.xOf(l.fromPos!.column), 1e-9));
        expect(xs.last, closeTo(plan.toLayout.xOf(l.toPos!.column), 1e-9));
      }
    });
  });

  group('Given layouts at different sizes', () {
    test('when the auto size differs then positions and the font size '
        'interpolate between them', () {
      final la = CodeLayout.layout('ab', const CodeLayoutOptions(fontSize: 20));
      final lb = CodeLayout.layout(
        'xab',
        const CodeLayoutOptions(fontSize: 10),
      );

      final plan = TokenMorphPlan.build(
        'ab',
        'xab',
        fromLayout: la,
        toLayout: lb,
      );
      final mid = plan.frameAt(plan.durationMs / 2);

      expect(mid.first.fontSize, closeTo(15, 1e-9));
    });
  });

  group('Given a stagger', () {
    test('when lines are staggered then later rows start later', () {
      final plan = TokenMorphPlan.build('a\nb', 'b\na', staggerMs: 100);

      expect(plan.totalDurationMs, plan.durationMs + 100);
      final early = plan.frameAt(50);
      final a = early.firstWhere((g) => g.lexeme.text == 'a');
      final b = early.firstWhere((g) => g.lexeme.text == 'b');
      // 'b' ends in row 0 (starts now), 'a' in row 1 (starts at 100 ms).
      expect(a.y, plan.fromLayout.yOf(0));
      expect(b.y, lessThan(plan.fromLayout.yOf(1)));
    });
  });

  group('Given colors of a matched lexeme whose class changes', () {
    test('when mixing in OKLab then the ends are the input colors', () {
      expect(oklabLerp(0xFFFF0000, 0xFF0000FF, 0), 0xFFFF0000);
      expect(oklabLerp(0xFFFF0000, 0xFF0000FF, 1), 0xFF0000FF);
    });

    test('when mixing black and white halfway then the result is a mid '
        'grey', () {
      final c = oklabLerp(0xFF000000, 0xFFFFFFFF, 0.5);
      final r = (c >> 16) & 0xFF;

      expect(r, inInclusiveRange(90, 110));
      expect(c >>> 24, 0xFF);
    });
  });
}

bool _monotonic(List<double> v) {
  var up = true, down = true;
  for (var i = 1; i < v.length; i++) {
    if (v[i] < v[i - 1] - 1e-9) up = false;
    if (v[i] > v[i - 1] + 1e-9) down = false;
  }
  return up || down;
}
