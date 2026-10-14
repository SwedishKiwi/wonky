@Tags(['property'])
library;

import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';

const _alphabet = 'ab ,;"\t\r\n€é1.-=';

String _field(Random r) {
  final n = r.nextInt(8);
  return String.fromCharCodes([
    for (var i = 0; i < n; i++)
      _alphabet.codeUnitAt(r.nextInt(_alphabet.length)),
  ]);
}

void main() {
  group('Given random tables', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      test('when encoding and parsing them (seed $seed) then the fields are '
          'unchanged', () {
        final r = Random(seed);
        for (var t = 0; t < 40; t++) {
          final cols = 1 + r.nextInt(5);
          final rows = [
            for (var i = 0; i < 1 + r.nextInt(6); i++)
              [for (var c = 0; c < cols; c++) _field(r)],
          ];
          // A lone empty field is a blank line: give such rows content.
          for (final row in rows) {
            if (row.length == 1 && row.single.isEmpty) row[0] = 'x';
          }
          final text = CsvExporter.encodeRows(rows);
          final parsed = [
            for (final rec in CsvParser.parseAll(text)) rec.fields,
          ];
          expect(parsed, rows, reason: text);
        }
      });
    }
  });
}
