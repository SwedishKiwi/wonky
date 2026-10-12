import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../commands/shell_commands/general_commands.dart' show mcpUrl;
import '../data/api.dart';
import '../l10n/wonky_app_localizations.dart';
import '../settings/settings_screen.dart';
import '../shell/dialogs.dart';
import '../shell/form_dialog.dart';
import '../shell/shell_services.dart';
import 'mcp_bridge_client.dart';
import 'mcp_bridge_scope.dart';

/// Human labels of the token scopes (suite 09 §2).
const mcpScopeLabels = <String, String>{
  McpScope.driveRead: 'Drive: read (list, search, export)',
  McpScope.driveWrite: 'Drive: write (create, rename, move, trash, share)',
  McpScope.writeRead: 'Documents: read',
  McpScope.writeEdit: 'Documents: edit (content, comments, suggestions)',
  McpScope.sheetsRead: 'Spreadsheets: read',
  McpScope.sheetsEdit: 'Spreadsheets: edit',
  McpScope.scriptsRun: 'Scripts: run',
  McpScope.uiControl: 'Control app windows (ui.* tools)',
};

/// Default scopes of new tokens (Sheets is not available yet).
const mcpDefaultScopes = [
  McpScope.driveRead,
  McpScope.driveWrite,
  McpScope.writeRead,
  McpScope.writeEdit,
  McpScope.uiControl,
];

/// The connection snippets for MCP clients.
abstract final class McpConnectionSnippets {
  /// `.mcp.json` / Claude Desktop config with the Streamable HTTP server.
  static String json(String url, String token) =>
      const JsonEncoder.withIndent('  ').convert({
        'mcpServers': {
          'wonky': {
            'type': 'http',
            'url': url,
            'headers': {'Authorization': 'Bearer $token'},
          },
        },
      });

  /// `claude mcp add` command line.
  static String claudeCode(String url, String token) =>
      'claude mcp add --transport http wonky $url '
      '--header "Authorization: Bearer $token"';

  /// Config for stdio-only clients through `wonky_mcp_stdio`.
  static String stdio(
    String url,
    String token,
  ) => const JsonEncoder.withIndent('  ').convert({
    'mcpServers': {
      'wonky': {
        'command': 'dart',
        'args': [
          'run',
          '/path/to/wonky/packages/wonky_mcp_stdio/bin/wonky_mcp_stdio.dart',
          '--url',
          url,
          '--token',
          token,
        ],
      },
    },
  });
}

/// Settings › Developer / MCP (suite 04 §4): personal access tokens
/// (create with name, scopes and expiry, copy once, list, revoke), the
/// connection configuration for Claude Code / Claude Desktop, and the UI
/// bridge toggle with its live status.
class McpDeveloperSettings extends StatefulWidget {
  const McpDeveloperSettings({super.key, required this.services});

  final ShellServices services;

  @override
  State<McpDeveloperSettings> createState() => _McpDeveloperSettingsState();
}

class _McpDeveloperSettingsState extends State<McpDeveloperSettings> {
  List<AccessTokenView>? _tokens;
  Object? _loadError;
  CreatedAccessToken? _created;
  int _snippet = 0;

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await s.repositories.users.listTokens();
      if (mounted) {
        setState(() {
          _tokens = list;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _create() async {
    final l = WonkyAppLocalizations.of(context);
    final r = await showWonkyFormDialog(
      context,
      WonkyDialogSpec(
        title: l.tokenCreate,
        description:
            'The token acts as you with the permissions you choose. You '
            'can revoke it at any time.',
        dialogKey: 'dialog.createToken',
        width: 480,
        fields: [
          TextFieldSpec(
            id: 'name',
            label: l.tokenName,
            initial: 'Claude Code',
            maxLength: 100,
            validator: (v) =>
                v.trim().isEmpty ? 'Give the token a name.' : null,
          ),
          for (final scope in McpScope.all)
            if (!scope.startsWith('sheets') && scope != McpScope.scriptsRun)
              CheckboxFieldSpec(
                id: 'scope:$scope',
                label: mcpScopeLabels[scope] ?? scope,
                initial: mcpDefaultScopes.contains(scope),
              ),
          const SelectFieldSpec(
            id: 'expiry',
            label: 'Expires',
            options: {
              '30': 'In 30 days',
              '90': 'In 90 days',
              '365': 'In 1 year',
              'never': 'Never',
            },
            initial: '90',
          ),
        ],
        buttons: [
          DialogButtonSpec(
            id: 'cancel',
            label: l.actionCancel,
            validates: false,
          ),
          DialogButtonSpec(id: 'create', label: l.actionCreate, primary: true),
        ],
      ),
    );
    if (r == null || r.buttonId != 'create' || !mounted) return;
    final scopes = [
      for (final scope in McpScope.all)
        if (r.flag('scope:$scope')) scope,
    ];
    if (scopes.isEmpty) {
      s.toasts.error('Choose at least one permission.');
      return;
    }
    final expiry = r.text('expiry');
    final expiresAt = expiry == 'never'
        ? null
        : DateTime.now().toUtc().add(Duration(days: int.parse(expiry)));
    try {
      final created = await s.repositories.users.createToken(
        name: r.text('name').trim(),
        scopes: scopes,
        expiresAt: expiresAt,
      );
      setState(() => _created = created);
      await _reload();
    } catch (e) {
      s.toasts.error(l.errorGeneric, description: errorMessage(e));
    }
  }

  Future<void> _revoke(AccessTokenView t) async {
    final l = WonkyAppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Revoke "${t.name}"?',
      description:
          'MCP clients using this token stop working immediately. This '
          "can't be undone.",
      confirmLabel: l.tokenRevoke,
      destructive: true,
    );
    if (!ok) return;
    try {
      await s.repositories.users.revokeToken(t.id);
      if (_created?.token.id == t.id) _created = null;
      await _reload();
    } catch (e) {
      s.toasts.error(l.errorGeneric, description: errorMessage(e));
    }
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    s.toasts.show('$what copied');
  }

  String _date(DateTime? d) =>
      d == null ? '—' : intl.DateFormat.yMMMd().format(d.toLocal());

  Widget _tokenRow(BuildContext context, AccessTokenView t) {
    final theme = ShadTheme.of(context);
    final l = WonkyAppLocalizations.of(context);
    final revoked = t.revokedAt != null;
    final expired =
        t.expiresAt != null && t.expiresAt!.isBefore(DateTime.now().toUtc());
    final status = revoked
        ? l.tokenRevoked
        : expired
        ? 'expired'
        : null;
    return Padding(
      key: ValueKey<String>('settings.mcp.token.${t.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.name}${status == null ? '' : ' · $status'}',
                  style: theme.textTheme.small.copyWith(
                    color: status == null
                        ? theme.colorScheme.foreground
                        : theme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.prefix}… · ${t.scopes.join(', ')}',
                  style: theme.textTheme.muted.copyWith(
                    fontFamily: 'packages/shad/GeistMono',
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Created ${_date(t.createdAt)} · '
                  'expires ${t.expiresAt == null ? 'never' : _date(t.expiresAt)} · '
                  'last used ${t.lastUsedAt == null ? 'never' : _date(t.lastUsedAt)}',
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (!revoked)
            ShadButton.ghost(
              key: ValueKey<String>('settings.mcp.revoke.${t.id}'),
              size: ShadButtonSize.sm,
              onPressed: () => _revoke(t),
              child: Text(l.tokenRevoke),
            ),
        ],
      ),
    );
  }

  Widget _code(BuildContext context, String text, {Key? key}) {
    final theme = ShadTheme.of(context);
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'packages/shad/GeistMono',
          fontSize: 12,
          color: theme.colorScheme.foreground,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final url = mcpUrl(s);
    final created = _created;
    final token = created?.secret ?? r'${WONKY_TOKEN}';
    final snippets = [
      ('Claude Code', McpConnectionSnippets.claudeCode(url, token)),
      (
        'JSON (.mcp.json, Claude Desktop)',
        McpConnectionSnippets.json(url, token),
      ),
      ('stdio (wonky_mcp_stdio)', McpConnectionSnippets.stdio(url, token)),
    ];
    final bridge = mcpBridgeOf(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: l.tokensTitle,
          description: l.tokensHint,
          children: [
            if (created != null)
              ShadAlert(
                key: const ValueKey<String>('settings.mcp.newToken'),
                icon: const Icon(LucideIcons.keyRound),
                title: Text(l.tokenCopyOnce),
                description: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          created.secret,
                          style: TextStyle(
                            fontFamily: 'packages/shad/GeistMono',
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                      ),
                      ShadButton.outline(
                        key: const ValueKey<String>('settings.mcp.copyToken'),
                        size: ShadButtonSize.sm,
                        onPressed: () => _copy(created.secret, 'Token'),
                        child: Text(l.actionCopy),
                      ),
                    ],
                  ),
                ),
              ),
            if (_loadError != null)
              Text(errorMessage(_loadError!), style: theme.textTheme.muted)
            else if (_tokens == null)
              const Align(alignment: Alignment.centerLeft, child: ShadSpinner())
            else if (_tokens!.isEmpty)
              Text(l.tokensEmpty, style: theme.textTheme.muted)
            else
              Column(
                children: [for (final t in _tokens!) _tokenRow(context, t)],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: ShadButton(
                key: const ValueKey<String>('settings.mcp.createToken'),
                onPressed: _create,
                leading: const Icon(LucideIcons.plus, size: 16),
                child: Text(l.tokenCreate),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l.mcpTitle,
          description:
              '${l.mcpHint} Endpoint: $url'
              '${created == null ? ' Replace \${WONKY_TOKEN} with a token.' : ''}',
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (var i = 0; i < snippets.length; i++)
                  (i == _snippet ? ShadButton.secondary : ShadButton.ghost)(
                    key: ValueKey<String>('settings.mcp.snippet.$i'),
                    size: ShadButtonSize.sm,
                    onPressed: () => setState(() => _snippet = i),
                    child: Text(snippets[i].$1),
                  ),
              ],
            ),
            _code(
              context,
              snippets[_snippet].$2,
              key: const ValueKey<String>('settings.mcp.snippet'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ShadButton.outline(
                key: const ValueKey<String>('settings.mcp.copySnippet'),
                onPressed: () =>
                    _copy(snippets[_snippet].$2, snippets[_snippet].$1),
                leading: const Icon(LucideIcons.copy, size: 16),
                child: Text(l.cmdCopyMcpConfig),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Window control',
          description:
              'Lets MCP clients with the ui:control permission drive this '
              'window: navigate, run commands, fill dialogs, take '
              'screenshots. A pill with Stop shows while an agent works.',
          children: [
            ListenableBuilder(
              listenable: s.mcp,
              builder: (context, _) => SettingsRow(
                label: l.mcpAllowControl,
                control: ShadSwitch(
                  key: const ValueKey<String>('settings.mcp.bridge'),
                  value: s.mcp.enabled,
                  onChanged: (_) =>
                      s.dispatcher.invoke('shell.mcp.toggleUiBridge'),
                ),
              ),
            ),
            if (bridge != null)
              ListenableBuilder(
                listenable: Listenable.merge([bridge.state, bridge.sessionId]),
                builder: (context, _) => SettingsRow(
                  label: 'Status',
                  control: Text(
                    switch (bridge.state.value) {
                      McpBridgeState.off => 'Off',
                      McpBridgeState.connecting => 'Connecting…',
                      McpBridgeState.connected =>
                        'On · window ${bridge.sessionId.value ?? ''}',
                    },
                    key: const ValueKey<String>('settings.mcp.bridgeStatus'),
                    style: theme.textTheme.small,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
