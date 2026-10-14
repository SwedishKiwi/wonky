import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../formatting/rich_text_editing.dart';
import '../../l10n/sheets_l10n.dart';
import '../../theme/sheets_tokens.dart';
import '../ai/formula_bar_ai_buttons.dart';
import '../charts/chart_sheet_rules.dart';
import '../cell_editor/cell_editor_controller.dart';
import '../grid/selection/grid_selection.dart';
import '../named_ranges/named_range_menu.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// The formula bar (03 §9): name box | fx | editor (shared text controller
/// with the in-cell editor) | expand.
class FormulaBar extends StatelessWidget {
  const FormulaBar({super.key, required this.controller});

  final SheetEditorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final l = sheetsL10n(context);
    final tokens = GridPaintTokens.ofContext(context);
    return ListenableBuilder(
      listenable: Listenable.merge([c, c.editor, c.selection]),
      builder: (context, _) {
        if (!c.showFormulaBar) return const SizedBox.shrink();
        final expanded = c.formulaBarExpanded;
        // A chart sheet has no cells: the bar is shown disabled (08 §11).
        if (ChartSheetRules.onChartSheet(c)) {
          return Container(
            key: const ValueKey<String>('sheets.formulaBar.disabled'),
            height: 30,
            decoration: BoxDecoration(
              color: cs.background,
              border: Border(
                top: BorderSide(color: cs.border),
                bottom: BorderSide(color: cs.border),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            child: Text(
              l.reasonChartSheet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.small.copyWith(
                color: cs.mutedForeground,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
        return Container(
          key: const ValueKey<String>('sheets.formulaBar'),
          height: expanded ? 120 : 30,
          decoration: BoxDecoration(
            color: cs.background,
            border: Border(
              top: BorderSide(color: cs.border),
              bottom: BorderSide(color: cs.border),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 120, child: NameBox(controller: c)),
              NamedRangeMenuButton(editor: c),
              Container(width: 1, color: cs.border),
              ShadTooltip(
                builder: (_) => Text(l.cmdHelpFunctionList),
                child: SizedBox(
                  width: 32,
                  child: Center(
                    child: Text(
                      'fx',
                      style: theme.textTheme.small.copyWith(
                        fontStyle: FontStyle.italic,
                        color: cs.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, color: cs.border),
              Expanded(
                child: _Editor(controller: c, tokens: tokens),
              ),
              FormulaBarAiButtons(controller: c),
              ShadIconButton.ghost(
                key: const ValueKey<String>('sheets.formulaBar.expand'),
                width: 28,
                height: 28,
                iconSize: 14,
                icon: Icon(
                  expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                ),
                semanticLabel: l.cmdFormulaBarToggleExpanded,
                onPressed: () => unawaited(
                  c.invokeCommand('sheets.formulaBar.toggleExpanded'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.controller, required this.tokens});

  final SheetEditorController controller;
  final GridPaintTokens tokens;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = ShadTheme.of(context);
    final editing = c.editor.isEditing;
    final isFormula = editing
        ? c.editor.isFormula
        : c.activeDisplay()?.isFormula ?? false;
    final style = theme.textTheme.small.copyWith(
      fontFamily: isFormula ? 'GeistMono' : null,
      fontWeight: FontWeight.normal,
      color: theme.colorScheme.foreground,
    );
    if (!editing) {
      final r = c.selection.resolved;
      final text = c.editableText(r.activeRow, r.activeCol);
      return MouseRegion(
        cursor: c.canEdit ? SystemMouseCursors.text : SystemMouseCursors.basic,
        child: GestureDetector(
          key: const ValueKey<String>('sheets.formulaBar.display'),
          behavior: HitTestBehavior.opaque,
          onTap: c.canEdit
              ? () => c.editor.begin(
                  mode: EditMode.edit,
                  surface: EditSurface.formulaBar,
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text.rich(
              // Rich text runs (06 §11) keep their styles in the bar.
              (isFormula
                      ? null
                      : RichTextEditing.barSpan(
                          c,
                          r.activeRow,
                          r.activeCol,
                          style,
                          linkColor: tokens.linkText,
                          firstLineOnly: !c.formulaBarExpanded,
                        )) ??
                  TextSpan(
                    text: c.formulaBarExpanded ? text : text.split('\n').first,
                  ),
              maxLines: c.formulaBarExpanded ? 6 : 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: KeymapScope(
        scope: KeyScope.cellEditor,
        keymap: c.services.keymap,
        child: GestureDetector(
          onTap: () => c.editor.setSurface(EditSurface.formulaBar),
          child: EditableText(
            key: const ValueKey<String>('sheets.formulaBar.editor'),
            controller: c.editor.text,
            focusNode: c.editor.barFocus,
            style: style,
            cursorColor: tokens.selectionBorder,
            backgroundCursorColor: tokens.headerFg,
            selectionColor: tokens.selectionFill.withValues(alpha: 0.4),
            maxLines: c.formulaBarExpanded ? null : 1,
            keyboardType: TextInputType.multiline,
            onTapOutside: (_) {},
          ),
        ),
      ),
    );
  }
}

/// The name box (03 §9): shows the active cell / selection; typing an A1
/// target + Enter goes there (`sheets.nav.goTo`); a new name with a range
/// selected creates a named range.
class NameBox extends StatefulWidget {
  const NameBox({super.key, required this.controller});

  final SheetEditorController controller;

  @override
  State<NameBox> createState() => _NameBoxState();
}

class _NameBoxState extends State<NameBox> {
  final _text = TextEditingController();
  bool _error = false;

  SheetEditorController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.selection.addListener(_sync);
    c.nameBoxFocus.addListener(_onFocus);
    _sync();
  }

  void _onFocus() {
    if (c.nameBoxFocus.hasFocus) {
      // After the tap that focused the field has placed its caret.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !c.nameBoxFocus.hasFocus) return;
        _text.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _text.text.length,
        );
      });
    } else {
      _sync();
    }
  }

  void _sync() {
    if (c.nameBoxFocus.hasFocus) return;
    final r = c.selection.resolved;
    final range = r.activeRange;
    final label = range.kind == SelectionKind.cells && range.rect.cellCount > 1
        ? c.selection.describe()
        : c.selection.describe();
    if (_text.text != label) _text.text = label;
    if (_error) setState(() => _error = false);
  }

  @override
  void dispose() {
    c.selection.removeListener(_sync);
    c.nameBoxFocus.removeListener(_onFocus);
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    if (c.goTo(v)) {
      c.gridFocus.requestFocus();
      return;
    }
    final validName = RegExp(r'^[A-Za-z_][A-Za-z0-9_.]*$').hasMatch(v);
    if (validName && c.canEdit) {
      final ok = await c.invokeCommand(
        'sheets.namedRanges.createFromSelection',
        {'name': v},
      );
      if (ok) {
        c.gridFocus.requestFocus();
        return;
      }
    }
    setState(() => _error = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Focus(
        onKeyEvent: (node, e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
            _sync();
            c.gridFocus.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: EditableText(
          key: const ValueKey<String>('sheets.nameBox'),
          controller: _text,
          focusNode: c.nameBoxFocus,
          style: theme.textTheme.small.copyWith(
            color: _error
                ? theme.colorScheme.destructive
                : theme.colorScheme.foreground,
          ),
          cursorColor: theme.colorScheme.primary,
          backgroundCursorColor: theme.colorScheme.mutedForeground,
          maxLines: 1,
          onSubmitted: _submit,
          onTapOutside: (_) {
            if (c.nameBoxFocus.hasFocus) c.gridFocus.requestFocus();
          },
        ),
      ),
    );
  }
}
