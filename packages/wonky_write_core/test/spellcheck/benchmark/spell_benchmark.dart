// Spellcheck benchmark (not a test; run manually):
//
//   dart run test/spellcheck/benchmark/spell_benchmark.dart
//
// Reports parse time per shipped dictionary, the worst overshoot of
// `HunspellDictionaryLoader.step(8 ms)`, average `check` time on ~10k words
// of English text (the repo's specs) and average `suggest` time.
import 'dart:io';

import 'package:wonky_write_core/spellcheck.dart';

import '../support/dictionaries.dart';

void main() {
  final root = findWorkspaceRoot();
  if (root == null) {
    stderr.writeln('Workspace root not found');
    exitCode = 1;
    return;
  }
  for (final entry in shippedDictionaryIndex()) {
    final tag = entry['tag']! as String;
    final (aff, dic) = readShippedDictionary(tag);
    // Warm-up parse, then measure.
    HunspellDictionary.parse(aff, dic);
    final sw = Stopwatch()..start();
    HunspellDictionary.parse(aff, dic);
    final parseMs = sw.elapsedMilliseconds;

    final loader = HunspellDictionaryLoader(aff, dic);
    var steps = 0;
    var worstUs = 0;
    var done = false;
    while (!done) {
      final s = Stopwatch()..start();
      done = loader.step(const Duration(milliseconds: 8));
      final us = s.elapsedMicroseconds;
      if (us > worstUs) worstUs = us;
      steps++;
    }
    stdout.writeln(
      '$tag: parse ${parseMs}ms, ${loader.result.wordCount} roots, '
      'step(8ms) x$steps worst ${(worstUs / 1000).toStringAsFixed(2)}ms',
    );
  }

  final dict = loadShippedDictionary('en-US');
  final checker = SpellChecker(dict);
  final tokenizer = SpellTokenizer(wordChars: dict.wordChars);
  final words = <String>[];
  final specs =
      Directory('${root.path}/specs')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in specs) {
    for (final t in tokenizer.tokenize(f.readAsStringSync())) {
      words.add(t.word);
      if (words.length >= 10000) break;
    }
    if (words.length >= 10000) break;
  }
  // Warm up the JIT.
  for (final w in words) {
    checker.check(w);
  }
  final sw = Stopwatch()..start();
  var wrong = 0;
  final misspelled = <String>[];
  for (final w in words) {
    if (!checker.check(w)) {
      wrong++;
      if (misspelled.length < 200) misspelled.add(w);
    }
  }
  final checkUs = sw.elapsedMicroseconds / words.length;
  stdout.writeln(
    'en-US check: ${words.length} words, ${checkUs.toStringAsFixed(2)}us/word, '
    '$wrong flagged',
  );
  final sample = misspelled.toSet().take(50).toList();
  sw
    ..reset()
    ..start();
  for (final w in sample) {
    checker.suggest(w);
  }
  stdout.writeln(
    'en-US suggest (50ms budget): ${sample.length} words, '
    '${(sw.elapsedMicroseconds / sample.length / 1000).toStringAsFixed(1)}ms/word',
  );
  stdout.writeln('flagged sample: ${sample.take(40).join(' ')}');
}
