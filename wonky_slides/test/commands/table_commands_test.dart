import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/commands/table_commands.dart' show borderWrites;
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/elements/table/table_cells.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';

import '../harness/deck_harness.dart';

void main() {
  late DeckBuilder b;
  late String slide, table;
  late List<String> rows, cols;
  late DeckHarness d;

  setUp(() {
    b = DeckBuilder(title: 'Tables');
    slide = b.slide(layoutKey: 'blank');
    (table, rows, cols) = b.table(slide, rows: 3, cols: 3);
    b.cell(table, rows[0], cols[0], 'A1');
    b.cell(table, rows[1], cols[1], 'B2');
    d = DeckHarness.open(fixture: b);
    d.editor.setCurrentSlide(slide);
    selectionOf(d.editor).select([table]);
  });
  tearDown(() => d.dispose());

  TableIndex ix() => d.model.indexes.table(table);
  TableCellSelection cells() => TableCellSelection.of(d.editor);

  Future<CommandResult> agent(String id, Map<String, Object?> args) =>
      d.h.invoke(id, args, InvocationSource.mcp);

  Future<CommandResult> roundTrip(String id, Map<String, Object?> args) async {
    final before = d.model.dump();
    final steps = d.undoLabels.length;
    final r = await d.run(id, args);
    expect(r.status, CommandStatus.ok, reason: '$id: ${r.message}');
    final after = d.model.dump();
    expect(after, isNot(equals(before)), reason: '$id changed nothing');
    expect(d.undoLabels.length, steps + 1, reason: '$id: one undo step');
    await d.undo();
    expect(d.model.dump(), before, reason: '$id undo');
    await d.redo();
    expect(d.model.dump(), after, reason: '$id redo');
    return r;
  }

  group('Given Insert › Table', () {
    test('when a 2 × 4 table is inserted then it is 80 % of the slide wide, '
        'centered, has a header row and is selected', () async {
      d.editor.setCurrentSlide(slide);
      final r = await roundTrip('slides.insert.table', {'rows': 2, 'cols': 4});
      final id = (r.data! as Map)['elementId'] as String;
      final e = d.model.element(id)!;
      expect(e.kind, ElementKind.table);
      expect(e.width, 1536);
      expect(e.x, 192);
      final t = d.model.indexes.table(id);
      expect((t.rows.length, t.columns.length), (2, 4));
      final data = jsonDecode(e.str(ElementCols.dataJson)!) as Map;
      expect(data['style'], 'theme');
      expect((data['options'] as Map)['headerRow'], true);
      expect(d.editor.selectedElementIds, [id]);
    });

    test('when the size is out of range then it is refused', () async {
      final r = await agent('slides.insert.table', {'rows': 51, 'cols': 2});
      expect(r.status, CommandStatus.failed);
    });
  });

  group('Given rows and columns', () {
    test('when a row is inserted below the selected cell then it lands '
        'after it', () async {
      cells().selectAt(table, 0, 0);
      await roundTrip('slides.table.insertRow', {'below': true});
      expect(ix().rows.length, 4);
      expect(ix().rows[0].id, rows[0]);
      expect(ix().rows[2].id, rows[1]);
    });

    test(
      'when a column is inserted left of the selection then it is first',
      () async {
        cells().selectAt(table, 1, 0);
        await roundTrip('slides.table.insertColumn', {'right': false});
        expect(ix().columns.length, 4);
        expect(ix().columns[1].id, cols[0]);
      },
    );

    test(
      'when the selected rows are deleted then their cells go too',
      () async {
        cells().selectAt(table, 1, 0);
        cells().selectAt(table, 1, 2, extend: true);
        await roundTrip('slides.table.deleteRows', {});
        expect(ix().rows.map((r) => r.id), [rows[0], rows[2]]);
        expect(ix().cell(rows[1], cols[1]), isNull);
      },
    );

    test('when every column is deleted then the table is deleted', () async {
      await roundTrip('slides.table.deleteColumns', {
        'row': 0,
        'column': 0,
        'colSpan': 3,
      });
      expect(d.model.element(table), isNull);
    });

    test('when rows are deleted without a cell selection then the command '
        'is disabled with a reason', () {
      final st = d.services.dispatcher.stateOf('slides.table.deleteRows');
      expect(st.enabled, isFalse);
      expect(st.disabledReason, 'Select table cells');
    });

    test('when rows are distributed then they get the same height', () async {
      await agent('slides.table.resizeAxes', {
        'id': table,
        'sizes': {rows[0]: 40.0, rows[1]: 200.0},
      });
      await roundTrip('slides.table.distributeRows', {});
      final sizes = {for (final r in ix().rows) r.size};
      expect(sizes, hasLength(1));
    });

    test('when columns are resized by sizes then they round-trip', () async {
      await roundTrip('slides.table.resizeAxes', {
        'id': table,
        'sizes': {cols[0]: 100.0, cols[1]: 500.0, cols[2]: 200.0},
      });
      expect(ix().columns[1].size, 500);
      await roundTrip('slides.table.distributeColumns', {});
      final w = ix().columns.map((c) => c.size!).toList();
      expect(w.every((x) => (x - w.first).abs() < 0.01), isTrue);
    });
  });

  group('Given merges', () {
    test('when a 2 × 2 range is merged then the origin spans it; unmerge '
        'splits it', () async {
      cells().selectAt(table, 0, 0);
      cells().selectAt(table, 1, 1, extend: true);
      await roundTrip('slides.table.mergeCells', {});
      final m = ix().merges.single;
      expect((m.row, m.column, m.rowSpan, m.colSpan), (0, 0, 2, 2));
      // The selection now covers the merge as one cell.
      expect(cells().range!.isSingleCell(ix()), isTrue);
      expect(
        d.services.dispatcher.stateOf('slides.table.mergeCells').enabled,
        isFalse,
      );
      await roundTrip('slides.table.unmergeCells', {});
      expect(ix().merges, isEmpty);
    });

    test('when a range cuts a merge then it grows to cover it', () async {
      await agent('slides.table.mergeCells', {
        'id': table,
        'row': 0,
        'column': 1,
        'rowSpan': 2,
        'colSpan': 2,
      });
      final r = TableRange.spanning(ix(), 1, 0, 1, 1);
      expect((r.r0, r.c0, r.r1, r.c1), (0, 0, 1, 2));
    });
  });

  group('Given cell formatting', () {
    test('when the selected cells get a fill then only they change', () async {
      cells().selectAt(table, 2, 0);
      cells().selectAt(table, 2, 2, extend: true);
      await roundTrip('slides.table.setCellFill', {'color': 'theme:accent2'});
      expect(ix().cell(rows[2], cols[1])!.fill, 'theme:accent2');
      expect(ix().cell(rows[1], cols[1])!.fill, isNull);
      await roundTrip('slides.table.setCellFill', {'none': true});
      expect(ix().cell(rows[2], cols[1]), isNull);
    });

    test('when outer borders are set on the whole table then only edge cells '
        'get them', () async {
      await roundTrip('slides.table.setBorders', {
        'edges': 'outer',
        'width': 2,
        'color': '#FF0000',
      });
      final center = ix().cell(rows[1], cols[1])!;
      expect(center.str(TableCellCols.borderTop), isNull);
      expect(
        ix().cell(rows[0], cols[0])!.str(TableCellCols.borderTop),
        '2|solid|#FF0000',
      );
      expect(
        ix().cell(rows[2], cols[2])!.str(TableCellCols.borderRight),
        '2|solid|#FF0000',
      );
    });

    test('when vertical align, padding and options are set then they '
        'round-trip', () async {
      await roundTrip('slides.table.setCellAlign', {'vAlign': 'middle'});
      expect(ix().cell(rows[2], cols[2])!.vAlign, 'middle');
      await roundTrip('slides.table.setCellPadding', {'all': 4});
      expect(ix().cell(rows[0], cols[0])!.padding, '4,4,4,4');
      await roundTrip('slides.table.setOptions', {
        'bandedRows': false,
        'firstColumn': true,
        'style': 'none',
      });
      final data =
          jsonDecode(d.model.element(table)!.str(ElementCols.dataJson)!) as Map;
      expect(data['style'], 'none');
      expect((data['options'] as Map)['firstColumn'], true);
      expect((data['options'] as Map)['bandedRows'], false);
    });

    test(
      'when Delete clears the selected cells then their text goes',
      () async {
        cells().selectAt(table, 0, 0);
        cells().selectAt(table, 1, 1, extend: true);
        await roundTrip('slides.table.clearCells', {});
        expect(ix().cell(rows[0], cols[0]), isNull);
        expect(ix().cell(rows[1], cols[1]), isNull);
      },
    );
  });

  group('Given the cell selection (slidesTable scope)', () {
    test('when arrows, Shift+arrows and Tab are used then the selection '
        'moves, grows and steps in reading order', () async {
      cells().selectAt(table, 0, 0);
      await d.run('slides.table.selectRight');
      expect(cells().focus!.columnId, cols[1]);
      await d.run('slides.table.extendDown');
      expect(cells().range, TableRange(table, 0, 1, 1, 1));
      await d.run('slides.table.nextCell');
      expect(cells().focus, (rowId: rows[1], columnId: cols[2]));
      await d.run('slides.table.nextCell');
      expect(cells().focus, (rowId: rows[2], columnId: cols[0]));
      await d.run('slides.table.previousCell');
      expect(cells().focus, (rowId: rows[1], columnId: cols[2]));
      await d.run('slides.table.clearCellSelection');
      expect(cells().isEmpty, isTrue);
      // View state only.
      expect(d.undoLabels, isEmpty);
    });

    test('when an agent selects cells then the table and range are '
        'selected', () async {
      selectionOf(d.editor).select(const []);
      final r = await agent('slides.table.selectCells', {
        'id': table,
        'row': 1,
        'column': 1,
        'rowSpan': 2,
      });
      expect(r.status, CommandStatus.ok);
      expect(d.editor.selectedElementIds, [table]);
      expect(cells().range, TableRange(table, 1, 1, 2, 1));
    });

    test('when the table is deselected then the cell selection clears', () {
      cells().selectAt(table, 0, 0);
      selectionOf(d.editor).select(const []);
      expect(cells().isEmpty, isTrue);
    });
  });

  group('Given the format painter on cells (03 §9)', () {
    test('when a cell style is painted onto another cell then fill, borders '
        'and text attributes come along in one step', () async {
      await agent('slides.table.setCellFill', {
        'id': table,
        'row': 0,
        'column': 0,
        'color': '#112233',
      });
      await agent('slides.table.setCellAlign', {
        'id': table,
        'row': 0,
        'column': 0,
        'vAlign': 'bottom',
      });
      cells().selectAt(table, 0, 0);
      await d.run('slides.format.paintFormat');
      cells().selectAt(table, 1, 1);
      await roundTrip('slides.format.paintFormat', {
        'targetIds': [table],
      });
      final c = ix().cell(rows[1], cols[1])!;
      expect(c.fill, '#112233');
      expect(c.vAlign, 'bottom');
      expect(ix().cell(rows[2], cols[2]), isNull);
    });
  });

  group('Given the border picker edges (03 §6.6)', () {
    test(
      'when inner borders are written then shared edges are written once',
      () {
        final r = TableRange.all(ix())!;
        final writes = borderWrites(ix(), r, 'inner', '1|solid|#000000');
        final cols0 = writes.map((w) => w.columns.keys.toSet()).toList();
        // 3×3: 6 inner horizontal (rows 1–2) + 6 inner vertical (cols 1–2).
        final n = cols0.fold<int>(0, (a, s) => a + s.length);
        expect(n, 12);
        expect(
          writes.any(
            (w) =>
                w.rowId == rows[0] &&
                w.columns.containsKey(TableCellCols.borderTop),
          ),
          isFalse,
        );
      },
    );

    test('when all borders are written then every cell edge is covered', () {
      final r = TableRange.all(ix())!;
      final writes = borderWrites(ix(), r, 'all', '1|solid|#000000');
      final n = writes.fold<int>(0, (a, w) => a + w.columns.length);
      // 9 tops + 9 lefts + 3 bottoms + 3 rights.
      expect(n, 24);
    });
  });

  group('Given random table edits (property)', () {
    for (final seed in [1, 2, 3]) {
      test('when 30 random structure and cell ops run (seed $seed) then no '
          'merges overlap and undoing them all returns to the start', () async {
        final rnd = math.Random(seed);
        final start = d.model.dump();
        var applied = 0;
        for (var i = 0; i < 30; i++) {
          final t = ix();
          final nr = t.rows.length, nc = t.columns.length;
          final r = rnd.nextInt(nr), c = rnd.nextInt(nc);
          final (id, args) = switch (rnd.nextInt(8)) {
            0 => (
              'slides.table.insertRow',
              {'row': r, 'below': rnd.nextBool()},
            ),
            1 => (
              'slides.table.insertColumn',
              {'column': c, 'right': rnd.nextBool()},
            ),
            2 => ('slides.table.deleteRows', {'row': r, 'column': 0}),
            3 => ('slides.table.deleteColumns', {'row': 0, 'column': c}),
            4 => (
              'slides.table.mergeCells',
              {
                'row': r,
                'column': c,
                'rowSpan': 1 + rnd.nextInt(math.max(1, nr - r)),
                'colSpan': 1 + rnd.nextInt(math.max(1, nc - c)),
              },
            ),
            5 => ('slides.table.unmergeCells', {'row': 0, 'column': 0}),
            6 => (
              'slides.table.setCellFill',
              {'row': r, 'column': c, 'color': '#00FF00'},
            ),
            _ => (
              'slides.table.setBorders',
              {'row': r, 'column': c, 'edges': 'all'},
            ),
          };
          if (d.model.element(table) == null) break;
          if (!d.services.dispatcher.stateOf(id, {
            'id': table,
            ...args,
          }).enabled) {
            continue;
          }
          final res = await agent(id, {'id': table, ...args});
          if (res.status == CommandStatus.ok) applied++;
          if (d.model.element(table) == null) break;
          final merges = ix().merges;
          for (final a in merges) {
            for (final b2 in merges) {
              if (!identical(a, b2)) expect(a.overlaps(b2), isFalse);
            }
          }
          expect(ix().overlapping, isEmpty);
        }
        expect(applied, greaterThan(0));
        for (var i = 0; i < applied; i++) {
          await d.undo();
        }
        expect(d.model.dump(), start);
      });
    }
  });
}
