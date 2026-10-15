/// Composes `CodeScene`s from a `CodeElementModel` (Slides 07 §3.3–§5): the
/// box geometry and auto size, colored runs on the monospace grid, highlight
/// styles and step transitions, focus scrolling/zoom, callout anchors, and
/// the frames of type-in, morph and instant transitions.
library;

import 'dart:math' as math;

import 'package:wonky_code/wonky_code.dart';

import '../scene/nodes/code_scene.dart';
import '../theme/model/common.dart';
import 'code_element_data.dart';
import 'code_element_model.dart';

/// The resolved look of a code element (palette, font, theme defaults);
/// `CodeElementLayout` derives it from the deck theme.
final class CodeRenderStyle {
  const CodeRenderStyle({
    required this.palette,
    this.fontFamily = MonoFontMetrics.defaultFamily,
    this.metrics = MonoFontMetrics.jetBrainsMono,
    this.chromeDefault = 'window',
    this.cornerRadius = 16,
    this.shadow = 'soft',
    this.boxBackground,
    this.boxBorder,
    this.borderWidth = 1,
    this.barColorOverride,
    this.calloutColor,
    this.calloutTextColor,
    this.calloutFontFamily,
  });

  final SyntaxPalette palette;
  final String fontFamily;
  final MonoFontMetrics metrics;

  /// The theme's default chrome (`dataJson.chrome` overrides it).
  final String chromeDefault;

  /// Corner radius (su; the element's `box.cornerRadius` or the theme's).
  final double cornerRadius;

  /// `none`, `soft`, `strong`.
  final String shadow;

  /// The element's `box.background` (ARGB), or null = palette.
  final int? boxBackground;

  /// The element's `box.border` color (ARGB), or null = palette.
  final int? boxBorder;

  /// su.
  final double borderWidth;

  /// The element's `highlightStyle.barColor` (ARGB), or null = palette.
  final int? barColorOverride;

  /// Callout bubble color (the deck theme's accent, 07 §4.4; ARGB), or
  /// null = the palette's caret color (SL-31).
  final int? calloutColor;

  /// Callout text color on [calloutColor] (ARGB), or null = contrasting
  /// black or white (SL-31).
  final int? calloutTextColor;

  /// Callout font family (the deck's body font), or null = the code font
  /// (SL-31).
  final String? calloutFontFamily;

  /// The callout bubble color (ARGB).
  int get calloutFill => calloutColor ?? palette.caret;

  /// The callout text color (ARGB): [calloutTextColor] or black/white,
  /// whichever contrasts more with [calloutFill].
  int get calloutInk =>
      calloutTextColor ??
      (SyntaxPalette.contrastRatio(calloutFill, 0xff000000) >=
              SyntaxPalette.contrastRatio(calloutFill, 0xffffffff)
          ? 0xff000000
          : 0xffffffff);

  /// Box background (ARGB).
  int get background => boxBackground ?? palette.background;

  /// Box border (ARGB).
  int get border => boxBorder ?? palette.border;

  /// Highlight bar color (ARGB).
  int get barColor => barColorOverride ?? palette.highlightBar;
}

/// Composes scenes for one model and style (cache it per element revision
/// and theme; fits are memoized per frame size).
final class CodeSceneComposer {
  /// Creates a composer.
  CodeSceneComposer(this.model, this.style);

  final CodeElementModel model;
  final CodeRenderStyle style;

  final _fits = <Object, CodeFit>{};

  CodeElementData get data => model.data;

  /// Rise of an entering callout (su, 07 §4.4).
  static const calloutRise = 12.0;

  // -------------------------------------------------------------------
  // Geometry

  bool get _anyTitle => model.states.any((s) => s.title != null);

  /// Whether the title area is drawn for [state] (fitting across states
  /// keeps it for every state, so the code never jumps).
  bool titled(int state) =>
      data.fitAcrossStates ? _anyTitle : model.state(state).title != null;

  /// Box options at [state] (the gutter covers the largest line number of
  /// [states]).
  CodeBoxOptions boxOptions(int state, {Iterable<int>? states}) {
    final ids = states ?? [state];
    var lines = 1;
    for (final i in ids) {
      lines = math.max(lines, model.state(i).lineCount);
    }
    return CodeBoxOptions(
      chrome: data.chromeOr(style.chromeDefault),
      hasTitle: titled(state),
      padding: data.padding,
      lineNumbers: data.lineNumbers,
      lastLineNumber: data.startLine + lines - 1,
      lineHeight: data.lineHeight,
      tabSize: data.tabSize,
      wrap: data.wrap,
      metrics: style.metrics,
      fontSizeMin: data.fontSizeMin,
      fontSizeMax: data.fontSizeMax,
    );
  }

  /// The states whose text the size must fit when showing [states].
  List<int> _fitting(Iterable<int> states) => data.fitAcrossStates
      ? List.generate(model.stateCount, (i) => i)
      : [
          for (final i in states)
            if (i >= 0) i,
        ];

  /// Font size (su) when showing [states] (one state, or both ends of a
  /// transition) in a [width] × [height] frame (07 §3.3).
  CodeFit fit(double width, double height, List<int> states) {
    final fitting = _fitting(states);
    final key = (width, height, fitting.join(','), titled(states.last));
    return _fits[key] ??= () {
      if (data.fontSize case final s?) {
        final g = CodeBoxGeometry.compute(
          width,
          height,
          s,
          boxOptions(states.last, states: fitting),
        );
        var rows = 0, cols = 0;
        for (final i in fitting) {
          final l = CodeLayout.layout(model.state(i).code, g.layoutOptions());
          rows = math.max(rows, l.rowCount);
          cols = math.max(cols, l.maxColumns);
        }
        return CodeFit(
          fontSize: s,
          fits: rows <= g.visibleRows,
          rows: rows,
          columns: cols,
        );
      }
      return CodeAutoFit.fit(
        [for (final i in fitting) model.state(i).code],
        width,
        height,
        boxOptions(states.last, states: fitting),
      );
    }();
  }

  /// The box geometry of [state] at [fontSize].
  CodeBoxGeometry geometry(
    double width,
    double height,
    double fontSize,
    int state, {
    Iterable<int>? states,
  }) => CodeBoxGeometry.compute(
    width,
    height,
    fontSize,
    boxOptions(state, states: _fitting(states ?? [state])),
  );

  // -------------------------------------------------------------------
  // Static scenes (a state and a highlight step)

  /// The scene of [state] with highlight [step] (0-based; null = none). A
  /// step change animates from [fromStep] with eased [stepMix] (0..1);
  /// [dimming] false draws no highlight (the print frame); [vectorOnly]
  /// renders `blur` as `dim` 0.45 (PDF, 07 §4.2); [calloutProgress] fades
  /// and lifts the step's callout in.
  CodeScene build(
    int state, {
    int? step,
    int? fromStep,
    double stepMix = 1,
    required double width,
    required double height,
    bool dimming = true,
    bool vectorOnly = false,
    double calloutProgress = 1,
    double opacity = 1,
    CodeScene? underlay,
    double underlayOpacity = 0,
  }) {
    final s = model.state(state);
    final toStep = dimming ? s.steps[step ?? -1] : null;
    final fromStepObj = dimming && fromStep != null ? s.steps[fromStep] : null;
    final e = _easeInOut(fromStep == null ? 1 : stepMix);
    final base = fit(width, height, [state]).fontSize;
    final (size0, scroll0) = _focus(s, fromStepObj, width, height, base, state);
    final (size1, scroll1) = _focus(s, toStep, width, height, base, state);
    final fontSize = size0 + (size1 - size0) * e;
    final scrollY = scroll0 + (scroll1 - scroll0) * e;
    final g = geometry(width, height, fontSize, state);
    final layout = CodeLayout.layout(s.code, g.layoutOptions());
    final tokens = model.tokensOf(state);

    LineLook lookAt(int line) {
      final a = _look(fromStepObj, line, vectorOnly);
      final b = _look(toStep, line, vectorOnly);
      return LineLook.lerp(a, b, e);
    }

    final rows = _rows(
      layout,
      tokens,
      g,
      scrollY: scrollY,
      scrollX: 0,
      look: lookAt,
    );
    final bars = <CodeBar>[
      ..._stepBars(layout, g, scrollY, fromStepObj, toStep, e),
    ];
    final callouts = <CodeCalloutPlacement>[
      if (fromStep != null && fromStep != step && e < 1)
        ?_callout(s, fromStep, fromStepObj, layout, g, scrollY, 1 - e, 0),
      if (step != null)
        ?_callout(
          s,
          step,
          toStep,
          layout,
          g,
          scrollY,
          calloutProgress.clamp(0.0, 1.0),
          calloutRise * (1 - calloutProgress.clamp(0.0, 1.0)),
        ),
    ];
    return _scene(
      state: state,
      step: step,
      g: g,
      layout: layout,
      lines: rows,
      scrollY: scrollY,
      bars: bars,
      callouts: dimming ? callouts : const [],
      opacity: opacity,
      underlay: underlay,
      underlayOpacity: underlayOpacity,
    );
  }

  // -------------------------------------------------------------------
  // Transitions (07 §5)

  /// The frame [ms] into the change from state [from] (−1 = empty, the
  /// `codeType` in-build) to [to] in the effective mode (07 §5.1, §6).
  /// After the transition ends the static scene of [to] is returned (with
  /// [arrivalStep], when given).
  CodeScene buildTransition({
    required int from,
    required int to,
    required num ms,
    required double width,
    required double height,
    CodeTransitionMode? mode,
    bool reducedMotion = false,
    int? arrivalStep,
  }) {
    final m = from < 0
        ? (reducedMotion ? CodeTransitionMode.instant : CodeTransitionMode.type)
        : model.modeOf(from, to, override: mode, reducedMotion: reducedMotion);
    return switch (m) {
      CodeTransitionMode.type => buildTyping(
        from: from,
        to: to,
        ms: ms,
        width: width,
        height: height,
        arrivalStep: arrivalStep,
      ),
      CodeTransitionMode.morph => buildMorph(
        from: from,
        to: to,
        ms: ms,
        width: width,
        height: height,
        arrivalStep: arrivalStep,
      ),
      CodeTransitionMode.instant => buildInstant(
        from: from,
        to: to,
        ms: ms,
        width: width,
        height: height,
        arrivalStep: arrivalStep,
      ),
    };
  }

  /// Crossfade (07 §5.1 `instant`, 200 ms; reduced motion).
  CodeScene buildInstant({
    required int from,
    required int to,
    required num ms,
    required double width,
    required double height,
    int? arrivalStep,
  }) {
    final p = (ms / CodeElementModel.instantMs).clamp(0.0, 1.0);
    if (p >= 1 || from == to) {
      return build(to, step: arrivalStep, width: width, height: height);
    }
    final under = from < 0 ? null : build(from, width: width, height: height);
    return build(
      to,
      width: width,
      height: height,
      opacity: p,
      underlay: under,
      underlayOpacity: under == null ? 0 : 1,
    );
  }

  /// A type-in frame (07 §5.3–§5.5).
  CodeScene buildTyping({
    required int from,
    required int to,
    required num ms,
    required double width,
    required double height,
    int? arrivalStep,
  }) {
    final script = model.typingScript(from, to);
    if (ms >= script.durationMs) {
      return build(to, step: arrivalStep, width: width, height: height);
    }
    final target = model.state(to);
    final ends = [if (from >= 0) from, to];
    final fontSize = fit(width, height, ends).fontSize;
    final g = geometry(width, height, fontSize, to, states: ends);
    final f = script.stateAt(ms);
    final layout = CodeLayout.layout(f.text, g.layoutOptions());
    final tokens = model.tokensFor(f.text, target.language);
    final settings = target.arrival;
    final colW = layout.columnWidth, rowH = layout.rowHeight;

    // Caret position (glide from the previous one).
    CodeRect caretCell(int offset) => layout.rectOfRange(offset, offset);
    var cell = caretCell(f.caret);
    if (f.caretFrom != null && f.caretGlide < 1) {
      final from0 = caretCell(f.caretFrom!.clamp(0, f.text.length));
      cell = CodeRect.lerp(from0, cell, f.caretGlide);
    }

    // Scroll follow (07 §5.5): keep the caret 2 rows from the edges.
    var scrollY = 0.0, scrollX = 0.0;
    if (settings.scrollFollow) {
      final viewH = g.codeArea.height, viewW = g.codeArea.width;
      final maxY = math.max(0.0, layout.height - viewH);
      scrollY = (cell.top + 3 * rowH - viewH).clamp(0.0, maxY);
      final maxX = math.max(0.0, layout.width + colW - viewW);
      scrollX = (cell.left + 2 * colW - viewW).clamp(0.0, maxX);
    }

    final fades = [
      for (final fade in f.fades) (fade.start, fade.end, fade.opacity),
    ];
    final rows = _rows(
      layout,
      tokens,
      g,
      scrollY: scrollY,
      scrollX: scrollX,
      look: (_) => LineLook.normal,
      fades: fades,
    );
    final bars = <CodeBar>[
      if (f.selectionStart != null && f.selectionEnd != null)
        for (final r in layout.rectsOfRange(f.selectionStart!, f.selectionEnd!))
          CodeBar(
            kind: CodeBarKind.selection,
            rect: _local(g, r, scrollX, scrollY),
            color: style.palette.selection,
            radius: 2,
          ),
    ];
    final caretRect = switch (settings.caret) {
      TypingCaret.bar => CodeRect(cell.left - 1, cell.top, 2, cell.height),
      TypingCaret.block => CodeRect(cell.left, cell.top, colW, cell.height),
      TypingCaret.underline => CodeRect(cell.left, cell.bottom - 2, colW, 2),
    };
    return _scene(
      state: to,
      step: null,
      g: g,
      layout: layout,
      lines: rows,
      scrollY: scrollY,
      scrollX: scrollX,
      bars: bars,
      caret: f.caretOpacity <= 0
          ? null
          : CodeCaret(
              rect: _local(g, caretRect, scrollX, scrollY),
              color: style.palette.caret,
              opacity: f.caretOpacity,
              style: settings.caret.name,
            ),
    );
  }

  /// A morph frame (07 §5.6).
  CodeScene buildMorph({
    required int from,
    required int to,
    required num ms,
    required double width,
    required double height,
    int? arrivalStep,
  }) {
    if (from < 0) {
      return buildInstant(
        from: from,
        to: to,
        ms: ms,
        width: width,
        height: height,
        arrivalStep: arrivalStep,
      );
    }
    final ends = [from, to];
    final fontSize = fit(width, height, ends).fontSize;
    final g = geometry(width, height, fontSize, to, states: ends);
    final la = CodeLayout.layout(model.state(from).code, g.layoutOptions());
    final lb = CodeLayout.layout(model.state(to).code, g.layoutOptions());
    final plan = model.morphPlan(from, to, la, lb);
    if (ms >= plan.totalDurationMs) {
      return build(to, step: arrivalStep, width: width, height: height);
    }
    final e = TokenMorphPlan.easeInOutCubic(ms / plan.totalDurationMs);
    final palette = style.palette;
    final glyphs = <CodePlacedRun>[];
    for (final m in plan.frameAt(ms)) {
      final c0 = palette.styleOf(m.lexeme.fromToken ?? m.lexeme.toToken);
      final c1 = palette.styleOf(m.lexeme.toToken ?? m.lexeme.fromToken);
      final st = m.colorMix < 0.5 ? c0 : c1;
      final metrics = style.metrics;
      glyphs.add(
        CodePlacedRun(
          text: CodeColumns.expandTabs(m.lexeme.text, tabSize: data.tabSize),
          x: g.codeArea.left + m.x,
          baseline:
              g.codeArea.top +
              m.y +
              metrics.baselineInRow(m.fontSize, data.lineHeight),
          color: oklabLerp(c0.color, c1.color, m.colorMix),
          fontSize: m.fontSize,
          opacity: m.opacity,
          bold: st.bold,
          italic: st.italic,
        ),
      );
    }
    final gutter = <CodeGutterLabel>[];
    if (g.numbersRight != null) {
      void numbers(CodeLayout l, double opacity) {
        if (opacity <= 0) return;
        for (var r = 0; r < l.rowCount; r++) {
          final top = l.yOf(r);
          if (top > g.codeArea.height) break;
          final row = l.rows[r];
          gutter.add(
            CodeGutterLabel(
              text: row.continuation ? '↪' : '${data.startLine + row.line}',
              baseline: g.codeArea.top + l.baselineOf(r),
              color: palette.lineNumber,
              opacity: opacity,
            ),
          );
        }
      }

      numbers(la, 1 - e);
      numbers(lb, e);
    }
    return _scene(
      state: to,
      step: null,
      g: g,
      layout: lb,
      lines: const [],
      scrollY: 0,
      glyphs: glyphs,
      gutter: gutter,
    );
  }

  // -------------------------------------------------------------------
  // Internals

  /// The font size and scroll that bring [step]'s lines into view when the
  /// code overflows (07 §4.3).
  (double, double) _focus(
    CodeStateModel s,
    HighlightStep? step,
    double width,
    double height,
    double base,
    int state,
  ) {
    var size = base;
    var g = geometry(width, height, size, state);
    var layout = CodeLayout.layout(s.code, g.layoutOptions());
    final viewH = g.codeArea.height;
    if (layout.height <= viewH + 1e-6 ||
        step == null ||
        step.isAll ||
        data.highlightStyle.focus == CodeFocusMode.none) {
      return (size, 0.0);
    }
    (double, double) range(CodeLayout l) {
      final lines = step.lines.where((x) => x <= l.lineCount).toList();
      if (lines.isEmpty) return (0, 0);
      final r = l.rectOfLines(lines.first - 1, lines.last - 1);
      return (r.top, r.bottom);
    }

    if (data.highlightStyle.focus == CodeFocusMode.zoom) {
      final (t, b) = range(layout);
      final h = b - t;
      if (h > 0) {
        final target = h > viewH ? viewH : (h < 0.6 * viewH ? 0.6 * viewH : h);
        size = (size * target / h).clamp(
          data.fontSizeMin,
          data.fontSizeMax * 1.5,
        );
        g = geometry(width, height, size, state);
        layout = CodeLayout.layout(s.code, g.layoutOptions());
      }
    }
    final (t, b) = range(layout);
    final view = g.codeArea.height;
    final maxScroll = math.max(0.0, layout.height - view);
    final scroll = b - t > view ? t : (t + b) / 2 - view / 2;
    return (size, scroll.clamp(0.0, maxScroll));
  }

  LineLook _look(HighlightStep? step, int line, bool vectorOnly) {
    if (step == null || step.isAll) return LineLook.normal;
    if (step.highlights(line)) return LineLook.highlight;
    final h = data.highlightStyle;
    final dimO = h.dimOpacity;
    return switch (h.style) {
      CodeHighlightStyleKind.dim => LineLook(dimO, 0, dimmed: true),
      CodeHighlightStyleKind.blur =>
        vectorOnly
            ? const LineLook(0.45, 0, dimmed: true)
            : LineLook(0.6, h.blurSigma, dimmed: true),
      CodeHighlightStyleKind.dimBlur =>
        vectorOnly
            ? LineLook(math.min(dimO, 0.45), 0, dimmed: true)
            : LineLook(dimO, h.blurSigma, dimmed: true),
      CodeHighlightStyleKind.box => const LineLook(0.6, 0, dimmed: true),
      CodeHighlightStyleKind.bar ||
      CodeHighlightStyleKind.none => LineLook.normal,
    };
  }

  /// Rows intersecting the viewport, as [CodeLine]s with grid-placed runs.
  List<CodeLine> _rows(
    CodeLayout layout,
    List<CodeToken> tokens,
    CodeBoxGeometry g, {
    required double scrollY,
    required double scrollX,
    required LineLook Function(int line) look,
    List<(int, int, double)> fades = const [],
  }) {
    final code = layout.code;
    final palette = style.palette;
    final chromeHeight = g.captionHeight + g.titleHeight;
    final rowH = layout.rowHeight;
    final baselineIn = style.metrics.baselineInRow(
      layout.options.fontSize,
      layout.options.lineHeight,
    );
    final out = <CodeLine>[];
    var t = 0;
    for (var r = 0; r < layout.rowCount; r++) {
      final top = layout.yOf(r) - scrollY;
      if (top + rowH <= 0) continue;
      if (top >= g.codeArea.height) break;
      final row = layout.rows[r];
      final runs = <CodeRun>[];
      void add(int a, int b, SyntaxToken? token) {
        if (b <= a) return;
        // Split at fade boundaries.
        final cuts = <int>{a, b};
        for (final (fs, fe, _) in fades) {
          if (fs > a && fs < b) cuts.add(fs);
          if (fe > a && fe < b) cuts.add(fe);
        }
        final points = cuts.toList()..sort();
        final st = token == null
            ? TokenStyle(palette.text)
            : palette.styleOf(token);
        for (var i = 0; i < points.length - 1; i++) {
          final x = points[i], y = points[i + 1];
          var opacity = 1.0;
          for (final (fs, fe, o) in fades) {
            if (x >= fs && y <= fe) opacity = o;
          }
          final col = row.columnOf(x);
          runs.add(
            CodeRun(
              CodeColumns.expandTabs(
                code.substring(x, y),
                tabSize: layout.options.tabSize,
                startColumn: col,
              ),
              color: st.color,
              bold: st.bold,
              italic: st.italic,
              column: col,
              opacity: opacity,
            ),
          );
        }
      }

      while (t < tokens.length && tokens[t].end <= row.start) {
        t++;
      }
      var pos = row.start;
      var k = t;
      while (k < tokens.length && tokens[k].start < row.end) {
        final tk = tokens[k];
        final s = math.max(tk.start, row.start), e = math.min(tk.end, row.end);
        add(pos, s, null);
        add(s, e, tk.token);
        pos = e;
        if (tk.end > row.end) break;
        k++;
      }
      add(pos, row.end, null);
      final l = look(row.line + 1);
      out.add(
        CodeLine(
          number: data.startLine + row.line,
          runs: runs,
          y: g.codeArea.top + top + baselineIn - chromeHeight,
          dimmed: l.dimmed,
          highlighted: l.highlighted,
          index: row.line,
          row: r,
          continuation: row.continuation,
          opacity: l.opacity,
          blurSigma: l.blur,
        ),
      );
    }
    return out;
  }

  SuRect _local(
    CodeBoxGeometry g,
    CodeRect r,
    double scrollX,
    double scrollY,
  ) => SuRect(
    g.codeArea.left + r.left - scrollX,
    g.codeArea.top + r.top - scrollY,
    math.max(r.width, 0.0001),
    math.max(r.height, 0.0001),
  );

  /// Highlight bars/boxes and gutter markers of a step change.
  List<CodeBar> _stepBars(
    CodeLayout layout,
    CodeBoxGeometry g,
    double scrollY,
    HighlightStep? from,
    HighlightStep? to,
    double e,
  ) {
    final a = _barsOf(layout, g, scrollY, from);
    final b = _barsOf(layout, g, scrollY, to);
    if (e >= 1) return b;
    if (e <= 0) return a;
    final same =
        a.length == b.length &&
        Iterable<int>.generate(a.length).every((i) => a[i].kind == b[i].kind);
    if (same) {
      return [
        for (var i = 0; i < a.length; i++)
          CodeBar(
            kind: b[i].kind,
            rect: _lerpRect(a[i].rect, b[i].rect, e),
            color: b[i].color,
            radius: b[i].radius,
            strokeWidth: b[i].strokeWidth,
          ),
      ];
    }
    return [
      for (final x in a)
        CodeBar(
          kind: x.kind,
          rect: x.rect,
          color: x.color,
          opacity: 1 - e,
          radius: x.radius,
          strokeWidth: x.strokeWidth,
        ),
      for (final x in b)
        CodeBar(
          kind: x.kind,
          rect: x.rect,
          color: x.color,
          opacity: e,
          radius: x.radius,
          strokeWidth: x.strokeWidth,
        ),
    ];
  }

  List<CodeBar> _barsOf(
    CodeLayout layout,
    CodeBoxGeometry g,
    double scrollY,
    HighlightStep? step,
  ) {
    if (step == null || step.isAll) return const [];
    final h = data.highlightStyle;
    if (h.style == CodeHighlightStyleKind.none) return const [];
    final colW = layout.columnWidth;
    final out = <CodeBar>[];
    final blocks = step.blocks.where((b) => b.$1 <= layout.lineCount).toList();
    for (final (first, last) in blocks) {
      final r = layout.rectOfLines(
        first - 1,
        math.min(last, layout.lineCount) - 1,
      );
      final top = g.codeArea.top + r.top - scrollY;
      if (h.style == CodeHighlightStyleKind.bar) {
        // Column ranges draw only their columns.
        final cols = step.ranges.where(
          (x) => x.isColumnRange && x.first >= first && x.first <= last,
        );
        if (cols.isNotEmpty && first == last) {
          for (final c in cols) {
            out.add(
              CodeBar(
                kind: CodeBarKind.bar,
                rect: SuRect(
                  g.codeArea.left + (c.startColumn! - 1) * colW,
                  top,
                  (c.endColumn! - c.startColumn! + 1) * colW,
                  r.height,
                ),
                color: style.barColor,
              ),
            );
          }
        } else {
          out.add(
            CodeBar(
              kind: CodeBarKind.bar,
              rect: SuRect(
                g.codeArea.left - colW / 2,
                top,
                g.codeArea.width + colW,
                r.height,
              ),
              color: style.barColor,
            ),
          );
        }
      } else if (h.style == CodeHighlightStyleKind.box) {
        var cols = 0;
        for (var l = first; l <= math.min(last, layout.lineCount); l++) {
          final line = layout.lines[l - 1];
          for (var row = line.firstRow; row <= line.lastRow; row++) {
            cols = math.max(cols, layout.rows[row].columns);
          }
        }
        out.add(
          CodeBar(
            kind: CodeBarKind.box,
            rect: SuRect(
              g.codeArea.left - colW / 2,
              top,
              math.min(cols * colW + colW, g.codeArea.width + colW),
              r.height,
            ),
            color: style.palette.caret,
            radius: 6,
            strokeWidth: 2,
          ),
        );
      }
      if (h.gutterMarker && g.numbersRight != null) {
        out.add(
          CodeBar(
            kind: CodeBarKind.gutterMarker,
            rect: SuRect(g.box.left + data.padding / 2 - 1.5, top, 3, r.height),
            color: style.palette.lineNumberActive,
            radius: 1.5,
          ),
        );
      }
    }
    return out;
  }

  /// The callout of [stepIndex] (07 §4.4), or null.
  CodeCalloutPlacement? _callout(
    CodeStateModel s,
    int stepIndex,
    HighlightStep? step,
    CodeLayout layout,
    CodeBoxGeometry g,
    double scrollY,
    double opacity,
    double rise,
  ) {
    final c = s.annotations[stepIndex];
    if (c == null || opacity <= 0) return null;
    final lines =
        step?.lines.where((l) => l <= layout.lineCount).toList() ?? [];
    final anchor = (c.anchorLine ?? (lines.isEmpty ? 1 : lines.last)).clamp(
      1,
      layout.lineCount,
    );
    final colW = layout.columnWidth;
    final maxWidth = data.callouts.maxWidth;
    final rangeLines = lines.isEmpty ? [anchor] : lines;
    final range = layout.rectOfLines(rangeLines.first - 1, rangeLines.last - 1);
    var widest = 0;
    for (final l in rangeLines) {
      widest = math.max(widest, layout.lines[l - 1].columns);
    }
    final lineEnd = g.codeArea.left + widest * colW;
    var side = c.side;
    if (side == 'auto') {
      if (g.box.right - lineEnd >= maxWidth / 2) {
        side = 'right';
      } else if (g.box.bottom - (g.codeArea.top + range.bottom - scrollY) >=
          2 * layout.rowHeight) {
        side = 'below';
      } else {
        side = 'above';
      }
    }
    final anchorRect = layout.rectOfLines(anchor - 1, anchor - 1);
    final midY =
        g.codeArea.top + anchorRect.top - scrollY + anchorRect.height / 2;
    final anchorEnd =
        g.codeArea.left + layout.lines[anchor - 1].columns * colW + colW;
    final (x, y) = switch (side) {
      'right' => (anchorEnd, midY),
      'left' => (g.codeArea.left - colW, midY),
      'below' => (g.codeArea.left, g.codeArea.top + range.bottom - scrollY),
      _ => (g.codeArea.left, g.codeArea.top + range.top - scrollY),
    };
    return CodeCalloutPlacement(
      step: stepIndex,
      text: c.text,
      style: c.style ?? data.callouts.style,
      side: side,
      anchorX: x,
      anchorY: y,
      anchorLine: anchor,
      maxWidth: maxWidth,
      fontSize: layout.options.fontSize * 0.9,
      dx: c.dx,
      dy: c.dy,
      opacity: opacity,
      rise: rise,
      color: style.calloutFill,
      textColor: style.calloutInk,
      fontFamily: style.calloutFontFamily ?? style.fontFamily,
    );
  }

  CodeScene _scene({
    required int state,
    required int? step,
    required CodeBoxGeometry g,
    required CodeLayout layout,
    required List<CodeLine> lines,
    required double scrollY,
    double scrollX = 0,
    List<CodeBar> bars = const [],
    CodeCaret? caret,
    List<CodeCalloutPlacement> callouts = const [],
    List<CodePlacedRun> glyphs = const [],
    List<CodeGutterLabel> gutter = const [],
    double opacity = 1,
    CodeScene? underlay,
    double underlayOpacity = 0,
  }) {
    final s = model.state(state);
    final palette = style.palette;
    final visible = g.visibleRows;
    final hidden = layout.rowCount > visible ? layout.rowCount - visible : 0;
    final chrome = g.options.chrome;
    final showTitle = switch (chrome) {
      CodeChrome.none => false,
      _ => s.title != null && (g.titleHeight > 0 || g.captionHeight > 0),
    };
    return CodeScene(
      width: g.width,
      height: g.height,
      fontFamily: style.fontFamily,
      fontSize: layout.options.fontSize,
      lineHeight: layout.rowHeight,
      background: style.background,
      lines: lines,
      title: showTitle ? s.title : null,
      codeLeft: g.codeArea.left - scrollX,
      numbersRight: g.numbersRight,
      lineNumberColor: palette.lineNumber,
      chromeHeight: g.captionHeight + g.titleHeight,
      titleColor: palette.titleTabText,
      cornerRadius: style.cornerRadius,
      chrome: chrome.name,
      box: SuRect(g.box.left, g.box.top, g.box.width, g.box.height),
      captionHeight: g.captionHeight,
      titleHeight: g.titleHeight,
      titleBackground: palette.titleTabBackground,
      language: data.showLanguage && s.language.isNotEmpty
          ? CodeLanguages.displayName(s.language)
          : null,
      codeArea: SuRect(
        g.codeArea.left,
        g.codeArea.top,
        math.max(g.codeArea.width, 0.0001),
        math.max(g.codeArea.height, 0.0001),
      ),
      columnWidth: layout.columnWidth,
      gutterFontSize: g.gutterFontSize,
      lineNumberActiveColor: palette.lineNumberActive,
      textColor: palette.text,
      border: style.borderWidth > 0 ? style.border : null,
      borderWidth: style.borderWidth,
      shadow: style.shadow,
      scrollX: scrollX,
      scrollY: scrollY,
      hiddenRows: hidden,
      bars: bars,
      caret: caret,
      callouts: callouts,
      glyphs: glyphs,
      gutter: gutter,
      opacity: opacity,
      underlay: underlay,
      underlayOpacity: underlayOpacity,
      ligatures: data.ligatures,
      paletteId: palette.id,
      darkPalette: palette.brightness == PaletteBrightness.dark,
      stateIndex: state.clamp(0, model.stateCount - 1),
      step: step,
      semanticsLabel: model.semanticsLabel(state),
    );
  }

  static SuRect _lerpRect(SuRect a, SuRect b, double t) => SuRect(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.width + (b.width - a.width) * t,
    a.height + (b.height - a.height) * t,
  );

  static double _easeInOut(double x) {
    final t = x.clamp(0.0, 1.0);
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }
}

/// How a line looks under a highlight step.
final class LineLook {
  const LineLook(
    this.opacity,
    this.blur, {
    this.highlighted = false,
    this.dimmed = false,
  });

  static const normal = LineLook(1, 0);
  static const highlight = LineLook(1, 0, highlighted: true);

  final double opacity;

  /// Blur sigma (su).
  final double blur;
  final bool highlighted;
  final bool dimmed;

  /// Interpolates (flags follow the end state from halfway).
  static LineLook lerp(LineLook a, LineLook b, double t) => t >= 1
      ? b
      : t <= 0
      ? a
      : LineLook(
          a.opacity + (b.opacity - a.opacity) * t,
          a.blur + (b.blur - a.blur) * t,
          highlighted: t < 0.5 ? a.highlighted : b.highlighted,
          dimmed: t < 0.5 ? a.dimmed : b.dimmed,
        );
}
