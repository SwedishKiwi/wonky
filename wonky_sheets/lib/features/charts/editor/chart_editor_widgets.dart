import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/sheets_l10n.dart';

/// A labeled row of the chart editor (label above the control).
class EditorField extends StatelessWidget {
  const EditorField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.small.copyWith(
              fontSize: 12,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// Two fields side by side (each half width).
class EditorPair extends StatelessWidget {
  const EditorPair({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: 8),
      Expanded(child: right),
    ],
  );
}

/// A checkbox row.
class EditorCheck extends StatelessWidget {
  const EditorCheck({
    super.key,
    required this.keyName,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String keyName;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: ShadCheckbox(
      key: ValueKey<String>('chartEditor.$keyName'),
      value: value,
      enabled: enabled,
      onChanged: onChanged,
      label: Text(label),
    ),
  );
}

/// A text field that commits on Enter or blur (08 §8).
class CommitTextField extends StatefulWidget {
  const CommitTextField({
    super.key,
    required this.keyName,
    required this.value,
    required this.onCommit,
    this.placeholder,
    this.enabled = true,
  });

  final String keyName;
  final String value;
  final ValueChanged<String> onCommit;
  final String? placeholder;
  final bool enabled;

  @override
  State<CommitTextField> createState() => _CommitTextFieldState();
}

class _CommitTextFieldState extends State<CommitTextField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(CommitTextField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _c.text) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (_c.text != widget.value) widget.onCommit(_c.text);
  }

  @override
  Widget build(BuildContext context) => ShadInput(
    key: ValueKey<String>('chartEditor.${widget.keyName}'),
    controller: _c,
    focusNode: _focus,
    enabled: widget.enabled,
    placeholder: widget.placeholder == null ? null : Text(widget.placeholder!),
    onSubmitted: (_) => _commit(),
  );
}

/// A nullable number field: empty = automatic; commits on Enter or blur.
class NumberCommitField extends StatelessWidget {
  const NumberCommitField({
    super.key,
    required this.keyName,
    required this.value,
    required this.onCommit,
    this.placeholder,
  });

  final String keyName;
  final num? value;
  final ValueChanged<num?> onCommit;
  final String? placeholder;

  static String _fmt(num? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) => CommitTextField(
    keyName: keyName,
    value: _fmt(value),
    placeholder: placeholder,
    onCommit: (t) {
      final s = t.trim().replaceAll(',', '.');
      if (s.isEmpty) {
        onCommit(null);
        return;
      }
      final n = num.tryParse(s);
      if (n != null) onCommit(n);
    },
  );
}

/// A stepper whose changes are debounced into one commit (and coalesced
/// into one undo step by the caller's key).
class EditorStepper extends StatelessWidget {
  const EditorStepper({
    super.key,
    required this.keyName,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.suffix,
  });

  final String keyName;
  final num? value;
  final ValueChanged<num> onChanged;
  final num min;
  final num max;
  final num step;
  final String? suffix;

  @override
  Widget build(BuildContext context) => WonkyNumberStepper(
    key: ValueKey<String>('chartEditor.$keyName'),
    value: value,
    min: min,
    max: max,
    step: step,
    dense: true,
    suffix: suffix,
    onChanged: onChanged,
  );
}

/// A color button opening a `WonkyColorPicker` (null = automatic/none).
class EditorColorButton extends StatefulWidget {
  const EditorColorButton({
    super.key,
    required this.keyName,
    required this.value,
    required this.onChanged,
    required this.resetLabel,
    this.automatic,
  });

  final String keyName;

  /// `#RRGGBB` or null.
  final String? value;
  final ValueChanged<String?> onChanged;
  final String resetLabel;

  /// Color shown when [value] is null.
  final Color? automatic;

  @override
  State<EditorColorButton> createState() => _EditorColorButtonState();
}

class _EditorColorButtonState extends State<EditorColorButton> {
  final _popover = ShadPopoverController();

  @override
  void dispose() {
    _popover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final parsed = widget.value == null
        ? null
        : WonkyColor.tryParse(widget.value!);
    final swatch = parsed?.toColor() ?? widget.automatic;
    return ShadPopover(
      controller: _popover,
      popover: (context) => WonkyColorPicker(
        value: parsed,
        resetLabel: widget.resetLabel,
        onChanged: (c) {
          _popover.hide();
          widget.onChanged(c?.hex.toUpperCase());
        },
      ),
      child: ShadButton.outline(
        key: ValueKey<String>('chartEditor.${widget.keyName}'),
        width: double.infinity,
        size: ShadButtonSize.sm,
        mainAxisAlignment: MainAxisAlignment.start,
        onPressed: _popover.toggle,
        leading: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: swatch,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: theme.colorScheme.border),
          ),
        ),
        child: Expanded(
          child: Text(
            widget.value ?? widget.resetLabel,
            textAlign: TextAlign.start,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// A collapsible Customize section (08 §8.2, `ShadAccordion` look) with a
/// *Reset* link that clears the section's overrides.
class EditorSection extends StatelessWidget {
  const EditorSection({
    super.key,
    required this.id,
    required this.title,
    required this.open,
    required this.onToggle,
    required this.children,
    this.onReset,
  });

  final String id;
  final String title;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback? onReset;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: title,
            child: ShadFocusable(
              builder: (context, focused, _) => GestureDetector(
                key: ValueKey<String>('chartEditor.section.$id'),
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: focused
                                ? TextDecoration.underline
                                : null,
                          ),
                        ),
                      ),
                      if (open && onReset != null)
                        ShadButton.link(
                          key: ValueKey<String>('chartEditor.reset.$id'),
                          size: ShadButtonSize.sm,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          onPressed: onReset,
                          child: Text(l.chartEditorReset),
                        ),
                      Icon(
                        open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        size: 16,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
              onKeyEvent: (node, e) {
                if (e is KeyDownEvent &&
                    (e.logicalKey == LogicalKeyboardKey.enter ||
                        e.logicalKey == LogicalKeyboardKey.space)) {
                  onToggle();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}

/// Runs [action] after [delay] of quiet (debounced commits of live inputs).
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _t;

  void call(void Function() action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }

  void dispose() => _t?.cancel();
}
