import 'dart:math';

import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';

/// A random operation against [m] (null when nothing fits).
SlidesOperation? randomOp(Random r, DeckModel m) {
  final slides = m.slides;
  T pick<T>(List<T> l) => l[r.nextInt(l.length)];
  final elements = [
    for (final s in slides)
      for (final e in m.elementsOf(s.id))
        if (e.kind != ElementKind.group) e,
  ];
  switch (r.nextInt(11)) {
    case 0:
      return AddSlides(
        count: 1 + r.nextInt(2),
        afterSlideId: slides.isEmpty ? null : pick(slides).id,
      );
    case 1:
      return slides.length < 2 ? null : DeleteSlides([pick(slides).id]);
    case 2:
      if (slides.length < 2) return null;
      final a = pick(slides).id;
      final b = pick(slides).id;
      return a == b ? null : MoveSlides([a], TopLevel(beforeId: b));
    case 3:
      return slides.isEmpty
          ? null
          : SetSlideProps([pick(slides).id], skipped: r.nextBool());
    case 4:
      return SetDeckProps(title: 'Deck ${r.nextInt(1000)}');
    case 5:
      return slides.isEmpty
          ? null
          : InsertElements(pick(slides).id, [
              ElementSpec(
                kind: ElementKind.shape,
                x: r.nextInt(800).toDouble(),
                y: r.nextInt(400).toDouble(),
                width: 50 + r.nextInt(200).toDouble(),
                height: 50 + r.nextInt(200).toDouble(),
              ),
            ]);
    case 6:
      return elements.isEmpty
          ? null
          : UpdateFrames([
              FrameUpdate(
                pick(elements).id,
                x: r.nextInt(900).toDouble(),
                y: r.nextInt(500).toDouble(),
              ),
            ]);
    case 7:
      return elements.isEmpty
          ? null
          : SetElementProps([
              pick(elements).id,
            ], opacity: Patch(r.nextDouble()));
    case 8:
      return elements.isEmpty ? null : DeleteElements([pick(elements).id]);
    case 9:
      return slides.length < 2
          ? null
          : CreateGroup([pick(slides).id], title: 'G${r.nextInt(99)}');
    default:
      return elements.isEmpty
          ? null
          : SetText(
              ElementText(pick(elements).id),
              '[{"insert":"t${r.nextInt(999)}\\n"}]',
            );
  }
}
