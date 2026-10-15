import 'dart:convert';

import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/scene.dart' show ScenePaint;
import 'package:wonky_slides_core/themes.dart';

import '../selection/reading_order.dart';

/// The rules of the accessibility checker (Slides 03 §17.4; SL-34).
enum A11yRule {
  /// An image, icon or chart without alt text that isn't decorative.
  missingAltText,

  /// Text contrast below 4.5:1 (3:1 for large text) against its resolved
  /// background.
  lowContrast,

  /// Text over an image (or an image background): contrast can't be
  /// computed, check it by eye.
  contrastOverImage,

  /// A slide without a title (no title placeholder text and no
  /// `title`/`heading` paragraph).
  missingTitle,

  /// Several slides share one title.
  duplicateTitle,

  /// Text smaller than [AccessibilityChecker.minTextSize].
  smallText,

  /// A custom reading order that differs strongly from the visual order.
  readingOrder,

  /// A table without a header row.
  tableHeader,

  /// An empty placeholder (body, subtitle, picture, …) left on a slide.
  emptyPlaceholder;

  /// How serious it is (03 §17.4).
  A11ySeverity get severity => switch (this) {
    missingAltText || lowContrast => A11ySeverity.error,
    contrastOverImage ||
    missingTitle ||
    duplicateTitle ||
    smallText ||
    tableHeader => A11ySeverity.warning,
    readingOrder || emptyPlaceholder => A11ySeverity.info,
  };

  /// Whether `slides.a11y.fix` has a quick fix for it.
  bool get fixable => switch (this) {
    missingAltText ||
    lowContrast ||
    smallText ||
    readingOrder ||
    tableHeader ||
    emptyPlaceholder => true,
    contrastOverImage || missingTitle || duplicateTitle => false,
  };

  static A11yRule? fromName(Object? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// Severity of an [A11yIssue].
enum A11ySeverity { error, warning, info }

/// One finding of the [AccessibilityChecker].
class A11yIssue {
  const A11yIssue({
    required this.rule,
    required this.slideId,
    this.elementId,
    this.ratio,
    this.required,
    this.size,
    this.title,
  });

  final A11yRule rule;

  /// The slide (or layout / master) it was found on.
  final String slideId;

  /// The element, or null for slide-level rules.
  final String? elementId;

  /// [A11yRule.lowContrast]: the worst contrast ratio and the one required.
  final double? ratio;
  final double? required;

  /// [A11yRule.smallText]: the smallest text size (su).
  final double? size;

  /// [A11yRule.duplicateTitle]: the shared title.
  final String? title;

  A11ySeverity get severity => rule.severity;

  /// Stable id (`rule:slide:element`).
  String get id => '${rule.name}:$slideId:${elementId ?? ''}';

  /// MCP form (`slides.tools.accessibilityCheck` results).
  Map<String, Object?> toJson() => {
    'id': id,
    'rule': rule.name,
    'severity': severity.name,
    'slideId': slideId,
    'elementId': ?elementId,
    if (ratio != null) 'ratio': double.parse(ratio!.toStringAsFixed(2)),
    'required': ?required,
    'size': ?size,
    'title': ?title,
    'fixable': rule.fixable,
  };

  @override
  bool operator ==(Object other) =>
      other is A11yIssue &&
      other.id == id &&
      other.ratio == ratio &&
      other.size == size;

  @override
  int get hashCode => Object.hash(id, ratio, size);

  @override
  String toString() => 'A11yIssue($id)';
}

/// The issues of a deck, in slide order (slide-level rules first per
/// slide, then the elements in reading order).
class AccessibilityReport {
  const AccessibilityReport(this.issues);

  final List<A11yIssue> issues;

  int count(A11ySeverity s) => issues.where((i) => i.severity == s).length;

  /// The issues of [slideId].
  List<A11yIssue> of(String slideId) => [
    for (final i in issues)
      if (i.slideId == slideId) i,
  ];

  Map<String, Object?> toJson() => {
    'errors': count(A11ySeverity.error),
    'warnings': count(A11ySeverity.warning),
    'info': count(A11ySeverity.info),
    'issues': [for (final i in issues) i.toJson()],
  };
}

/// The accessibility checker (Slides 03 §17.4): pure rules over the deck
/// model and the resolved slides (no Flutter), so the panel, MCP and tests
/// share them.
///
/// Skipped slides are not checked (they aren't presented). Contrast is
/// computed for the deck's appearance (light or dark), with the theme
/// colors resolved for it: the text color of every run (inline ▸
/// paragraph style ▸ box defaults ▸ theme style, element opacity
/// applied) against the element's own fill, else the topmost filled
/// element behind its center, else the slide background. Text over an
/// image (element, image fill or image background) gives
/// [A11yRule.contrastOverImage] instead. Table cells, code and chart text
/// are not checked yet.
abstract final class AccessibilityChecker {
  /// Text smaller than this (su) is flagged (03 §17.4).
  static const minTextSize = 18.0;

  /// Normal text needs 4.5:1, large text 3:1 (WCAG AA).
  static const normalContrast = 4.5;
  static const largeContrast = 3.0;

  /// Large text: ≥ 40 su, or ≥ 32 su bold.
  static bool isLarge(double size, int weight) =>
      size >= 40 || (size >= 32 && weight >= 700);

  /// Checks the slides of [model] (all, or [slideIds]).
  static AccessibilityReport check(
    DeckModel model, {
    SlideResolver? resolver,
    Iterable<String>? slideIds,
  }) {
    final r = resolver ?? SlideResolver(model);
    final only = slideIds?.toSet();
    final styles = TextStyleResolver();
    final issues = <A11yIssue>[];
    // Titles across the deck (duplicates).
    final titles = <String, List<String>>{};
    final entries = [
      for (final e in model.indexes.order.entries)
        if (!e.skipped) e,
    ];
    for (final e in entries) {
      final t = _norm(slideTitle(model, e.id));
      if (t.isNotEmpty) (titles[t] ??= []).add(e.id);
    }
    for (final e in entries) {
      if (only != null && !only.contains(e.id)) continue;
      final slide = r.resolve(e.id);
      if (slide == null) continue;
      issues.addAll(_slideIssues(model, slide, styles, titles));
    }
    return AccessibilityReport(List.unmodifiable(issues));
  }

  /// The plain title of [slideId] (its title placeholder, else its first
  /// `title`/`heading` paragraph; '' when none).
  static String slideTitle(DeckReader model, String slideId) {
    String? heading;
    for (final e in model.elementsOf(slideId)) {
      if (e.placeholderType == SlidePlaceholderType.title) {
        final t = SlidesText.plainText(e.text).trim();
        if (t.isNotEmpty) return t;
      }
    }
    for (final e in model.allElementsOf(slideId)) {
      for (final p in _paragraphs(e.text)) {
        final style = p.block['style'];
        if ((style == 'title' || style == 'heading') && p.text.trim() != '') {
          heading ??= p.text.trim();
        }
      }
    }
    return heading ?? '';
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<A11yIssue> _slideIssues(
    DeckModel model,
    ResolvedSlide slide,
    TextStyleResolver styles,
    Map<String, List<String>> titles,
  ) {
    final id = slide.slide.id;
    final out = <A11yIssue>[];
    // Slide titles.
    final title = slideTitle(model, id);
    if (title.isEmpty) {
      out.add(A11yIssue(rule: A11yRule.missingTitle, slideId: id));
    } else if ((titles[_norm(title)]?.length ?? 0) > 1) {
      out.add(
        A11yIssue(rule: A11yRule.duplicateTitle, slideId: id, title: title),
      );
    }
    // Reading order.
    if (_readingOrderDiffers(slide)) {
      out.add(A11yIssue(rule: A11yRule.readingOrder, slideId: id));
    }
    // Elements, in reading order (group children after their group).
    final painted = _painted(slide);
    void visit(List<ResolvedElement> list) {
      for (final e in ReadingOrder.of(list, slideHeight: slide.bounds.height)) {
        out.addAll(_elementIssues(model, slide, e, painted, styles));
        if (e.children.isNotEmpty) visit(e.children);
      }
    }

    visit(slide.elements);
    return out;
  }

  static List<A11yIssue> _elementIssues(
    DeckModel model,
    ResolvedSlide slide,
    ResolvedElement e,
    List<ResolvedElement> painted,
    TextStyleResolver styles,
  ) {
    final sid = slide.slide.id;
    final out = <A11yIssue>[];
    final rec = e.record;
    final kind = rec.kind;
    final p = e.placeholderType;
    // Empty placeholders (the title is the slide-title rule's).
    if (p != null && p != SlidePlaceholderType.title && _isEmpty(e)) {
      out.add(
        A11yIssue(
          rule: A11yRule.emptyPlaceholder,
          slideId: sid,
          elementId: e.id,
        ),
      );
      return out;
    }
    // Alt text.
    if ((kind == ElementKind.image ||
            kind == ElementKind.icon ||
            kind == ElementKind.chart) &&
        !rec.decorative &&
        (rec.altText ?? '').trim().isEmpty) {
      out.add(
        A11yIssue(rule: A11yRule.missingAltText, slideId: sid, elementId: e.id),
      );
    }
    // Table header row.
    if (kind == ElementKind.table && !_hasHeaderRow(model, e)) {
      out.add(
        A11yIssue(rule: A11yRule.tableHeader, slideId: sid, elementId: e.id),
      );
    }
    // Text: size and contrast.
    if ((kind == ElementKind.text || kind == ElementKind.shape) &&
        e.textStyles != null &&
        !SlidesText.isBlank(e.text)) {
      out.addAll(_textIssues(slide, e, painted, styles));
    }
    return out;
  }

  /// Whether placeholder instance [e] holds nothing yet.
  static bool _isEmpty(ResolvedElement e) => switch (e.record.kind) {
    ElementKind.image => (e.data?['src'] as String? ?? '').isEmpty,
    ElementKind.chart => e.record.dataJson == null,
    ElementKind.text || ElementKind.shape => SlidesText.isBlank(e.text),
    _ => false,
  };

  static bool _hasHeaderRow(DeckModel model, ResolvedElement e) {
    final options = e.data?['options'];
    final headerRow = options is Map && options['headerRow'] is bool
        ? options['headerRow'] as bool
        : true;
    if (headerRow) return true;
    return model.indexes.table(e.id).rows.any((r) => r.header);
  }

  static List<A11yIssue> _textIssues(
    ResolvedSlide slide,
    ResolvedElement e,
    List<ResolvedElement> painted,
    TextStyleResolver resolver,
  ) {
    final sid = slide.slide.id;
    final theme = slide.theme;
    final defaults = e.record.kind == ElementKind.shape
        ? theme.shapeStyles.shape
        : theme.shapeStyles.text;
    final styles = e.textStyles!.withBox(
      (defaults.textStyle ?? BoxTextStyle.empty).merge(e.textStyle),
    );
    final background = backgroundOf(slide, e, painted);
    double? minSize;
    double? worst;
    double? worstRequired;
    for (final para in _paragraphs(e.text)) {
      for (final run in para.runs) {
        if (run.text.trim().isEmpty) continue;
        final style = resolver.run(
          theme,
          styles,
          block: para.block,
          inline: run.attributes,
        );
        final size = style.size;
        if (size < minTextSize && (minSize == null || size < minSize)) {
          minSize = size;
        }
        if (background == null) continue;
        final weight = style.font.requestedWeight;
        final need = isLarge(size, weight) ? largeContrast : normalContrast;
        final fg = _withOpacity(style.color, e.opacity);
        final ratio = ThemeContrast.ratio(fg, background);
        if (ratio + 1e-9 < need &&
            (worst == null || ratio / need < worst / worstRequired!)) {
          worst = ratio;
          worstRequired = need;
        }
      }
    }
    return [
      if (background == null)
        A11yIssue(
          rule: A11yRule.contrastOverImage,
          slideId: sid,
          elementId: e.id,
        )
      else if (worst != null)
        A11yIssue(
          rule: A11yRule.lowContrast,
          slideId: sid,
          elementId: e.id,
          ratio: worst,
          required: worstRequired,
        ),
      if (minSize != null)
        A11yIssue(
          rule: A11yRule.smallText,
          slideId: sid,
          elementId: e.id,
          size: minSize,
        ),
    ];
  }

  /// The opaque color behind [e]'s text (03 §17.4), or null when it is an
  /// image: [e]'s own fill (composited over what is behind it), else the
  /// topmost filled element of [painted] below [e] containing its center,
  /// else the slide background.
  static int? backgroundOf(
    ResolvedSlide slide,
    ResolvedElement e,
    List<ResolvedElement> painted,
  ) {
    final theme = slide.theme;
    final base =
        theme.colorOf('bg1') ??
        (theme.appearance == SlideAppearance.dark ? 0xff000000 : 0xffffffff);
    final bgFill = slide.background.fill;
    int? behind = bgFill is ResolvedImageFill
        ? null
        : slide.background.effectiveColor(base);
    final index = painted.indexWhere((x) => x.id == e.id);
    final cx = e.frame.x + e.frame.width / 2;
    final cy = e.frame.y + e.frame.height / 2;
    for (var i = 0; i < (index < 0 ? painted.length : index); i++) {
      final x = painted[i];
      if (x.hidden || x.record.kind == ElementKind.group) continue;
      if (!_contains(x, cx, cy)) continue;
      if (x.record.kind == ElementKind.image) {
        behind = null;
        continue;
      }
      final fill = _fillOf(theme, x);
      if (fill is ResolvedImageFill) {
        behind = null;
      } else if (ScenePaint.visible(fill)) {
        final c = _withOpacity(fill.representativeColor!, x.opacity);
        behind = behind == null && (c >>> 24) != 0xff
            ? null
            : compositeOver(c, behind ?? 0xffffffff);
      }
    }
    final own = _fillOf(theme, e);
    if (own is ResolvedImageFill) return null;
    if (ScenePaint.visible(own)) {
      final c = _withOpacity(own.representativeColor!, e.opacity);
      if ((c >>> 24) == 0xff) return c;
      if (behind == null) return null;
      return compositeOver(c, behind);
    }
    return behind;
  }

  /// Whether ([cx], [cy]) is inside [x]: its frame, and for an unrotated
  /// ellipse the ellipse itself (a round decoration whose frame corner
  /// reaches under text isn't behind it).
  static bool _contains(ResolvedElement x, double cx, double cy) {
    final f = x.frame;
    if (cx < f.x || cx > f.right || cy < f.y || cy > f.bottom) return false;
    if (x.record.kind != ElementKind.shape || x.rotation != 0) {
      return true;
    }
    final data = x.record.dataJson;
    if (data == null || !data.contains('"ellipse"')) return true;
    final Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on FormatException {
      return true;
    }
    if (decoded is! Map || decoded['geometry'] != 'ellipse') return true;
    final rx = f.width / 2, ry = f.height / 2;
    if (rx <= 0 || ry <= 0) return true;
    final dx = (cx - f.x - rx) / rx, dy = (cy - f.y - ry) / ry;
    return dx * dx + dy * dy <= 1;
  }

  static ResolvedFill _fillOf(ResolvedTheme theme, ResolvedElement e) {
    final kind = e.record.kind;
    if (kind != ElementKind.shape && kind != ElementKind.text) {
      return kind == ElementKind.table || kind == ElementKind.code
          ? const ResolvedNoFill()
          : ScenePaint.fill(theme, e.fill);
    }
    final defaults = kind == ElementKind.shape
        ? theme.shapeStyles.shape
        : theme.shapeStyles.text;
    return ScenePaint.fill(theme, e.fill, fallback: defaults.fill);
  }

  static int _withOpacity(int argb, double opacity) {
    if (opacity >= 1) return argb;
    final a = (((argb >>> 24) & 0xff) * opacity.clamp(0, 1)).round();
    return (a << 24) | (argb & 0xffffff);
  }

  /// Master, layout and slide elements in painting order (group children
  /// after their group).
  static List<ResolvedElement> _painted(ResolvedSlide slide) =>
      slide.painted.toList();

  /// Whether a custom reading order differs strongly from the automatic
  /// one: the title isn't read first, or more than a third of the element
  /// pairs are swapped (at least 3 elements).
  static bool _readingOrderDiffers(ResolvedSlide slide) {
    final els = slide.elements;
    if (!els.any((e) => e.record.readingKey != null)) return false;
    final h = slide.bounds.height;
    final custom = [for (final e in ReadingOrder.of(els, slideHeight: h)) e.id];
    final auto = [
      for (final e in ReadingOrder.of(els, slideHeight: h, custom: false)) e.id,
    ];
    final title = els
        .where((e) => e.placeholderType == SlidePlaceholderType.title)
        .firstOrNull;
    if (title != null &&
        custom.isNotEmpty &&
        custom.first != title.id &&
        auto.isNotEmpty &&
        auto.first == title.id) {
      return true;
    }
    final n = custom.length;
    if (n < 3) return false;
    final pos = {for (final (i, id) in auto.indexed) id: i};
    var inversions = 0;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if ((pos[custom[i]] ?? 0) > (pos[custom[j]] ?? 0)) inversions++;
      }
    }
    return inversions / (n * (n - 1) / 2) > 1 / 3;
  }

  // ------------------------------------------------------------ text runs

  static List<_Para> _paragraphs(String? json) {
    if (json == null) return const [];
    final List<Object?> ops;
    try {
      final v = jsonDecode(json);
      if (v is! List) return const [];
      ops = v;
    } on FormatException {
      return const [];
    }
    final out = <_Para>[];
    var runs = <_Run>[];
    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = op['attributes'] is Map
          ? (op['attributes'] as Map).cast<String, Object?>()
          : const <String, Object?>{};
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) runs.add(_Run(parts[i], attrs));
        if (i < parts.length - 1) {
          out.add(_Para(runs, attrs));
          runs = <_Run>[];
        }
      }
    }
    if (runs.isNotEmpty) out.add(_Para(runs, const {}));
    return out;
  }
}

/// The quick fixes of the checker (`slides.a11y.fix`, 03 §17.4): the
/// operations that resolve an issue, run as one undo step.
abstract final class A11yFixes {
  /// Text colors tried for low contrast, theme colors first.
  static const contrastCandidates = [
    'theme:text1',
    'theme:bg1',
    'theme:text2',
    'theme:bg2',
    '#000000',
    '#FFFFFF',
  ];

  /// The operations fixing [issue] in [model], or null when it has no
  /// automatic fix (alt text needs a text or *Decorative*: the command
  /// handles it).
  static List<SlidesOperation>? opsFor(
    DeckModel model,
    A11yIssue issue, {
    SlideResolver? resolver,
  }) {
    final id = issue.elementId;
    switch (issue.rule) {
      case A11yRule.readingOrder:
        return [SetReadingOrder(issue.slideId, const [])];
      case A11yRule.tableHeader:
        if (id == null) return null;
        return [
          SetTableOptions(id, const {
            'options': {'headerRow': true},
          }),
        ];
      case A11yRule.emptyPlaceholder:
        if (id == null) return null;
        return [
          DeleteElements([id]),
        ];
      case A11yRule.smallText:
        if (id == null) return null;
        final ranges = smallRanges(model, issue.slideId, id, resolver);
        if (ranges.isEmpty) return null;
        return [
          for (final (start, length) in ranges)
            FormatText(
              [ElementText(id)],
              const {'size': AccessibilityChecker.minTextSize},
              start: start,
              length: length,
            ),
        ];
      case A11yRule.lowContrast:
        if (id == null) return null;
        final color = contrastColor(
          model,
          issue.slideId,
          id,
          resolver: resolver,
        );
        if (color == null) return null;
        return [
          FormatText([ElementText(id)], {'color': color}),
        ];
      case A11yRule.missingAltText ||
          A11yRule.contrastOverImage ||
          A11yRule.missingTitle ||
          A11yRule.duplicateTitle:
        return null;
    }
  }

  /// The first of [contrastCandidates] that meets the required contrast on
  /// element [elementId]'s background (else the one with the best ratio).
  static String? contrastColor(
    DeckModel model,
    String slideId,
    String elementId, {
    SlideResolver? resolver,
  }) {
    final slide = (resolver ?? SlideResolver(model)).resolve(slideId);
    final e = slide?.element(elementId);
    if (slide == null || e == null) return null;
    final bg = AccessibilityChecker.backgroundOf(
      slide,
      e,
      slide.painted.toList(),
    );
    if (bg == null) return null;
    String? best;
    var bestRatio = 0.0;
    for (final c in contrastCandidates) {
      final argb = slide.theme.colorString(c);
      final ratio = ThemeContrast.ratio(argb, bg);
      if (ratio + 1e-9 >= AccessibilityChecker.normalContrast) return c;
      if (ratio > bestRatio) {
        bestRatio = ratio;
        best = c;
      }
    }
    return best;
  }

  /// `(start, length)` character ranges of [elementId]'s text set smaller
  /// than [AccessibilityChecker.minTextSize].
  static List<(int, int)> smallRanges(
    DeckModel model,
    String slideId,
    String elementId, [
    SlideResolver? resolver,
  ]) {
    final slide = (resolver ?? SlideResolver(model)).resolve(slideId);
    final e = slide?.element(elementId);
    if (slide == null || e == null || e.textStyles == null) return const [];
    final theme = slide.theme;
    final defaults = e.record.kind == ElementKind.shape
        ? theme.shapeStyles.shape
        : theme.shapeStyles.text;
    final styles = e.textStyles!.withBox(
      (defaults.textStyle ?? BoxTextStyle.empty).merge(e.textStyle),
    );
    final resolver0 = TextStyleResolver();
    final out = <(int, int)>[];
    var offset = 0;
    for (final para in AccessibilityChecker._paragraphs(e.text)) {
      for (final run in para.runs) {
        final size = resolver0
            .run(theme, styles, block: para.block, inline: run.attributes)
            .size;
        if (size < AccessibilityChecker.minTextSize &&
            run.text.trim().isNotEmpty) {
          if (out.isNotEmpty && out.last.$1 + out.last.$2 == offset) {
            out[out.length - 1] = (out.last.$1, out.last.$2 + run.text.length);
          } else {
            out.add((offset, run.text.length));
          }
        }
        offset += run.text.length;
      }
      offset += 1; // The paragraph's "\n".
    }
    return out;
  }
}

class _Run {
  const _Run(this.text, this.attributes);

  final String text;
  final Map<String, Object?> attributes;
}

class _Para {
  const _Para(this.runs, this.block);

  final List<_Run> runs;
  final Map<String, Object?> block;

  String get text => runs.map((r) => r.text).join();
}
