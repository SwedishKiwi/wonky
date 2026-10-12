import 'dart:convert';
import 'dart:math';
import 'package:wonky_write_core/testing.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

void main() {
  const rewriter = SuggestionRewriter();
  final random = Random(1);
  for (var run = 0; run < 1500; run++) {
    final gen = DeltaGen(
      random,
      options: const DeltaGenOptions(embeds: false, mentions: false),
    );
    final edits = EditGen(random, deltaGen: gen);
    var doc = gen.document();
    for (var i = 0; i < 2; i++) {
      final other = SuggestionContext(
        userUuid: 'u${2 + i}',
        nowMs: 10 + i,
        suggestionId: 'p$i',
      );
      final c = edits.change(doc);
      doc = WonkyOt.apply(doc, rewriter.rewrite(doc, c, other));
      doc = const WonkyDeltaNormalizer().normalize(doc).document;
    }
    final change = edits.change(doc);
    final s = rewriter.rewrite(
      doc,
      change,
      SuggestionContext(userUuid: 'u1', nowMs: 1000 + run, suggestionId: 'S'),
    );
    final after = const WonkyDeltaNormalizer()
        .normalize(WonkyOt.apply(doc, s))
        .document;
    final a1 = DeltaUtils.text(SuggestionView.accepted(after));
    final a2 = DeltaUtils.text(
      SuggestionView.accepted(
        const WonkyDeltaNormalizer()
            .normalize(WonkyOt.apply(doc, change))
            .document,
      ),
    );
    if (a1 != a2) {
      print('run $run');
      print('doc: ${jsonEncode(doc.toJson())}');
      print('change: ${jsonEncode(change.toJson())}');
      print('S: ${jsonEncode(s.toJson())}');
      print(jsonEncode(a1));
      print(jsonEncode(a2));
      break;
    }
  }
}
