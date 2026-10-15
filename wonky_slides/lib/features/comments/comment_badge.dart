import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import 'slides_comments.dart';

/// The open-comment badge of a navigator row or grid cell (Slides 04 §5.2,
/// 09 §3.3): the number of open threads on [slideId] (or, for a collapsed
/// group header, on the slides of [groupId]); clicking it makes the slide
/// current and opens the comments panel scoped to it.
class SlideCommentBadge extends StatelessWidget {
  const SlideCommentBadge({
    super.key,
    required this.editor,
    this.slideId,
    this.groupId,
  }) : assert(slideId != null || groupId != null);

  final DeckEditorController editor;
  final String? slideId;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final comments = SlidesComments.of(editor);
    if (comments == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: comments,
      builder: (context, _) {
        if (!comments.visible) return const SizedBox.shrink();
        final n = slideId != null
            ? comments.threadsOn(slideId!).length
            : comments.openCountOfGroup(groupId!);
        if (n == 0) return const SizedBox.shrink();
        final theme = ShadTheme.of(context);
        final l = slidesL10n(context);
        final label = l.commentsBadge(n);
        final badge = Container(
          height: 16,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.popover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.messageSquare,
                size: 10,
                color: theme.colorScheme.popoverForeground,
              ),
              const SizedBox(width: 2),
              Text(
                '$n',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.popoverForeground,
                ),
              ),
            ],
          ),
        );
        return ShadTooltip(
          builder: (_) => Text(label),
          child: Semantics(
            button: slideId != null,
            label: label,
            excludeSemantics: true,
            child: slideId == null
                ? badge
                : GestureDetector(
                    key: ValueKey<String>('slides.comments.badge.$slideId'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      editor.setCurrentSlide(slideId!);
                      unawaited(
                        editor.invokeCommand(
                          'slides.comments.openPanel',
                          const {'scope': SlidesComments.scopeSlide},
                          InvocationSource.ui,
                        ),
                      );
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: badge,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
