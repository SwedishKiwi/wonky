import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart' show SlidesText;

import '../../commands/slides_command.dart' show SlidesKeyScopes;
import '../../l10n/slides_l10n.dart';
import 'deck_editor_controller.dart';

/// The speaker notes pane below the canvas (04 §8), shell: a handle bar
/// ("Speaker notes ⌃", `slides.view.toggleNotes`) and the current slide's
/// notes as text in the `slidesNotes` key scope. The notes editor (rich
/// notes subset, mini toolbar, soft lock, zoom) is SL-16's; until then the
/// pane shows the notes read-only.
class NotesPane extends StatelessWidget {
  const NotesPane({
    super.key,
    required this.services,
    required this.editor,
    required this.expanded,
  });

  final ShellServices services;
  final DeckEditorController editor;

  /// Whether the body shows (collapsed = only the handle bar).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final slide = editor.currentEntry?.slide;
    final notes = SlidesText.plainText(slide?.notes).trim();
    final handle = Semantics(
      button: true,
      expanded: expanded,
      label: l.notesLabel,
      child: GestureDetector(
        key: const ValueKey<String>('slides.notes.handle'),
        behavior: HitTestBehavior.opaque,
        onTap: () => services.dispatcher.invoke(
          'slides.view.toggleNotes',
          source: InvocationSource.ui,
          context: context,
        ),
        child: SizedBox(
          height: 26,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Text(
                l.notesLabel,
                style: theme.textTheme.small.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
    return DecoratedBox(
      key: const ValueKey<String>('slides.notes'),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border(top: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          handle,
          if (expanded)
            Expanded(
              child: KeymapScope(
                scope: SlidesKeyScopes.notes,
                keymap: services.keymap,
                focusNode: editor.notesFocus,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: editor.notesFocus.requestFocus,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(
                      notes.isEmpty ? l.notesPlaceholder : notes,
                      key: const ValueKey<String>('slides.notes.text'),
                      style:
                          (notes.isEmpty
                                  ? theme.textTheme.muted
                                  : theme.textTheme.p)
                              .copyWith(fontSize: 14, height: 1.45),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
