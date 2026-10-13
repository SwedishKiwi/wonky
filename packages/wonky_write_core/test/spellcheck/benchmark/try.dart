import 'dart:io';

import 'package:wonky_write_core/spellcheck.dart';

import '../support/dictionaries.dart';

void main(List<String> args) {
  final tag = args.first;
  final sw = Stopwatch()..start();
  final d = loadShippedDictionary(tag);
  print('parse $tag: ${sw.elapsedMilliseconds} ms, ${d.wordCount} roots');
  final c = SpellChecker(d);
  final words = args.length > 1
      ? args.skip(1)
      : File(args[1]).readAsLinesSync();
  for (final w in words) {
    final s = Stopwatch()..start();
    final ok = c.check(w);
    final t1 = s.elapsedMicroseconds;
    final sug = c.suggest(w, budget: const Duration(seconds: 5));
    print('$w: $ok (${t1}us) [${sug.join(', ')}] (${s.elapsedMilliseconds} ms)');
  }
}
