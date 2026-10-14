import 'package:flutter/widgets.dart' hide RichText;
import 'package:wonky_sheets_core/model.dart' show RichText;
import 'package:wonky_sheets_core/formula.dart';

import '../../theme/sheets_tokens.dart';

/// Text controller of the cell editor and formula bar: formulas are
/// syntax-highlighted (03 §8.7) with reference colors matching the boxes on
/// the grid.
class FormulaTextController extends TextEditingController {
  FormulaTextController({super.text});

  GridPaintTokens tokens = GridPaintTokens.light;
  FormulaLocale locale = FormulaLocale.enUS;

  /// Rich text runs of the edited text (06 §11); null for plain cells.
  RichText? richRuns;

  /// Style of a run's format on top of the base style (set by the editor).
  TextStyle Function(Map<String, Object?> format, TextStyle base)? richStyle;

  /// Rebuilds the spans after [richRuns] changed.
  void notifyRichChange() => notifyListeners();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    final rich = richRuns;
    final rs = richStyle;
    if (rich != null &&
        rs != null &&
        rich.text == t &&
        rich.runs.isNotEmpty &&
        !t.startsWith('=') &&
        !(withComposing && value.isComposingRangeValid)) {
      final base = style ?? const TextStyle();
      final children = <TextSpan>[];
      var pos = 0;
      for (final r in rich.runs) {
        if (r.start > pos) {
          children.add(TextSpan(text: t.substring(pos, r.start)));
        }
        if (r.end > r.start && r.start >= pos) {
          children.add(
            TextSpan(
              text: t.substring(r.start, r.end),
              style: rs(r.format, base),
            ),
          );
          pos = r.end;
        }
      }
      if (pos < t.length) children.add(TextSpan(text: t.substring(pos)));
      return TextSpan(style: style, children: children);
    }
    if (!t.startsWith('=') || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final caret = selection.isValid && selection.isCollapsed
        ? selection.baseOffset
        : null;
    final List<HighlightSpan> spans;
    try {
      spans = FormulaHighlighter.highlight(t, locale: locale, caret: caret);
    } catch (_) {
      return TextSpan(style: style, text: t);
    }
    final children = <TextSpan>[];
    var pos = 0;
    for (final s in spans) {
      if (s.start > pos) {
        children.add(TextSpan(text: t.substring(pos, s.start)));
      }
      if (s.end <= s.start || s.start < pos) continue;
      children.add(
        TextSpan(text: t.substring(s.start, s.end), style: _styleFor(s)),
      );
      pos = s.end;
    }
    if (pos < t.length) children.add(TextSpan(text: t.substring(pos)));
    return TextSpan(style: style, children: children);
  }

  TextStyle? _styleFor(HighlightSpan s) {
    final tk = tokens;
    return switch (s.cls) {
      HighlightClass.reference => TextStyle(
        color: tk.reference(s.colorIndex ?? 0),
      ),
      HighlightClass.namedRange => TextStyle(
        color: tk.reference(s.colorIndex ?? 0),
        fontStyle: FontStyle.italic,
      ),
      HighlightClass.function => TextStyle(
        color: tk.formulaFunction,
        fontWeight: FontWeight.w500,
      ),
      HighlightClass.number => TextStyle(color: tk.formulaNumber),
      HighlightClass.string => TextStyle(color: tk.formulaString),
      HighlightClass.operator ||
      HighlightClass.punctuation => TextStyle(color: tk.formulaOperator),
      HighlightClass.error ||
      HighlightClass.unmatchedParen => TextStyle(color: tk.formulaError),
      HighlightClass.matchedParen => TextStyle(
        backgroundColor: tk.selectionFill,
      ),
      _ => null,
    };
  }
}
