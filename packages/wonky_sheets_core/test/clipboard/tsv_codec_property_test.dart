@Tags(['property'])
library;

import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/clipboard/clipboard.dart';

String _field(Random r) {
  const alphabet = [
    'a',
    'Z',
    '1',
    ' ',
    '\t',
    '\n',
    '\r\n',
    '"',
    'é',
    '😀',
    ',',
  ];
  final n = r.nextInt(6);
  return [
    for (var i = 0; i < n; i++) alphabet[r.nextInt(alphabet.length)],
  ].join();
}

void main() {
  group('Given random tables with tabs, quotes and line breaks', () {
    for (var seed = 1; seed <= 200; seed++) {
      test(
        'when encoding and parsing (seed $seed) then the table round-trips',
        () {
          final r = Random(seed);
          final cols = 1 + r.nextInt(4);
          final rows = [
            for (var i = 0; i < 1 + r.nextInt(5); i++)
              [for (var j = 0; j < cols; j++) _field(r)],
          ];
          // A last row of empty fields encodes as an empty line, which parses
          // as no row (Google Sheets behaves the same).
          if (rows.last.every((f) => f.isEmpty) && cols == 1) {
            rows.last[0] = 'x';
          }
          expect(TsvCodec.parse(TsvCodec.encode(rows)), rows);
        },
      );
    }
  });
}
