import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_ui_localizations.dart';
import 'wonky_color.dart';

/// The "Custom…" panel of [WonkyColorPicker]: saturation/value square, hue
/// slider, optional alpha slider, hex and RGB inputs, eyedropper.
class CustomColorPanel extends StatefulWidget {
  const CustomColorPanel({
    super.key,
    required this.initial,
    required this.onApply,
    required this.onCancel,
    this.allowAlpha = false,
    this.onEyedropper,
  });

  final Color initial;
  final ValueChanged<Color> onApply;
  final VoidCallback onCancel;
  final bool allowAlpha;
  final Future<Color?> Function()? onEyedropper;

  @override
  State<CustomColorPanel> createState() => _CustomColorPanelState();
}

class _CustomColorPanelState extends State<CustomColorPanel> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController();
  late final _r = TextEditingController();
  late final _g = TextEditingController();
  late final _b = TextEditingController();
  final _svFocus = FocusNode(debugLabel: 'sv-square');
  late final _hue = ShadSliderController(initialValue: _hsv.hue);
  late final _alpha = ShadSliderController(initialValue: _hsv.alpha);

  @override
  void initState() {
    super.initState();
    _syncFields();
  }

  @override
  void dispose() {
    _hex.dispose();
    _r.dispose();
    _g.dispose();
    _b.dispose();
    _svFocus.dispose();
    _hue.dispose();
    _alpha.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _syncFields() {
    _syncSliders();
    final c = WonkyColor.fromColor(widget.allowAlpha ? _color : _color.withValues(alpha: 1));
    _hex.text = c.hex.substring(1).toUpperCase();
    _r.text = '${(_color.r * 255).round()}';
    _g.text = '${(_color.g * 255).round()}';
    _b.text = '${(_color.b * 255).round()}';
  }

  void _syncSliders() {
    if (_hue.value != _hsv.hue) _hue.value = _hsv.hue;
    if (_alpha.value != _hsv.alpha) _alpha.value = _hsv.alpha;
  }

  void _set(HSVColor hsv) {
    setState(() => _hsv = hsv);
    _syncFields();
  }

  void _onHex(String text) {
    final c = WonkyColor.tryParse(text);
    if (c != null) {
      setState(() => _hsv = HSVColor.fromColor(c.toColor()));
      _syncSliders();
      _r.text = '${(_color.r * 255).round()}';
      _g.text = '${(_color.g * 255).round()}';
      _b.text = '${(_color.b * 255).round()}';
    }
  }

  void _onRgb() {
    int v(TextEditingController t) => (int.tryParse(t.text) ?? 0).clamp(0, 255);
    final c = Color.fromARGB((_hsv.alpha * 255).round(), v(_r), v(_g), v(_b));
    setState(() => _hsv = HSVColor.fromColor(c));
    _syncSliders();
    _hex.text = WonkyColor.fromColor(c).hex.substring(1).toUpperCase();
  }

  void _svAt(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1 - (local.dy / size.height).clamp(0.0, 1.0);
    _set(_hsv.withSaturation(s).withValue(v));
  }

  KeyEventResult _svKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    const d = 0.02;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _set(_hsv.withSaturation((_hsv.saturation - d).clamp(0, 1)));
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _set(_hsv.withSaturation((_hsv.saturation + d).clamp(0, 1)));
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _set(_hsv.withValue((_hsv.value + d).clamp(0, 1)));
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _set(_hsv.withValue((_hsv.value - d).clamp(0, 1)));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = WonkyUiLocalizations.of(context);
    final theme = ShadTheme.of(context);
    const width = 224.0;
    Widget field(String label, TextEditingController c, VoidCallback onDone, {double w = 44}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.muted.copyWith(fontSize: 11)),
            SizedBox(
              width: w,
              height: 30,
              child: ShadInput(
                controller: c,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onDone(),
              ),
            ),
          ],
        );

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.colorCustomTitle, style: theme.textTheme.small),
          const SizedBox(height: 8),
          Semantics(
            label: l10n.colorSaturationValue,
            value: '${(_hsv.saturation * 100).round()}%, ${(_hsv.value * 100).round()}%',
            child: Focus(
              focusNode: _svFocus,
              onKeyEvent: _svKey,
              onFocusChange: (_) => setState(() {}),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(constraints.maxWidth, 140);
                  return GestureDetector(
                    onPanDown: (d) {
                      _svFocus.requestFocus();
                      _svAt(d.localPosition, size);
                    },
                    onPanUpdate: (d) => _svAt(d.localPosition, size),
                    child: CustomPaint(
                      size: size,
                      painter: _SvPainter(
                        hue: _hsv.hue,
                        saturation: _hsv.saturation,
                        value: _hsv.value,
                        focusColor: _svFocus.hasFocus ? theme.colorScheme.ring : null,
                        radius: 6,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            label: l10n.colorHue,
            child: ShadSlider(
              controller: _hue,
              max: 360,
              onChanged: (h) => _set(_hsv.withHue(h)),
            ),
          ),
          if (widget.allowAlpha) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(l10n.colorAlpha, style: theme.textTheme.muted.copyWith(fontSize: 11)),
                Expanded(
                  child: ShadSlider(
                    controller: _alpha,
                    max: 1,
                    onChanged: (a) => _set(_hsv.withAlpha(a)),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.colorScheme.border),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.colorHex, style: theme.textTheme.muted.copyWith(fontSize: 11)),
                    SizedBox(
                      height: 30,
                      child: ShadInput(
                        key: const ValueKey<String>('colorPicker.hex'),
                        controller: _hex,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Text('#', style: theme.textTheme.muted),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                          LengthLimitingTextInputFormatter(widget.allowAlpha ? 8 : 6),
                        ],
                        onChanged: _onHex,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              field(l10n.colorRed, _r, _onRgb),
              field(l10n.colorGreen, _g, _onRgb),
              field(l10n.colorBlue, _b, _onRgb),
              if (widget.onEyedropper != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ShadIconButton.outline(
                    width: 30,
                    height: 30,
                    iconSize: 14,
                    semanticLabel: l10n.colorEyedropper,
                    icon: const Icon(LucideIcons.pipette),
                    onPressed: () async {
                      final c = await widget.onEyedropper!();
                      if (c != null && mounted) _set(HSVColor.fromColor(c));
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShadButton.ghost(
                height: 30,
                onPressed: widget.onCancel,
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 6),
              ShadButton(
                key: const ValueKey<String>('colorPicker.apply'),
                height: 30,
                onPressed: () => widget.onApply(
                  widget.allowAlpha ? _color : _color.withValues(alpha: 1),
                ),
                child: Text(l10n.colorApply),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SvPainter extends CustomPainter {
  _SvPainter({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.radius,
    this.focusColor,
  });

  final double hue;
  final double saturation;
  final double value;
  final double radius;
  final Color? focusColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(rect, Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor());
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffffff), Color(0x00ffffff)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xff000000)],
        ).createShader(rect),
    );
    canvas.restore();
    if (focusColor != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = focusColor!,
      );
    }
    final p = Offset(saturation * size.width, (1 - value) * size.height);
    canvas.drawCircle(
      p,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xffffffff),
    );
    canvas.drawCircle(
      p,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66000000),
    );
  }

  @override
  bool shouldRepaint(_SvPainter old) =>
      old.hue != hue ||
      old.saturation != saturation ||
      old.value != value ||
      old.focusColor != focusColor;
}
