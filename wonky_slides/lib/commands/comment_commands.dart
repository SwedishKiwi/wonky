import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../features/canvas/canvas_interactions.dart';
import '../features/comments/comment_pins_layer.dart';
import '../features/comments/slides_comments.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../l10n/slides_l10n.dart';
import 'slides_command.dart';

/// Slides comment commands (Slides 09 §3.4–§3.5, §7). Creating, replying,
/// resolving and deleting threads are the suite's `shell.comments.*`
/// commands with the Slides anchor provider ([SlidesComments]); these add
/// next/previous, the scoped panel and showing a thread in place.
/// Registers the comment pins layer of the canvas.
List<Command<CommandArgs>> commentCommands(ShellServices s) {
  CanvasInteractions.register(CommentPinsLayer.new);

  CommandResult step(DeckEditorController ed, {required bool forward}) {
    final c = SlidesComments.of(ed);
    final next = c?.neighbor(forward: forward);
    if (c == null || next == null) {
      return CommandResult.failed(slidesL10nOf(s).reasonNoComments);
    }
    c.show(next.uuid);
    return ok({'threadUuid': next.uuid, 'slideId': next.slideId});
  }

  bool hasThreads(DeckEditorController ed) {
    final c = SlidesComments.of(ed);
    return c != null && c.visible && c.readingOrder.isNotEmpty;
  }

  bool visible(DeckEditorController ed) =>
      SlidesComments.of(ed)?.visible ?? false;

  return [
    SlidesCommand(
      'slides.comments.next',
      label: (l) => l.cmdCommentsNext,
      icon: LucideIcons.arrowDownToLine,
      categoryOf: SlidesCategory.view,
      defaultBindings: const [KeyBinding('N', mod: true, alt: true)],
      enabled: (ed, _) => hasThreads(ed),
      reason: (l, _) => l.reasonNoComments,
      run: (ctx, ed, a) => step(ed, forward: true),
    ),
    SlidesCommand(
      'slides.comments.previous',
      label: (l) => l.cmdCommentsPrevious,
      icon: LucideIcons.arrowUpToLine,
      categoryOf: SlidesCategory.view,
      defaultBindings: const [KeyBinding('P', mod: true, alt: true)],
      enabled: (ed, _) => hasThreads(ed),
      reason: (l, _) => l.reasonNoComments,
      run: (ctx, ed, a) => step(ed, forward: false),
    ),
    SlidesCommand(
      'slides.comments.openPanel',
      label: (l) => l.cmdCommentsOpenPanel,
      icon: LucideIcons.messageSquare,
      categoryOf: SlidesCategory.view,
      argsSchema: const JsonSchema.object(
        properties: {
          'scope': JsonSchema.string(
            enumValues: [SlidesComments.scopeSlide, SlidesComments.scopeAll],
            description: 'This slide or all slides (default: unchanged).',
          ),
        },
      ),
      enabled: (ed, _) => visible(ed),
      run: (ctx, ed, a) {
        final c = SlidesComments.of(ed)?.controller;
        final scope = a.string('scope');
        if (scope != null) c?.setScope(scope);
        s.panels.open(ShellPanels.comments);
        return ok({'scope': ?c?.scope});
      },
    ),
    SlidesCommand(
      'slides.comments.show',
      label: (l) => l.cmdCommentsOpenPanel,
      icon: LucideIcons.messageSquare,
      categoryOf: SlidesCategory.view,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'threadUuid': JsonSchema.string(
            format: 'uuid',
            description: 'The thread to show next to its pin.',
          ),
        },
        required: ['threadUuid'],
      ),
      enabled: (ed, _) => visible(ed),
      run: (ctx, ed, a) {
        final id = a.requireString('threadUuid');
        final c = SlidesComments.of(ed);
        if (c == null || !c.show(id)) {
          return const CommandResult.failed('Comment not found');
        }
        return ok({'threadUuid': id});
      },
    ),
  ];
}
