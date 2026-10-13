import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

import '../settings/settings_screen.dart';
import '../shell/dialogs.dart';
import '../shell/shell_services.dart';
import 'assistant_panel.dart';
import 'shell_assistant.dart';

/// Settings › AI (suite 10 §1 privacy, Write 09 §5.1): the opt-out, the
/// quality tier, today's usage, clearing the chat history and the notice
/// that content is sent to Anthropic.
class AiSettingsSection extends StatefulWidget {
  const AiSettingsSection({super.key, required this.services});

  final ShellServices services;

  @override
  State<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends State<AiSettingsSection> {
  ShellAssistant? get _assistant => ShellAssistant.of(widget.services);

  @override
  void initState() {
    super.initState();
    final a = _assistant;
    if (a != null) unawaited(a.refreshStatus());
  }

  static String _qualityLabel(AiQuality q) => switch (q) {
    AiQuality.best => 'Best',
    AiQuality.balanced => 'Balanced',
    AiQuality.fast => 'Fast',
  };

  static String _qualityHint(AiQuality q) => switch (q) {
    AiQuality.best => 'Most capable answers and edits',
    AiQuality.balanced => 'Good answers, a little faster',
    AiQuality.fast => 'Quickest answers for simple tasks',
  };

  Future<void> _clear(BuildContext context) async {
    final a = _assistant;
    if (a == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Clear assistant history?',
      description:
          'All your assistant chats in every document are deleted. This '
          "can't be undone. Edits the assistant made stay in the documents.",
      confirmLabel: 'Clear history',
      destructive: true,
    );
    if (!ok) return;
    try {
      final n = await a.api.clearHistory();
      widget.services.toasts.show(
        n == 1 ? 'Deleted 1 chat' : 'Deleted $n chats',
      );
    } on Object {
      widget.services.toasts.error("Couldn't clear the history");
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.services.prefs;
    final a = _assistant;
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([p, ?a?.status]),
      builder: (context, _) {
        final status = a?.status.value;
        final serverReady =
            status != null && (status.available || status.reason == 'optedOut');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              title: 'Assistant',
              description:
                  'The assistant helps you write, edit and understand '
                  'documents. It only sees the document you use it in.',
              children: [
                if (status != null && !serverReady)
                  Text(
                    status.message ?? "AI isn't configured on this server.",
                    key: const ValueKey<String>('settings.ai.serverStatus'),
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.destructive,
                    ),
                  ),
                SettingsRow(
                  label: 'Enable the assistant',
                  description:
                      'Turn off to hide AI features and stop sending '
                      'content to the AI service.',
                  control: ShadSwitch(
                    key: const ValueKey<String>('settings.ai.enabled'),
                    value: p.aiEnabled,
                    onChanged: (v) async {
                      await p.setAiEnabled(v);
                      if (a != null) await a.refreshStatus();
                    },
                  ),
                ),
                SettingsRow(
                  label: 'AI quality',
                  description: status == null
                      ? null
                      : _qualityHint(status.quality),
                  control: ShadSelect<AiQuality>(
                    key: const ValueKey<String>('settings.ai.quality'),
                    initialValue: status?.quality ?? AiQuality.best,
                    enabled: a != null && p.aiEnabled,
                    minWidth: 160,
                    options: [
                      for (final q in AiQuality.values)
                        ShadOption(value: q, child: Text(_qualityLabel(q))),
                    ],
                    selectedOptionBuilder: (context, q) =>
                        Text(_qualityLabel(q)),
                    onChanged: (q) async {
                      if (q == null || a == null) return;
                      try {
                        await a.setQuality(q);
                      } on Object {
                        widget.services.toasts.error(
                          "Couldn't save the AI quality",
                        );
                      }
                    },
                  ),
                ),
                if (status != null && status.dailyTokenBudget > 0)
                  SettingsRow(
                    label: 'Usage today',
                    description: 'Resets daily at midnight UTC.',
                    control: Text(
                      '${(status.tokensUsedToday * 100 / status.dailyTokenBudget).clamp(0, 100).round()} %',
                      key: const ValueKey<String>('settings.ai.usage'),
                      style: theme.textTheme.small,
                    ),
                  ),
                SettingsRow(
                  label: 'Chat history',
                  description: 'Delete all your assistant chats.',
                  control: ShadButton.outline(
                    key: const ValueKey<String>('settings.ai.clearHistory'),
                    enabled: a != null,
                    onPressed: () => unawaited(_clear(context)),
                    child: const Text('Clear history'),
                  ),
                ),
                Text(
                  AssistantPanel.privacyNotice,
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
