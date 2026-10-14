import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards suite 12 §2.1 / Sheets 02 S8: every synced update names its
/// columns. A whole-row write (`update`, `updateRow`, `upsert`, `upsertRow`)
/// records every field as written, so a concurrent edit of another field on
/// another device would be overwritten. Updates go through
/// `updateWhere`/`updateById` with `columnValues` (toptap pattern).
void main() {
  final roots = [
    Directory('lib/features/sync'),
    Directory('lib/features/model'),
    // The shared table codec the writer uses.
    Directory('../packages/wonky_sync_models/lib/src/tables'),
  ];
  final files = [
    for (final root in roots)
      if (root.existsSync())
        for (final f in root.listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart')) f,
  ];
  final wholeRow = RegExp(r'\.(update|updateRow|upsert|upsertRow)(<[^>]*>)?\(');
  final namedUpdate = RegExp(r'\.(updateWhere|updateById)(<[^>]*>)?\(');

  test(
    'when scanning the Sheets data layer then no update writes whole rows',
    () {
      final offending = <String>[];
      for (final f in files) {
        final lines = f.readAsLinesSync();
        for (final (i, line) in lines.indexed) {
          final code = line.split('//').first;
          if (wholeRow.hasMatch(code)) {
            offending.add('${f.path}:${i + 1}: $line');
          }
        }
      }
      expect(offending, isEmpty, reason: 'Whole-row writes found');
    },
  );

  test('when scanning the Sheets data layer then every updateWhere/updateById '
      'passes columnValues', () {
    final offending = <String>[];
    var calls = 0;
    for (final f in files) {
      final source = f.readAsStringSync();
      for (final m in namedUpdate.allMatches(source)) {
        calls++;
        // The argument list up to the matching parenthesis.
        var depth = 0;
        var end = m.end - 1;
        for (; end < source.length; end++) {
          final ch = source[end];
          if (ch == '(') depth++;
          if (ch == ')' && --depth == 0) break;
        }
        final args = source.substring(m.end, end);
        if (!args.contains('columnValues')) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          offending.add('${f.path}:$line');
        }
      }
    }
    expect(offending, isEmpty, reason: 'Updates without columnValues');
    expect(calls, greaterThan(0), reason: 'Sanity check: files were read');
  });
}
