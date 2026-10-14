import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart' show HorizontalAlign;

import '../../l10n/sheets_l10n.dart';
import '../../theme/sheets_tokens.dart';
import '../grid/paint/auto_text.dart';
import '../grid/paint/layers/content_layers.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'cell_editor_controller.dart';
import 'formula_assist.dart';
import 'formula_preview.dart';

/// The in-cell editor (03 §8.3): an `EditableText` positioned over the edited
/// cell (or merge) with the cell's font, color, fill and alignment, growing
/// with its text; plus the autocomplete / signature help popups.
class CellEditorOverlay extends StatefulWidget {
  const CellEditorOverlay({
    super.key,
    required this.controller,
    required this.tokens,
  });

  final SheetEditorController controller;
  final GridPaintTokens tokens;

  @override
  State<CellEditorOverlay> createState() => _CellEditorOverlayState();
}

/// The editor's `EditableText` stays mounted (invisible while not editing)
/// so that `begin()` can move focus to it synchronously: keys typed right
/// after the first one never get lost while the overlay builds (03 §8.3).
class _CellEditorOverlayState extends State<CellEditorOverlay> {
  final _fieldKey = GlobalKey(debugLabel: 'sheets.cellEditor.field');

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final tokens = widget.tokens;
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: Listenable.merge([c.editor, c.scroll, c.overlaySignal]),
        builder: (context, _) {
          final editor = c.editor;
          final session = editor.session;
          final target = editor.target;
          final editing =
              session != null &&
              target != null &&
              session.sheetId == c.activeSheetId;
          final g = c.geometryFor(
            constraints.biggest,
            MediaQuery.devicePixelRatioOf(context),
          );
          final sel = c.selection.resolved;
          final (row, col) = editing ? target : (sel.activeRow, sel.activeCol);
          final merge = g?.sheet.mergeAt(row, col) ?? GridRect.cell(row, col);
          final cellRect = g?.rangeRect(merge) ?? Rect.zero;
          final format = c.cells.displayAt(c.activeSheetId, row, col);
          final f = format?.format ?? c.activeFormat();
          final z = g?.zoom ?? 1;
          final isFormula = editing && editor.isFormula;
          final explicitFill = hexToColor(format?.fillColor);
          final textColor =
              hexToColor(format?.textColor) ?? autoTextOn(tokens, explicitFill);
          final fill = explicitFill ?? tokens.sheetBackground;
          final style = TextStyle(
            fontFamily: f.fontFamily,
            fontFamilyFallback: const ['Inter', 'Geist', 'Roboto'],
            fontSize: f.fontSize * kPointToPx * z,
            fontWeight: f.bold ? FontWeight.w700 : FontWeight.w400,
            fontStyle: f.italic ? FontStyle.italic : FontStyle.normal,
            color: textColor,
            height: 1.2,
          );
          editor.text.tokens = tokens;
          // Auto-size: grow to the right up to the viewport edge, then wrap.
          final padH = kCellPadH * z;
          var width = cellRect.width;
          if (editing) {
            final painter = TextPainter(
              text: TextSpan(text: '${editor.text.text} ', style: style),
              textDirection: TextDirection.ltr,
            )..layout();
            final maxWidth = math.max(
              cellRect.width,
              constraints.maxWidth - cellRect.left - 12,
            );
            width = (painter.width + 2 * padH + 4)
                .clamp(cellRect.width, maxWidth)
                .toDouble();
          }
          final rect = Rect.fromLTWH(
            cellRect.left,
            cellRect.top,
            math.max(1, width),
            math.max(1, cellRect.height),
          );
          final align = isFormula
              ? TextAlign.left
              : switch (format?.hAlign) {
                  HorizontalAlign.center => TextAlign.center,
                  HorizontalAlign.right => TextAlign.right,
                  _ => TextAlign.left,
                };
          final field = KeymapScope(
            key: _fieldKey,
            scope: KeyScope.cellEditor,
            keymap: c.services.keymap,
            child: EditableText(
              key: const ValueKey<String>('sheets.cellEditor'),
              controller: editor.text,
              focusNode: editor.cellFocus,
              style: isFormula
                  ? style.copyWith(color: tokens.formulaFunction)
                  : style,
              cursorColor: tokens.selectionBorder,
              backgroundCursorColor: tokens.headerFg,
              selectionColor: tokens.selectionFill.withValues(alpha: 0.4),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlign: align,
              onTapOutside: (_) {},
              readOnly:
                  !c.canEdit ||
                  (editing && session.surface != EditSurface.cell),
              showCursor: editing && session.surface == EditSurface.cell,
              rendererIgnoresPointer: false,
            ),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: rect.left - 1,
                top: rect.top - 1,
                child: IgnorePointer(
                  ignoring: !editing,
                  child: Opacity(
                    opacity: editing ? 1 : 0,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: rect.width + 2,
                        maxWidth: rect.width + 2,
                        minHeight: rect.height + 2,
                        maxHeight: math.max(
                          rect.height + 2,
                          constraints.maxHeight * 0.5,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: fill,
                          border: Border.all(
                            color: tokens.selectionBorder,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: math.max(0, padH - 1),
                            vertical: math.max(0, kCellPadV * z - 1),
                          ),
                          child: field,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Cell reference badge when the headers are scrolled away,
              // and the live formula result (03 §8.7).
              if (editing)
                Positioned(
                  left: rect.left,
                  bottom: constraints.maxHeight - rect.top + 3,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (g != null &&
                          (rect.top < g.colHeaderHeight + 2 ||
                              rect.left < g.rowHeaderWidth + 2))
                        _Badge(text: c.activeA1, tokens: tokens),
                      ValueListenableBuilder<FormulaPreview?>(
                        valueListenable: editor.preview,
                        builder: (context, p, _) => p == null || !isFormula
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: FormulaPreviewChip(preview: p),
                              ),
                      ),
                    ],
                  ),
                ),
              if (editing)
                Positioned(
                  left: rect.left,
                  top: rect.bottom + 4,
                  child: FormulaAssist(editor: editor, tokens: tokens),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The live result of the formula being typed (03 §8.7): `= 1,234.50`,
/// or the error with its message.
class FormulaPreviewChip extends StatelessWidget {
  const FormulaPreviewChip({super.key, required this.preview});

  final FormulaPreview preview;

  @override
  Widget build(BuildContext context) {
    final cs = schemeOf(context);
    final detail = preview.detail;
    final label = detail == null
        ? preview.text
        : preview.isError
        ? '${preview.text} — $detail'
        : '${preview.text} $detail';
    return Semantics(
      liveRegion: true,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          key: const ValueKey<String>('sheets.cellEditor.preview'),
          decoration: BoxDecoration(
            color: cs.popover,
            border: Border.all(color: cs.border),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: preview.isError ? cs.destructive : cs.popoverForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.tokens});

  final String text;
  final GridPaintTokens tokens;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tokens.selectionBorder,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Text(
        text,
        style: TextStyle(
          color: tokens.sheetBackground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Shows editor mode labels for the status bar.
String editorModeLabel(SheetsLocalizations l, CellEditorController e) {
  if (!e.isEditing) return l.statusModeReady;
  if (e.isPointing) return l.statusModePoint;
  return e.mode == EditMode.enter ? l.statusModeEnter : l.statusModeEdit;
}

/// Shad theme helper for popups.
ShadColorScheme schemeOf(BuildContext context) =>
    ShadTheme.of(context).colorScheme;
