import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart' show ElementCols, TableCellCols;

import '../canvas/canvas_tools.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../elements/style/element_style.dart';
import '../elements/table/table_cells.dart';

/// The inline text attributes a copied style carries (02 §4.1; links stay
/// with their text).
const styleInlineAttributes = [
  'bold',
  'italic',
  'underline',
  'strike',
  'code',
  'font',
  'weight',
  'size',
  'color',
  'highlight',
  'script',
  'caps',
  'letterSpacing',
];

/// The paragraph attributes a copied style carries (lists and indents keep
/// the target's structure).
const styleBlockAttributes = [
  'style',
  'align',
  'lineHeight',
  'spaceBefore',
  'spaceAfter',
];

/// The style of one element as copied by *Paint format* and *Copy style*
/// (Slides 03 §9): fill, stroke, effects and opacity; for text-capable
/// elements the box text properties and the dominant run + paragraph
/// attributes; for images the mask and adjustments (not the crop).
class ElementStylePayload {
  const ElementStylePayload({
    required this.kind,
    this.fill,
    this.stroke,
    this.effects,
    this.opacity,
    this.textStyle,
    this.run = const {},
    this.paragraph = const {},
    this.image,
    this.cell,
  });

  /// Table cells (03 §9, SL-15): the source cell's fill, borders, padding
  /// and vertical align (`SlideTableCell` columns, null = unset) and its
  /// dominant run + paragraph attributes ([run], [paragraph]). Applied to
  /// table cells only.
  final Map<String, Object?>? cell;

  /// [capture] of a table with a focused cell: that cell's style.
  static ElementStylePayload captureIn(
    DeckEditorController ed,
    ResolvedElement e,
  ) {
    if (e.record.kind != ElementKind.table) {
      return ElementStylePayload.capture(e);
    }
    final sel = TableCellSelection.of(ed);
    final focus = sel.tableId == e.id ? sel.focus : textCellOf(ed, e.id);
    if (focus == null) return ElementStylePayload.capture(e);
    final rec = ed.model.indexes.table(e.id).cell(focus.rowId, focus.columnId);
    final (run, paragraph) = dominantAttributes(rec?.text);
    return ElementStylePayload(
      kind: ElementKind.table,
      run: run,
      paragraph: paragraph,
      cell: {for (final c in cellStyleColumns) c: rec?.str(c)},
    );
  }

  /// The cell being edited in table [id], or null (hook of the text host).
  static ({String rowId, String columnId})? Function(
    DeckEditorController ed,
    String id,
  )
  textCellOf = (_, _) => null;

  /// The `SlideTableCell` style columns a cell style carries.
  static const cellStyleColumns = [
    TableCellCols.fill,
    TableCellCols.borderTop,
    TableCellCols.borderRight,
    TableCellCols.borderBottom,
    TableCellCols.borderLeft,
    TableCellCols.vAlign,
    TableCellCols.padding,
  ];

  /// The operations applying a cell style to [cells] of table [tableId].
  List<SlidesOperation> cellOpsFor(
    String tableId,
    List<({String rowId, String columnId})> cells,
    TableIndex ix,
  ) {
    final c = cell;
    if (c == null || cells.isEmpty) return const [];
    final out = <SlidesOperation>[
      SetCells(tableId, [
        for (final x in cells) CellWrite(x.rowId, x.columnId, {...c}),
      ]),
    ];
    final targets = <TextTarget>[
      for (final x in cells)
        if (!SlidesText.isBlank(ix.cell(x.rowId, x.columnId)?.text))
          CellText(tableId, x.rowId, x.columnId),
    ];
    if (targets.isNotEmpty) {
      out.add(
        FormatText(targets, {
          for (final a in styleInlineAttributes) a: run[a],
          for (final a in styleBlockAttributes) a: paragraph[a],
        }),
      );
    }
    return out;
  }

  /// Captures [e]'s style (resolved values, so placeholders bring what
  /// they inherit).
  factory ElementStylePayload.capture(ResolvedElement e) {
    final kind = e.record.kind;
    final text = ElementStyle.hasText(kind) || e.placeholderType != null;
    final (run, paragraph) = text
        ? dominantAttributes(e.text)
        : (const <String, Object?>{}, const <String, Object?>{});
    final data = e.data;
    return ElementStylePayload(
      kind: kind,
      fill: e.fill == null ? null : _strip(e.fill!),
      stroke: e.stroke == null ? null : _strip(e.stroke!),
      effects: e.effects == null ? null : _strip(e.effects!),
      opacity: e.record.opacity,
      textStyle: text
          ? ElementStyle.decode(e.record.str(ElementCols.textStyleJson))
          : null,
      run: run,
      paragraph: paragraph,
      image: kind == ElementKind.image && data != null
          ? {
              for (final k in const ['mask', 'maskAdjust', 'adjust'])
                k: data[k],
            }
          : null,
    );
  }

  /// From MCP / `slides.format.pasteStyle {style}` JSON.
  static ElementStylePayload? fromJson(Object? json) {
    if (json is! Map) return null;
    Map<String, Object?>? map(Object? v) =>
        v is Map ? v.cast<String, Object?>() : null;
    final kind = ElementKind.fromName('${json['kind']}') ?? ElementKind.shape;
    return ElementStylePayload(
      kind: kind,
      fill: map(json['fill']),
      stroke: map(json['stroke']),
      effects: map(json['effects']),
      opacity: (json['opacity'] as num?)?.toDouble(),
      textStyle: map(json['textStyle']),
      run: map(json['run']) ?? const {},
      paragraph: map(json['paragraph']) ?? const {},
      image: map(json['image']),
      cell: map(json['cell']),
    );
  }

  final ElementKind kind;
  final Map<String, Object?>? fill;
  final Map<String, Object?>? stroke;
  final Map<String, Object?>? effects;
  final double? opacity;
  final Map<String, Object?>? textStyle;
  final Map<String, Object?> run;
  final Map<String, Object?> paragraph;
  final Map<String, Object?>? image;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'fill': ?fill,
    'stroke': ?stroke,
    'effects': ?effects,
    'opacity': ?opacity,
    'textStyle': ?textStyle,
    if (run.isNotEmpty) 'run': run,
    if (paragraph.isNotEmpty) 'paragraph': paragraph,
    'image': ?image,
    'cell': ?cell,
  };

  static Map<String, Object?> _strip(Map<String, Object?> m) =>
      {...m}..remove('v');

  bool get _textual => ElementStyle.hasText(kind) || textStyle != null;

  /// The operations applying this style to [targets] (one transaction =
  /// one undo step "Paste style").
  List<SlidesOperation> opsFor(Iterable<ResolvedElement> targets) {
    final out = <SlidesOperation>[];
    for (final t in targets) {
      final k = t.record.kind;
      Patch<String?>? strokePatch;
      if (ElementStyle.hasStroke(k) && ElementStyle.hasStroke(kind)) {
        var s = stroke;
        if (s != null && k != ElementKind.line) {
          s = {...s}
            ..remove('startArrow')
            ..remove('endArrow')
            ..remove('arrowSize');
        }
        strokePatch = Patch(ElementStyle.encode(s));
      }
      out.add(
        SetElementProps(
          [t.id],
          fillJson: ElementStyle.hasFill(k) && ElementStyle.hasFill(kind)
              ? Patch(ElementStyle.encode(fill))
              : null,
          strokeJson: strokePatch,
          effectsJson: Patch(ElementStyle.encode(effects)),
          opacity: Patch(opacity == null || opacity! >= 1 ? null : opacity),
        ),
      );
      final img = image;
      if (k == ElementKind.image && img != null) {
        final data = t.data ?? const <String, Object?>{};
        out.add(SetElementData(t.id, jsonEncode({'v': 1, ...data, ...img})));
      }
      final targetText = ElementStyle.hasText(k) || t.placeholderType != null;
      if (targetText && _textual) {
        final current =
            ElementStyle.decode(t.record.str(ElementCols.textStyleJson)) ??
            const <String, Object?>{};
        final patch = <String, Object?>{
          for (final key in current.keys)
            if (key != 'v') key: null,
          ...?textStyle,
        }..remove('v');
        if (patch.isNotEmpty) out.add(SetTextBoxStyle([t.id], patch));
        if (!SlidesText.isBlank(t.text)) {
          out.add(
            FormatText(
              [ElementText(t.id)],
              {
                for (final a in styleInlineAttributes) a: run[a],
                for (final a in styleBlockAttributes) a: paragraph[a],
              },
            ),
          );
        }
      }
    }
    return out;
  }

  /// The attributes of the longest run and of the first paragraph of the
  /// Delta [json].
  static (Map<String, Object?>, Map<String, Object?>) dominantAttributes(
    String? json,
  ) {
    if (json == null) return (const {}, const {});
    Object? ops;
    try {
      ops = jsonDecode(json);
    } on FormatException {
      return (const {}, const {});
    }
    if (ops is! List) return (const {}, const {});
    Map<String, Object?> run = const {};
    Map<String, Object?>? para;
    var best = -1;
    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = op['attributes'] is Map
          ? (op['attributes'] as Map).cast<String, Object?>()
          : const <String, Object?>{};
      final len = insert.replaceAll('\n', '').length;
      if (len > best && len > 0) {
        best = len;
        run = {
          for (final a in styleInlineAttributes)
            if (attrs[a] != null) a: attrs[a],
        };
      }
      if (para == null && insert.contains('\n')) {
        para = {
          for (final a in styleBlockAttributes)
            if (attrs[a] != null) a: attrs[a],
        };
      }
    }
    return (run, para ?? const {});
  }
}

/// The format painter and style clipboard of an open deck (Slides 03 §9):
/// the style armed by *Paint format* (sticky until Esc or the brush when
/// double-clicked) and the style kept by *Copy style* for *Paste style*
/// (in-app, not the system clipboard).
class FormatPainter {
  FormatPainter._();

  static final Expando<FormatPainter> _of = Expando('slidesFormatPainter');

  /// The painter of [ed].
  static FormatPainter of(DeckEditorController ed) =>
      _of[ed] ??= FormatPainter._();

  /// The armed tool name.
  static const toolName = 'paintFormat';

  /// The style being painted (while armed).
  ElementStylePayload? paint;

  /// Whether painting stays armed after an application.
  bool sticky = false;

  /// When the brush was armed (a second click within 500 ms = double-click
  /// = sticky).
  DateTime? armedAt;

  /// The *Copy style* clipboard.
  ElementStylePayload? clipboard;

  /// Whether [ed] paints.
  static bool armed(DeckEditorController ed) => ed.armedTool == toolName;
}

/// The armed painter: a click on an element applies the style.
class PaintFormatTool extends CanvasTool {
  const PaintFormatTool();

  @override
  CanvasToolGesture get gesture => CanvasToolGesture.pick;

  @override
  MouseCursor get cursor => SystemMouseCursors.copy;

  @override
  Future<void> commit(
    DeckEditorController ed,
    CanvasToolStroke stroke,
    BuildContext context,
  ) async {
    final id = stroke.pickedId;
    if (id == null) {
      // A click beside the objects ends one-shot painting.
      if (!FormatPainter.of(ed).sticky) ed.armTool(null);
      return;
    }
    await ed.invokeCommand(
      'slides.format.paintFormat',
      {
        'targetIds': [id],
        // The clicked point picks a table cell (SL-15).
        'x': stroke.end.dx,
        'y': stroke.end.dy,
      },
      InvocationSource.ui,
      context.mounted ? context : null,
    );
  }
}

/// The [CanvasTools] factory of the format painter.
CanvasTool? paintFormatToolFactory(DeckEditorController ed, String armed) =>
    armed == FormatPainter.toolName ? const PaintFormatTool() : null;
