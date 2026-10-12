import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_ui_localizations.dart';

/// `ShadInput` with −/+ buttons, min/max/step, scroll-to-change, arrow keys
/// and validation (suite 02 §4.9). Used for font size, decimal places, row
/// counts, page margins.
///
/// The field commits on Enter, blur, button press, arrow key or scroll; an
/// invalid entry reverts to the last valid [value]. A null [value] shows an
/// empty field (mixed selection).
class WonkyNumberStepper extends StatefulWidget {
  const WonkyNumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
    this.step = 1,
    this.fractionDigits = 0,
    this.enabled = true,
    this.dense = false,
    this.width,
    this.suffix,
    this.semanticLabel,
  });

  final num? value;
  final ValueChanged<num> onChanged;
  final num min;
  final num max;
  final num step;
  final int fractionDigits;
  final bool enabled;

  /// Toolbar size (28 px high).
  final bool dense;
  final double? width;

  /// Unit shown after the number ("pt", "cm").
  final String? suffix;
  final String? semanticLabel;

  @override
  State<WonkyNumberStepper> createState() => _WonkyNumberStepperState();
}

class _WonkyNumberStepperState extends State<WonkyNumberStepper> {
  late final TextEditingController _text = TextEditingController(
    text: _format(widget.value),
  );
  final _focus = FocusNode(debugLabel: 'WonkyNumberStepper');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commitText();
    });
  }

  @override
  void didUpdateWidget(WonkyNumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _text.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _format(num? v) {
    if (v == null) return '';
    if (widget.fractionDigits == 0) return v.round().toString();
    final s = v.toStringAsFixed(widget.fractionDigits);
    // Trim trailing zeros: 10.50 → 10.5, 10.00 → 10.
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }

  num _clamp(num v) {
    final c = v.clamp(widget.min, widget.max);
    if (widget.fractionDigits == 0) return c.round();
    final p = _pow10(widget.fractionDigits);
    return (c * p).round() / p;
  }

  static num _pow10(int n) {
    var p = 1;
    for (var i = 0; i < n; i++) {
      p *= 10;
    }
    return p;
  }

  void _emit(num v) {
    final c = _clamp(v);
    _text.text = _format(c);
    if (c != widget.value) widget.onChanged(c);
  }

  void _commitText() {
    final parsed = num.tryParse(_text.text.trim().replaceAll(',', '.'));
    if (parsed == null) {
      _text.text = _format(widget.value);
      return;
    }
    _emit(parsed);
  }

  void _bump(int direction) {
    final current =
        num.tryParse(_text.text.trim().replaceAll(',', '.')) ??
        widget.value ??
        widget.min;
    _emit(current + widget.step * direction);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = WonkyUiLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final height = widget.dense ? 28.0 : 36.0;
    final canDec = widget.enabled && (widget.value ?? widget.max) > widget.min;
    final canInc = widget.enabled && (widget.value ?? widget.min) < widget.max;
    Widget button(IconData icon, String label, bool enabled, int dir) =>
        ShadIconButton.ghost(
          icon: Icon(icon, size: 14),
          width: height - 4,
          height: height - 4,
          semanticLabel: label,
          enabled: enabled,
          onPressed: () => _bump(dir),
        );

    return Semantics(
      label: widget.semanticLabel,
      child: Listener(
        onPointerSignal: (event) {
          if (!widget.enabled || event is! PointerScrollEvent) return;
          if (!_focus.hasFocus) return;
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {
            _bump(event.scrollDelta.dy < 0 ? 1 : -1);
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(LucideIcons.minus, l10n.stepperDecrease, canDec, -1),
            SizedBox(
              width: widget.width ?? (widget.dense ? 44 : 64),
              height: height,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _bump(1),
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _bump(-1),
                },
                child: ShadInput(
                  controller: _text,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                  ],
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.normal,
                  ),
                  trailing: widget.suffix == null
                      ? null
                      : Text(widget.suffix!, style: theme.textTheme.muted),
                  onSubmitted: (_) => _commitText(),
                ),
              ),
            ),
            button(LucideIcons.plus, l10n.stepperIncrease, canInc, 1),
          ],
        ),
      ),
    );
  }
}
