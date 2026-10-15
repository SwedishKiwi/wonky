import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/slides_l10n.dart';
import '../ai/slides_ai_controller.dart';
import '../editor_screen/deck_editor_controller.dart';

/// The assistant side panel of a presentation (suite 10 §3.1, Slides 11
/// §6.3): the shared `AssistantPanel` with the Slides adapter. Offered
/// unless AI is switched off on the server; shows "AI isn't configured"
/// (with *Add an API key*) when the server has no key.
SidePanelSpec? slidesAssistantPanelSpec(
  BuildContext context,
  ShellServices services,
  DeckEditorController editor,
) {
  final assistant = ShellAssistant.of(services);
  if (assistant == null || !assistant.available) return null;
  return SidePanelSpec(
    id: ShellPanels.assistant,
    title: slidesL10n(context).aiPanelTitle,
    icon: LucideIcons.sparkles,
    builder: (context) =>
        SlidesAssistantPanel(ai: SlidesAiController.of(editor)),
  );
}

/// The panel body.
class SlidesAssistantPanel extends StatelessWidget {
  const SlidesAssistantPanel({super.key, required this.ai});

  final SlidesAiController ai;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([ai.services.prefs, ?ai.assistant?.status]),
    builder: (context, _) {
      final chat = ai.chat;
      final l = slidesL10n(context);
      if (chat == null || !ai.services.prefs.aiEnabled) {
        return WonkyEmptyState(
          key: const ValueKey<String>('slides.assistant.off'),
          illustration: EmptyIllustration.error,
          title: ai.services.prefs.aiEnabled ? l.aiUnavailable : l.aiTurnedOff,
          description: ai.services.prefs.aiEnabled ? null : l.aiTurnOnHint,
          size: 72,
        );
      }
      return AssistantPanel(services: ai.services, controller: chat);
    },
  );
}
