import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

void main() {
  group('Given a cached tokenizer', () {
    test('when tokenizing the same text twice then the second is a hit with '
        'equal tokens', () {
      final t = CachedCodeTokenizer();

      final a = t.tokenize('final x = 1;', 'dart');
      final b = t.tokenize('final x = 1;', 'dart');

      expect(b, a);
      expect((t.hits, t.misses), (1, 1));
    });

    test('when the language differs then it is a separate entry', () {
      final t = CachedCodeTokenizer();

      t.tokenize('x = 1', 'python');
      t.tokenize('x = 1', 'ruby');

      expect(t.misses, 2);
    });

    test('when the capacity is exceeded then the least recently used entry '
        'is evicted', () {
      final t = CachedCodeTokenizer(capacity: 2);

      t.tokenize('a', 'dart');
      t.tokenize('b', 'dart');
      t.tokenize('a', 'dart'); // a is now the most recent
      t.tokenize('c', 'dart'); // evicts b
      t.tokenize('a', 'dart');
      t.tokenize('b', 'dart');

      expect((t.hits, t.misses), (2, 4));
    });
  });
}
