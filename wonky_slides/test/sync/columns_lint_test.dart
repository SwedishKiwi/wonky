import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards Slides 02 P7 (suite 12 §2.1, as Sheets 02 S8): every synced update
/// names its columns. A whole-row write (`update`, `updateRow`, `upsert`,
/// `upsertRow`) records every field as written, so a concurrent edit of
/// another field on another device would be overwritten. Updates go through
/// `updateWhere`/`updateById` with `columnValues` (toptap pattern).
///
/// Covers every Slides writer: the app's data layer (`lib/features/{sync,
/// model}`, SL-9), the server's Slides code (`wonky_server/lib/src/slides`,
/// SL-5/SL-8), the shared table codec and the shared sync client (moved
/// here from `wonky_slides_core` by SL-9, Slides 12 SL-2).
void main() {
  // Client data layers: any whole-row call is suspect (as Sheets' lint).
  final clientRoots = [
    Directory('lib/features/sync'),
    Directory('lib/features/model'),
    // The shared table codec the writers use.
    Directory('../packages/wonky_sync_models/lib/src/tables'),
    // The shared sync client (replica, writer, journal; Drive 05 D-6).
    Directory('../packages/wonky_sync_kit_flutter/lib'),
  ];
  // Server code also uses `Map.update`, so only database calls count there.
  final serverRoots = [Directory('../wonky_server/lib/src/slides')];

  List<File> dartFiles(List<Directory> roots) => [
    for (final root in roots)
      if (root.existsSync())
        for (final f in root.listSync(recursive: true))
          if (f is File && f.path.endsWith('.dart')) f,
  ];

  final clientFiles = dartFiles(clientRoots);

  test('when the lint runs then the Slides data layer is scanned', () {
    expect(
      clientFiles.map((f) => f.path),
      containsAll([
        'lib/features/sync/slides_writer.dart',
        'lib/features/model/synced_deck_session.dart',
      ]),
    );
  });
  final serverFiles = dartFiles(serverRoots);
  final wholeRowClient = RegExp(
    r'\.(update|updateRow|upsert|upsertRow)(<[^>]*>)?\(',
  );
  final wholeRowServer = RegExp(
    r'\.db\s*\.\s*(update|updateRow|upsert|upsertRow)(<[^>]*>)?\(',
  );
  final namedUpdate = RegExp(r'\.(updateWhere|updateById)(<[^>]*>)?\(');

  List<String> wholeRowWrites(List<File> files, RegExp pattern) => [
    for (final f in files)
      for (final (i, line) in f.readAsLinesSync().indexed)
        if (pattern.hasMatch(line.split('//').first))
          '${f.path}:${i + 1}: $line',
  ];

  test('when scanning the Slides writers then no update writes whole rows', () {
    expect(
      [
        ...wholeRowWrites(clientFiles, wholeRowClient),
        ...wholeRowWrites(serverFiles, wholeRowServer),
      ],
      isEmpty,
      reason: 'Whole-row writes found',
    );
  });

  test('when scanning the Slides writers then every updateWhere/updateById '
      'passes columnValues', () {
    final offending = <String>[];
    var calls = 0;
    for (final f in [...clientFiles, ...serverFiles]) {
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

  test('when the lint patterns see whole-row and named writes then they '
      'flag exactly the whole-row ones', () {
    expect(wholeRowClient.hasMatch('await session.db.update(rows);'), isTrue);
    expect(wholeRowClient.hasMatch('Deck.db.updateRow(s, deck)'), isTrue);
    expect(wholeRowServer.hasMatch('session.db.upsert<Slide>(x)'), isTrue);
    expect(wholeRowServer.hasMatch('counts.update(k, (v) => v + 1)'), isFalse);
    expect(
      wholeRowClient.hasMatch('db.updateWhere<Slide>(columnValues: v)'),
      isFalse,
    );
  });
}
