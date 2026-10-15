import 'package:super_editor/super_editor.dart';
import 'package:wonky_app/wonky_app.dart' show CommandContext;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/scene.dart'
    show ResolvedTextStyles, TextBody, defaultTextInsets;

import '../editor_screen/deck_editor_controller.dart';
import '../selection/slide_elements.dart';
import 'slide_text_editor.dart';
import 'slides_delta_mapper.dart';
import 'text_editing_host.dart';

/// One run of a text body: characters `[start, end)` with their inline
/// attributes.
class BodyRun {
  const BodyRun(this.start, this.end, this.inline);

  final int start;
  final int end;
  final Map<String, Object?> inline;
}

/// One paragraph of a text body: characters `[start, end)` (without the
/// closing `"\n"` at [end]), its block attributes and runs.
class BodyParagraph {
  const BodyParagraph(this.start, this.end, this.block, this.runs);

  final int start;
  final int end;
  final Map<String, Object?> block;
  final List<BodyRun> runs;
}

/// The paragraphs of a stored body (Delta JSON; null = one empty
/// paragraph). Offsets are those of `FormatText` (02 §4.1).
List<BodyParagraph> paragraphsOf(String? json) {
  final out = <BodyParagraph>[];
  var runs = <BodyRun>[];
  var at = 0, paraStart = 0;
  for (final op in TextBody.fromJson(json).ops) {
    final insert = op['insert'];
    if (insert is! String) continue;
    final attrs = op['attributes'] is Map
        ? (op['attributes'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    var from = 0;
    while (from <= insert.length) {
      final nl = insert.indexOf('\n', from);
      final stop = nl < 0 ? insert.length : nl;
      if (stop > from) {
        runs.add(BodyRun(at, at + stop - from, attrs));
        at += stop - from;
      }
      if (nl < 0) break;
      out.add(BodyParagraph(paraStart, at, attrs, runs));
      runs = [];
      at += 1;
      paraStart = at;
      from = nl + 1;
    }
  }
  if (runs.isNotEmpty || out.isEmpty) {
    out.add(BodyParagraph(paraStart, at, const {}, runs));
  }
  return out;
}

/// The list of a paragraph with [block] attributes in a box whose text
/// defaults are [defaults] (`TextParagraphs`: an explicit `list`, else the
/// box default unless the paragraph names a style or `listStyle: none`).
String? effectiveList(
  Map<String, Object?> block,
  Map<String, Object?> defaults,
) {
  final explicit = block['list'] as String?;
  if (explicit != null) return explicit;
  if (block['style'] != null || block['listStyle'] == 'none') return null;
  return defaults['list'] as String?;
}

/// Where a text format command applies (03 §6.1): the range of the body
/// being edited, or the whole bodies of the selected text-capable
/// elements.
class TextFormatTarget {
  const TextFormatTarget(
    this.element,
    this.slide, {
    this.start,
    this.end,
    this.cell,
    this.cellText,
    this.cellStyles,
  });

  final ResolvedElement element;
  final ResolvedSlide slide;

  /// A table cell of [element] (SL-15: text formatting of cells), else
  /// null for the element's own body.
  final ({String rowId, String columnId})? cell;

  /// The stored body of [cell].
  final String? cellText;

  /// The text styles of [cell] (the table area's, 05 §2.8).
  final ResolvedTextStyles? cellStyles;

  /// The body the format ops write.
  TextTarget get target => cell == null
      ? ElementText(element.id)
      : CellText(element.id, cell!.rowId, cell!.columnId);

  /// The stored body.
  String? get body => cell == null ? element.text : cellText;

  /// The current stored body in [model] (after earlier writes of the same
  /// command).
  String? currentBody(DeckModel model) => cell == null
      ? model.element(element.id)?.text
      : model.indexes.table(element.id).cell(cell!.rowId, cell!.columnId)?.text;

  /// Whether [c] edits this body.
  bool isEditedBy(SlideTextEditController? c) =>
      c != null &&
      c.elementId == element.id &&
      c.cellRowId == cell?.rowId &&
      c.cellColumnId == cell?.columnId;

  /// The selected body range while editing (null = the whole body).
  final int? start;
  final int? end;

  String get id => element.id;

  /// The box text defaults (`textStyleJson.defaults` along the placeholder
  /// chain and the theme's object style; none for table cells).
  Map<String, Object?> get defaults => cell == null
      ? SlideTextEditing.boxStyleOf(element, slide).defaults
      : const {};

  bool get isRange => start != null;
  bool get collapsed => start != null && start == end;

  /// The text styles of the body (theme styles + box properties).
  ResolvedTextStyles? get styles {
    if (cell != null) return cellStyles;
    final base = element.textStyles;
    if (base == null) return null;
    return base.withBox(SlideTextEditing.boxStyleOf(element, slide));
  }
}

/// The format targets of [ed] and the names of soft-locked bodies that
/// were skipped (format commands on whole elements, 03 §6.1).
class TextFormatScope {
  const TextFormatScope(this.targets, {this.editing, this.skipped = const []});

  final List<TextFormatTarget> targets;

  /// The editing session when the command applies to its selection.
  final SlideTextEditController? editing;

  /// Who holds the skipped bodies (one entry per skipped body).
  final List<String> skipped;

  bool get isEmpty => targets.isEmpty;

  /// The cells of a selected table that whole-element text formatting
  /// applies to (the cell selection, else every cell; SL-15). Set by the
  /// table feature.
  static List<TextFormatTarget> Function(
    DeckEditorController ed,
    ResolvedElement table,
    ResolvedSlide slide,
  )?
  tableCells;

  /// The scope of [ed]: the selection of the body being edited, else every
  /// selected text-capable element (group children included), skipping
  /// locked elements and bodies someone else edits.
  static TextFormatScope of(DeckEditorController ed) {
    final host = textEditingOf(ed);
    final slideId = ed.currentSlideId;
    final slide = slideId == null ? null : ed.resolver.resolve(slideId);
    if (slide == null) return const TextFormatScope([]);
    final els = SlideElements.of(slide);
    final c = host.active;
    if (c != null) {
      final e = els[c.elementId];
      final r = c.selectionRange;
      if (e == null) return const TextFormatScope([]);
      return TextFormatScope([
        TextFormatTarget(
          e,
          slide,
          start: r?.$1 ?? 0,
          end: r?.$2 ?? 0,
          cell: c.isCell
              ? (rowId: c.cellRowId!, columnId: c.cellColumnId!)
              : null,
          cellText: c.isCell ? c.json : null,
          cellStyles: c.isCell ? c.geometry.spec.styles : null,
        ),
      ], editing: c);
    }
    final out = <TextFormatTarget>[];
    final skipped = <String>[];
    void add(ResolvedElement e) {
      if (e.record.kind == ElementKind.group) {
        e.children.forEach(add);
        return;
      }
      if (e.locked || e.hidden) return;
      // A body someone else is editing is skipped (soft lock, 09 §2.2;
      // for tables: any of its cells).
      final holder = host.locks.heldBy(e.id);
      if (e.record.kind == ElementKind.table) {
        if (holder != null) {
          skipped.add(holder);
          return;
        }
        out.addAll(tableCells?.call(ed, e, slide) ?? const []);
        return;
      }
      if (!SlideTextEditing.isTextCapable(e)) return;
      if (holder != null) {
        skipped.add(holder);
        return;
      }
      out.add(TextFormatTarget(e, slide));
    }

    for (final id in ed.selectedElementIds) {
      final e = els[id];
      if (e != null) add(e);
    }
    return TextFormatScope(out, skipped: skipped);
  }

  /// The elements of the scope (box-level commands).
  List<String> get elementIds => [
    for (final t in targets)
      if (t.cell == null) t.id,
  ];
}

/// The effective formatting of a scope (toolbar and inspector state,
/// checked states of the format commands): a value when every run agrees
/// (booleans: all on), else the first run's for single values.
class TextFormatState {
  const TextFormatState({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.script,
    this.caps,
    this.font,
    this.fontRef,
    this.size,
    this.color,
    this.colorRef,
    this.highlight,
    this.letterSpacing,
    this.align,
    this.list,
    this.lineHeight,
    this.spaceBefore,
    this.spaceAfter,
    this.styleKey,
    this.link,
    this.anchor,
    this.autofit,
    this.insets,
    this.wrap,
    this.indent = 0,
  });

  static const empty = TextFormatState();

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  /// `super`, `sub` or null (mixed or none).
  final String? script;

  /// Stored caps (`all`, `small`, `title`) or null.
  final String? caps;

  /// The face's family.
  final String? font;

  /// The stored `font` attribute (theme refs like `@heading`) or null.
  final String? fontRef;
  final double? size;

  /// ARGB.
  final int? color;

  /// The stored `color` attribute or null (automatic).
  final String? colorRef;

  /// The stored `highlight` attribute or null.
  final String? highlight;
  final double? letterSpacing;
  final String? align;

  /// `bullet`, `ordered`, `check` (incl. unchecked) or null.
  final String? list;
  final double? lineHeight;
  final double? spaceBefore;
  final double? spaceAfter;

  /// The paragraph style key (common) or null.
  final String? styleKey;
  final String? link;
  final String? anchor;
  final String? autofit;
  final List<double>? insets;
  final bool? wrap;

  /// The first paragraph's list level.
  final int indent;

  static final TextStyleResolver _resolver = TextStyleResolver(cacheSize: 8);

  /// The state of [scope].
  static TextFormatState of(TextFormatScope scope) {
    if (scope.isEmpty) return empty;
    final runs = <(EffectiveRunStyle, Map<String, Object?>)>[];
    final paras = <(Map<String, Object?>, Map<String, Object?>)>[];
    for (final t in scope.targets) {
      final styles = t.styles;
      if (styles == null) continue;
      final theme = t.slide.theme;
      final body = t.isEditedBy(scope.editing) ? scope.editing!.json : t.body;
      final ps = paragraphsOf(body);
      for (final p in ps) {
        final inRange =
            !t.isRange ||
            (t.collapsed
                ? t.start! >= p.start && t.start! <= p.end
                : p.start < t.end! && p.end >= t.start!);
        if (!inRange) continue;
        paras.add((p.block, t.defaults));
        if (t.collapsed) {
          final prefs = scope.editing?.composer.preferences;
          final inline = prefs == null
              ? const <String, Object?>{}
              : SlidesDeltaMapper.inlineOf(prefs.currentAttributions);
          runs.add((
            _resolver.run(theme, styles, block: p.block, inline: inline),
            inline,
          ));
          continue;
        }
        var any = false;
        for (final r in p.runs) {
          if (t.isRange && (r.end <= t.start! || r.start >= t.end!)) continue;
          any = true;
          runs.add((
            _resolver.run(theme, styles, block: p.block, inline: r.inline),
            r.inline,
          ));
        }
        if (!any && (!t.isRange || p.runs.isEmpty)) {
          runs.add((
            _resolver.run(theme, styles, block: p.block),
            const <String, Object?>{},
          ));
        }
      }
    }
    if (runs.isEmpty) return empty;
    T? common<T>(Iterable<T?> values) {
      final set = values.toSet();
      return set.length == 1 ? set.single : null;
    }

    final first = runs.first;
    final t0 = scope.targets.first;
    final box = SlideTextEditing.boxStyleOf(t0.element, t0.slide);
    final isShape = t0.element.record.kind == ElementKind.shape;
    final f = first.$1;
    final list = common(paras.map((b) => effectiveList(b.$1, b.$2)));
    return TextFormatState(
      bold: runs.every((r) => r.$1.font.requestedWeight >= 600),
      italic: runs.every((r) => r.$1.italic),
      underline: runs.every((r) => r.$2['underline'] == true),
      strike: runs.every((r) => r.$1.strike),
      script: common(runs.map((r) => r.$1.script)),
      caps: common(runs.map((r) => r.$1.caps)),
      font: f.font.requestedFamily,
      fontRef: first.$2['font'] as String?,
      size: f.size,
      color: f.color,
      colorRef: first.$2['color'] as String?,
      highlight: first.$2['highlight'] as String?,
      letterSpacing: f.letterSpacing,
      align: common(runs.map((r) => r.$1.align)),
      list: list == 'unchecked' ? 'check' : list,
      lineHeight: f.lineHeight,
      spaceBefore: f.spaceBefore,
      spaceAfter: f.spaceAfter,
      styleKey: common(runs.map((r) => r.$1.styleKey)),
      link: first.$1.link,
      anchor: box.anchor ?? (isShape ? 'middle' : 'top'),
      autofit: box.autofit ?? (isShape ? 'shrink' : 'resize'),
      insets: box.insets ?? defaultTextInsets,
      wrap: box.wrap ?? true,
      indent: ((paras.first.$1['indent'] as num?)?.toInt() ?? 0),
    );
  }

  /// Whether the theme (not an inline attribute) makes any run bold.
  static bool themeBold(TextFormatScope scope) {
    for (final t in scope.targets) {
      final styles = t.styles;
      if (styles == null) continue;
      for (final p in paragraphsOf(t.body)) {
        final s = _resolver.run(t.slide.theme, styles, block: p.block);
        if (s.font.requestedWeight >= 600) return true;
      }
    }
    return false;
  }
}

/// Applies text formatting to a [TextFormatScope] through the deck's write
/// path (one undo step per command, 03 §15). While editing, pending typing
/// is written first (its own "Typing" step), a range is formatted with
/// `FormatText`, and a collapsed caret changes the typing attributes
/// instead (no document change).
class TextFormatter {
  TextFormatter(this.ctx, this.ed) : scope = TextFormatScope.of(ed);

  final CommandContext ctx;
  final DeckEditorController ed;
  final TextFormatScope scope;

  SlideTextEditController? get editing => scope.editing;

  TextFormatTarget? get _range =>
      editing == null || scope.targets.isEmpty ? null : scope.targets.single;

  /// Inline attributes ([attrs]; null removes) on the scope.
  void inline(Map<String, Object?> attrs) {
    final r = _range;
    if (r != null && r.collapsed) {
      setTypingAttributes(editing!, attrs);
      return;
    }
    _flush();
    if (r != null) {
      ed.apply(
        ctx,
        FormatText(
          [r.target],
          attrs,
          start: r.start,
          length: r.end! - r.start!,
        ),
      );
      return;
    }
    ed.apply(ctx, FormatText([for (final t in scope.targets) t.target], attrs));
  }

  /// Inline attributes computed per run from its effective style (font
  /// size steps). A collapsed caret changes the typing attributes.
  void perRun(
    Map<String, Object?>? Function(
      EffectiveRunStyle style,
      Map<String, Object?> inline,
    )
    f,
  ) {
    final r = _range;
    final resolver = TextStyleResolver(cacheSize: 4);
    if (r != null && r.collapsed) {
      final styles = r.styles;
      if (styles == null) return;
      final prefs = editing!.composer.preferences;
      final inline = SlidesDeltaMapper.inlineOf(prefs.currentAttributions);
      final block = _paragraphAt(editing!.json, r.start!)?.block ?? const {};
      final style = resolver.run(
        r.slide.theme,
        styles,
        block: block,
        inline: inline,
      );
      final attrs = f(style, inline);
      if (attrs != null) setTypingAttributes(editing!, attrs);
      return;
    }
    _flush();
    for (final t in scope.targets) {
      final styles = t.styles;
      if (styles == null) continue;
      final body = t.currentBody(ed.model);
      for (final p in paragraphsOf(body)) {
        for (final run in p.runs) {
          final from = r == null
              ? run.start
              : run.start.clamp(r.start!, r.end!);
          final to = r == null ? run.end : run.end.clamp(r.start!, r.end!);
          if (to <= from) continue;
          final style = resolver.run(
            t.slide.theme,
            styles,
            block: p.block,
            inline: run.inline,
          );
          final attrs = f(style, run.inline);
          if (attrs == null) continue;
          ed.apply(
            ctx,
            FormatText([t.target], attrs, start: from, length: to - from),
          );
        }
      }
    }
  }

  /// Block attributes on the paragraphs of the scope.
  void block(Map<String, Object?> attrs) {
    final r = _range;
    _flush();
    if (r != null) {
      ed.apply(
        ctx,
        FormatText(
          [r.target],
          attrs,
          start: r.start,
          length: r.end! - r.start!,
        ),
      );
      return;
    }
    ed.apply(ctx, FormatText([for (final t in scope.targets) t.target], attrs));
  }

  /// Block attributes computed per paragraph (indent, list toggles).
  void perParagraph(
    Map<String, Object?>? Function(
      Map<String, Object?> block,
      Map<String, Object?> defaults,
    )
    f,
  ) {
    final r = _range;
    _flush();
    for (final t in scope.targets) {
      final body = t.currentBody(ed.model);
      for (final p in paragraphsOf(body)) {
        if (r != null) {
          final inRange = r.collapsed
              ? r.start! >= p.start && r.start! <= p.end
              : p.start < r.end! && p.end >= r.start!;
          if (!inRange) continue;
        }
        final attrs = f(p.block, t.defaults);
        if (attrs == null) continue;
        ed.apply(ctx, FormatText([t.target], attrs, start: p.start, length: 0));
      }
    }
  }

  /// Box-level text properties (`textStyleJson`) of the scope's elements.
  void box(Map<String, Object?> patch) {
    _flush();
    final ids = scope.elementIds;
    if (ids.isEmpty) return;
    ed.apply(ctx, SetTextBoxStyle(ids, patch));
  }

  /// The paragraphs of the scope (range-overlapping when editing): block
  /// attributes and the box text defaults.
  List<(Map<String, Object?>, Map<String, Object?>)> get paragraphs {
    final r = _range;
    return [
      for (final t in scope.targets)
        for (final p in paragraphsOf(
          t.isEditedBy(editing) ? editing!.json : t.body,
        ))
          if (r == null ||
              (r.collapsed
                  ? r.start! >= p.start && r.start! <= p.end
                  : p.start < r.end! && p.end >= r.start!))
            (p.block, t.defaults),
    ];
  }

  void _flush() => editing?.commit();

  static BodyParagraph? _paragraphAt(String json, int offset) {
    for (final p in paragraphsOf(json)) {
      if (offset >= p.start && offset <= p.end) return p;
    }
    return null;
  }
}

/// Changes the typing attributes of [c] (collapsed caret): `true`/values
/// add, null removes (03 §6.1 "collapsed caret sets typing attributes").
void setTypingAttributes(
  SlideTextEditController c,
  Map<String, Object?> attrs,
) {
  final prefs = c.composer.preferences;
  final current = SlidesDeltaMapper.inlineOf(prefs.currentAttributions);
  final remove = <Attribution>{};
  for (final key in attrs.keys) {
    final v = current[key];
    if (v != null) {
      remove.addAll(SlidesDeltaMapper.attributionsOf({key: v}));
    }
  }
  if (remove.isNotEmpty) prefs.removeStyles(remove);
  final add = <String, Object?>{
    for (final e in attrs.entries)
      if (e.value != null) e.key: e.value,
  };
  if (add.isNotEmpty) {
    prefs.addStyles(SlidesDeltaMapper.attributionsOf(add).toSet());
  }
}
