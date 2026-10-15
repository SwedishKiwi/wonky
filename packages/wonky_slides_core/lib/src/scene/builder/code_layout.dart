/// The basic layout of code elements (07 §3, until SL-26's
/// `CodeElementModel`): the state per scene purpose (06 §9.6), tokens from
/// the shared tokenizer, the theme's code palette and mono font, a
/// monospace grid auto-fitted to the box, line numbers and a title bar.
library;

import 'dart:math' as math;

import 'package:wonky_code/wonky_code.dart';

import '../../model/api/deck_reader.dart';
import '../../model/api/resolved.dart';
import '../../theme/resolve/resolved_theme.dart';
import '../nodes/code_scene.dart';
import '../nodes/scene_nodes.dart';

/// Lays out code elements with the core's basic rules.
final class BasicCodeLayout implements CodeSceneSource {
  /// Creates the layout.
  const BasicCodeLayout();

  /// Advance of a monospace character (em).
  static const advance = 0.6;

  /// Line height multiplier.
  static const lineHeight = 1.45;

  @override
  CodeScene? codeScene(
    ResolvedElement element,
    DeckReader? deck,
    ResolvedTheme theme, {
    required double width,
    required double height,
    required ScenePurpose purpose,
    int? stateIndex,
  }) {
    final data = element.data ?? const <String, Object?>{};
    final states = deck?.codeStatesOf(element.id) ?? const [];
    final index =
        stateIndex ??
        switch (purpose) {
          ScenePurpose.thumbnail || ScenePurpose.print => states.length - 1,
          _ => 0,
        };
    final state = states.isEmpty
        ? null
        : states[index.clamp(0, states.length - 1)];
    final code = (state?.code ?? '').replaceAll('\r\n', '\n');
    final language = CodeLanguages.normalize(
      state?.language ?? (data['language'] as String?) ?? '',
    );
    final palette = switch (data['palette']) {
      'light' => theme.codeLight,
      'dark' => theme.codeDark,
      _ => theme.codePalette,
    };
    final lines = code.split('\n');
    final showNumbers = data['lineNumbers'] != false;
    final startLine = (data['startLine'] as num?)?.toInt() ?? 1;
    final title = (state?.title ?? data['title']) as String?;
    final pad = math.max(16.0, math.min(width, height) * 0.05);
    final maxCols = lines.fold<int>(1, (m, l) => math.max(m, _cols(l)));
    final digits = '${startLine + lines.length - 1}'.length;
    final gutterCols = showNumbers ? digits + 2 : 0;
    final explicit = (data['fontSize'] as num?)?.toDouble();
    double chromeFor(double fs) =>
        title == null || data['chrome'] == 'none' ? 0 : fs * 2.2;
    double fontSize;
    if (explicit != null && explicit > 0) {
      fontSize = explicit;
    } else {
      // Fit lines × columns into the box.
      final byWidth = (width - 2 * pad) / ((maxCols + gutterCols) * advance);
      final byHeight = (height - 2 * pad) / (lines.length * lineHeight + 2.2);
      fontSize = math.min(byWidth, byHeight).clamp(8.0, 40.0);
    }
    final chrome = chromeFor(fontSize);
    final advancePx = fontSize * advance;
    final numbersRight = showNumbers ? pad + digits * advancePx : null;
    final codeLeft = pad + gutterCols * advancePx;
    final tokens = language.isEmpty
        ? const <CodeToken>[]
        : DefaultCodeTokenizer.instance.tokenize(code, language);
    final out = <CodeLine>[];
    var lineStart = 0;
    var t = 0;
    for (var i = 0; i < lines.length; i++) {
      final text = lines[i];
      final lineEnd = lineStart + text.length;
      final runs = <CodeRun>[];
      var pos = lineStart;
      void add(int from, int to, SyntaxToken? token) {
        if (to <= from) return;
        final style = palette.styleOf(token);
        runs.add(
          CodeRun(
            _expandTabs(code.substring(from, to)),
            color: style.color,
            bold: style.bold,
            italic: style.italic,
          ),
        );
      }

      while (t < tokens.length && tokens[t].end <= lineStart) {
        t++;
      }
      var k = t;
      while (k < tokens.length && tokens[k].start < lineEnd) {
        final tk = tokens[k];
        final s = math.max(tk.start, lineStart), e = math.min(tk.end, lineEnd);
        add(pos, s, null);
        add(s, e, tk.token);
        pos = e;
        if (tk.end > lineEnd) break;
        k++;
      }
      add(pos, lineEnd, null);
      out.add(
        CodeLine(
          number: startLine + i,
          runs: runs,
          y: pad + (i + 0.78) * fontSize * lineHeight,
        ),
      );
      lineStart = lineEnd + 1;
    }
    return CodeScene(
      width: width,
      height: height,
      fontFamily: theme.font(theme.codeStyle.font).family,
      fontSize: fontSize,
      lineHeight: fontSize * lineHeight,
      background: palette.background,
      lines: out,
      title: chrome > 0 ? title : null,
      codeLeft: codeLeft,
      numbersRight: numbersRight,
      lineNumberColor: palette.lineNumber,
      chromeHeight: chrome,
      titleColor: palette.titleTabText,
      cornerRadius: theme.codeStyle.cornerRadius,
    );
  }

  static int _cols(String line) => _expandTabs(line).length;

  static String _expandTabs(String s) =>
      s.contains('\t') ? s.replaceAll('\t', '    ') : s;
}
