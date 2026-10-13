import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

import '../../data/api.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/overlays/shell_overlays.dart';
import '../../assistant/ai_settings_section.dart';
import '../../mcp_bridge/developer_settings.dart';
import '../../shell/shell_services.dart';
import '../settings_screen.dart';
import 'package:flutter/foundation.dart';

export 'offline_section.dart';

Widget _switch(String key, bool value, ValueChanged<bool> onChanged) =>
    ShadSwitch(key: ValueKey<String>(key), value: value, onChanged: onChanged);

/// Settings › Language & region.
class LanguageSection extends StatefulWidget {
  const LanguageSection({super.key, required this.services});

  final ShellServices services;

  @override
  State<LanguageSection> createState() => _LanguageSectionState();
}

class _LanguageSectionState extends State<LanguageSection> {
  late final _tz = TextEditingController(
    text: widget.services.currentUser.value?.timeZone ?? '',
  );

  @override
  void dispose() {
    _tz.dispose();
    super.dispose();
  }

  Future<void> _save({String? locale, String? tz}) async {
    final s = widget.services;
    final l = WonkyAppLocalizations.of(context);
    try {
      s.currentUser.value = await s.repositories.users.updateProfile(
        locale: locale,
        timeZone: tz,
      );
      s.toasts.show(l.settingsSaved);
    } catch (e) {
      s.toasts.error(l.errorGeneric, description: errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final me = widget.services.currentUser.value;
    return SettingsGroup(
      title: l.settingsLanguage,
      description: l.settingsLanguageHint,
      children: [
        SettingsRow(
          label: l.settingsUiLanguage,
          control: ShadSelect<String>(
            initialValue: me?.locale ?? 'en',
            options: const [ShadOption(value: 'en', child: Text('English'))],
            selectedOptionBuilder: (context, v) => const Text('English'),
            onChanged: (v) => _save(locale: v),
          ),
        ),
        SettingsRow(
          label: l.settingsTimeZone,
          description: l.settingsTimeZoneHint,
          control: SizedBox(
            width: 220,
            child: ShadInput(
              controller: _tz,
              placeholder: Text(DateTime.now().timeZoneName),
              onSubmitted: (v) => _save(tz: v.trim().isEmpty ? null : v.trim()),
            ),
          ),
        ),
      ],
    );
  }
}

/// Settings › Write (defaults stored in `writeDefaults`).
class WriteDefaultsSection extends StatelessWidget {
  const WriteDefaultsSection({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final p = services.prefs;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        bool v(String k, bool d) => p.writeDefaults[k] as bool? ?? d;
        return SettingsGroup(
          title: l.settingsWrite,
          children: [
            for (final (k, label, d) in [
              ('spellcheck', l.writeSpellcheck, true),
              ('smartQuotes', l.writeSmartQuotes, true),
              ('autoPairBrackets', l.writeAutoPair, true),
              ('markdownShortcuts', l.writeMarkdownShortcuts, true),
              ('pageless', l.writePageless, false),
            ])
              SettingsRow(
                label: label,
                control: _switch(
                  'settings.write.$k',
                  v(k, d),
                  (x) => p.setWriteDefault(k, x),
                ),
              ),
            SettingsRow(
              label: l.writeExportFormat,
              control: ShadSelect<String>(
                initialValue:
                    p.writeDefaults['exportFormat'] as String? ?? 'md',
                options: const [
                  ShadOption(value: 'md', child: Text('Markdown (.md)')),
                  ShadOption(value: 'html', child: Text('HTML (.html)')),
                  ShadOption(value: 'pdf', child: Text('PDF (.pdf)')),
                  ShadOption(value: 'txt', child: Text('Plain text (.txt)')),
                ],
                selectedOptionBuilder: (context, v) => Text(v),
                onChanged: (x) => p.setWriteDefault('exportFormat', x),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Settings › Sheets (defaults stored in `sheetsDefaults`).
class SheetsDefaultsSection extends StatelessWidget {
  const SheetsDefaultsSection({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final p = services.prefs;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        bool v(String k, bool d) => p.sheetsDefaults[k] as bool? ?? d;
        return SettingsGroup(
          title: l.settingsSheets,
          children: [
            for (final (k, label, d) in [
              ('formulaAutocomplete', l.sheetsAutocomplete, true),
              ('formulaHelp', l.sheetsFormulaHelp, true),
              ('scriptsEnabled', l.sheetsScripts, true),
            ])
              SettingsRow(
                label: label,
                control: _switch(
                  'settings.sheets.$k',
                  v(k, d),
                  (x) => p.setSheetsDefault(k, x),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Settings › Notifications.
class NotificationsSection extends StatelessWidget {
  const NotificationsSection({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final p = services.prefs;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        String v(String k) => p.notificationSettings[k] as String? ?? 'inApp';
        Widget choice(String k) => ShadSelect<String>(
          key: ValueKey<String>('settings.notifications.$k'),
          initialValue: v(k),
          options: [
            ShadOption(value: 'inApp', child: Text(l.notifyInApp)),
            ShadOption(value: 'email', child: Text(l.notifyEmail)),
            ShadOption(value: 'off', child: Text(l.notifyOff)),
          ],
          selectedOptionBuilder: (context, x) => Text(switch (x) {
            'email' => l.notifyEmail,
            'off' => l.notifyOff,
            _ => l.notifyInApp,
          }),
          onChanged: (x) => p.setNotificationSetting(k, x),
        );
        return SettingsGroup(
          title: l.settingsNotifications,
          children: [
            SettingsRow(label: l.notifyMentions, control: choice('mentions')),
            SettingsRow(label: l.notifyReplies, control: choice('replies')),
            SettingsRow(label: l.notifyShares, control: choice('shares')),
          ],
        );
      },
    );
  }
}

/// Settings › AI.
class AiSection extends StatelessWidget {
  const AiSection({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) => AiSettingsSection(services: services);
}

/// Settings › Developer / MCP: tokens, connection snippet, UI-bridge toggle
/// (implemented by the MCP bridge, `mcp_bridge/developer_settings.dart`).
class DeveloperSection extends StatelessWidget {
  const DeveloperSection({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) =>
      McpDeveloperSettings(services: services);
}

/// Settings › About: versions and licenses.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return ValueListenableBuilder<ProtocolInfo?>(
      valueListenable: services.serverInfo,
      builder: (context, info, _) => SettingsGroup(
        title: '${services.config.appName} · ${l.wonkyWork}',
        children: [
          SettingsRow(
            label: l.aboutAppVersion,
            control: const Text(clientVersion),
          ),
          SettingsRow(
            label: l.aboutServerVersion,
            control: Text(info?.serverVersion ?? '—'),
          ),
          SettingsRow(
            label: l.aboutProtocol,
            control: Text(
              info == null
                  ? '—'
                  : '${info.minClientVersion} · ${info.syncTablesHash.substring(0, info.syncTablesHash.length.clamp(0, 8))}',
            ),
          ),
          SettingsRow(
            label: l.aboutRunMode,
            control: Text(info?.runMode ?? '—'),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ShadButton.outline(
              onPressed: () => showShadDialog<void>(
                context: context,
                builder: (context) => ShadDialog(
                  title: Text(l.aboutLicenses),
                  child: SizedBox(
                    width: 520,
                    height: 400,
                    child: FutureBuilder<List<LicenseEntry>>(
                      future: LicenseRegistry.licenses.toList(),
                      builder: (context, snap) => ListView(
                        children: [
                          for (final e in snap.data ?? const <LicenseEntry>[])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                e.packages.join(', '),
                                style: ShadTheme.of(context).textTheme.small,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child: Text(l.aboutLicenses),
            ),
          ),
        ],
      ),
    );
  }
}
