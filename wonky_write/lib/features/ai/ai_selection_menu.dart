import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../screen/write_document_controller.dart';
import '../screen/write_toolbar.dart' show CommandUi;
import '../../l10n/write_l10n.dart';
import 'write_ai_controller.dart';

/// Tone ids of "Change tone ▸" (sent to the model).
const aiTones = ['professional', 'casual', 'friendly', 'confident'];

/// The display name of tone [id].
String aiToneLabel(WriteLocalizations l, String id) => switch (id) {
  'casual' => l.aiToneCasual,
  'friendly' => l.aiToneFriendly,
  'confident' => l.aiToneConfident,
  'professional' => l.aiToneProfessional,
  _ => id,
};

/// Languages of "Translate ▸" (English names, sent to the model).
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

/// The display name of [language] (an English name from [aiLanguages]).
String aiLanguageLabel(WriteLocalizations l, String language) =>
    switch (language) {
      'English' => l.aiLanguageEnglish,
      'Swedish' => l.aiLanguageSwedish,
      'German' => l.aiLanguageGerman,
      'French' => l.aiLanguageFrench,
      'Spanish' => l.aiLanguageSpanish,
      'Italian' => l.aiLanguageItalian,
      'Portuguese' => l.aiLanguagePortuguese,
      'Dutch' => l.aiLanguageDutch,
      'Japanese' => l.aiLanguageJapanese,
      'Chinese' => l.aiLanguageChinese,
      _ => language,
    };

/// The ✨ entries of the selection toolbar (Write 09 §5.3), all bound to
/// `write.ai.rewriteSelection`.
List<WonkyMenuEntry> aiSelectionEntries(CommandUi ui) {
  final l = writeL10n(ui.context);
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
    item('improve', l.aiImproveWriting, LucideIcons.wandSparkles),
    item('fixGrammar', l.aiFixGrammar, LucideIcons.spellCheck),
    item('shorter', l.aiMakeShorter, LucideIcons.minimize2),
    item('longer', l.aiMakeLonger, LucideIcons.maximize2),
    WonkyMenuSubmenu(
      key: const ValueKey<String>('write.ai.menu.tone'),
      label: l.aiChangeTone,
      icon: LucideIcons.messageCircle,
      children: [
        for (final t in aiTones)
          item(
            'tone',
            aiToneLabel(l, t),
            LucideIcons.dot,
            extra: {'tone': t},
            key: 'tone.$t',
          ),
      ],
    ),
    WonkyMenuSubmenu(
      key: const ValueKey<String>('write.ai.menu.translate'),
      label: l.aiTranslate,
      icon: LucideIcons.languages,
      children: [
        for (final lang in aiLanguages)
          item(
            'translate',
            aiLanguageLabel(l, lang),
            LucideIcons.dot,
            extra: {'language': lang},
            key: 'translate.${lang.toLowerCase()}',
          ),
      ],
    ),
    const WonkyMenuSeparator(),
    item('summarize', l.aiSummarize, LucideIcons.listCollapse),
    item('explain', l.aiExplain, LucideIcons.lightbulb),
    WonkyMenuItem(
      key: const ValueKey<String>('write.ai.menu.continue'),
      label: l.cmdAiContinue,
      icon: LucideIcons.penLine,
      enabled: ui.state('write.ai.continue').enabled,
      onSelected: () => ui.run('write.ai.continue'),
    ),
    WonkyMenuItem(
      key: const ValueKey<String>('write.ai.menu.custom'),
      label: l.aiCustom,
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
    final label = writeL10n(context).aiButtonLabel;
    return WonkyDropdownMenu(
      entries: () => aiSelectionEntries(ui),
      builder: (context, c) => ShadTooltip(
        builder: (_) => Text(label),
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
          child: Text(label),
        ),
      ),
    );
  }
}
