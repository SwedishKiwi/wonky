import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../../theme/sheets_tokens.dart';
import 'cell_cards.dart';
import 'in_cell_controller.dart';
import 'in_cell_paint.dart';

/// Writes [input] into the popup's cell (as typed; one undo step).
Future<bool> _write(InCellController c, CellPopup p, String input) {
  final s = c.editor.model.sheet(p.sheetId);
  if (s == null) return Future.value(false);
  return c.editor.invokeCommand('sheets.cell.setInput', {
    'input': input,
    'sheetId': p.sheetId,
    'rowId': s.rows.idAt(p.row),
    'colId': s.columns.idAt(p.col),
  });
}

/// `DropdownPickerPopover` (03 §14.2): search (above 7 items), the items
/// with their chip colors, the current value checked; ↑/↓/Enter, Esc
/// closes. Multi-select rules (P2) toggle items with checkboxes and write
/// them joined by ", " on *Done*.
class DropdownPickerPopover extends StatefulWidget {
  const DropdownPickerPopover({
    super.key,
    required this.controller,
    required this.popup,
  });

  final InCellController controller;
  final CellPopup popup;

  @override
  State<DropdownPickerPopover> createState() => _DropdownPickerPopoverState();
}

class _DropdownPickerPopoverState extends State<DropdownPickerPopover> {
  final _search = TextEditingController();
  final _focus = FocusNode(debugLabel: 'sheets.dropdownPicker');
  final _searchFocus = FocusNode(debugLabel: 'sheets.dropdownPicker.search');
  final _scroll = ScrollController();
  late final List<DvItem> _items;
  late final String _current;
  late final bool _multiple;
  late final Set<String> _chosen;
  int _highlight = 0;

  InCellController get c => widget.controller;
  CellPopup get p => widget.popup;

  @override
  void initState() {
    super.initState();
    final dv = c.dv;
    _items = dv.evaluator.dropdownItems(p.sheetId, p.row, p.col);
    _current = c.editor.cells.displayAt(p.sheetId, p.row, p.col)?.text ?? '';
    final criteria = dv.ruleAt(p.sheetId, p.row, p.col)?.criteria;
    _multiple = switch (criteria) {
      DvListCriteria(:final allowMultiple) => allowMultiple,
      DvRangeCriteria(:final allowMultiple) => allowMultiple,
      _ => false,
    };
    _chosen = _multiple
        ? _current.split(', ').where((s) => s.isNotEmpty).toSet()
        : {_current};
    final i = _items.indexWhere((x) => x.value == _current);
    _highlight = i < 0 ? 0 : i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_items.length > 7 ? _searchFocus : _focus).requestFocus();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<DvItem> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return [
      for (final i in _items)
        if (i.value.toLowerCase().contains(q)) i,
    ];
  }

  Future<void> _pick(DvItem item) async {
    if (_multiple) {
      setState(() {
        if (!_chosen.remove(item.value)) _chosen.add(item.value);
      });
      return;
    }
    c.closePopup();
    if (item.value == _current) return;
    // A leading = would make the item a formula.
    final input = item.value.startsWith('=') ? "'${item.value}" : item.value;
    await _write(c, p, input);
  }

  Future<void> _done() async {
    c.closePopup();
    final value = [
      for (final i in _items)
        if (_chosen.contains(i.value)) i.value,
    ].join(', ');
    if (value == _current) return;
    await _write(c, p, value.startsWith('=') ? "'$value" : value);
  }

  KeyEventResult _keys(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final items = _visible;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.escape:
        c.closePopup();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        if (items.isNotEmpty) {
          setState(() => _highlight = (_highlight + 1) % items.length);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (items.isNotEmpty) {
          setState(
            () => _highlight = (_highlight - 1 + items.length) % items.length,
          );
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (_multiple) {
          unawaited(_done());
        } else if (items.isNotEmpty) {
          unawaited(_pick(items[_highlight.clamp(0, items.length - 1)]));
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space when _multiple && !_searchFocus.hasFocus:
        if (items.isNotEmpty) {
          unawaited(_pick(items[_highlight.clamp(0, items.length - 1)]));
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final tokens = GridPaintTokens.ofContext(context);
    final items = _visible;
    final rule = c.dv.ruleAt(p.sheetId, p.row, p.col);
    return Focus(
      focusNode: _focus,
      onKeyEvent: _keys,
      child: TapRegion(
        onTapOutside: (_) => c.closePopup(),
        child: Semantics(
          label: l.pickerLabel(p.a1),
          container: true,
          child: CellPopoverSurface(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_items.length > 7)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
                    child: ShadInput(
                      key: const ValueKey<String>(
                        'sheets.dropdownPicker.search',
                      ),
                      controller: _search,
                      focusNode: _searchFocus,
                      placeholder: Text(l.pickerSearch),
                      leading: Icon(
                        LucideIcons.search,
                        size: 15,
                        color: cs.mutedForeground,
                      ),
                      onChanged: (_) => setState(() => _highlight = 0),
                    ),
                  ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      _items.isEmpty ? l.pickerNoItems : l.pickerNoMatches,
                      style: theme.textTheme.muted.copyWith(fontSize: 12.5),
                    ),
                  )
                else
                  Flexible(
                    child: WonkyScrollArea(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < items.length; i++)
                              _ItemRow(
                                key: ValueKey<String>(
                                  'sheets.dropdownPicker.item.${items[i].value}',
                                ),
                                item: items[i],
                                tokens: tokens,
                                highlighted: i == _highlight,
                                checked: _chosen.contains(items[i].value),
                                multiple: _multiple,
                                onTap: () => unawaited(_pick(items[i])),
                                onHover: () => setState(() => _highlight = i),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_multiple || (c.editor.canEdit && rule != null)) ...[
                  const ShadSeparator.horizontal(
                    margin: EdgeInsets.symmetric(vertical: 4),
                  ),
                  Row(
                    children: [
                      if (c.editor.canEdit && rule != null)
                        ShadButton.ghost(
                          key: const ValueKey<String>(
                            'sheets.dropdownPicker.edit',
                          ),
                          size: ShadButtonSize.sm,
                          leading: const Icon(LucideIcons.pencil, size: 14),
                          onPressed: () {
                            c.closePopup();
                            unawaited(
                              c.editor.invokeCommand('sheets.dv.openPanel', {
                                'ruleId': rule.id,
                              }),
                            );
                          },
                          child: Text(l.pickerEdit),
                        ),
                      const Spacer(),
                      if (_multiple)
                        ShadButton(
                          key: const ValueKey<String>(
                            'sheets.dropdownPicker.done',
                          ),
                          size: ShadButtonSize.sm,
                          onPressed: () => unawaited(_done()),
                          child: Text(l.dialogOk),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.tokens,
    required this.highlighted,
    required this.checked,
    required this.multiple,
    required this.onTap,
    required this.onHover,
  });

  final DvItem item;
  final GridPaintTokens tokens;
  final bool highlighted;
  final bool checked;
  final bool multiple;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final neutral = neutralChipColors(tokens);
    final bg = hexToColor(item.colors.bg) ?? neutral.bg;
    final fg = hexToColor(item.colors.fg) ?? neutral.fg;
    return Semantics(
      button: true,
      selected: checked,
      label: item.value,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: highlighted ? cs.accent : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: multiple
                      ? ShadCheckbox(value: checked, onChanged: (_) => onTap())
                      : (checked
                            ? Icon(
                                LucideIcons.check,
                                size: 14,
                                color: cs.foreground,
                              )
                            : null),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.value.isEmpty ? ' ' : item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(
                        color: fg,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The date picker of date-validated cells (Alt+↓, double-click; 03 §14).
class DatePickerPopover extends StatelessWidget {
  const DatePickerPopover({
    super.key,
    required this.controller,
    required this.popup,
  });

  final InCellController controller;
  final CellPopup popup;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = popup;
    final l = sheetsL10n(context);
    final v = c.editor.cells.displayAt(p.sheetId, p.row, p.col)?.value;
    DateTime? selected;
    if (v is NumberValue && v.number >= 1 && v.number < 2958466) {
      final ymd = DateSerial.toYmd(v.number.toDouble());
      selected = DateTime(ymd.year, ymd.month, ymd.day);
    }
    return Focus(
      autofocus: true,
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          c.closePopup();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TapRegion(
        onTapOutside: (_) => c.closePopup(),
        child: Semantics(
          label: l.datePickerLabel(p.a1),
          container: true,
          child: CellPopoverSurface(
            padding: const EdgeInsets.all(4),
            child: ShadCalendar(
              key: const ValueKey<String>('sheets.datePicker'),
              selected: selected,
              initialMonth: selected,
              onChanged: (d) {
                if (d == null) return;
                c.closePopup();
                final iso =
                    '${d.year.toString().padLeft(4, '0')}-'
                    '${d.month.toString().padLeft(2, '0')}-'
                    '${d.day.toString().padLeft(2, '0')}';
                unawaited(_write(c, p, iso));
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// `NotePopover` (03 §14.5): edits the cell's note; Esc, a click outside or
/// moving the selection saves (`sheets.notes.insert`, empty text deletes).
class NotePopover extends StatefulWidget {
  const NotePopover({super.key, required this.controller, required this.popup});

  final InCellController controller;
  final CellPopup popup;

  @override
  State<NotePopover> createState() => _NotePopoverState();
}

class _NotePopoverState extends State<NotePopover> {
  late final TextEditingController _text;
  late final String _initial;
  final _focus = FocusNode(debugLabel: 'sheets.noteEditor');
  bool _saved = false;

  InCellController get c => widget.controller;
  CellPopup get p => widget.popup;

  @override
  void initState() {
    super.initState();
    _initial =
        c.editor.model.sheet(p.sheetId)?.cellAt(p.row, p.col)?.note ?? '';
    _text = TextEditingController(text: _initial);
    c.editor.selection.addListener(_onSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onSelection() {
    final sel = c.editor.selection.resolved;
    if (sel.activeRow != p.row || sel.activeCol != p.col) _save();
  }

  void _save() {
    if (_saved) return;
    _saved = true;
    final text = _text.text;
    if (c.popup.value == p) c.closePopup();
    if (text.trim() == _initial.trim()) return;
    final s = c.editor.model.sheet(p.sheetId);
    if (s == null) return;
    unawaited(
      c.editor.invokeCommand('sheets.notes.insert', {
        'cell': p.a1,
        'text': text.trim().isEmpty ? '' : text,
      }),
    );
  }

  @override
  void dispose() {
    c.editor.selection.removeListener(_onSelection);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    return Focus(
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          _save();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TapRegion(
        onTapOutside: (_) => _save(),
        child: Semantics(
          label: l.noteEditorLabel(p.a1),
          container: true,
          child: CellPopoverSurface(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadTextarea(
                  key: const ValueKey<String>('sheets.noteEditor.text'),
                  controller: _text,
                  focusNode: _focus,
                  placeholder: Text(l.notePlaceholder),
                  minHeight: 96,
                  maxHeight: 220,
                ),
                const SizedBox(height: 4),
                Text(
                  l.noteEditorHint,
                  style: theme.textTheme.muted.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
