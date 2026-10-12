import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../keys/key_names.dart';
import '../../l10n/wonky_ui_localizations.dart';

/// Captures a key chord for the keyboard settings page (suite 02 §4.16) and
/// displays bindings with `ShadKbd`.
///
/// Click (or Enter) starts recording; the next non-modifier key with its
/// modifiers is reported through [onRecorded]. Esc cancels recording.
class KeyboardShortcutRecorder extends StatefulWidget {
  const KeyboardShortcutRecorder({
    super.key,
    required this.labels,
    required this.onRecorded,
    this.onClear,
    this.conflict,
    this.enabled = true,
    this.semanticLabel,
  });

  /// Key caps of the current binding (empty = none).
  final List<String> labels;
  final ValueChanged<RecordedChord> onRecorded;
  final VoidCallback? onClear;

  /// Message shown under the recorder (e.g. "Already used by Bold").
  final String? conflict;
  final bool enabled;
  final String? semanticLabel;

  @override
  State<KeyboardShortcutRecorder> createState() =>
      _KeyboardShortcutRecorderState();
}

class _KeyboardShortcutRecorderState extends State<KeyboardShortcutRecorder> {
  final _focus = FocusNode(debugLabel: 'ShortcutRecorder');
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _recording) setState(() => _recording = false);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    setState(() => _recording = true);
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) {
      return _recording ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (!_recording) {
      if (e.logicalKey == LogicalKeyboardKey.enter ||
          e.logicalKey == LogicalKeyboardKey.space) {
        _start();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final kb = HardwareKeyboard.instance;
    if (e.logicalKey == LogicalKeyboardKey.escape &&
        !kb.isControlPressed &&
        !kb.isMetaPressed &&
        !kb.isAltPressed &&
        !kb.isShiftPressed) {
      setState(() => _recording = false);
      return KeyEventResult.handled;
    }
    final name = WonkyKeyNames.nameOf(e.logicalKey);
    if (name == null) return KeyEventResult.handled; // modifier or unsupported
    setState(() => _recording = false);
    widget.onRecorded(
      RecordedChord(
        key: name,
        control: kb.isControlPressed,
        meta: kb.isMetaPressed,
        alt: kb.isAltPressed,
        shift: kb.isShiftPressed,
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = WonkyUiLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: widget.semanticLabel ?? l10n.shortcutRecord,
              value: _recording
                  ? l10n.shortcutPress
                  : widget.labels.isEmpty
                  ? l10n.shortcutNone
                  : widget.labels.join(' '),
              child: Focus(
                focusNode: _focus,
                onKeyEvent: _onKey,
                onFocusChange: (_) => setState(() {}),
                child: GestureDetector(
                  onTap: _start,
                  child: MouseRegion(
                    cursor: widget.enabled
                        ? SystemMouseCursors.click
                        : MouseCursor.defer,
                    child: Container(
                      key: const ValueKey<String>('shortcutRecorder.field'),
                      constraints: const BoxConstraints(
                        minWidth: 120,
                        minHeight: 32,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: _recording ? theme.colorScheme.accent : null,
                        border: Border.all(
                          color: _focus.hasFocus
                              ? theme.colorScheme.ring
                              : widget.conflict != null
                              ? theme.colorScheme.destructive
                              : theme.colorScheme.input,
                          width: _focus.hasFocus ? 2 : 1,
                        ),
                      ),
                      child: _recording
                          ? Text(
                              l10n.shortcutPress,
                              style: theme.textTheme.muted,
                            )
                          : widget.labels.isEmpty
                          ? Text(
                              l10n.shortcutNone,
                              style: theme.textTheme.muted,
                            )
                          : ShadKbd.group(widget.labels, height: 22),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.onClear != null && widget.labels.isNotEmpty) ...[
              const SizedBox(width: 4),
              ShadIconButton.ghost(
                width: 28,
                height: 28,
                iconSize: 14,
                semanticLabel: l10n.shortcutClear,
                icon: const Icon(LucideIcons.x),
                onPressed: widget.onClear,
              ),
            ],
          ],
        ),
        if (_recording)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.shortcutCancelHint,
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          )
        else if (widget.conflict != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.conflict!,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
          ),
      ],
    );
  }
}
