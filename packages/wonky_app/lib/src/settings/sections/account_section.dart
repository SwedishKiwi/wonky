import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../data/api.dart';
import '../../drive/drive_format.dart';
import '../../l10n/wonky_app_localizations.dart';
import '../../shell/form_dialog.dart';
import '../../shell/shell_services.dart';
import '../settings_screen.dart';

/// Settings › Account (suite 04 §4.1): display name, email, password
/// (reset flow), sign out, delete account (type-to-confirm).
class AccountSection extends StatefulWidget {
  const AccountSection({super.key, required this.services});

  final ShellServices services;

  @override
  State<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<AccountSection> {
  late final _name = TextEditingController(text: widget.services.me?.displayName ?? '');
  bool _saving = false;

  ShellServices get s => widget.services;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final l = WonkyAppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty || name == s.me?.displayName) return;
    setState(() => _saving = true);
    try {
      s.currentUser.value = await s.repositories.users.updateProfile(displayName: name);
      s.toasts.show(l.settingsSaved);
    } catch (e) {
      s.toasts.error(l.errorGeneric, description: errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final l = WonkyAppLocalizations.of(context);
    AccountDeletionPreview? preview;
    try {
      preview = await s.repositories.users.deleteAccountPreview();
    } catch (_) {}
    if (!mounted) return;
    final email = s.me?.email ?? '';
    final r = await showWonkyFormDialog(
      context,
      WonkyDialogSpec(
        title: l.deleteAccountTitle,
        description: preview == null
            ? l.deleteAccountBody(email)
            : '${l.deleteAccountCounts(preview.ownedDocuments, preview.ownedSpreadsheets, preview.ownedFolders)}\n${l.deleteAccountBody(email)}',
        dialogKey: 'dialog.deleteAccount',
        fields: [
          TextFieldSpec(
            id: 'confirm',
            label: l.deleteAccountConfirmLabel(email),
            selectAll: false,
            validator: (v) => v.trim().toLowerCase() == email.toLowerCase() ? null : l.deleteAccountMismatch,
          ),
        ],
        buttons: [
          DialogButtonSpec(id: 'cancel', label: l.actionCancel),
          DialogButtonSpec(id: 'delete', label: l.deleteAccountAction, primary: true, destructive: true),
        ],
      ),
    );
    if (r?.buttonId != 'delete') return;
    try {
      await s.repositories.users.deleteAccount(r!.text('confirm').trim());
      await s.auth.signOut();
    } catch (e) {
      s.toasts.error(l.errorGeneric, description: errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return ValueListenableBuilder<UserProfileView?>(
      valueListenable: s.currentUser,
      builder: (context, me, _) {
        final u = me?.summary;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGroup(
              title: l.settingsProfile,
              children: [
                Row(
                  children: [
                    WonkyAvatar(name: u?.displayName ?? '?', color: u == null ? const Color(0xff71717a) : parseHexColor(u.avatarColor), imageUrl: u?.avatarUrl, size: 56),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u?.displayName ?? '', style: ShadTheme.of(context).textTheme.large),
                          Text(u?.email ?? '', style: ShadTheme.of(context).textTheme.muted),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.authDisplayName, style: ShadTheme.of(context).textTheme.small),
                          const SizedBox(height: 6),
                          ShadInput(key: const ValueKey<String>('settings.account.name'), controller: _name, onSubmitted: (_) => _saveName()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadButton(
                      key: const ValueKey<String>('settings.account.saveName'),
                      enabled: !_saving,
                      onPressed: _saveName,
                      child: Text(l.actionSave),
                    ),
                  ],
                ),
              ],
            ),
            SettingsGroup(
              title: l.settingsSecurity,
              children: [
                SettingsRow(
                  label: l.authPassword,
                  description: l.settingsPasswordHint,
                  control: ShadButton.outline(
                    key: const ValueKey<String>('settings.account.password'),
                    onPressed: () async {
                      await s.auth.signOut();
                      s.router.go('/reset');
                    },
                    child: Text(l.settingsChangePassword),
                  ),
                ),
                SettingsRow(
                  label: l.cmdSignOut,
                  description: l.settingsSignOutHint,
                  control: ShadButton.outline(
                    key: const ValueKey<String>('settings.account.signOut'),
                    onPressed: () => s.dispatcher.invoke('shell.account.signOut'),
                    child: Text(l.cmdSignOut),
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: l.deleteAccountTitle,
              description: l.deleteAccountHint,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ShadButton.destructive(
                    key: const ValueKey<String>('settings.account.delete'),
                    onPressed: _delete,
                    child: Text(l.deleteAccountAction),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
