import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/write_l10n.dart';
import 'write_ai_controller.dart';

/// The assistant side panel of a Write document (suite 10 §3): the shared
/// `AssistantPanel` with the Write adapter; 360–640 px, tabbed with the
/// other right panels.
SidePanelSpec writeAssistantPanelSpec(WriteAiController ai) => SidePanelSpec(
  id: ShellPanels.assistant,
  title: writeL10nOf(ai.services).aiPanelTitle,
  icon: LucideIcons.sparkles,
  defaultWidth: 400,
  minWidth: 360,
  maxWidth: 640,
  builder: (context) => ListenableBuilder(
    listenable: Listenable.merge([ai.services.prefs, ?ai.assistant?.status]),
    builder: (context, _) {
      final chat = ai.chat;
      if (chat == null || !ai.services.prefs.aiEnabled) {
        final l = writeL10n(context);
        return WonkyEmptyState(
          illustration: EmptyIllustration.error,
          title: ai.services.prefs.aiEnabled
              ? l.aiNotConfigured
              : l.aiTurnedOff,
          description: ai.services.prefs.aiEnabled ? null : l.aiTurnOnHint,
          size: 72,
        );
      }
      return AssistantPanel(services: ai.services, controller: chat);
    },
  ),
);
