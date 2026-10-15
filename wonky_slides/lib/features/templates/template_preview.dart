import 'package:flutter/widgets.dart';
import 'package:wonky_slides_core/templates.dart';
import 'package:wonky_sync_models/ids.dart' show SequentialIdGenerator;

import '../stage/slide_renderer.dart';
import '../thumbnails/slide_thumbnail.dart';

/// The picture of a built-in template's gallery card (Slides 04 §15): its
/// first slide rendered like a navigator thumbnail, in the deck's own
/// appearance (a dark template stays dark in a light app). The template
/// deck is built in memory once per template (the same planner operations
/// a new deck gets, with fixed ids) and kept with its renderer for the
/// app's lifetime (5–10 small decks).
class SlidesTemplatePreview extends StatelessWidget {
  const SlidesTemplatePreview({
    super.key,
    required this.template,
    required this.width,
  });

  final SlidesTemplate template;

  /// Width in logical px (the height follows the slide size, 16:9).
  final double width;

  static final Map<String, SlideRenderer> _renderers = {};

  /// The renderer of [t]'s preview deck (built on first use).
  static SlideRenderer rendererOf(SlidesTemplate t) =>
      _renderers[t.key] ??= SlideRenderer(
        model: t
            .build(
              deckId: '00000000-0000-4000-8000-00000000c0de',
              userId: '00000000-0000-4000-8000-000000000001',
              now: DateTime.utc(2026),
              ids: SequentialIdGenerator(1),
            )
            .model,
      );

  @override
  Widget build(BuildContext context) {
    final renderer = rendererOf(template);
    return SlideThumbnail(
      renderer: renderer,
      slideId: renderer.model.slides.first.id,
      width: width,
      semanticLabel: template.name,
    );
  }
}
