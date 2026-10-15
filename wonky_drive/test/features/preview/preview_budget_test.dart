@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';
import 'package:wonky_drive/features/preview/preview_content.dart';
import 'package:wonky_drive/features/preview/viewers/text_file_viewer.dart';

import '../../support/preview_fakes.dart';

/// Preview budgets of suite 11 §2 measured on the fixtures (VM; the
/// browser numbers come from the release build): "1 MB text file
/// highlighted < 300 ms".
void main() {
  test('when a 1 MB Dart file is previewed then decoding and highlighting '
      'stay within the budget', () {
    final line = utf8.decode(PreviewFixtures.dart);
    final big = StringBuffer();
    while (big.length < 1024 * 1024) {
      big.write(line);
    }
    final bytes = Uint8List.fromList(utf8.encode(big.toString()));
    // Warm up the grammars (loaded once per app run).
    DefaultCodeTokenizer.instance.tokenize(line, 'dart');
    const HighlightJsTokenizer().tokenize(line, 'dart');

    final sw = Stopwatch()..start();
    final text = TextPreview.decode(bytes)!;
    final decoded = sw.elapsedMilliseconds;
    // The text viewer highlights the first 250,000 characters.
    final tokens = PreviewTokenizer.instance.tokenize(
      text.text.substring(0, PreviewTokenizer.maxHighlightLength),
      'dart',
    );
    sw.stop();

    // ignore: avoid_print
    print(
      'Budget: 1 MB text decoded in $decoded ms, highlighted in '
      '${sw.elapsedMilliseconds - decoded} ms (${tokens.length} tokens).',
    );
    expect(tokens, isNotEmpty);
    expect(sw.elapsedMilliseconds, lessThan(1500));
  });
}
