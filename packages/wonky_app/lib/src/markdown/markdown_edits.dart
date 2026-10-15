import 'dart:math' as math;

import 'package:flutter/services.dart';

/// The plain-text Markdown transforms of [MarkdownComposer]'s toolbar
/// (specs/16 §7.3), following the conventions of `wonky_rich_text`'s
/// `InlineMarkdownWriter`: `**bold**`, `*italic*`, `` `code` `` (a longer
/// backtick run when the code contains backticks), `[label](url)` (`<url>`
/// when the URL has spaces or parentheses) and `- ` bullets.
///
/// Each transform toggles: applied again to its own result it removes the
/// markup. The selected text stays selected (inside the markup).
abstract final class MarkdownEdits {
  /// Toggles `**bold**` around the selection.
  static TextEditingValue bold(TextEditingValue v) => _toggle(v, '**');

  /// Toggles `*italic*` around the selection.
  static TextEditingValue italic(TextEditingValue v) => _toggle(v, '*');

  /// Toggles inline code around the selection; a selection over several
  /// lines becomes (or stops being) a fenced code block.
  static TextEditingValue code(TextEditingValue v) {
    final sel = _selection(v);
    final selected = v.text.substring(sel.start, sel.end);
    if (selected.contains('\n')) return _toggleFence(v, sel);
    final fence = '`' * (_longestRun(selected, '`') + 1);
    final padded = selected.startsWith('`') || selected.endsWith('`');
    if (fence == '`') return _toggle(v, '`');
    final open = padded ? '$fence ' : fence;
    final close = padded ? ' $fence' : fence;
    return _wrap(v, sel, open, close);
  }

  /// Makes the selection a link to [url] (the URL is the label when nothing
  /// is selected). The caret ends after the link.
  static TextEditingValue link(TextEditingValue v, String url) {
    final sel = _selection(v);
    final selected = v.text.substring(sel.start, sel.end);
    final label = selected.trim().isEmpty
        ? url
        : selected.replaceAll('[', r'\[').replaceAll(']', r'\]');
    final dest = RegExp(r'[\s()<>]').hasMatch(url) ? '<$url>' : url;
    final insert = '[$label]($dest)';
    return TextEditingValue(
      text: v.text.replaceRange(sel.start, sel.end, insert),
      selection: TextSelection.collapsed(offset: sel.start + insert.length),
    );
  }

  /// Toggles `- ` bullets on the lines of the selection: removed when every
  /// non-empty line is a bullet, added to every non-empty line otherwise.
  static TextEditingValue bullets(TextEditingValue v) {
    final sel = _selection(v);
    final text = v.text;
    final start = text.lastIndexOf('\n', math.max(0, sel.start - 1)) + 1;
    final lineStart = sel.start == 0 ? 0 : start;
    var lineEnd = text.indexOf('\n', sel.end);
    if (lineEnd < 0) lineEnd = text.length;
    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');
    final bullet = RegExp(r'^(\s*)[-*+] ');
    final nonEmpty = lines.where((l) => l.trim().isNotEmpty);
    final remove = nonEmpty.isNotEmpty && nonEmpty.every(bullet.hasMatch);
    final out = [
      for (final l in lines)
        if (remove)
          l.replaceFirstMapped(bullet, (m) => m.group(1)!)
        else if (l.trim().isEmpty && lines.length > 1)
          l
        else
          '- $l',
    ].join('\n');
    final next = text.replaceRange(lineStart, lineEnd, out);
    final delta = out.length - block.length;
    final selection = sel.isCollapsed
        ? TextSelection.collapsed(
            offset: (sel.start + delta).clamp(
              lineStart,
              lineStart + out.length,
            ),
          )
        : TextSelection(
            baseOffset: lineStart,
            extentOffset: lineStart + out.length,
          );
    return TextEditingValue(text: next, selection: selection);
  }

  static TextSelection _selection(TextEditingValue v) {
    final s = v.selection;
    if (!s.isValid) return TextSelection.collapsed(offset: v.text.length);
    return TextSelection(
      baseOffset: math.min(s.start, s.end),
      extentOffset: math.max(s.start, s.end),
    );
  }

  static int _longestRun(String s, String ch) {
    var best = 0, run = 0;
    for (var i = 0; i < s.length; i++) {
      run = s[i] == ch ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }

  /// The length of the run of [ch] ending before [end] / starting at [start].
  static int _runBefore(String s, int end, String ch) {
    var n = 0;
    while (end - n - 1 >= 0 && s[end - n - 1] == ch) {
      n++;
    }
    return n;
  }

  static int _runAfter(String s, int start, String ch) {
    var n = 0;
    while (start + n < s.length && s[start + n] == ch) {
      n++;
    }
    return n;
  }

  /// Whether a run of [n] marker characters contains [marker] as its own
  /// delimiter (`*` in `*`/`***`, not in `**`).
  static bool _runHas(int n, String marker) {
    if (marker == '*') return n == 1 || n >= 3;
    return n >= marker.length;
  }

  static TextEditingValue _toggle(TextEditingValue v, String marker) {
    final sel = _selection(v);
    final text = v.text;
    final ch = marker[0];
    final m = marker.length;
    // Inside the selection: "**x**" selected.
    final selected = text.substring(sel.start, sel.end);
    if (selected.length >= 2 * m &&
        _runHas(_runAfter(selected, 0, ch), marker) &&
        _runHas(_runBefore(selected, selected.length, ch), marker) &&
        (selected.length > 2 * m || marker != '*')) {
      final inner = selected.substring(m, selected.length - m);
      return TextEditingValue(
        text: text.replaceRange(sel.start, sel.end, inner),
        selection: TextSelection(
          baseOffset: sel.start,
          extentOffset: sel.start + inner.length,
        ),
      );
    }
    // Around the selection: "**[x]**".
    if (_runHas(_runBefore(text, sel.start, ch), marker) &&
        _runHas(_runAfter(text, sel.end, ch), marker)) {
      final next = text
          .replaceRange(sel.end, sel.end + m, '')
          .replaceRange(sel.start - m, sel.start, '');
      return TextEditingValue(
        text: next,
        selection: TextSelection(
          baseOffset: sel.start - m,
          extentOffset: sel.end - m,
        ),
      );
    }
    if (selected.contains('\n')) return _wrapLines(v, sel, marker);
    return _wrap(v, sel, marker, marker);
  }

  /// Wraps the selection (without its surrounding spaces: `** x**` is not
  /// emphasis) in [open] and [close]; an empty selection gets the markup
  /// with the caret between.
  static TextEditingValue _wrap(
    TextEditingValue v,
    TextSelection sel,
    String open,
    String close,
  ) {
    final text = v.text;
    var start = sel.start, end = sel.end;
    while (start < end && text[start].trim().isEmpty) {
      start++;
    }
    while (end > start && text[end - 1].trim().isEmpty) {
      end--;
    }
    final inner = text.substring(start, end);
    return TextEditingValue(
      text: text.replaceRange(start, end, '$open$inner$close'),
      selection: TextSelection(
        baseOffset: start + open.length,
        extentOffset: start + open.length + inner.length,
      ),
    );
  }

  /// Emphasis cannot span lines: wraps every non-empty line.
  static TextEditingValue _wrapLines(
    TextEditingValue v,
    TextSelection sel,
    String marker,
  ) {
    final selected = v.text.substring(sel.start, sel.end);
    final out = selected
        .split('\n')
        .map((l) {
          if (l.trim().isEmpty) return l;
          final lead = l.length - l.trimLeft().length;
          final trail = l.length - l.trimRight().length;
          return '${l.substring(0, lead)}$marker${l.trim()}$marker'
              '${l.substring(l.length - trail)}';
        })
        .join('\n');
    return TextEditingValue(
      text: v.text.replaceRange(sel.start, sel.end, out),
      selection: TextSelection(
        baseOffset: sel.start,
        extentOffset: sel.start + out.length,
      ),
    );
  }

  static TextEditingValue _toggleFence(TextEditingValue v, TextSelection sel) {
    final text = v.text;
    final selected = text.substring(sel.start, sel.end);
    final fenced = RegExp(r'^(`{3,})[^\n]*\n([\s\S]*)\n\1\s*$');
    final m = fenced.firstMatch(selected);
    if (m != null) {
      final inner = m.group(2)!;
      return TextEditingValue(
        text: text.replaceRange(sel.start, sel.end, inner),
        selection: TextSelection(
          baseOffset: sel.start,
          extentOffset: sel.start + inner.length,
        ),
      );
    }
    final fence = '`' * math.max(3, _longestRun(selected, '`') + 1);
    final before = sel.start == 0 || text[sel.start - 1] == '\n' ? '' : '\n';
    final after = sel.end == text.length || text[sel.end] == '\n' ? '' : '\n';
    final out = '$before$fence\n$selected\n$fence$after';
    final innerStart = sel.start + before.length + fence.length + 1;
    return TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, out),
      selection: TextSelection(
        baseOffset: innerStart,
        extentOffset: innerStart + selected.length,
      ),
    );
  }
}
