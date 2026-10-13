import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../branding/product_icon.dart';
import '../config/wonky_app_config.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/page_frame.dart';
import '../shell/shell_services.dart';
import 'sections/account_section.dart';
import 'sections/appearance_section.dart';
import 'sections/keyboard_section.dart';
import 'sections/other_sections.dart';

/// A settings section.
class _Section {
  const _Section(this.id, this.title, this.icon, this.builder, {this.product});
  final String id;
  final String title;
  final IconData icon;
  final WidgetBuilder builder;

  /// Shown instead of [icon] for the sections of a product.
  final WonkyProduct? product;
}

/// `/settings/:section` (suite 04 §4): left nav + section page. Every change
/// is a command or a preference write; settings are not undoable.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.services,
    required this.section,
  });

  final ShellServices services;
  final String section;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final s = services;
    final sections = <_Section>[
      _Section(
        'account',
        l.settingsAccount,
        LucideIcons.user,
        (_) => AccountSection(services: s),
      ),
      _Section(
        'appearance',
        l.settingsAppearance,
        LucideIcons.palette,
        (_) => AppearanceSection(services: s),
      ),
      _Section(
        'language',
        l.settingsLanguage,
        LucideIcons.languages,
        (_) => LanguageSection(services: s),
      ),
      _Section(
        'keyboard',
        l.settingsKeyboard,
        LucideIcons.keyboard,
        (_) => KeyboardSection(services: s),
      ),
      _Section(
        'write',
        l.settingsWrite,
        LucideIcons.fileText,
        (_) => WriteDefaultsSection(services: s),
        product: WonkyProduct.write,
      ),
      _Section(
        'sheets',
        l.settingsSheets,
        LucideIcons.sheet,
        (_) => SheetsDefaultsSection(services: s),
        product: WonkyProduct.sheets,
      ),
      _Section(
        'notifications',
        l.settingsNotifications,
        LucideIcons.bell,
        (_) => NotificationsSection(services: s),
      ),
      _Section(
        'ai',
        l.settingsAi,
        LucideIcons.sparkles,
        (_) => AiSection(services: s),
      ),
      _Section(
        'developer',
        l.settingsDeveloper,
        LucideIcons.squareTerminal,
        (_) => DeveloperSection(services: s),
      ),
      _Section(
        'offline',
        l.settingsOffline,
        LucideIcons.hardDrive,
        (_) => OfflineSection(services: s),
      ),
      for (final SettingsSectionSpec x in s.config.settingsSections(s))
        _Section(x.id, x.title(context), x.icon, x.builder),
      _Section(
        'about',
        l.settingsAbout,
        LucideIcons.info,
        (_) => AboutSection(services: s),
      ),
    ];
    final current = sections.firstWhere(
      (x) => x.id == section,
      orElse: () => sections.first,
    );
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final nav = Container(
      width: narrow ? double.infinity : 240,
      padding: const EdgeInsets.all(12),
      child: ListView(
        shrinkWrap: narrow,
        children: [
          for (final x in sections)
            ShadButton.ghost(
              key: ValueKey<String>('settings.nav.${x.id}'),
              mainAxisAlignment: MainAxisAlignment.start,
              backgroundColor: x.id == current.id
                  ? theme.colorScheme.sidebarAccent
                  : null,
              leading: x.product == null
                  ? Icon(x.icon, size: 16)
                  : WonkyProductIcon(x.product!, size: 18, semanticLabel: ''),
              onPressed: () => s.router.go('/settings/${x.id}'),
              child: Flexible(
                child: Text(x.title, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
      ),
    );
    final content = ListView(
      key: ValueKey<String>('settings.section.${current.id}'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  container: true,
                  header: true,
                  child: Text(current.title, style: theme.textTheme.h3),
                ),
                const SizedBox(height: 20),
                current.builder(context),
              ],
            ),
          ),
        ),
      ],
    );
    return ShellPageFrame(
      services: s,
      title: l.cmdSettings,
      onBack: () => s.router.go('/'),
      child: narrow
          ? Column(
              children: [
                SizedBox(height: 180, child: nav),
                Expanded(child: content),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: theme.colorScheme.border),
                    ),
                  ),
                  child: nav,
                ),
                Expanded(child: content),
              ],
            ),
    );
  }
}

/// A titled group of settings.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ShadCard(
        title: Text(title),
        description: description == null ? null : Text(description!),
        backgroundColor: theme.colorScheme.card,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// A label + control row.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.description,
    required this.control,
  });

  final String label;
  final String? description;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final row = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.small),
              if (description != null)
                Text(
                  description!,
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        control,
      ],
    );
    // A switch or checkbox has no text of its own: the row's label names it
    // for screen readers (labeledTapTargetGuideline).
    return control is ShadSwitch || control is ShadCheckbox
        ? MergeSemantics(child: row)
        : row;
  }
}
