import 'dart:convert';
import 'dart:math';

import 'package:wonky_write_core/testing.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

bool fails(Delta d) {
  const codec = MarkdownCodec();
  final normalized = const WonkyDeltaNormalizer().normalize(d).document;
  final ids = [for (final (_, e) in WonkyDocument(normalized).embeds) e.id];
  var next = 0;
  final md = codec.exportMarkdown(normalized);
  final back = codec.importMarkdown(
    md,
    options: ImportOptions(
      idGenerator: () => next < ids.length ? ids[next++] : 'x${next++}',
    ),
  );
  return canonicalJson(back.delta) != canonicalJson(normalized);
}

Delta shrink(Delta d) {
  var doc = WonkyDocument(const WonkyDeltaNormalizer().normalize(d).document);
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < doc.lines.length; i++) {
      final l = doc.lines[i];
      final cand = DeltaUtils.canonical(
        doc.delta.compose(
          Delta()
            ..retain(l.start)
            ..delete(l.length),
        ),
      );
      if (cand.isNotEmpty && fails(cand)) {
        doc = WonkyDocument(cand);
        changed = true;
        break;
      }
    }
    if (!changed) {
      // try shrinking segments
      for (final l in doc.lines) {
        for (final s in l.segments) {
          if (s.length <= 1) continue;
          for (final cut in [(0, 1), (s.length - 1, 1)]) {
            final cand = DeltaUtils.canonical(
              doc.delta.compose(
                Delta()
                  ..retain(s.start + cut.$1)
                  ..delete(cut.$2),
              ),
            );
            if (fails(cand)) {
              doc = WonkyDocument(cand);
              changed = true;
              break;
            }
          }
          if (changed) break;
        }
        if (changed) break;
      }
    }
  }
  return doc.delta;
}

void main(List<String> args) {
  final seed = int.parse(args.isEmpty ? '1' : args[0]);
  final runs = int.parse(args.length > 1 ? args[1] : '400');
  final r = Random(seed);
  var failures = 0;
  for (var i = 0; i < runs; i++) {
    final d = DeltaGen(r).document();
    if (fails(d)) {
      failures++;
      if (failures <= 3) {
        final m = shrink(d);
        const codec = MarkdownCodec();
        final md = codec.exportMarkdown(m);
        print('--- run $i minimal: ${jsonEncode(m.toJson())}');
        print('md: ${jsonEncode(md)}');
        print('back: ${jsonEncode(codec.importMarkdown(md).delta.toJson())}');
      }
    }
  }
  print('failures: $failures / $runs');
}
