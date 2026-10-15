import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart';

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import 'find_controller.dart';

/// "3 of 12" / "12 matches" / "No results" (03 §13).
String findStatusText(SlidesLocalizations l, DeckFindController f) {
  if (f.query.isEmpty || f.error != null) return '';
  final (cur, total) = f.status;
  if (total == 0) return l.findNoResults;
  return cur <= 0 ? l.findMatchesCount(total) : l.findOfCount(cur, total);
}

/// The compact find bar at the top-right of the canvas (03 §13, ⌘F):
/// query, "3 of 12", ↑/↓, *Find and replace*, ✕. Enter = next,
/// Shift+Enter = previous, Esc closes and returns to the canvas.
class SlidesFindBar extends StatefulWidget {
  const SlidesFindBar({super.key, required this.editor});

  final DeckEditorController editor;

  static const barKey = ValueKey<String>('slides.findBar');

  @override
  State<SlidesFindBar> createState() => _SlidesFindBarState();
}

class _SlidesFindBarState extends State<SlidesFindBar> {
  late final DeckFindController f = DeckFindController.of(widget.editor);
  late final TextEditingController _text = TextEditingController(text: f.query);
  final _focus = FocusNode(debugLabel: 'slides.find.query');

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

  Future<void> _run(String id, [Map<String, Object?> args = const {}]) => widget
      .editor
      .services
      .dispatcher
      .invoke(id, args: args, source: InvocationSource.ui);

  Future<void> _step(String id) async {
    await _run(id, {'query': _text.text});
    // Showing a match starts text editing: the bar keeps the keyboard.
    if (mounted) _focus.requestFocus();
  }

  KeyEventResult _keys(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(_run('slides.find.close'));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      unawaited(
        _step(
          HardwareKeyboard.instance.isShiftPressed
              ? 'slides.find.previous'
              : 'slides.find.next',
        ),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final status = findStatusText(l, f);
    final has = f.matches.isNotEmpty;
    return Focus(
      onKeyEvent: _keys,
      child: Container(
        key: SlidesFindBar.barKey,
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
                width: 220,
                child: Semantics(
                  label: l.findPlaceholder,
                  textField: true,
                  child: ShadInput(
                    key: const ValueKey<String>('slides.findBar.query'),
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
                                'slides.findBar.status',
                              ),
                              style: theme.textTheme.muted.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ),
                    onChanged: (v) => f.search(v),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            FindIconButton(
              keyName: 'slides.findBar.previous',
              icon: LucideIcons.chevronUp,
              tooltip: l.cmdFindPrevious,
              onPressed: has ? () => _step('slides.find.previous') : null,
            ),
            FindIconButton(
              keyName: 'slides.findBar.next',
              icon: LucideIcons.chevronDown,
              tooltip: l.cmdFindNext,
              onPressed: has ? () => _step('slides.find.next') : null,
            ),
            FindIconButton(
              keyName: 'slides.findBar.replace',
              icon: LucideIcons.replace,
              tooltip: l.cmdFindOpenReplace,
              onPressed: () => unawaited(
                _run('slides.find.openReplace', {'find': _text.text}),
              ),
            ),
            FindIconButton(
              keyName: 'slides.findBar.close',
              icon: LucideIcons.x,
              tooltip: l.findClose,
              onPressed: () => unawaited(_run('slides.find.close')),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small ghost icon button with a tooltip and a stable key.
class FindIconButton extends StatelessWidget {
  const FindIconButton({
    super.key,
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
    child: Semantics(
      button: true,
      label: tooltip,
      child: ShadIconButton.ghost(
        key: ValueKey<String>(keyName),
        width: 30,
        height: 30,
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        enabled: onPressed != null,
      ),
    ),
  );
}
