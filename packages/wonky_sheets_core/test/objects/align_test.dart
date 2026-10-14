import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

void main() {
  group('Given three object rectangles', () {
    const rects = {
      'a': ChartRect(10, 10, 100, 50),
      'b': ChartRect(200, 40, 60, 30),
      'c': ChartRect(90, 300, 80, 80),
    };

    test('when aligning edges then sizes stay and edges line up with the '
        'selection bounds', () {
      final l = ObjectAlign.apply(rects, 'left');
      expect([for (final r in l.values) r.left], [10, 10, 10]);
      final r = ObjectAlign.apply(rects, 'right');
      expect([for (final x in r.values) x.right], [260, 260, 260]);
      final b = ObjectAlign.apply(rects, 'bottom');
      expect([for (final x in b.values) x.bottom], [380, 380, 380]);
      expect(b['b']!.width, 60);
    });

    test('when centering then centers meet in the middle of the bounds', () {
      final c = ObjectAlign.apply(rects, 'center');
      expect([for (final r in c.values) r.centerX], [135, 135, 135]);
      final m = ObjectAlign.apply(rects, 'middle');
      expect([for (final r in m.values) r.centerY], [195, 195, 195]);
    });

    test('when distributing vertically then the outer objects stay and the '
        'gaps are equal', () {
      final d = ObjectAlign.apply(rects, 'distributeVertically');
      expect(d['a']!.top, 10);
      expect(d['c']!.top, 300);
      final g1 = d['b']!.top - d['a']!.bottom;
      final g2 = d['c']!.top - d['b']!.bottom;
      expect(g1, closeTo(g2, 1e-9));
    });

    test('when distributing two objects or an unknown op then nothing '
        'changes', () {
      final two = {'a': rects['a']!, 'b': rects['b']!};
      expect(ObjectAlign.apply(two, 'distributeHorizontally'), two);
      expect(ObjectAlign.apply(rects, 'diagonal'), rects);
    });
  });
}
