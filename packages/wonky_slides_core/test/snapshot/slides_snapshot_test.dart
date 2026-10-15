import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:test/test.dart';
import 'package:wonky_slides_core/history.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';

final _at = DateTime.utc(2026, 10, 15, 9, 30);

List<int> _gzip(String text) => const GZipEncoder().encode(utf8.encode(text));

void main() {
  group('Given a deck with groups, nested elements, a table and builds', () {
    late DeckBuilder b;
    late DeckModel model;
    late String groupEl;
    late String child;

    setUp(() {
      b = DeckBuilder();
      final g = b.group('Intro', color: 'blue');
      final s1 = b.slide(groupId: g, title: 'Hello', notes: 'Say hi');
      // A child listed before its group: the codec puts the group first.
      groupEl = b.ids.newId();
      child = b.shape(s1, text: 'Inside', parentId: groupEl);
      b.elementGroup(s1, groupId: groupEl);
      final s2 = b.slide(title: 'Numbers');
      final (t, rows, cols) = b.table(s2);
      b.cell(t, rows.first, cols.first, 'A1');
      b.build_(s2, t);
      model = b.build();
    });

    test('when encoded and decoded then every row comes back unchanged', () {
      final bytes = SlidesSnapshotCodec.encodeModel(model, capturedAt: _at);

      final snapshot = SlidesSnapshotCodec.decode(bytes);

      expect(snapshot.header.deckId, model.deckId);
      expect(snapshot.header.capturedAt, _at);
      expect(snapshot.toModel().dump(), model.dump());
    });

    test('when encoded then the header counts rows per table', () {
      final snapshot = SlidesSnapshotCodec.decode(
        SlidesSnapshotCodec.encodeModel(model, capturedAt: _at),
      );

      expect(snapshot.header.counts[SlidesTables.slide], 2);
      expect(snapshot.header.counts[SlidesTables.slideTableCell], 1);
      expect(
        snapshot.header.counts[SlidesTables.slideElement],
        model.count(SlidesTables.slideElement),
      );
    });

    test('when encoded then tables come in dependency order and a group '
        'element before its children', () {
      final rows = SlidesSnapshotCodec.decode(
        SlidesSnapshotCodec.encodeModel(model, capturedAt: _at),
      ).rows;

      final ranks = [for (final (t, _) in rows) SlidesTables.rank(t)];
      expect(ranks, orderedEquals([...ranks]..sort()));
      final ids = [
        for (final (t, c) in rows)
          if (t == SlidesTables.slideElement) c[SlidesCols.id],
      ];
      expect(ids.indexOf(groupEl), lessThan(ids.indexOf(child)));
    });

    test('when change-log rows are given then they are not stored', () {
      final bytes = SlidesSnapshotCodec.encode(
        [
          ...b.rows,
          (
            SlidesTables.deckChangeLog,
            {SlidesCols.id: 'log-1', SlidesCols.label: 'Edit'},
          ),
        ],
        deckId: b.deckId,
        capturedAt: _at,
      );

      final snapshot = SlidesSnapshotCodec.decode(bytes);

      expect(snapshot.table(SlidesTables.deckChangeLog), isEmpty);
      expect(snapshot.header.counts, isNot(contains('deck_change_log')));
    });

    test('when read by table then rows are keyed by id', () {
      final snapshot = SlidesSnapshotCodec.decode(
        SlidesSnapshotCodec.encodeModel(model, capturedAt: _at),
      );

      final byTable = snapshot.byTable();

      expect(byTable[SlidesTables.slide]!.keys, hasLength(2));
      expect(
        byTable[SlidesTables.slideElement]![child]![SlidesCols.parentId],
        groupEl,
      );
    });
  });

  group('Given snapshot bytes', () {
    test('when they are not gzip then decoding throws a FormatException', () {
      expect(
        () => SlidesSnapshotCodec.decode(utf8.encode('nope')),
        throwsFormatException,
      );
    });

    test('when the header names another format then decoding throws', () {
      final bytes = _gzip(
        '${jsonEncode({'format': 'wonky-sheets-snapshot', 'v': 1})}\n',
      );

      expect(() => SlidesSnapshotCodec.decode(bytes), throwsFormatException);
    });

    test('when the version is newer than supported then decoding throws', () {
      final bytes = _gzip(
        '${jsonEncode({'format': 'wonky-slides-snapshot', 'v': 2, 'deckId': 'd', 'capturedAt': _at.toIso8601String()})}\n',
      );

      expect(() => SlidesSnapshotCodec.decode(bytes), throwsFormatException);
    });

    test('when records use full column names (no key map) then they decode '
        'and dates come back as DateTime', () {
      final bytes = _gzip(
        [
          jsonEncode({
            'format': 'wonky-slides-snapshot',
            'v': 1,
            'deckId': 'd',
            'capturedAt': _at.toIso8601String(),
          }),
          jsonEncode({
            'tb': 'deck',
            'row': {
              'id': 'd',
              'title': 'Plain',
              'createdAt': {r'$d': _at.toIso8601String()},
            },
          }),
        ].join('\n'),
      );

      final snapshot = SlidesSnapshotCodec.decode(bytes);

      expect(snapshot.toModel().deck!.title, 'Plain');
      expect(snapshot.rows.single.$2['createdAt'], _at);
    });
  });
}
