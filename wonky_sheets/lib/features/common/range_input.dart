import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters, GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// A1 text of [r] relative to [contextSheetId] (`B2:D9`, `A:C`, `3:5`,
/// `'Q3 plan'!A1:B2`).
String rangeToA1(
  WorkbookModel model,
  ResolvedRange r, {
  required String contextSheetId,
}) {
  final rect = r.rect;
  final String body;
  if (r.wholeColumns && !r.wholeRows) {
    body =
        '${ColumnLetters.fromIndex(rect.left)}:${ColumnLetters.fromIndex(rect.right)}';
  } else if (r.wholeRows && !r.wholeColumns) {
    body = '${rect.top + 1}:${rect.bottom + 1}';
  } else {
    body = rect.a1;
  }
  if (r.sheetId == contextSheetId) return body;
  final name = model.sheet(r.sheetId)?.name ?? '';
  final plain = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name);
  return plain ? '$name!$body' : "'${name.replaceAll("'", "''")}'!$body";
}

/// The A1 list (`A1:B2, D4`) of [rects] on [sheetId].
String rectsToA1(List<GridRect> rects) => rects.map((r) => r.a1).join(', ');

/// Parses a comma-separated A1 list; throws [InvalidRangeException].
List<ResolvedRange> parseRangeList(
  WorkbookModel model,
  String text, {
  required String contextSheetId,
}) => [
  for (final part in text.split(','))
    if (part.trim().isNotEmpty)
      model.parseA1(part.trim(), contextSheetId: contextSheetId),
];

/// `RangeInput` (04 §13): an A1 range input (several ranges separated by
/// commas when [multiple]) with validation and **range picking**: while the
/// input is focused — and after the user went from it to the grid to select
/// — selecting on the grid (also Mod+click ranges and other sheets) writes
/// the range into it live, so panels and dialogs stay open while the user
/// picks. Picking ends when focus moves anywhere but the grid; the ⊞
/// toggle keeps it on until pressed again. [onCommitted] reports the value
/// when picking or editing ends (for inputs that write on commit).
class RangeInput extends StatefulWidget {
  const RangeInput({
    super.key,
    required this.editor,
    required this.value,
    required this.onChanged,
    this.multiple = true,
    this.placeholder,
    this.keyName = 'rangeInput',
    this.enabled = true,
    this.autofocus = false,
    this.onCommitted,
  });

  final SheetEditorController editor;

  /// The A1 text.
  final String value;

  /// Called with the A1 text and the parsed ranges (null when invalid).
  final void Function(String text, List<ResolvedRange>? ranges) onChanged;
  final bool multiple;
  final String? placeholder;
  final String keyName;
  final bool enabled;
  final bool autofocus;

  /// The text when picking or editing ends (focus left the input and the
  /// grid, or Enter).
  final void Function(String text, List<ResolvedRange>? ranges)? onCommitted;

  @override
  State<RangeInput> createState() => _RangeInputState();
}

class _RangeInputState extends State<RangeInput> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  bool _picking = false;

  /// Picking because the input is (or was last, before the grid) focused.
  bool _armed = false;
  final FocusNode _focus = FocusNode(debugLabel: 'sheets.rangeInput');
  String? _committed;

  /// null = valid, true = empty, false = invalid.
  bool? _error;

  SheetEditorController get ed => widget.editor;

  @override
  void initState() {
    super.initState();
    _validate(widget.value, notify: false);
    _committed = widget.value;
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focus.hasFocus) {
      _setArmed(true);
      return;
    }
    // Focus moved on: to the grid (or the cell editor field the grid keeps
    // focused) keeps picking; anywhere else ends it.
    scheduleMicrotask(() {
      if (!mounted || _focus.hasFocus) return;
      final now = FocusManager.instance.primaryFocus;
      final toGrid =
          now == ed.gridFocus ||
          now == ed.editor.cellFocus ||
          (now != null && now.ancestors.contains(ed.gridFocus));
      if (!toGrid) _setArmed(false);
    });
  }

  void _setArmed(bool armed) {
    if (armed == _armed) return;
    if (!_picking) {
      if (armed) {
        ed.selection.addListener(_follow);
      } else {
        ed.selection.removeListener(_follow);
      }
    }
    setState(() => _armed = armed);
    if (!armed) {
      ed.gridFocus.removeListener(_onGridFocus);
      _commit();
    } else {
      ed.gridFocus.addListener(_onGridFocus);
    }
  }

  /// Leaving the grid to somewhere else (not back to this input) ends
  /// picking.
  void _onGridFocus() {
    if (!_armed || _focus.hasFocus) return;
    scheduleMicrotask(() {
      if (!mounted || _focus.hasFocus) return;
      final now = FocusManager.instance.primaryFocus;
      final inGrid =
          now == ed.gridFocus ||
          now == ed.editor.cellFocus ||
          (now != null && now.ancestors.contains(ed.gridFocus));
      if (!inGrid) {
        ed.gridFocus.removeListener(_onGridFocus);
        _setArmed(false);
      }
    });
  }

  void _commit() {
    final t = _text.text;
    if (t == _committed) return;
    _committed = t;
    widget.onCommitted?.call(t, _parse(t));
  }

  @override
  void didUpdateWidget(RangeInput old) {
    super.didUpdateWidget(old);
    if (widget.value != _text.text) {
      _text.text = widget.value;
      _committed = widget.value;
      _validate(widget.value, notify: false);
    }
  }

  @override
  void dispose() {
    if (_picking || _armed) ed.selection.removeListener(_follow);
    ed.gridFocus.removeListener(_onGridFocus);
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  List<ResolvedRange>? _parse(String t) {
    try {
      final list = parseRangeList(
        ed.model,
        t,
        contextSheetId: ed.activeSheetId,
      );
      if (list.isEmpty || (!widget.multiple && list.length > 1)) return null;
      return list;
    } on InvalidRangeException {
      return null;
    }
  }

  void _validate(String t, {bool notify = true}) {
    final r = _parse(t);
    final err = t.trim().isEmpty ? true : (r == null ? false : null);
    if (mounted && err != _error) setState(() => _error = err);
    _error = err;
    if (notify) widget.onChanged(t, r);
  }

  void _toggle() {
    setState(() => _picking = !_picking);
    if (_armed) return; // Already following.
    if (_picking) {
      ed.selection.addListener(_follow);
      _follow();
    } else {
      ed.selection.removeListener(_follow);
      _commit();
    }
  }

  void _follow() {
    final sel = ed.selection.resolved;
    final ranges = sel.toResolvedRanges();
    final list = widget.multiple ? ranges : [ranges[sel.activeRangeIndex]];
    final t = list
        .map((r) => rangeToA1(ed.model, r, contextSheetId: ed.activeSheetId))
        .join(', ');
    _text.text = t;
    _validate(t);
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final err = switch (_error) {
      true => l.rangeInputEmpty,
      false => l.rangeInputInvalid,
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadInput(
          key: ValueKey<String>('${widget.keyName}.input'),
          controller: _text,
          focusNode: _focus,
          enabled: widget.enabled,
          onSubmitted: (_) => _commit(),
          autofocus: widget.autofocus,
          placeholder: Text(widget.placeholder ?? 'A1:B10'),
          onChanged: (v) => _validate(v),
          trailing: ShadTooltip(
            builder: (_) => Text(l.rangeInputPick),
            child: ShadIconButton.ghost(
              key: ValueKey<String>('${widget.keyName}.pick'),
              width: 26,
              height: 26,
              iconSize: 15,
              semanticLabel: l.rangeInputPick,
              backgroundColor: _picking ? theme.colorScheme.accent : null,
              icon: Icon(
                LucideIcons.grid2x2Check,
                color: _picking ? theme.colorScheme.primary : null,
              ),
              onPressed: widget.enabled ? _toggle : null,
            ),
          ),
        ),
        if (_picking || (_armed && !_focus.hasFocus))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.rangeInputPicking,
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          )
        else if (err != null && _text.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              err,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.destructive,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
