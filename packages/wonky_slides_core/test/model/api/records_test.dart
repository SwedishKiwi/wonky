import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  group('Given a column map of every model table', () {
    test('when building records then each table gets its record class', () {
      final expected = {
        SlidesTables.deck: isA<DeckRec>(),
        SlidesTables.deckTheme: isA<DeckThemeRec>(),
        SlidesTables.slideMaster: isA<SlideMasterRec>(),
        SlidesTables.slideLayout: isA<SlideLayoutRec>(),
        SlidesTables.slideGroup: isA<SlideGroupRec>(),
        SlidesTables.slide: isA<SlideRec>(),
        SlidesTables.slideElement: isA<SlideElementRec>(),
        SlidesTables.slideTableAxis: isA<SlideTableAxisRec>(),
        SlidesTables.slideTableCell: isA<SlideTableCellRec>(),
        SlidesTables.slideBuild: isA<SlideBuildRec>(),
        SlidesTables.codeState: isA<CodeStateRec>(),
        SlidesTables.chartLink: isA<ChartLinkRec>(),
        SlidesTables.deckChangeLog: isA<GenericSlidesRecord>(),
      };
      for (final MapEntry(key: table, value: matcher) in expected.entries) {
        final r = slidesRecordFromColumns(table, {'id': 'r1'});
        expect(r, matcher, reason: table);
        expect(r.table, table);
      }
    });

    test('when a record is built from a partial map then it holds every '
        'column of its table, missing ones as null', () {
      final r = slidesRecordFromColumns(SlidesTables.slide, {
        'id': 's1',
        'sortKey': 'a0',
      });

      expect(r.columns.keys.toSet(), SlidesTables.columns[SlidesTables.slide]);
      expect(r['notes'], isNull);
      expect(r.toColumns()['sortKey'], 'a0');
    });
  });

  group('Given an element row', () {
    final e = SlideElementRec({
      'id': 'e1',
      'slideId': 's1',
      'kind': 'shape',
      'x': 10,
      'y': 20.5,
      'width': 100.0,
      'height': 50.0,
      'flipH': 1,
      'zKey': 'a1',
      'placeholderType': 'title',
      'createdAt': '2026-10-01T12:00:00Z',
    });

    test('when reading typed getters then numbers, flags, enums and dates '
        'are converted', () {
      expect(e.kind, ElementKind.shape);
      expect(e.ownerId, 's1');
      expect(e.ownerKind, ElementOwnerKind.slide);
      expect(e.frame, isA<SuRect>().having((r) => r.x, 'x', 10.0));
      expect(e.flipH, isTrue);
      expect(e.flipV, isFalse);
      expect(e.placeholderType, SlidePlaceholderType.title);
      expect(e.isPlaceholder, isTrue);
      expect(e.createdAt, DateTime.utc(2026, 10, 1, 12));
    });

    test('when applying withColumns then a new record of the same class '
        'with the update is returned', () {
      final moved = e.withColumns({'x': 30.0});

      expect(moved, isA<SlideElementRec>().having((r) => r.x, 'x', 30.0));
      expect(e.x, 10.0);
      expect(moved.id, 'e1');
    });

    test('when a placeholder instance inherits its frame then frame is '
        'null', () {
      final inst = e.withColumns({'x': null}) as SlideElementRec;

      expect(inst.frame, isNull);
    });
  });

  group('Given a deck row without optional values', () {
    final d = DeckRec({'id': 'd1', 'title': 'Q3'});

    test('when reading it then the schema defaults apply', () {
      expect(d.width, 1920);
      expect(d.height, 1080);
      expect(d.sizePreset, SlideSizeKind.widescreen16x9);
      expect(d.appearance, SlideAppearance.light);
      expect(d.hideNumberOnTitle, isTrue);
      expect(d.firstSlideNumber, 1);
    });
  });
}
