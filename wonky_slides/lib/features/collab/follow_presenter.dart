import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart' show ShellServices;
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/slides_command.dart' show editorOfServices;
import '../../l10n/slides_l10n.dart';
import '../present/present_controller.dart';
import 'slides_collab.dart';
import 'slides_presence_controller.dart';

/// The presenter a follower view follows (09 §1.6): the collaborator whose
/// presence cursor presents session [sessionId], or null (they left the
/// editor's presence, or the deck isn't open in the editor underneath).
RemoteDeckCursor? presenterOfSession(ShellServices s, String? sessionId) {
  final ed = editorOfServices(s);
  final collab = ed == null ? null : SlidesCollab.of(ed);
  if (collab == null || sessionId == null) return null;
  for (final c in collab.presence.presenters) {
    if (c.cursor.presenting?.presentationId == sessionId) return c;
  }
  return null;
}

/// The bar of a follower view (`?view=follow`, 09 §1.6, 10 §6.3; SL-37):
/// "Following Anna — press Esc to stop" with *Full screen* and *Stop
/// following*; after browsing away "You left Anna's slide" with *Return to
/// presenter* (`slides.presence.returnToPresenter`, Shift+R). Narrow
/// widths wrap the buttons under the text.
class FollowerBar extends StatelessWidget {
  const FollowerBar({
    super.key,
    required this.services,
    required this.controller,
    required this.sessionId,
    required this.onFullscreen,
    required this.fullscreen,
  });

  final ShellServices services;
  final PresentController controller;
  final String? sessionId;
  final VoidCallback onFullscreen;
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final ed = editorOfServices(services);
    final collab = ed == null ? null : SlidesCollab.of(ed);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, ?collab?.presence]),
      builder: (context, _) {
        final p = presenterOfSession(services, sessionId);
        final name = p == null ? null : collab!.presence.labelOf(p.participant);
        final color = p == null
            ? theme.colorScheme.primary
            : theme.colorScheme.presence(p.colorIndex);
        final browsing = controller.browsing;
        final text = browsing
            ? (name == null
                  ? l.followerBrowsingUnknown
                  : l.followerBrowsing(name))
            : (name == null
                  ? l.followerFollowingUnknown
                  : l.followerFollowing(name));
        void run(String id) => services.dispatcher.invoke(
          id,
          source: InvocationSource.ui,
          context: context,
        );
        return Semantics(
          container: true,
          liveRegion: true,
          child: Container(
            key: const ValueKey<String>('slides.present.followerBar'),
            constraints: const BoxConstraints(maxWidth: 560),
            decoration: BoxDecoration(
              color: theme.colorScheme.popover.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: color, width: 3)),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      text,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.popoverForeground,
                      ),
                    ),
                  ),
                  if (browsing)
                    ShadButton(
                      key: const ValueKey<String>(
                        'slides.present.followerBar.return',
                      ),
                      size: ShadButtonSize.sm,
                      onPressed: () => run('slides.presence.returnToPresenter'),
                      child: Text(l.followerReturn),
                    ),
                  if (!fullscreen)
                    ShadButton.ghost(
                      key: const ValueKey<String>(
                        'slides.present.followerBar.fullscreen',
                      ),
                      size: ShadButtonSize.sm,
                      onPressed: onFullscreen,
                      child: Text(l.followerFullscreen),
                    ),
                  ShadButton.outline(
                    key: const ValueKey<String>(
                      'slides.present.followerBar.stop',
                    ),
                    size: ShadButtonSize.sm,
                    onPressed: () => run('slides.present.end'),
                    child: Text(l.followerStop),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
