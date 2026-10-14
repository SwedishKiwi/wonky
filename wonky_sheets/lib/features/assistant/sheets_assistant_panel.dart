import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../ai/sheets_ai_controller.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// The assistant side panel of a spreadsheet (suite 10 §3, Sheets 12 §6):
/// the shared `AssistantPanel` with the Sheets adapter. Offered unless AI
/// is switched off on the server; shows "AI isn't configured" (with *Add
/// an API key*) when the server has no key.
SidePanelSpec? sheetsAssistantPanelSpec(
  ShellServices services,
  SheetEditorController? editor,
) {
  final assistant = ShellAssistant.of(services);
  if (editor == null || assistant == null || !assistant.available) {
    return null;
  }
  return SidePanelSpec(
    id: ShellPanels.assistant,
    title: sheetsL10nOf(services).aiPanelTitle,
    icon: LucideIcons.sparkles,
    builder: (context) =>
        SheetsAssistantPanel(ai: SheetsAiController.of(editor)),
  );
}

/// The panel body.
class SheetsAssistantPanel extends StatelessWidget {
  const SheetsAssistantPanel({super.key, required this.ai});

  final SheetsAiController ai;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([ai.services.prefs, ?ai.assistant?.status]),
    builder: (context, _) {
      final chat = ai.chat;
      final l = sheetsL10n(context);
      if (chat == null || !ai.services.prefs.aiEnabled) {
        return WonkyEmptyState(
          key: const ValueKey<String>('sheets.assistant.off'),
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
