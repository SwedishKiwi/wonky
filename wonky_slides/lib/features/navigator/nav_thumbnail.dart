import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../stage/slide_renderer.dart';
import '../thumbnails/slide_thumbnail.dart';

/// A slide thumbnail of the navigator and the grid view (04 §5.2, §9):
/// rounded 4 px with a 1 px border; the **current** slide gets a 2 px
/// `primary` ring, a **selected** one the selection ring; skipped slides
/// are drawn at 40 % opacity with an `eye-off` badge (tooltip *Skipped
/// with group* when skipped through the group).
class NavThumbnail extends StatelessWidget {
  const NavThumbnail({
    super.key,
    required this.renderer,
    required this.slideId,
    required this.width,
    this.current = false,
    this.selected = false,
    this.skipped = false,
    this.skippedWithGroup = false,
    this.dimmed = false,
    this.overlay,
  });

  final SlideRenderer renderer;
  final String slideId;
  final double width;
  final bool current;
  final bool selected;
  final bool skipped;
  final bool skippedWithGroup;

  /// Drawn faded (the rows being dragged).
  final bool dimmed;

  /// Painted over the thumbnail (number, hover menu button).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final tokens = SlidesTokens.of(context);
    final l = slidesL10n(context);
    final ring = current
        ? tokens.thumbnailRing
        : selected
        ? tokens.thumbnailSelection
        : theme.colorScheme.border;
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Opacity(
        opacity: skipped ? 0.4 : 1,
        child: SlideThumbnail(
          renderer: renderer,
          slideId: slideId,
          width: width,
        ),
      ),
    );
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: ring,
                width: current || selected ? 2 : 1,
              ),
            ),
            child: thumb,
          ),
          if (skipped)
            Positioned(
              right: 4,
              bottom: 4,
              child: ShadTooltip(
                builder: (_) => Text(
                  skippedWithGroup
                      ? l.navigatorSkippedWithGroup
                      : l.cmdSlideToggleSkip,
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.background,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: theme.colorScheme.border),
                  ),
                  child: Icon(
                    LucideIcons.eyeOff,
                    size: 11,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
          ?overlay,
        ],
      ),
    );
  }
}

/// The stacked preview of a collapsed group (04 §5.3): its first slide,
/// 64 px wide, with two offset shadows.
class StackedSlidePreview extends StatelessWidget {
  const StackedSlidePreview({
    super.key,
    required this.renderer,
    required this.slideId,
    this.width = 64,
  });

  final SlideRenderer renderer;
  final String slideId;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final size = renderer.slideSize;
    final h = width * size.height / size.width;
    Widget sheet(double dx) => Positioned(
      left: dx,
      top: dx,
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: theme.colorScheme.border),
        ),
      ),
    );
    return SizedBox(
      width: width + 6,
      height: h + 6,
      child: Stack(
        children: [
          sheet(6),
          sheet(3),
          Positioned(
            left: 0,
            top: 0,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: theme.colorScheme.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SlideThumbnail(
                  renderer: renderer,
                  slideId: slideId,
                  width: width,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
