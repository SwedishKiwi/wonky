import 'package:test/test.dart';
import 'package:wonky_core/diff.dart';

String _render(List<DiffLine> d) => d.map((l) => l.toString()).join('\n');

void main() {
  group('Given two texts', () {
    test('when lines change then the diff is minimal', () {
      final d = LineDiff.diff('a\nb\nc\nd', 'a\nx\nc\nd\ne');
      expect(_render(d), '  a\n- b\n+ x\n  c\n  d\n+ e');
      expect(d[2].newLine, 2);
      expect(d[1].oldLine, 2);
    });

    test('when the texts are equal then every line is equal', () {
      final d = LineDiff.diff('a\nb', 'a\nb');
      expect(d.every((l) => l.op == DiffOp.equal), isTrue);
    });

    test('when one side is empty then all lines are inserted or deleted', () {
      expect(LineDiff.diff('', 'a\nb').map((l) => l.op), [
        DiffOp.insert,
        DiffOp.insert,
      ]);
      expect(LineDiff.diff('a', '').single.op, DiffOp.delete);
    });

    test('when lines move then the edit script reproduces the new text', () {
      const a = 'one\ntwo\nthree\nfour\nfive\nsix';
      const b = 'zero\none\nthree\ntwo\nfive\nsix\nseven';
      final d = LineDiff.diff(a, b);
      final rebuilt = [
        for (final l in d)
          if (l.op != DiffOp.delete) l.text,
      ].join('\n');
      final old = [
        for (final l in d)
          if (l.op != DiffOp.insert) l.text,
      ].join('\n');
      expect(rebuilt, b);
      expect(old, a);
    });
  });

  group('Given a three-way merge', () {
    const base = 'a\nb\nc\nd\ne';

    test('when the sides change different lines then both apply', () {
      final r = LineDiff.merge3(base, 'a\nB\nc\nd\ne', 'a\nb\nc\nD\ne');
      expect(r.text, 'a\nB\nc\nD\ne');
      expect(r.hasConflicts, isFalse);
    });

    test('when both sides make the same change then it applies once', () {
      final r = LineDiff.merge3(base, 'a\nX\nc\nd\ne', 'a\nX\nc\nd\ne');
      expect(r.text, 'a\nX\nc\nd\ne');
      expect(r.hasConflicts, isFalse);
    });

    test('when both sides change the same line then a conflict is marked', () {
      final r = LineDiff.merge3(base, 'a\nmine\nc\nd\ne', 'a\ntheirs\nc\nd\ne');
      expect(
        r.text,
        'a\n<<<<<<< yours\nmine\n=======\ntheirs\n>>>>>>> theirs\nc\nd\ne',
      );
      expect(r.conflictLines, [2]);
    });

    test(
      'when one side inserts and the other deletes elsewhere then both apply',
      () {
        final r = LineDiff.merge3(base, 'a\nb\nnew\nc\nd\ne', 'a\nb\nc\ne');
        expect(r.text, 'a\nb\nnew\nc\ne');
      },
    );

    test('when only one side changed then its text wins', () {
      expect(LineDiff.merge3(base, base, 'x').text, 'x');
      expect(LineDiff.merge3(base, 'y', base).text, 'y');
    });
  });
}
