import 'dart:convert';

import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_models/ids.dart';

import '../model/api/deck_model.dart';
import '../model/api/kinds.dart';
import '../ops/change_summary.dart';
import '../ops/operations.dart';
import '../ops/plan_context.dart';
import '../ops/planner.dart';
import '../planner/slides_planner.dart';
import '../schema/slides_schema.dart';
import '../theme/color/color_ref.dart';
import '../theme/model/box_text_style.dart';
import '../theme/model/common.dart';
import '../theme/model/paint.dart';
import 'template_text.dart';

/// Builds the deck of a built-in template (Slides 04 §15) with the real
/// planner: every slide, group, placeholder text, shape and table is a
/// `SlidesOperation` planned against the growing [model], exactly as if a
/// user had made the deck — so template decks pass maintenance, copy and
/// render like any other deck.
///
/// Placeholder bodies are addressed by the layout's part names (`title`,
/// `subtitle`, `body`, `bodyRight`, `headingLeft`, `bigNumber`, `caption`,
/// `quote`, `attribution`, `label`, `code`, …; `BuiltInLayouts`).
final class TemplateDeckBuilder {
  /// Starts a deck with [CreateDeck] (no first slide).
  TemplateDeckBuilder({
    required String deckId,
    required String title,
    required String themeKey,
    required this.ctx,
    SlideAppearance? appearance,
    this.planner = const SlidesPlanner(),
  }) : model = DeckModel(deckId: deckId) {
    final r = run(
      CreateDeck(
        deckId: deckId,
        title: title,
        themeKey: themeKey,
        appearance: appearance,
        firstLayoutKey: null,
      ),
    );
    themeId = r['themeId']! as String;
  }

  /// The deck being built.
  final DeckModel model;

  /// Ids, author and time of every row.
  final SlidesPlanContext ctx;

  /// The planner.
  final SlidesMutationPlanner planner;

  /// The deck's theme copy.
  late final String themeId;

  /// Planner warnings, prefixed with the operation name.
  final List<String> warnings = [];

  /// Every plan, in order.
  final List<SlidesPlan> plans = [];

  /// Plans [op], applies it to [model] and returns the plan's result.
  Map<String, Object?> run(SlidesOperation op) {
    final plan = planner.plan(op, model, ctx);
    plans.add(plan);
    for (final w in plan.warnings) {
      warnings.add('${op.name}: $w');
    }
    model.applyChanges(plan.changes);
    return plan.result;
  }

  /// The id of layout [key] in the deck's theme copy.
  String layoutId(String key) {
    final id = SlidesIds.themePartId(themeId, 'layout:$key');
    if (model.layout(id) == null) {
      throw ArgumentError.value(key, 'key', 'Unknown layout');
    }
    return id;
  }

  /// The instance of placeholder [name] (a layout part name) on [slideId].
  String placeholder(String slideId, String name) {
    final slide = model.slide(slideId)!;
    final layout = model.layout(slide.layoutId!)!;
    final def = SlidesIds.themePartId(themeId, 'el:${layout.key}/$name');
    final id = SlidesIds.placeholderInstanceId(slideId, def);
    if (model.element(id) == null) {
      throw ArgumentError.value(
        name,
        'name',
        'No placeholder on layout ${layout.key}',
      );
    }
    return id;
  }

  /// Creates a slide group at the end of the deck; the next [slide]s go
  /// into it until [endGroup] or the next [group].
  String group(String title, {String? color}) {
    final r = run(
      CreateGroup(const [], title: title, color: color, target: TopLevel()),
    );
    return _group = r['groupId']! as String;
  }

  /// Slides added after this go to the top level again.
  void endGroup() => _group = null;

  String? _group;

  /// Adds a slide with layout [layoutKey] at the end (of the open group):
  /// placeholder bodies by part name ([text]; a `String`, `TemplatePara` or
  /// `List<TemplatePara>`), speaker [notes], extra [elements] (on top of the
  /// placeholders), [skipped].
  String slide(
    String layoutKey, {
    Map<String, Object> text = const {},
    Object? notes,
    List<ElementSpec> elements = const [],
    bool skipped = false,
  }) {
    final g = _group;
    final r = run(
      AddSlides(
        layoutId: layoutId(layoutKey),
        target: g == null ? const TopLevel() : InGroup(g),
      ),
    );
    final id = (r['slideIds']! as List).single as String;
    for (final MapEntry(:key, :value) in text.entries) {
      run(SetText(ElementText(placeholder(id, key)), TemplateText.of(value)));
    }
    if (notes != null || skipped) {
      run(
        SetSlideProps(
          [id],
          notes: notes == null ? null : Patch(TemplateText.of(notes)),
          skipped: skipped ? true : null,
        ),
      );
    }
    if (elements.isNotEmpty) run(InsertElements(id, elements));
    return id;
  }

  /// Fills the code placeholder of [slideId] with one state.
  void code(String slideId, String source, {required String language}) {
    run(
      AddCodeStates(placeholder(slideId, 'code'), [
        {CodeStateCols.code: source, CodeStateCols.language: language},
      ]),
    );
  }

  /// Adds a [rows] × columns table on [slideId] at [rect]: the first row is
  /// the header (the table style's default), its text bold at 36 su. Cells
  /// are plain text.
  String table(String slideId, SuRect rect, List<List<String>> rows) {
    final cols = rows.first.length;
    final r = run(
      InsertElements(slideId, [
        ElementSpec(
          kind: ElementKind.table,
          x: rect.x,
          y: rect.y,
          width: rect.width,
          height: rect.height,
          tableRows: rows.length,
          tableColumns: cols,
        ),
      ]),
    );
    final el = (r['elementIds']! as List).single as String;
    final rowIds = [
      for (final a in model.axesOf(el, TableAxisDimension.row)) a.id,
    ];
    final colIds = [
      for (final a in model.axesOf(el, TableAxisDimension.column)) a.id,
    ];
    run(
      SetCells(el, [
        for (final (ri, row) in rows.indexed)
          for (final (ci, cell) in row.indexed)
            if (cell.isNotEmpty)
              CellWrite(rowIds[ri], colIds[ci], {
                SlidesCols.text: TemplateText.of(
                  // Header cells a little larger: large bold text keeps
                  // ≥ 3:1 on accent header fills (05 §11).
                  ri == 0
                      ? TemplatePara.runs([
                          TemplateRun(cell, const {'bold': true, 'size': 36}),
                        ])
                      : cell,
                ),
              }),
      ]),
    );
    return el;
  }

  /// The deck's rows as inserts in dependency order (a writer's input).
  List<RowChange> get inserts => [
    for (final t in SlidesTables.dependencyOrder)
      for (final r in model.records(t))
        RowChange.insert(t, r.id, r.toColumns()),
  ];
}

/// Element specs for template slides (frames in su on the 1920 × 1080
/// grid). Colors are `ColorRef` strings (`theme:accent1`,
/// `theme:bg2/alpha:0.5`).
abstract final class TemplateShapes {
  /// A shape with [geometry] (`ShapeLibrary` key) at [rect]: fill and
  /// stroke explicit (none when null), optional [text] (`String`, `TemplatePara`,
  /// `List<TemplatePara>`) with box [box] (default: centered, middle anchored,
  /// 24 su insets) and [textColor].
  static ElementSpec shape(
    String geometry,
    SuRect rect, {
    String? fill,
    String? stroke,
    double strokeWidth = 4,
    Object? text,
    String? textColor,
    String textStyle = 'body',
    double? textSize,
    String align = 'center',
    String anchor = 'middle',
    List<double> insets = const [24, 32, 24, 32],
    Map<String, Object?> adjust = const {},
    double? rotation,
    double? opacity,
    String? name,
    bool decorative = false,
  }) => ElementSpec(
    kind: ElementKind.shape,
    x: rect.x,
    y: rect.y,
    width: rect.width,
    height: rect.height,
    rotation: rotation,
    columns: {
      ElementCols.dataJson: jsonEncode({
        'v': 1,
        'geometry': geometry,
        if (adjust.isNotEmpty) 'adjust': adjust,
      }),
      ElementCols.fillJson: jsonEncode(
        fill == null
            ? const NoFill().toJson()
            : SolidFill(ColorRef.parse(fill)).toJson(),
      ),
      ElementCols.strokeJson: jsonEncode(
        stroke == null
            ? const SlideStroke.none().toJson()
            : SlideStroke(
                color: ColorRef.parse(stroke),
                width: strokeWidth,
              ).toJson(),
      ),
      if (text != null) SlidesCols.text: TemplateText.of(text),
      if (text != null)
        ElementCols.textStyleJson: jsonEncode(
          BoxTextStyle(
            anchor: anchor,
            insets: insets,
            autofit: 'shrink',
            wrap: true,
            defaults: {
              'style': textStyle,
              'align': align,
              'color': ?textColor,
              'size': ?textSize,
            },
          ).toJson(),
        ),
      ElementCols.opacity: ?opacity,
      SlidesCols.name: ?name,
      if (decorative) ElementCols.decorative: true,
    },
  );

  /// A text box at [rect] (no fill), [text] in style [textStyle].
  static ElementSpec text(
    SuRect rect,
    Object text, {
    String textStyle = 'body',
    String? color,
    double? size,
    String align = 'left',
    String anchor = 'top',
    String? name,
  }) => ElementSpec(
    kind: ElementKind.text,
    x: rect.x,
    y: rect.y,
    width: rect.width,
    height: rect.height,
    columns: {
      SlidesCols.text: TemplateText.of(text),
      ElementCols.textStyleJson: jsonEncode(
        BoxTextStyle(
          anchor: anchor,
          insets: const [0, 0, 0, 0],
          autofit: 'shrink',
          wrap: true,
          defaults: {
            'style': textStyle,
            'align': align,
            'color': ?color,
            'size': ?size,
          },
        ).toJson(),
      ),
      SlidesCols.name: ?name,
    },
  );

  /// A straight line from ([x1], [y1]) to ([x2], [y2]).
  static ElementSpec line(
    double x1,
    double y1,
    double x2,
    double y2, {
    required String color,
    double width = 4,
    String? endArrow,
    String? dash,
    bool decorative = true,
  }) {
    final x = x1 < x2 ? x1 : x2, y = y1 < y2 ? y1 : y2;
    final w = (x2 - x1).abs(), h = (y2 - y1).abs();
    double nx(double v) => w == 0 ? 0 : (v - x) / w;
    double ny(double v) => h == 0 ? 0 : (v - y) / h;
    return ElementSpec(
      kind: ElementKind.line,
      x: x,
      y: y,
      // Frames have a minimum side; a horizontal line keeps height 1.
      width: w == 0 ? 1 : w,
      height: h == 0 ? 1 : h,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'routing': 'straight',
          'start': {'x': nx(x1), 'y': ny(y1)},
          'end': {'x': nx(x2), 'y': ny(y2)},
        }),
        ElementCols.strokeJson: jsonEncode(
          SlideStroke(
            color: ColorRef.parse(color),
            width: width,
            dash: dash,
            endArrow: endArrow,
          ).toJson(),
        ),
        if (decorative) ElementCols.decorative: true,
      },
    );
  }
}
