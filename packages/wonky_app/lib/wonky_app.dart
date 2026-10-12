/// The Wonky Work app shell (suite 03): client bootstrap, auth, routing,
/// drive, sharing, commands, keymap, undo, collaboration UI, settings.
///
/// Apps describe themselves with a [WonkyAppConfig] and run
/// `WonkyShell.run(config)`.
library;

export 'src/auth/auth_controller.dart';
export 'src/auth/auth_repository.dart';
export 'src/bootstrap/app_urls.dart';
export 'src/bootstrap/cross_app.dart';
export 'src/bootstrap/platform.dart';
export 'src/bootstrap/wonky_client.dart';
export 'src/commands/command.dart';
export 'src/commands/command_dispatcher.dart';
export 'src/commands/command_registry.dart';
export 'src/commands/keymap_service.dart';
export 'src/commands/palette/command_palette.dart';
export 'src/commands/palette/quick_switcher.dart';
export 'src/commands/shell_commands/drive_commands.dart' show itemUrl;
export 'src/commands/shell_commands/general_commands.dart'
    show ShellPanels, mcpConnectionJson, mcpUrl;
export 'src/commands/shell_commands/shell_command_base.dart'
    show shellCommand, l10nOf;
export 'src/commands/shortcuts_help.dart';
export 'src/comments/comment_anchor.dart';
export 'src/comments/comments_controller.dart';
export 'src/comments/comments_panel.dart';
export 'src/comments/comments_undo.dart';
export 'src/config/wonky_app_config.dart';
export 'src/core/connectivity_service.dart';
export 'src/core/local_database.dart';
export 'src/core/local_store.dart';
export 'src/core/offline_storage.dart';
export 'src/core/preferences_controller.dart';
export 'src/core/shell_view_state.dart';
export 'src/core/stream_supervisor.dart';
export 'src/core/toasts.dart';
export 'src/data/api.dart';
export 'src/data/cached_drive_repository.dart';
export 'src/data/collab_repositories.dart';
export 'src/data/drive_cache.dart';
export 'src/data/drive_repository.dart';
export 'src/data/file_repository.dart';
export 'src/data/models_ext.dart';
export 'src/data/sharing_repository.dart';
export 'src/data/user_repository.dart';
export 'src/document/document_controller.dart';
export 'src/drive/drive_format.dart';
export 'src/editor/editor_scaffold.dart';
export 'src/l10n/wonky_app_localizations.dart';
export 'src/mcp_bridge/mcp_bridge_client.dart';
export 'src/mcp_bridge/mcp_bridge_scope.dart' show McpBridgeScope, mcpBridgeOf;
export 'src/mcp_bridge/mcp_control.dart';
export 'src/mcp_bridge/shared_ui_tools.dart';
export 'src/mcp_bridge/ui_tool.dart';
export 'src/menus/menu_resolver.dart';
export 'src/menus/shell_menus.dart';
export 'src/presence/presence_session.dart';
export 'src/routing/misc_pages.dart';
export 'src/settings/sections/offline_section.dart'
    show clearLocalData, simulateOfflinePref;
export 'src/settings/settings_screen.dart' show SettingsGroup, SettingsRow;
export 'src/sharing/share_dialog.dart';
export 'src/shell/account_menu.dart';
export 'src/shell/dialogs.dart';
export 'src/shell/form_dialog.dart';
export 'src/shell/page_frame.dart';
export 'src/shell/shell_scope.dart';
export 'src/shell/shell_services.dart';
export 'src/shell/wonky_shell.dart';
export 'src/undo/drive_undo.dart';
export 'src/undo/undo_history.dart';
export 'src/undo/undo_service.dart';
export 'src/versions/version_renderer.dart';
export 'src/versions/versions_list.dart';
export 'src/versions/versions_undo.dart';
