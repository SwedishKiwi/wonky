import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../theme/wonky_theme.dart';

/// A remote caret: 2 px bar + name flag in the presence color (suite 02
/// §4.8). The flag fades out after [WonkyThemeExtension.cursorFlagFadeDelay]
/// of inactivity and reappears on hover or when [lastActivity] changes.
///
/// Position it with a `Positioned` in the text layer; [height] is the line
/// height at the caret.
class RemoteCaret extends StatefulWidget {
  const RemoteCaret({
    super.key,
    required this.name,
    required this.color,
    required this.height,
    this.lastActivity,
    this.showFlag = true,
  });

  final String name;
  final Color color;
  final double height;

  /// Changes when the collaborator moves/types; restarts the flag timer.
  final Object? lastActivity;

  /// Screen-reader optimisation can turn flags off (suite 11 §3).
  final bool showFlag;

  @override
  State<RemoteCaret> createState() => _RemoteCaretState();
}

class _RemoteCaretState extends State<RemoteCaret> {
  bool _hover = false;
  bool _recent = true;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Timer _start() => Timer(WonkyThemeScope.of(context).cursorFlagFadeDelay, () {
    if (mounted) setState(() => _recent = false);
  });

  @override
  void didUpdateWidget(RemoteCaret oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastActivity != widget.lastActivity) _restart();
  }

  void _restart() {
    _timer?.cancel();
    _recent = true;
    _timer = _start();
  }

  @override
  Widget build(BuildContext context) {
    final ext = WonkyThemeScope.of(context);
    final fg = ShadColorScheme.contrastingForeground(widget.color);
    final visible = widget.showFlag && (_hover || _recent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        label: widget.name,
        child: SizedBox(
          width: 2,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: ColoredBox(color: widget.color)),
              Positioned(
                left: 0,
                bottom: widget.height,
                child: IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: ext.motion(context, 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                          bottomRight: Radius.circular(3),
                        ),
                      ),
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: fg,
                          fontSize: 11,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints remote selections: each rect filled with the presence color at
/// 20 % alpha (Write: text-line boxes; Sheets: cell ranges with a border).
class RemoteSelectionPainter extends CustomPainter {
  RemoteSelectionPainter({
    required this.selections,
    this.fillAlpha = 0.2,
    this.borderWidth = 0,
  });

  /// (color, rects) per collaborator.
  final List<(Color, List<Rect>)> selections;
  final double fillAlpha;

  /// Sheets draws a 2 px border around ranges; Write uses 0.
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (color, rects) in selections) {
      final fill = Paint()..color = color.withValues(alpha: fillAlpha);
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      for (final r in rects) {
        canvas.drawRect(r, fill);
        if (borderWidth > 0) {
          canvas.drawRect(r.deflate(borderWidth / 2), stroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(RemoteSelectionPainter old) =>
      old.fillAlpha != fillAlpha ||
      old.borderWidth != borderWidth ||
      !_sameSelections(old.selections, selections);

  static bool _sameSelections(
    List<(Color, List<Rect>)> a,
    List<(Color, List<Rect>)> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].$1 != b[i].$1 || a[i].$2.length != b[i].$2.length) return false;
      for (var j = 0; j < a[i].$2.length; j++) {
        if (a[i].$2[j] != b[i].$2[j]) return false;
      }
    }
    return true;
  }
}

/// Paints a caret bar with a small square "handle" on top, for canvases that
/// draw cursors without widgets (Sheets grid).
class RemoteCaretPainter extends CustomPainter {
  RemoteCaretPainter({required this.carets});

  /// (color, top-left of the caret, height).
  final List<(Color, Offset, double)> carets;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (color, at, height) in carets) {
      final p = Paint()..color = color;
      canvas.drawRect(Rect.fromLTWH(at.dx, at.dy, 2, height), p);
      canvas.drawRect(Rect.fromLTWH(at.dx - 2, at.dy - 2, 6, 4), p);
    }
  }

  @override
  bool shouldRepaint(RemoteCaretPainter old) {
    if (old.carets.length != carets.length) return true;
    for (var i = 0; i < carets.length; i++) {
      if (old.carets[i] != carets[i]) return true;
    }
    return false;
  }
}
