import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

void main() {
  group('Given fuzzy matching', () {
    test('when the query is a subsequence then it matches with indices', () {
      final m = Fuzzy.match('nf', 'New folder')!;
      expect(m.indices, [0, 4]);
    });

    test('when characters are out of order then it does not match', () {
      expect(Fuzzy.match('fn', 'New'), isNull);
    });

    test('when ranking then prefix matches come before scattered ones', () {
      final ranked = Fuzzy.rank('bold', [
        'Insert table of contents with bullets of lists dots',
        'Bold',
        'Toggle bold text',
      ], (s) => [s]);
      expect(ranked.first, 'Bold');
      expect(ranked[1], 'Toggle bold text');
    });

    test('when matching menu paths then word starts are preferred', () {
      final a = Fuzzy.match('ftb', 'Format › Text › Bold')!;
      expect(a.indices, [0, 9, 16]);
    });

    test('when the query is empty then everything matches in order', () {
      expect(Fuzzy.rank('', ['b', 'a'], (s) => [s]), ['b', 'a']);
    });

    test('when only a secondary field matches then the item is kept with a '
        'lower weight', () {
      final ranked = Fuzzy.rank('undo', [
        ('History', ['History', 'undo list']),
        ('Undo', ['Undo']),
      ], (e) => e.$2);
      expect(ranked.map((e) => e.$1), ['Undo', 'History']);
    });
  });
}
