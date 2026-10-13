import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../screen/write_document_controller.dart';
import '../screen/write_toolbar.dart' show CommandUi;
import 'write_ai_controller.dart';

/// Tones of "Change tone ▸".
const aiTones = ['Professional', 'Casual', 'Friendly', 'Confident'];

/// Languages of "Translate ▸".
const aiLanguages = [
  'English',
  'Swedish',
  'German',
  'French',
  'Spanish',
  'Italian',
  'Portuguese',
  'Dutch',
  'Japanese',
  'Chinese',
];

/// The ✨ entries of the selection toolbar (Write 09 §5.3), all bound to
/// `write.ai.rewriteSelection`.
List<WonkyMenuEntry> aiSelectionEntries(CommandUi ui) {
  WonkyMenuEntry item(
    String mode,
    String label,
    IconData icon, {
    Map<String, Object?> extra = const {},
    String? key,
  }) {
    final args = {'mode': mode, ...extra};
    final st = ui.state('write.ai.rewriteSelection', args);
    return WonkyMenuItem(
      key: ValueKey<String>('write.ai.menu.${key ?? mode}'),
      label: label,
      icon: icon,
      enabled: st.enabled,
      disabledReason: st.disabledReason,
      onSelected: () => ui.run('write.ai.rewriteSelection', args),
    );
  }

  return [
    item('improve', 'Improve writing', LucideIcons.wandSparkles),
    item('fixGrammar', 'Fix spelling & grammar', LucideIcons.spellCheck),
    item('shorter', 'Make shorter', LucideIcons.minimize2),
    item('longer', 'Make longer', LucideIcons.maximize2),
    WonkyMenuSubmenu(
      key: const ValueKey<String>('write.ai.menu.tone'),
      label: 'Change tone',
      icon: LucideIcons.messageCircle,
      children: [
        for (final t in aiTones)
          item(
            'tone',
            t,
            LucideIcons.dot,
            extra: {'tone': t.toLowerCase()},
            key: 'tone.${t.toLowerCase()}',
          ),
      ],
    ),
    WonkyMenuSubmenu(
      key: const ValueKey<String>('write.ai.menu.translate'),
      label: 'Translate',
      icon: LucideIcons.languages,
      children: [
        for (final l in aiLanguages)
          item(
            'translate',
            l,
            LucideIcons.dot,
            extra: {'language': l},
            key: 'translate.${l.toLowerCase()}',
          ),
      ],
    ),
    const WonkyMenuSeparator(),
    item('summarize', 'Summarize', LucideIcons.listCollapse),
    item('explain', 'Explain', LucideIcons.lightbulb),
    WonkyMenuItem(
      key: const ValueKey<String>('write.ai.menu.continue'),
      label: 'Continue writing',
      icon: LucideIcons.penLine,
      enabled: ui.state('write.ai.continue').enabled,
      onSelected: () => ui.run('write.ai.continue'),
    ),
    WonkyMenuItem(
      key: const ValueKey<String>('write.ai.menu.custom'),
      label: 'Custom…',
      icon: LucideIcons.sparkles,
      enabled: ui.state('write.ai.inline').enabled,
      onSelected: () => ui.run('write.ai.inline'),
    ),
  ];
}

/// The ✨ button of the selection toolbar (hidden when AI is off).
class AiSelectionButton extends StatelessWidget {
  const AiSelectionButton({super.key, required this.doc, required this.ui});

  final WriteDocumentController doc;
  final CommandUi ui;

  @override
  Widget build(BuildContext context) {
    final ai = WriteAiController.forItem(doc.itemUuid);
    if (ai == null || !ai.shown) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    return WonkyDropdownMenu(
      entries: () => aiSelectionEntries(ui),
      builder: (context, c) => ShadTooltip(
        builder: (_) => const Text('AI'),
        child: ShadButton.ghost(
          key: const ValueKey<String>('write.selectionToolbar.ai'),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          leading: Icon(
            LucideIcons.sparkles,
            size: 15,
            color: theme.colorScheme.primary,
          ),
          onPressed: c.toggle,
          child: const Text('AI'),
        ),
      ),
    );
  }
}
