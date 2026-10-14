import 'package:flutter/widgets.dart' hide RichText;
import 'package:wonky_app/wonky_app.dart' show CommandContext;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../theme/sheets_tokens.dart';
import '../cell_editor/cell_editor_controller.dart';
import '../links/link_dialog.dart' show showLinkEditorDialog;
import '../sheet_editor/sheet_editor_controller.dart';
import 'cell_fonts.dart';

/// Rich text runs inside the cell editor (06 §11, 03 §8.8).
///
/// The editor keeps the runs of the edited text in
/// `FormulaTextController.richRuns`: loaded from a rich cell when editing
/// starts, re-offset on every text change ([remapRuns]) and changed by the
/// text formatting commands while a text range is selected
/// ([applyToEditorSelection]). Commit writes them with
/// `sheets.cell.setRichText`.
abstract final class RichTextEditing {
  /// The runs of the cell being edited (null when it isn't rich).
  static RichText? runsOfCell(
    SheetEditorController host,
    String sheetId,
    int row,
    int col,
  ) {
    final content = host.model.cellAt(sheetId, row, col)?.decoded;
    return content is RichTextContent ? content.rich : null;
  }

  /// Re-offsets [rich] after its text became [newText] (one contiguous edit:
  /// common prefix and suffix are kept, typed text inherits the format of
  /// the character before it).
  static RichText remapRuns(RichText rich, String newText) {
    final old = rich.text;
    if (old == newText) return rich;
    var p = 0;
    final maxP = old.length < newText.length ? old.length : newText.length;
    while (p < maxP && old.codeUnitAt(p) == newText.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < old.length - p &&
        s < newText.length - p &&
        old.codeUnitAt(old.length - 1 - s) ==
            newText.codeUnitAt(newText.length - 1 - s)) {
      s++;
    }
    final oldEnd = old.length - s;
    final delta = newText.length - old.length;
    int map(int o, {required bool isEnd}) {
      if (isEnd ? o <= p : o < p) return o;
      if (o >= oldEnd) return o + delta;
      // Inside the replaced span: collapse to its start.
      return p;
    }

    final out = <RichRun>[];
    for (final r in rich.runs) {
      var start = map(r.start, isEnd: false);
      var end = map(r.end, isEnd: true);
      // Text typed right at the end of a run extends it.
      if (r.end == p && delta > 0 && oldEnd == p) end = p + delta;
      if (start > end) start = end;
      if (end > start) out.add(RichRun(start, end, r.format));
    }
    return RichText(newText, out);
  }

  /// Whether the cell editor has a text selection in plain (non-formula)
  /// text: text formatting then applies to that run, and formatting that
  /// can't be a run (fills, borders, number formats …) is unavailable.
  static bool hasRunSelection(CellEditorController editor) {
    if (!editor.isEditing || editor.isFormula) return false;
    final sel = editor.text.selection;
    return sel.isValid && !sel.isCollapsed;
  }

  /// Command ids that format a run of the editor's selection (06 §11).
  static const runCommands = {
    'sheets.format.bold',
    'sheets.format.italic',
    'sheets.format.underline',
    'sheets.format.strikethrough',
    'sheets.format.textColor',
    'sheets.format.fontFamily',
    'sheets.format.fontSize',
    'sheets.format.increaseFontSize',
    'sheets.format.decreaseFontSize',
    'sheets.insert.link',
  };

  /// Whether command [id] is cell formatting that doesn't apply to a run.
  static bool isCellOnlyFormatting(String id) =>
      id.startsWith('sheets.format.') && !runCommands.contains(id);

  /// Mod+K on a text selection of the cell editor (06 §11): links the
  /// selected text (link run). Without [url] the link dialog asks for the
  /// text and URL; an empty URL removes the link run. [normalize] turns the
  /// typed URL into the stored link (null = invalid).
  static Future<CommandResult> linkSelection(
    CommandContext ctx,
    SheetEditorController ed, {
    String? url,
    String? text,
    required String? Function(String url) normalize,
  }) async {
    final editor = ed.editor;
    final t = editor.text;
    final sel = t.selection;
    final session = editor.session;
    if (session == null) return const CommandResult.cancelled();
    final selected = sel.textInside(t.text);
    if (url == null) {
      final current = (t.richRuns?.text == t.text)
          ? t.richRuns!.formatAt(sel.start)[RichRunKeys.link] as String?
          : null;
      final dc = ctx.dialogContext;
      if (dc == null || !dc.mounted) return const CommandResult.cancelled();
      final r = await showLinkEditorDialog(
        dc,
        model: ed.model,
        activeSheetId: ed.activeSheetId,
        text: selected,
        url: current ?? '',
      );
      if (r == null || !editor.isEditing) {
        _refocus(editor);
        return const CommandResult.cancelled();
      }
      (text, url) = r;
    }
    final link = url.trim().isEmpty ? null : normalize(url);
    if (url.trim().isNotEmpty && link == null) {
      _refocus(editor);
      return CommandResult.failed(ed.l10n.linkInvalid);
    }
    // A changed text replaces the selection (runs re-offset by the editor).
    var start = sel.start;
    var end = sel.end;
    if (text != null && text.isNotEmpty && text != selected) {
      t.value = TextEditingValue(
        text: t.text.replaceRange(start, end, text),
        selection: TextSelection(
          baseOffset: start,
          extentOffset: start + text.length,
        ),
      );
      end = start + text.length;
    } else {
      t.selection = TextSelection(baseOffset: start, extentOffset: end);
    }
    applyToEditorSelection(editor, values: {RichRunKeys.link: link});
    _refocus(editor);
    return const CommandResult.ok();
  }

  static void _refocus(CellEditorController editor) {
    final s = editor.session;
    if (s == null) return;
    (s.surface == EditSurface.cell ? editor.cellFocus : editor.barFocus)
        .requestFocus();
  }

  /// Applies run attributes to the editor's selected text. [toggleKey]
  /// toggles a boolean key (all true → false). Returns false when the editor
  /// has no text selection in plain (non-formula) text, so the caller formats
  /// the cell instead.
  static bool applyToEditorSelection(
    CellEditorController editor, {
    String? toggleKey,
    Map<String, Object?> values = const {},
    bool? cellValue,
  }) {
    if (!editor.isEditing || editor.isFormula) return false;
    final t = editor.text;
    final sel = t.selection;
    if (!sel.isValid || sel.isCollapsed) return false;
    final current = t.richRuns ?? RichText(t.text, const []);
    final rich = current.text == t.text ? current : remapRuns(current, t.text);
    final f = Map<String, Object?>.of(values);
    if (toggleKey != null) {
      // Characters without a run use the cell's value.
      var all = true;
      for (var i = sel.start; i < sel.end; i++) {
        final v = rich.formatAt(i)[toggleKey] ?? cellValue ?? false;
        if (v != true) {
          all = false;
          break;
        }
      }
      f[toggleKey] = !all;
    }
    t.richRuns = rich.applyFormat(sel.start, sel.end, f);
    // Rebuild the editor's spans.
    t.notifyRichChange();
    return true;
  }

  /// The rich text of the cell at ([row], [col]) of the active sheet as
  /// spans for the formula bar display (06 §11): bold, italic, underline,
  /// strikethrough, colors and links; sizes and families keep the bar's.
  /// Null when the cell isn't rich text.
  static TextSpan? barSpan(
    SheetEditorController host,
    int row,
    int col,
    TextStyle base, {
    required Color linkColor,
    bool firstLineOnly = false,
  }) {
    final rich = runsOfCell(host, host.activeSheetId, row, col);
    if (rich == null || rich.runs.isEmpty) return null;
    final theme = host.model.theme;
    var t = rich.text;
    if (firstLineOnly) {
      final nl = t.indexOf('\n');
      if (nl >= 0) t = t.substring(0, nl);
    }
    final children = <TextSpan>[];
    var pos = 0;
    for (final r in rich.runs) {
      if (r.start >= t.length) break;
      final end = r.end > t.length ? t.length : r.end;
      if (r.start > pos) {
        children.add(TextSpan(text: t.substring(pos, r.start)));
      }
      if (end > r.start && r.start >= pos) {
        final f = r.format;
        final style = runStyle(
          {...f, RichRunKeys.fontFamily: null, RichRunKeys.fontSize: null},
          base,
          theme: theme,
          pxPerPoint: 1,
        );
        children.add(
          TextSpan(
            text: t.substring(r.start, end),
            style:
                f[RichRunKeys.link] is String &&
                    f[RichRunKeys.textColor] == null
                ? style.copyWith(color: linkColor)
                : style,
          ),
        );
        pos = end;
      }
    }
    if (pos < t.length) children.add(TextSpan(text: t.substring(pos)));
    return TextSpan(style: base, children: children);
  }

  /// The text style of a run's format on top of [base] (editor rendering).
  static TextStyle runStyle(
    Map<String, Object?> f,
    TextStyle base, {
    required SpreadsheetTheme theme,
    required double pxPerPoint,
  }) {
    final decorations = <TextDecoration>[
      if (f[RichRunKeys.underline] == true ||
          (f[RichRunKeys.link] != null && f[RichRunKeys.underline] != false))
        TextDecoration.underline,
      if (f[RichRunKeys.strikethrough] == true) TextDecoration.lineThrough,
    ];
    final color = hexToColor(
      theme.resolveColor(f[RichRunKeys.textColor] as String?),
    );
    final family = f[RichRunKeys.fontFamily];
    final size = f[RichRunKeys.fontSize];
    return base.copyWith(
      fontWeight: switch (f[RichRunKeys.bold]) {
        true => FontWeight.w700,
        false => FontWeight.w400,
        _ => null,
      },
      fontStyle: switch (f[RichRunKeys.italic]) {
        true => FontStyle.italic,
        false => FontStyle.normal,
        _ => null,
      },
      color: color,
      fontFamily: family is String ? CellFonts.screenFamily(family) : null,
      fontSize: size is num ? size.toDouble() * pxPerPoint : null,
      decoration: decorations.isEmpty
          ? null
          : TextDecoration.combine(decorations),
    );
  }
}
