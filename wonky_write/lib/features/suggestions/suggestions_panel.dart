import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../document/write_document_session.dart';
import '../editor/controller/editor_types.dart';
import 'suggestion_card.dart';

/// Id of the suggestions side panel.
const writeSuggestionsPanelId = 'suggestions';

/// The side panel spec of [WriteSuggestionsPanel] (add it to the editor
/// scaffold's `panels`).
SidePanelSpec suggestionsPanelSpec(WriteDocumentSession session) =>
    SidePanelSpec(
      id: writeSuggestionsPanelId,
      title: 'Suggestions',
      icon: LucideIcons.fileDiff,
      defaultWidth: 340,
      minWidth: 300,
      builder: (_) => WriteSuggestionsPanel(session: session),
    );

/// Pending suggestions with *Accept all* / *Reject all* (Write 05 §10.2,
/// Write 08 §2.7): one card per suggestion in document order; the empty
/// state offers switching to Suggesting mode.
class WriteSuggestionsPanel extends StatelessWidget {
  const WriteSuggestionsPanel({super.key, required this.session});

  final WriteDocumentSession session;

  Future<void> _all(BuildContext context, {required bool accept}) async {
    final c = session.suggestions;
    final n = c.count();
    if (n == 0) return;
    if (n > 10) {
      final ok = await confirmDialog(
        context,
        title: accept ? 'Accept all suggestions?' : 'Reject all suggestions?',
        description: accept
            ? 'All $n suggestions will be applied to the document.'
            : 'All $n suggestions will be discarded.',
        confirmLabel: accept ? 'Accept all' : 'Reject all',
        destructive: !accept,
      );
      if (!ok) return;
    }
    if (!context.mounted) return;
    await invokeCollabCommand(
      session,
      accept ? 'write.suggestions.acceptAll' : 'write.suggestions.rejectAll',
      const {},
      () => accept ? c.acceptAll() : c.rejectAll(),
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([session.suggestions, session]),
      builder: (context, _) {
        final c = session.suggestions;
        final list = c.pending;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      list.isEmpty
                          ? 'No suggestions'
                          : '${list.length} '
                                '${list.length == 1 ? 'suggestion' : 'suggestions'}',
                      style: theme.textTheme.muted,
                    ),
                  ),
                  if (c.canDecide && list.isNotEmpty) ...[
                    ShadButton.outline(
                      key: const ValueKey<String>(
                        'write.suggestions.acceptAll',
                      ),
                      size: ShadButtonSize.sm,
                      onPressed: () => _all(context, accept: true),
                      child: const Text('Accept all'),
                    ),
                    const SizedBox(width: 6),
                    ShadButton.ghost(
                      key: const ValueKey<String>(
                        'write.suggestions.rejectAll',
                      ),
                      size: ShadButtonSize.sm,
                      onPressed: () => _all(context, accept: false),
                      child: const Text('Reject all'),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? WonkyEmptyState(
                      illustration: EmptyIllustration.comments,
                      title: 'No suggestions',
                      description:
                          'Switch to Suggesting mode to propose changes.',
                      actions: [
                        if (session.canUseMode(EditorMode.suggesting) &&
                            !c.suggesting)
                          ShadButton.outline(
                            key: const ValueKey<String>(
                              'write.suggestions.switchMode',
                            ),
                            onPressed: () =>
                                session.setMode(EditorMode.suggesting),
                            child: const Text('Switch to Suggesting'),
                          ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => SuggestionCard(
                        session: session,
                        suggestion: list[i],
                        active: list[i].id == c.activeId,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
