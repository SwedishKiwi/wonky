import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

import '../l10n/wonky_app_localizations.dart';
import '../settings/settings_screen.dart';
import '../shell/dialogs.dart';
import '../shell/shell_services.dart';
import 'shell_assistant.dart';

/// Settings › AI providers (suite 10 §1 "Keys", 04 §4): which provider the
/// AI features use, and — when the server has no key of its own — the
/// user's own OpenAI, Anthropic or Gemini key. The key is sent once, stored
/// on the server and never shown again (only the provider and its last
/// four characters).
class AiProvidersSection extends StatefulWidget {
  const AiProvidersSection({super.key, required this.services});

  final ShellServices services;

  @override
  State<AiProvidersSection> createState() => _AiProvidersSectionState();
}

class _AiProvidersSectionState extends State<AiProvidersSection> {
  final _key = TextEditingController();
  AiProvider _provider = AiProvider.openai;
  bool _busy = false;

  ShellAssistant? get _assistant => ShellAssistant.of(widget.services);

  @override
  void initState() {
    super.initState();
    final a = _assistant;
    final current = a?.status.value?.userKey?.provider;
    if (current != null) _provider = current;
    if (a != null) unawaited(a.refreshStatus());
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = _assistant;
    final key = _key.text.trim();
    if (a == null || key.isEmpty || _busy) return;
    final l = WonkyAppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await a.setProviderKey(_provider, key);
      _key.clear();
      widget.services.toasts.show(l.aiProvidersSaved);
    } on WonkyException catch (e) {
      widget.services.toasts.error(e.message);
    } on Object {
      widget.services.toasts.error(l.aiProvidersSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final a = _assistant;
    if (a == null) return;
    final l = WonkyAppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.aiProvidersRemoveTitle,
      description: l.aiProvidersRemoveBody,
      confirmLabel: l.aiProvidersRemove,
      destructive: true,
    );
    if (!ok) return;
    try {
      await a.removeProviderKey();
      widget.services.toasts.show(l.aiProvidersRemoved);
    } on Object {
      widget.services.toasts.error(l.aiProvidersRemoveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _assistant;
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([?a?.status]),
      builder: (context, _) {
        final status = a?.status.value;
        if (status == null) {
          return SettingsGroup(
            title: l.settingsAiProviders,
            children: [Text(l.aiNotConfigured, style: theme.textTheme.muted)],
          );
        }
        if (status.reason == 'disabled') {
          return SettingsGroup(
            title: l.settingsAiProviders,
            children: [
              Text(
                l.aiDisabled,
                key: const ValueKey<String>('settings.aiProviders.disabled'),
                style: theme.textTheme.muted,
              ),
            ],
          );
        }
        if (status.keySource == 'server' && status.provider != null) {
          return SettingsGroup(
            title: l.aiProvidersServerTitle,
            children: [
              Text(
                l.aiProvidersServerBody(aiProviderName(l, status.provider!)),
                key: const ValueKey<String>('settings.aiProviders.server'),
              ),
            ],
          );
        }
        if (!status.userKeysAllowed) {
          return SettingsGroup(
            title: l.settingsAiProviders,
            children: [
              Text(
                l.aiProvidersNotAllowed,
                key: const ValueKey<String>('settings.aiProviders.notAllowed'),
                style: theme.textTheme.muted,
              ),
            ],
          );
        }
        final current = status.userKey;
        return SettingsGroup(
          title: l.aiProvidersKeyTitle,
          description: l.aiProvidersKeyHint,
          children: [
            if (current != null)
              SettingsRow(
                label: l.aiProvidersCurrent,
                description: l.aiProvidersCurrentValue(
                  aiProviderName(l, current.provider),
                  current.last4,
                ),
                control: ShadButton.outline(
                  key: const ValueKey<String>('settings.aiProviders.remove'),
                  onPressed: () => unawaited(_remove()),
                  child: Text(l.aiProvidersRemove),
                ),
              ),
            SettingsRow(
              label: l.aiProvidersProvider,
              control: ShadSelect<AiProvider>(
                key: const ValueKey<String>('settings.aiProviders.provider'),
                initialValue: _provider,
                minWidth: 180,
                options: [
                  for (final p in AiProvider.values)
                    ShadOption(value: p, child: Text(aiProviderName(l, p))),
                ],
                selectedOptionBuilder: (context, p) =>
                    Text(aiProviderName(l, p)),
                onChanged: (p) {
                  if (p != null) setState(() => _provider = p);
                },
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(l.aiProvidersKey, style: theme.textTheme.small),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: ShadInput(
                        key: const ValueKey<String>('settings.aiProviders.key'),
                        controller: _key,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        placeholder: Text(l.aiProvidersKeyPlaceholder),
                        onSubmitted: (_) => unawaited(_save()),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: _key,
                      builder: (context, _) => ShadButton(
                        key: const ValueKey<String>(
                          'settings.aiProviders.save',
                        ),
                        enabled: !_busy && _key.text.trim().isNotEmpty,
                        onPressed: () => unawaited(_save()),
                        child: Text(l.aiProvidersSave),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
