import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/code.dart' show CodeElementData;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

import '../../../l10n/slides_l10n.dart';

/// The copy button of code elements while presenting (Slides 07 §3.7):
/// hovering a code element whose `copyButton` is `present` or `always`
/// shows a 32 su copy button at the top-right of its box; it copies the
/// displayed state's code as plain text and shows a check for 1 s. Lies
/// above the stage's pointer input, so only the button takes clicks.
class CodeCopyOverlay extends StatelessWidget {
  const CodeCopyOverlay({
    super.key,
    required this.model,
    required this.slide,
    required this.frame,
    required this.origin,
    required this.scale,
  });

  final DeckModel model;
  final ResolvedSlide slide;

  static int? _claimed;

  /// Whether pointer [pointer] went down on a copy button (the stage's
  /// click-to-advance ignores it).
  static bool claims(int pointer) => _claimed == pointer;
  final SlideFrame frame;
  final Offset origin;
  final double scale;

  /// The code elements of [slide] that offer the button.
  static List<ResolvedElement> targets(ResolvedSlide slide) {
    final out = <ResolvedElement>[];
    void walk(List<ResolvedElement> list) {
      for (final e in list) {
        if (e.hidden) continue;
        if (e.record.kind == ElementKind.code) {
          final mode = CodeElementData.fromJson(e.data).copyButton;
          if (mode == 'present' || mode == 'always') out.add(e);
        }
        walk(e.children);
      }
    }

    walk(slide.elements);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = targets(slide);
    if (items.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        for (final e in items)
          if (frame.stateOf(e.id).visible)
            Positioned(
              left: origin.dx + e.frame.x * scale,
              top: origin.dy + e.frame.y * scale,
              width: e.frame.width * scale,
              height: e.frame.height * scale,
              child: _CodeCopyTarget(
                key: ValueKey<String>('slides.present.codeCopy.${e.id}'),
                code: () => _displayedCode(e.id),
                size: (32 * scale).clamp(24.0, 48.0),
              ),
            ),
      ],
    );
  }

  String _displayedCode(String elementId) {
    final states = model.codeStatesOf(elementId);
    if (states.isEmpty) return '';
    final s = frame.stateOf(elementId);
    final i = (s.code?.stateIndex ?? s.codeStateIndex ?? 0).clamp(
      0,
      states.length - 1,
    );
    return states[i].code;
  }
}

class _CodeCopyTarget extends StatefulWidget {
  const _CodeCopyTarget({super.key, required this.code, required this.size});

  final String Function() code;
  final double size;

  @override
  State<_CodeCopyTarget> createState() => _CodeCopyTargetState();
}

class _CodeCopyTargetState extends State<_CodeCopyTarget> {
  bool _hover = false;
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code()));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final s = widget.size;
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      opaque: false,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(s * 0.25),
          child: Visibility(
            visible: _hover || _copied,
            maintainState: true,
            child: Semantics(
              button: true,
              label: _copied ? l.toastCodeCopied : l.cmdCodeCopy,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Listener(
                  onPointerDown: (e) => CodeCopyOverlay._claimed = e.pointer,
                  child: GestureDetector(
                    key: const ValueKey<String>(
                      'slides.present.codeCopy.button',
                    ),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(_copy()),
                    child: Container(
                      width: s,
                      height: s,
                      decoration: BoxDecoration(
                        color: const Color(0xcc1f2937),
                        borderRadius: BorderRadius.circular(s * 0.2),
                      ),
                      child: CustomPaint(painter: _GlyphPainter(_copied)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A copy (two rounded squares) or check glyph.
class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.check);

  final bool check;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xffe5e7eb);
    final w = size.width;
    if (check) {
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.28, w * 0.52)
          ..lineTo(w * 0.44, w * 0.68)
          ..lineTo(w * 0.72, w * 0.34),
        p,
      );
      return;
    }
    final r = Radius.circular(w * 0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.36, w * 0.36, w * 0.34, w * 0.34),
        r,
      ),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, w * 0.6)
        ..lineTo(w * 0.28, w * 0.32)
        ..arcToPoint(Offset(w * 0.32, w * 0.28), radius: r)
        ..lineTo(w * 0.6, w * 0.28),
      p,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.check != check;
}
