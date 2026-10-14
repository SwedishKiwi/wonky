import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'data_tools.dart';

/// The floating *Separator* chip after *Split text to columns* (04 §11.13):
/// Detect automatically / Comma / Semicolon / Period / Space / Custom.
/// Changing it undoes the previous split and splits again (one undo step).
class SplitSeparatorChip extends StatefulWidget {
  const SplitSeparatorChip({
    super.key,
    required this.editor,
    required this.state,
  });

  final SheetEditorController editor;
  final SplitChipState state;

  @override
  State<SplitSeparatorChip> createState() => _SplitSeparatorChipState();
}

class _SplitSeparatorChipState extends State<SplitSeparatorChip> {
  static const _presets = {
    'comma': ',',
    'semicolon': ';',
    'period': '.',
    'space': ' ',
  };

  late String _choice = _choiceOf(widget.state.separator);
  final _custom = TextEditingController();

  static String _choiceOf(String? sep) {
    if (sep == null) return 'auto';
    for (final e in _presets.entries) {
      if (e.value == sep) return e.key;
    }
    return 'custom';
  }

  @override
  void initState() {
    super.initState();
    final sep = widget.state.separator;
    if (_choice == 'custom' && sep != null) _custom.text = sep;
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  Future<void> _resplit(String? separator) async {
    final ed = widget.editor;
    final st = widget.state;
    if (!st.failed) await ed.services.undo.undo();
    await ed.invokeCommand('sheets.data.splitTextToColumns', {
      'range': st.range.a1,
      'separator': ?separator,
    });
  }

  String _label(SheetsLocalizations l, String c) => switch (c) {
    'auto' => l.splitDetect,
    'comma' => l.splitComma,
    'semicolon' => l.splitSemicolon,
    'period' => l.splitPeriod,
    'space' => l.splitSpace,
    _ => l.splitCustom,
  };

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return Focus(
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          DataTools.of(widget.editor).splitChip.value = null;
          widget.editor.gridFocus.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        key: const ValueKey<String>('sheets.splitChip'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: cs.popover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.splitSeparator, style: theme.textTheme.small),
            const SizedBox(width: 6),
            ShadSelect<String>(
              key: ValueKey<String>('sheets.splitChip.select.$_choice'),
              initialValue: _choice,
              minWidth: 150,
              options: [
                for (final c in const [
                  'auto',
                  'comma',
                  'semicolon',
                  'period',
                  'space',
                  'custom',
                ])
                  ShadOption(value: c, child: Text(_label(l, c))),
              ],
              selectedOptionBuilder: (context, v) => Text(_label(l, v)),
              onChanged: (v) {
                if (v == null || v == _choice) return;
                setState(() => _choice = v);
                if (v == 'custom') return;
                unawaited(_resplit(v == 'auto' ? null : _presets[v]));
              },
            ),
            if (_choice == 'custom') ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 64,
                child: ShadInput(
                  key: const ValueKey<String>('sheets.splitChip.custom'),
                  controller: _custom,
                  autofocus: true,
                  onSubmitted: (v) {
                    if (v.isNotEmpty) unawaited(_resplit(v));
                  },
                ),
              ),
            ],
            if (widget.state.failed) ...[
              const SizedBox(width: 8),
              Text(
                l.splitNoSeparator,
                style: theme.textTheme.small.copyWith(color: cs.destructive),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
