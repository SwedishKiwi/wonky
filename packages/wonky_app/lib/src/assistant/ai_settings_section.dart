import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

import '../l10n/wonky_app_localizations.dart';
import '../settings/settings_screen.dart';
import '../shell/dialogs.dart';
import '../shell/shell_services.dart';
import 'shell_assistant.dart';

/// Settings › AI (suite 10 §1 privacy, Write 09 §5.1): the opt-out, the
/// quality tier, today's usage, clearing the chat history and the notice
/// naming the provider content is sent to. Keys are on Settings › AI
/// providers (`AiProvidersSection`).
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

  static String _qualityLabel(WonkyAppLocalizations l, AiQuality q) =>
      switch (q) {
        AiQuality.best => l.aiQualityBest,
        AiQuality.balanced => l.aiQualityBalanced,
        AiQuality.fast => l.aiQualityFast,
      };

  static String _qualityHint(WonkyAppLocalizations l, AiQuality q) =>
      switch (q) {
        AiQuality.best => l.aiQualityBestHint,
        AiQuality.balanced => l.aiQualityBalancedHint,
        AiQuality.fast => l.aiQualityFastHint,
      };

  Future<void> _clear(BuildContext context) async {
    final a = _assistant;
    if (a == null) return;
    final l = WonkyAppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.aiClearHistoryTitle,
      description: l.aiClearHistoryBody,
      confirmLabel: l.aiClearHistory,
      destructive: true,
    );
    if (!ok) return;
    try {
      final n = await a.api.clearHistory();
      widget.services.toasts.show(l.aiHistoryCleared(n));
    } on Object {
      widget.services.toasts.error(l.aiClearHistoryFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.services.prefs;
    final a = _assistant;
    final theme = ShadTheme.of(context);
    final l = WonkyAppLocalizations.of(context);
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
              title: l.aiAssistantTitle,
              description: l.aiAssistantHint,
              children: [
                if (status != null && !serverReady)
                  Text(
                    assistantStatusMessage(l, status),
                    key: const ValueKey<String>('settings.ai.serverStatus'),
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.destructive,
                    ),
                  ),
                if (status != null &&
                    status.reason == 'notConfigured' &&
                    status.userKeysAllowed)
                  SettingsRow(
                    label: l.aiAddApiKey,
                    description: l.aiNotConfiguredHint,
                    control: ShadButton.outline(
                      key: const ValueKey<String>('settings.ai.addApiKey'),
                      onPressed: () =>
                          openAiProviderSettings(widget.services, context),
                      child: Text(l.aiProvidersManage),
                    ),
                  ),
                SettingsRow(
                  label: l.aiEnable,
                  description: l.aiEnableHint,
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
                  label: l.aiQuality,
                  description: status == null
                      ? null
                      : _qualityHint(l, status.quality),
                  control: ShadSelect<AiQuality>(
                    key: const ValueKey<String>('settings.ai.quality'),
                    initialValue: status?.quality ?? AiQuality.best,
                    enabled: a != null && p.aiEnabled,
                    minWidth: 160,
                    options: [
                      for (final q in AiQuality.values)
                        ShadOption(value: q, child: Text(_qualityLabel(l, q))),
                    ],
                    selectedOptionBuilder: (context, q) =>
                        Text(_qualityLabel(l, q)),
                    onChanged: (q) async {
                      if (q == null || a == null) return;
                      try {
                        await a.setQuality(q);
                      } on Object {
                        widget.services.toasts.error(l.aiQualitySaveFailed);
                      }
                    },
                  ),
                ),
                if (status != null && status.dailyTokenBudget > 0)
                  SettingsRow(
                    label: l.aiUsageToday,
                    description: l.aiUsageTodayHint,
                    control: Text(
                      l.aiUsagePercent(
                        (status.tokensUsedToday * 100 / status.dailyTokenBudget)
                            .clamp(0, 100)
                            .round(),
                      ),
                      key: const ValueKey<String>('settings.ai.usage'),
                      style: theme.textTheme.small,
                    ),
                  ),
                SettingsRow(
                  label: l.aiChatHistory,
                  description: l.aiChatHistoryHint,
                  control: ShadButton.outline(
                    key: const ValueKey<String>('settings.ai.clearHistory'),
                    enabled: a != null,
                    onPressed: () => unawaited(_clear(context)),
                    child: Text(l.aiClearHistory),
                  ),
                ),
                Text(
                  assistantPrivacyNotice(l, status),
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
