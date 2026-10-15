import 'package:test/test.dart';
import 'package:wonky_slides_core/history.dart';
import 'package:wonky_slides_core/testing.dart';

void main() {
  group('Given two texts', () {
    test('when equal then one equal span', () {
      expect(TextDiff.of('Hello world', 'Hello world'), [
        (op: TextDiffOp.equal, text: 'Hello world'),
      ]);
    });

    test('when both are empty then no spans', () {
      expect(TextDiff.of('', ''), isEmpty);
    });

    test('when a word is replaced then delete and insert sit between the '
        'common parts', () {
      expect(TextDiff.of('The quick fox', 'The slow fox'), [
        (op: TextDiffOp.equal, text: 'The '),
        (op: TextDiffOp.delete, text: 'quick'),
        (op: TextDiffOp.insert, text: 'slow'),
        (op: TextDiffOp.equal, text: ' fox'),
      ]);
    });

    test('when words are inserted then only the insertion is marked', () {
      expect(TextDiff.of('Ship it', 'Ship it today'), [
        (op: TextDiffOp.equal, text: 'Ship it'),
        (op: TextDiffOp.insert, text: ' today'),
      ]);
    });

    test('when everything differs then one deletion and one insertion', () {
      expect(TextDiff.of('alpha', 'omega'), [
        (op: TextDiffOp.delete, text: 'alpha'),
        (op: TextDiffOp.insert, text: 'omega'),
      ]);
    });

    test('when the texts are huge then the diff still covers both texts', () {
      final a = List.generate(2000, (i) => 'a$i').join(' ');
      final b = List.generate(2000, (i) => 'b$i').join(' ');

      final d = TextDiff.of(a, b);

      String side(TextDiffOp skip) => [
        for (final s in d)
          if (s.op != skip) s.text,
      ].join();
      expect(side(TextDiffOp.insert), a);
      expect(side(TextDiffOp.delete), b);
    });
  });

  group('Given two Slides text bodies', () {
    test('when diffed then their plain texts are compared', () {
      final d = TextDiff.ofBodies(
        deltaOf('Revenue up'),
        deltaOf('Revenue down'),
      );

      expect(d.last, (op: TextDiffOp.insert, text: 'down'));
      expect(d.first, (op: TextDiffOp.equal, text: 'Revenue '));
    });
  });
}
