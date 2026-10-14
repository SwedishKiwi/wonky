import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'find_controller.dart';

/// "3 of 12" / "No results" / "100,000+".
String findStatusText(SheetsLocalizations l, FindController f) {
  if (f.query.isEmpty) return '';
  if (f.error != null) return '';
  final (cur, total, capped) = f.status;
  if (total == 0) return l.findNoResults;
  final t = capped ? '$total+' : '$total';
  return cur <= 0 ? l.findMatchesCount(t) : l.findOfCount(cur, t);
}

/// The compact find bar at the top-right of the grid (07 §11.1): query,
/// "3 of 12", ↑/↓, ⋮ (Find and replace), ✕. Enter = next, Shift+Enter =
/// previous, Esc closes and returns to the grid.
class FindBar extends StatefulWidget {
  const FindBar({super.key, required this.editor, required this.find});

  final SheetEditorController editor;
  final FindController find;

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  late final TextEditingController _text = TextEditingController(
    text: widget.find.query,
  );
  final _focus = FocusNode(debugLabel: 'sheets.find.query');

  FindController get f => widget.find;

  @override
  void initState() {
    super.initState();
    f.addListener(_sync);
    f.focusRequest.addListener(_focusInput);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusInput());
  }

  void _focusInput() {
    if (!mounted) return;
    _focus.requestFocus();
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
  }

  void _sync() {
    if (_text.text != f.query && !_focus.hasFocus) _text.text = f.query;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    f.removeListener(_sync);
    f.focusRequest.removeListener(_focusInput);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run(String id) => unawaited(widget.editor.invokeCommand(id));

  KeyEventResult _keys(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _run('sheets.find.close');
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _run(
        HardwareKeyboard.instance.isShiftPressed
            ? 'sheets.find.previous'
            : 'sheets.find.next',
      );
      _focus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final status = findStatusText(l, f);
    final has = f.matches.isNotEmpty;
    return Focus(
      onKeyEvent: _keys,
      child: Container(
        key: const ValueKey<String>('sheets.findBar'),
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cs.popover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SizedBox(
                width: 230,
                child: Semantics(
                  label: l.findPlaceholder,
                  textField: true,
                  child: ShadInput(
                    key: const ValueKey<String>('sheets.findBar.query'),
                    controller: _text,
                    focusNode: _focus,
                    placeholder: Text(l.findPlaceholder),
                    leading: Icon(
                      LucideIcons.search,
                      size: 15,
                      color: cs.mutedForeground,
                    ),
                    trailing: status.isEmpty
                        ? null
                        : Semantics(
                            liveRegion: true,
                            child: Text(
                              status,
                              key: const ValueKey<String>(
                                'sheets.findBar.status',
                              ),
                              style: theme.textTheme.muted.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ),
                    onChanged: (v) => f.setQuery(v),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            _IconBtn(
              keyName: 'sheets.findBar.previous',
              icon: LucideIcons.chevronUp,
              tooltip: l.cmdFindPrevious,
              onPressed: has ? () => _run('sheets.find.previous') : null,
            ),
            _IconBtn(
              keyName: 'sheets.findBar.next',
              icon: LucideIcons.chevronDown,
              tooltip: l.cmdFindNext,
              onPressed: has ? () => _run('sheets.find.next') : null,
            ),
            _IconBtn(
              keyName: 'sheets.findBar.more',
              icon: LucideIcons.ellipsisVertical,
              tooltip: l.cmdFindOpenReplace,
              onPressed: () => unawaited(
                widget.editor.invokeCommand('sheets.find.openReplace', {
                  'query': _text.text,
                }),
              ),
            ),
            _IconBtn(
              keyName: 'sheets.findBar.close',
              icon: LucideIcons.x,
              tooltip: l.findClose,
              onPressed: () => _run('sheets.find.close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.keyName,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final String keyName;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ShadTooltip(
    builder: (_) => Text(tooltip),
    child: ShadIconButton.ghost(
      key: ValueKey<String>(keyName),
      width: 30,
      height: 30,
      icon: Icon(icon, size: 16),
      onPressed: onPressed,
      enabled: onPressed != null,
    ),
  );
}
