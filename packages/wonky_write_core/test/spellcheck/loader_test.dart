import 'package:test/test.dart';
import 'package:wonky_write_core/spellcheck.dart';

import 'support/dictionaries.dart';

/// A fixture large enough to need many 64-line / 256-line chunks.
String _bigAff() => [
  'SET UTF-8',
  'TRY abcdefghij',
  'PFX P Y 1',
  'PFX P 0 pre .',
  for (var i = 0; i < 100; i++) ...[
    'SFX ${String.fromCharCode(0x100 + i)} Y 1',
    'SFX ${String.fromCharCode(0x100 + i)} 0 s$i .',
  ],
].join('\n');

String _bigDic() => [
  '3000',
  for (var i = 0; i < 3000; i++)
    'w${i.toRadixString(36)}/P${String.fromCharCode(0x100 + i % 100)}',
].join('\n');

const _probes = ['w0', 'prew0s0', 'w1s1', 'w1s2', 'prewabs88', 'wzz', 'w2bs0'];

void main() {
  group('Given an incremental loader', () {
    test('when result is read before parsing is done then it throws', () {
      final loader = HunspellDictionaryLoader(_bigAff(), _bigDic());
      expect(() => loader.result, throwsStateError);
    });

    test('when stepping with a zero budget then every step makes progress '
        'until done', () {
      final loader = HunspellDictionaryLoader(_bigAff(), _bigDic());
      final progress = <double>[loader.progress];
      while (!loader.step(Duration.zero)) {
        progress.add(loader.progress);
      }
      expect(progress.length, greaterThan(10));
      expect([
        for (var i = 1; i < progress.length; i++) progress[i] > progress[i - 1],
      ], everyElement(isTrue));
      expect((loader.isDone, loader.progress), (true, 1.0));
    });

    test('when done then step returns true without more work', () {
      final loader = HunspellDictionaryLoader('', '1\nword');
      while (!loader.step(Duration.zero)) {}
      expect(loader.step(Duration.zero), isTrue);
    });

    test('when parsed step-wise then it checks like a synchronous parse', () {
      final loader = HunspellDictionaryLoader(_bigAff(), _bigDic());
      while (!loader.step(Duration.zero)) {}
      final stepwise = SpellChecker(loader.result);
      final sync = SpellChecker(HunspellDictionary.parse(_bigAff(), _bigDic()));
      expect(
        [for (final w in _probes) stepwise.check(w)],
        [for (final w in _probes) sync.check(w)],
      );
      expect(loader.result.wordCount, 3000);
    });
  });

  group('Given the shipped en-US dictionary', () {
    test('when parsed step-wise then it checks and suggests like a '
        'synchronous parse', () {
      final (aff, dic) = readShippedDictionary('en-US');
      final loader = HunspellDictionaryLoader(aff, dic);
      while (!loader.step(Duration.zero)) {}
      final stepwise = SpellChecker(loader.result);
      final sync = SpellChecker(loadShippedDictionary('en-US'));
      const words = [
        'house',
        'houses',
        'unhappiness',
        'teh',
        'recieve',
        '21st',
      ];
      expect(
        [
          loader.result.wordCount,
          [for (final w in words) stepwise.check(w)],
          stepwise.suggest('teh', budget: const Duration(minutes: 1)),
        ],
        [
          sync.dictionary.wordCount,
          [for (final w in words) sync.check(w)],
          sync.suggest('teh', budget: const Duration(minutes: 1)),
        ],
      );
    });
  }, skip: shippedDictionariesSkipReason);
}
