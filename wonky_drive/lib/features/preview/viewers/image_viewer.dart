import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../../l10n/drive_l10n.dart';
import '../file_preview_controller.dart';

/// Image viewer (Drive 02 §6.2): fit to window by default, zoom 10–800 %
/// (`+`/`−`, `Mod`+scroll, pinch), drag to pan, rotate 90° (view only), a
/// checkerboard behind transparency in the theme's colors.
class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key, required this.controller});

  final FilePreviewController controller;

  static const imageKey = ValueKey<String>('drive.preview.image');

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  final _h = ScrollController();
  final _v = ScrollController();
  double _pinchStart = 1;

  FilePreviewController get c => widget.controller;

  @override
  void dispose() {
    _h.dispose();
    _v.dispose();
    super.dispose();
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final kb = HardwareKeyboard.instance;
    if (!kb.isControlPressed && !kb.isMetaPressed) return;
    final factor = e.scrollDelta.dy > 0 ? 1 / 1.1 : 1.1;
    c.setZoom(c.effectiveZoom * factor);
  }

  void _pan(Offset delta) {
    void by(ScrollController sc, double d) {
      if (!sc.hasClients) return;
      final p = sc.position;
      sc.jumpTo((p.pixels - d).clamp(p.minScrollExtent, p.maxScrollExtent));
    }

    by(_h, delta.dx);
    by(_v, delta.dy);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = c.bytes!;
    final l = driveL10n(context);
    final cs = ShadTheme.of(context).colorScheme;
    final w = (c.imageWidth ?? 1).toDouble();
    final h = (c.imageHeight ?? 1).toDouble();
    final turned = c.quarterTurns.isOdd;
    final iw = turned ? h : w;
    final ih = turned ? w : h;
    return LayoutBuilder(
      builder: (context, box) {
        const pad = 24.0;
        final aw = math.max(1.0, box.maxWidth - pad * 2);
        final ah = math.max(1.0, box.maxHeight - pad * 2);
        // Fit to window; small images stay at their actual size.
        final fit = math.min(1.0, math.min(aw / iw, ah / ih));
        c.reportFitScale(fit);
        final z = c.effectiveZoom;
        final dw = iw * z;
        final dh = ih * z;
        final image = Image.memory(
          bytes,
          key: ImageViewer.imageKey,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          filterQuality: z < 1 ? FilterQuality.medium : FilterQuality.none,
          semanticLabel: l.previewImageSemantics(
            c.item?.name ?? '',
            c.imageWidth ?? 0,
            c.imageHeight ?? 0,
          ),
          errorBuilder: (context, error, stack) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => c.reportImageBroken(),
            );
            return const SizedBox.shrink();
          },
        );
        return Listener(
          onPointerSignal: _onSignal,
          child: GestureDetector(
            onScaleStart: (_) => _pinchStart = c.effectiveZoom,
            onScaleUpdate: (d) {
              if (d.pointerCount >= 2) {
                c.setZoom(_pinchStart * d.scale);
              } else {
                _pan(d.focalPointDelta);
              }
            },
            child: MouseRegion(
              cursor: dw > aw || dh > ah
                  ? SystemMouseCursors.grab
                  : MouseCursor.defer,
              child: RawScrollbar(
                controller: _v,
                child: SingleChildScrollView(
                  controller: _v,
                  physics: const ClampingScrollPhysics(),
                  child: RawScrollbar(
                    controller: _h,
                    notificationPredicate: (n) => n.depth == 0,
                    child: SingleChildScrollView(
                      controller: _h,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: box.maxWidth,
                          minHeight: box.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(pad),
                          child: Center(
                            child: SizedBox(
                              width: dw,
                              height: dh,
                              child: CustomPaint(
                                painter: _CheckerPainter(
                                  cs.muted,
                                  cs.background,
                                ),
                                child: RotatedBox(
                                  quarterTurns: c.quarterTurns,
                                  child: image,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The transparency checkerboard (8 px squares in theme colors).
class _CheckerPainter extends CustomPainter {
  _CheckerPainter(this.a, this.b);

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    const s = 8.0;
    final all = Offset.zero & size;
    canvas.drawRect(all, Paint()..color = b);
    final p = Paint()..color = a;
    // Only the visible part (zoomed images can be huge).
    final r = canvas.getLocalClipBounds().intersect(all);
    if (r.isEmpty) return;
    final y0 = (r.top / s).floorToDouble() * s;
    final x0 = (r.left / (s * 2)).floorToDouble() * s * 2;
    for (var y = y0; y < r.bottom; y += s) {
      final odd = (y ~/ s).isOdd;
      for (var x = x0 + (odd ? s : 0.0); x < r.right; x += s * 2) {
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            y,
            math.min(s, size.width - x),
            math.min(s, size.height - y),
          ),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => old.a != a || old.b != b;
}
