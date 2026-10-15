import 'dart:convert';

import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_models/ids.dart';

/// A rich deck for planner tests: a title slide, two content slides, a
/// group with two slides, shapes, a text box, an element group with two
/// children, a table with cells and a merge, a code block with two states,
/// a linked chart, an image and builds — built with [DeckBuilder] and then
/// completed through the planner itself.
final class PlannerFixture {
  PlannerFixture() {
    final b = DeckBuilder();
    title = b.slide(layoutKey: 'title', title: 'Hello', notes: 'Say hi');
    s2 = b.slide(title: 'Agenda', body: 'One');
    s3 = b.slide(layoutKey: 'blank');
    group = b.group('Part 1', color: 'blue');
    g1 = b.slide(groupId: group, title: 'Inside');
    g2 = b.slide(groupId: group, layoutKey: 'blank');
    shape = b.shape(s3, x: 100, y: 100, width: 300, height: 200, text: 'Box');
    shape2 = b.shape(s3, x: 600, y: 120, width: 300, height: 200);
    text = b.textBox(s3, 'Caption', x: 100, y: 500);
    grp = '00000000-0000-4000-8000-00000000fff1';
    child1 = b.shape(
      s3,
      x: 1000,
      y: 100,
      width: 100,
      height: 100,
      parentId: grp,
    );
    child2 = b.shape(
      s3,
      x: 1200,
      y: 300,
      width: 100,
      height: 100,
      parentId: grp,
    );
    b.elementGroup(s3, groupId: grp, x: 1000, y: 100, width: 300, height: 300);
    final t = b.table(s2, rows: 3, cols: 3, x: 200, y: 600);
    table = t.$1;
    rows = t.$2;
    cols = t.$3;
    b.cell(table, rows[0], cols[0], 'A1');
    b.cell(table, rows[1], cols[1], 'B2');
    build1 = b.build_(s3, shape);
    build2 = b.build_(s3, text);
    layouts = b.themeIds.layoutIds;
    themeId = b.themeIds.themeId;
    masterId = b.themeIds.masterId;
    base = b.rows;

    // Complete through the planner: code, chart, image, merge.
    final deck = session(seed: 900000, complete: false);
    final code = deck.execute(
      InsertElements(s2, const [
        ElementSpec(
          kind: ElementKind.code,
          x: 1000,
          y: 600,
          width: 600,
          height: 300,
          codeStates: [
            {'code': 'void main() {}'},
            {'code': 'void main() {\n  print(1);\n}'},
          ],
        ),
        ElementSpec(
          kind: ElementKind.chart,
          x: 100,
          y: 100,
          width: 500,
          height: 300,
        ),
        ElementSpec(
          kind: ElementKind.image,
          x: 700,
          y: 100,
          width: 400,
          height: 300,
          columns: {
            'dataJson':
                '{"v":1,"src":"wonky-file://00000000-0000-4000-8000-0000000000f1","naturalWidth":800,"naturalHeight":600}',
          },
        ),
      ]),
    );
    final ids = (code.result['elementIds']! as List).cast<String>();
    this.code = ids[0];
    chart = ids[1];
    image = ids[2];
    states = [for (final s in deck.model.codeStatesOf(this.code)) s.id];
    deck.execute(
      LinkChart(
        chart,
        spreadsheetItemUuid: '00000000-0000-4000-8000-0000000000e1',
        chartObjectId: '00000000-0000-4000-8000-0000000000e2',
        snapshot: snapshot('1'),
      ),
    );
    deck.execute(
      MergeCells(
        table,
        rowId: rows[1],
        columnId: cols[1],
        rowSpan: 2,
        colSpan: 2,
      ),
    );
    theme2 =
        deck
                .execute(const ImportTheme(builtInKey: 'midnight'))
                .result['themeId']!
            as String;
    final s2Title = deck.model
        .elementsOf(s2)
        .firstWhere((e) => e.placeholderType == SlidePlaceholderType.title)
        .id;
    deck.execute(UpdateFrames([FrameUpdate(s2Title, x: 50, y: 60)]));
    rowsOf = [
      for (final t in deck.model.dump().entries)
        for (final r in t.value.values) (t.key, r),
    ];
  }

  late final String title, s2, s3, group, g1, g2;
  late final String shape, shape2, text, grp, child1, child2;
  late final String table, code, chart, image, build1, build2;
  late final List<String> rows, cols, states;
  late final Map<String, String> layouts;
  late final String themeId, masterId, theme2;
  late final List<SlidesRow> base;
  late final List<SlidesRow> rowsOf;

  /// A chart snapshot with version [v].
  static ChartSnapshot snapshot(String v) => ChartSnapshot(
    sourceSpecJson: jsonEncode({'v': 1, 'type': 'column', 'rev': v}),
    dataSnapshotJson: jsonEncode({"v": 1, "series": <Object?>[], "rev": v}),
    sourceVersion: v,
    sheetId: '00000000-0000-4000-8000-0000000000e3',
  );

  /// A memory session over the fixture (the base rows before the planner
  /// completed them when [complete] is false).
  MemoryDeck session({
    int seed = 5000,
    String userId = testUserId,
    bool complete = true,
  }) => MemoryDeck(
    model: DeckModel.fromRows(testDeckId, complete ? rowsOf : base),
    userId: userId,
    planner: const SlidesPlanner(),
    ids: SequentialIdGenerator(seed),
  );

  /// The layout id of [key] in the fixture's theme.
  String layout(String key) => layouts[key]!;
}

/// A clipboard payload (03 §12.2) of [kind] built from [model] rows.
Map<String, Object?> clipboardOf(
  DeckModel model, {
  required String kind,
  List<String> slideIds = const [],
  List<String> elementIds = const [],
  String? sourceSlideId,
  bool withThemes = false,
  String sourceDeckId = testDeckId,
}) {
  final elements = <SlideElementRec>[
    for (final s in slideIds) ...model.allElementsOf(s),
  ];
  for (final id in elementIds) {
    final e = model.element(id)!;
    elements.add(e);
    void children(String p) {
      for (final c in model.allElementsOf(e.ownerId!)) {
        if (c.parentId == p) {
          elements.add(c);
          children(c.id);
        }
      }
    }

    children(id);
  }
  final ids = {for (final e in elements) e.id};
  final layoutIds = {for (final s in slideIds) ?model.slide(s)!.layoutId};
  final themeIds = {
    for (final l in layoutIds)
      ?model.master(model.layout(l)!.masterId!)?.themeId,
  };
  return {
    'format': 'wonky-slides-clipboard',
    'v': 1,
    'sourceDeckId': sourceDeckId,
    'sourceItemUuid': sourceDeckId,
    'sourceSlideId': ?sourceSlideId,
    'kind': kind,
    if (withThemes)
      'themes': [
        for (final t in themeIds)
          {
            ...model.theme(t)!.toColumns(),
            'masters': [for (final m in model.mastersOf(t)) m.toColumns()],
            'layouts': [
              for (final m in model.mastersOf(t))
                for (final l in model.layoutsOf(m.id)) l.toColumns(),
            ],
            'elements': [
              for (final m in model.mastersOf(t)) ...[
                for (final e in model.allElementsOf(m.id)) e.toColumns(),
                for (final l in model.layoutsOf(m.id))
                  for (final e in model.allElementsOf(l.id)) e.toColumns(),
              ],
            ],
          },
      ],
    'slides': [for (final s in slideIds) model.slide(s)!.toColumns()],
    'elements': [for (final e in elements) e.toColumns()],
    'tableAxes': [
      for (final id in ids)
        for (final d in TableAxisDimension.values)
          for (final a in model.axesOf(id, d)) a.toColumns(),
    ],
    'tableCells': [
      for (final id in ids)
        for (final c in model.cellsOf(id)) c.toColumns(),
    ],
    'builds': [
      for (final s in slideIds)
        for (final bd in model.buildsOf(s)) bd.toColumns(),
    ],
    'codeStates': [
      for (final id in ids)
        for (final c in model.codeStatesOf(id)) c.toColumns(),
    ],
    'chartLinks': [for (final id in ids) ?model.chartLinkOf(id)?.toColumns()],
  };
}

/// The built-in theme package of [key] as JSON (an `ImportTheme` payload).
Map<String, Object?> themePackageJson(String key) =>
    BuiltInThemes.package(key)!.toJson();

/// Every slide-table column (fixtures of payload slides).
Set<String> get slideColumns => SlidesTables.columns[SlidesTables.slide]!;
