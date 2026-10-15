import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../text_editing/text_editing_host.dart';
import 'collab_canvas_layer.dart' show SoftLockPopover;
import 'slides_collab.dart';
import 'slides_presence_controller.dart';

/// Presence dots of a navigator row or grid cell (Slides 09 §1.2): up to 3
/// 14 px avatars of the participants on [slideId] (or, for a collapsed
/// group header, on any slide of [groupId]), then "+N"; hover lists the
/// names; clicking one jumps to that participant (09 §1.3).
class SlidePresenceDots extends StatelessWidget {
  const SlidePresenceDots({
    super.key,
    required this.editor,
    this.slideId,
    this.groupId,
  }) : assert(slideId != null || groupId != null);

  final DeckEditorController editor;
  final String? slideId;
  final String? groupId;

  /// Avatars shown before "+N".
  static const maxDots = 3;

  @override
  Widget build(BuildContext context) {
    final collab = SlidesCollab.of(editor);
    if (collab == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: collab.presence,
      builder: (context, _) {
        final here = _here(collab.presence);
        if (here.isEmpty) return const SizedBox.shrink();
        final theme = ShadTheme.of(context);
        final l = slidesL10n(context);
        final names = here
            .map((c) => collab.presence.labelOf(c.participant))
            .join(', ');
        final shown = here.take(maxDots).toList();
        return ShadTooltip(
          builder: (_) => Text(names),
          child: Semantics(
            label: slideId != null
                ? l.presenceOnSlide(names)
                : l.presenceInGroup(names),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in shown)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: GestureDetector(
                      key: ValueKey<String>(
                        'slides.presence.dot.${slideId ?? groupId}.'
                        '${c.sessionId}',
                      ),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(
                        editor.invokeCommand('slides.presence.jumpTo', {
                          'sessionId': c.sessionId,
                        }),
                      ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: WonkyAvatar(
                          name: c.displayName,
                          color: theme.colorScheme.presence(c.colorIndex),
                          imageUrl: c.participant.avatarUrl,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                if (here.length > maxDots)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '+${here.length - maxDots}',
                      style: theme.textTheme.muted.copyWith(fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<RemoteDeckCursor> _here(SlidesPresenceController p) {
    final s = slideId;
    if (s != null) return p.bySlide[s] ?? const [];
    final g = groupId!;
    final out = <RemoteDeckCursor>[];
    for (final MapEntry(:key, :value) in p.bySlide.entries) {
      if (editor.order.entry(key)?.groupId == g) out.addAll(value);
    }
    return out;
  }
}

/// The speaker notes' soft-lock strip (09 §1.2: "✎ Bo is editing the
/// notes"; 02 §4.4: the question before editing notes someone edits).
class NotesLockBanner extends StatelessWidget {
  const NotesLockBanner({super.key, required this.editor});

  final DeckEditorController editor;

  @override
  Widget build(BuildContext context) {
    final collab = SlidesCollab.of(editor);
    if (collab == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([collab.locks, collab.locks.prompt, editor]),
      builder: (context, _) {
        final slide = editor.currentSlideId;
        if (slide == null) return const SizedBox.shrink();
        final target = TextLockTarget.notes(slide);
        final prompt = collab.locks.prompt.value;
        if (prompt != null && prompt.target == target) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: SoftLockPopover(prompt: prompt, collab: collab),
          );
        }
        final holders = collab.locks.holdersOf(target);
        if (holders.isEmpty) return const SizedBox.shrink();
        final theme = ShadTheme.of(context);
        final l = slidesL10n(context);
        final color = theme.colorScheme.presence(holders.first.colorIndex);
        return Container(
          key: const ValueKey<String>('slides.notes.lockBanner'),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Text(
            l.notesEditingBanner(collab.locks.namesOf(holders)),
            style: theme.textTheme.small.copyWith(fontSize: 12),
          ),
        );
      },
    );
  }
}

/// "Anna is presenting — Follow" (09 §1.6) in the status bar.
class PresenterPill extends StatelessWidget {
  const PresenterPill({super.key, required this.editor});

  final DeckEditorController editor;

  @override
  Widget build(BuildContext context) {
    final collab = SlidesCollab.of(editor);
    if (collab == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: collab.presence,
      builder: (context, _) {
        final presenters = collab.presence.presenters;
        if (presenters.isEmpty) return const SizedBox.shrink();
        final p = presenters.first;
        final theme = ShadTheme.of(context);
        final l = slidesL10n(context);
        final color = theme.colorScheme.presence(p.colorIndex);
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
            key: const ValueKey<String>('slides.status.presenter'),
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l.presenterPill(collab.presence.labelOf(p.participant)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small.copyWith(fontSize: 12),
                  ),
                ),
                ShadButton.link(
                  key: const ValueKey<String>('slides.status.presenter.follow'),
                  size: ShadButtonSize.sm,
                  onPressed: () => editor.services.dispatcher.invoke(
                    'slides.presence.followPresenter',
                    args: {'sessionId': p.sessionId},
                    source: InvocationSource.ui,
                    context: context,
                  ),
                  child: Text(l.presenterFollow),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
