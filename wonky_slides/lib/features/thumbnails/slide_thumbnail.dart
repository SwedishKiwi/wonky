import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/themes.dart';

import '../stage/slide_renderer.dart';

/// A slide thumbnail (navigator, grid view, slide picker; 04 §5): the
/// renderer's cached picture of the slide at [width], repainted when the
/// deck changes, fonts load or images decode.
class SlideThumbnail extends StatelessWidget {
  const SlideThumbnail({
    super.key,
    required this.renderer,
    required this.slideId,
    required this.width,
    this.appearance,
    this.semanticLabel,
  });

  final SlideRenderer renderer;
  final String slideId;

  /// Width in logical px (the height follows the slide size).
  final double width;

  /// Appearance override (null = the deck's).
  final SlideAppearance? appearance;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final size = renderer.slideSize;
    final height = width * size.height / size.width;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: height,
        child: ListenableBuilder(
          listenable: Listenable.merge([renderer, renderer.images]),
          builder: (context, _) {
            final picture = renderer.thumbnail(
              slideId,
              width: width,
              appearance: appearance,
            );
            return CustomPaint(
              size: Size(width, height),
              painter: _PicturePainter(picture?.picture),
            );
          },
        ),
      ),
    );
  }
}

class _PicturePainter extends CustomPainter {
  _PicturePainter(this.picture);

  final ui.Picture? picture;

  @override
  void paint(Canvas canvas, Size size) {
    final p = picture;
    if (p == null) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPicture(p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PicturePainter old) => !identical(old.picture, picture);
}
