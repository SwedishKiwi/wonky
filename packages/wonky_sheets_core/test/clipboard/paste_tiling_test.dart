import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/addressing/grid_geometry.dart';
import 'package:wonky_sheets_core/src/clipboard/clipboard.dart';

void main() {
  group('Given a 3 × 3 source', () {
    const cases = [
      (GridRect(0, 0, 5, 5), GridRect(0, 0, 5, 5), (2, 2)),
      (GridRect(2, 2, 4, 4), GridRect(2, 2, 4, 4), (1, 1)),
      (GridRect(0, 0, 5, 2), GridRect(0, 0, 5, 2), (2, 1)),
      (GridRect(0, 0, 4, 4), GridRect(0, 0, 2, 2), null),
      (GridRect(1, 1, 1, 1), GridRect(1, 1, 3, 3), null),
    ];
    for (final (selection, target, tiles) in cases) {
      test(
        'when pasting into ${selection.a1} then ${target.a1} is written',
        () {
          expect(PasteTiling.target(3, 3, selection), target);
          expect(PasteTiling.tiles(3, 3, selection), tiles);
        },
      );
    }

    test('when mapping target cells then source cells repeat per tile', () {
      expect(
        PasteTiling.sourceCellFor(
          4,
          5,
          top: 0,
          left: 0,
          sourceRows: 3,
          sourceCols: 3,
        ),
        (1, 2),
      );
    });
  });

  group('Given an empty source', () {
    test('when pasting then only the top-left cell is the target', () {
      expect(
        PasteTiling.target(0, 0, const GridRect(2, 2, 5, 5)),
        const GridRect(2, 2, 2, 2),
      );
      expect(PasteTiling.tiles(0, 3, const GridRect(0, 0, 5, 5)), isNull);
    });
  });
}
