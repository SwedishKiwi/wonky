import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

/// A text input that commits on Enter and when it loses focus (range,
/// value names, calculated field formulas).
class PivotCommitInput extends StatefulWidget {
  const PivotCommitInput({
    super.key,
    required this.value,
    required this.onCommit,
    this.placeholder,
    this.enabled = true,
    this.mono = false,
    this.error,
    this.semanticLabel,
  });

  final String value;
  final ValueChanged<String> onCommit;
  final String? placeholder;
  final bool enabled;
  final bool mono;

  /// Inline validation message under the input.
  final String? error;
  final String? semanticLabel;

  @override
  State<PivotCommitInput> createState() => _PivotCommitInputState();
}

class _PivotCommitInputState extends State<PivotCommitInput> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(PivotCommitInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _text.text = widget.value;
    }
  }

  void _onFocus() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (_text.text != widget.value) widget.onCommit(_text.text);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final err = widget.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: widget.semanticLabel,
          textField: true,
          child: ShadInput(
            controller: _text,
            focusNode: _focus,
            enabled: widget.enabled,
            style: widget.mono
                ? theme.textTheme.small.copyWith(
                    fontFamily: 'GeistMono',
                    fontSize: 12,
                  )
                : null,
            placeholder: widget.placeholder == null
                ? null
                : Text(widget.placeholder!),
            onSubmitted: (_) => _commit(),
          ),
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              err,
              style: theme.textTheme.small.copyWith(
                fontSize: 12,
                color: theme.colorScheme.destructive,
              ),
            ),
          ),
      ],
    );
  }
}

/// A labelled option row of a field card: label at the left, control at the
/// right (stacked below 260 px).
class PivotOptionRow extends StatelessWidget {
  const PivotOptionRow({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.small.copyWith(
        fontSize: 12,
        color: theme.colorScheme.mutedForeground,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth < 260
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 4), child],
              )
            : Row(
                children: [
                  SizedBox(width: 92, child: text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: child),
                  ),
                ],
              ),
      ),
    );
  }
}

/// A `ShadSelect` over [options] (value → label) showing [value].
class PivotSelect<T> extends StatelessWidget {
  const PivotSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.minWidth = 140,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final double minWidth;

  @override
  Widget build(BuildContext context) => ShadSelect<T>(
    key: ValueKey<Object?>(('pivot.select', value, options.length)),
    enabled: enabled,
    initialValue: value,
    minWidth: minWidth,
    maxHeight: 320,
    selectedOptionBuilder: (context, v) =>
        Text(options[v] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
    onChanged: (v) {
      if (v != null && v != value) onChanged(v);
    },
    options: [
      for (final e in options.entries)
        ShadOption<T>(value: e.key, child: Text(e.value)),
    ],
  );
}
