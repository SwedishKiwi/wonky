import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/slides_l10n.dart';

/// Binds chrome controls to commands: every toolbar, header, status bar and
/// inspector control invokes a command id (suite 08) — no control calls
/// business logic. Enabled state, reasons, checked state and shortcuts come
/// from the registry.
class SlidesCommandUi {
  SlidesCommandUi(this.context, this.s);

  final BuildContext context;
  final ShellServices s;

  SlidesLocalizations get l => slidesL10n(context);

  CommandState state(String id, [Map<String, Object?> args = const {}]) =>
      s.dispatcher.stateOf(id, args);

  String title(String id) => s.registry.byId(id)?.title(context) ?? id;

  List<String>? shortcut(String id, [Map<String, Object?> args = const {}]) =>
      s.keymap.labelsFor(id, args);

  /// Invokes [id]; failures become toasts.
  void run(
    String id, [
    Map<String, Object?> args = const {},
    InvocationSource source = InvocationSource.toolbar,
  ]) => unawaited(
    s.dispatcher
        .invoke(id, args: args, source: source, context: context)
        .then((r) {
          if (r.status == CommandStatus.failed &&
              r.message != null &&
              !source.isAgent) {
            s.toasts.error(title(id), description: r.message);
          }
          return r;
        })
        .catchError((Object e) {
          s.toasts.error(title(id), description: '$e');
          return const CommandResult.failed('error');
        }),
  );

  String _key(String id, String? keyName) =>
      'slides.toolbar.${keyName ?? id.split('.').skip(1).join('.')}';

  /// A toolbar button bound to [id].
  ToolbarItem button(
    String id, {
    IconData? icon,
    int priority = 3,
    Map<String, Object?> args = const {},
    String? label,
    String? keyName,
    VoidCallback? onLongPress,
  }) {
    final st = state(id, args);
    return ToolbarButton(
      id: _key(id, keyName),
      priority: priority,
      icon: icon ?? s.registry.byId(id)?.icon ?? LucideIcons.circle,
      label: label ?? title(id),
      shortcut: shortcut(id, args),
      enabled: st.enabled,
      disabledReason: st.disabledReason,
      onPressed: () => run(id, args),
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
    );
  }

  /// A toggle bound to [id] (checked state from the command).
  ToolbarItem toggle(
    String id, {
    IconData? icon,
    int priority = 3,
    Map<String, Object?> args = const {},
    String? label,
    String? keyName,
  }) {
    final st = state(id, args);
    return ToolbarToggleButton(
      id: _key(id, keyName),
      priority: priority,
      icon: icon ?? s.registry.byId(id)?.icon ?? LucideIcons.circle,
      label: label ?? title(id),
      value: st.checked ?? false,
      shortcut: shortcut(id, args),
      enabled: st.enabled,
      disabledReason: st.disabledReason,
      onChanged: (_) => run(id, args),
    );
  }

  /// A dropdown whose entries are menu specs (resolved against the
  /// registry like the menubar).
  ToolbarItem dropdown(
    String keyName, {
    required String label,
    required List<MenuSpec> Function() items,
    IconData? icon,
    int priority = 3,
    bool? enabled,
    String? tooltip,
    double? minWidth,
    MenuCustomItems custom = const MenuCustomItems(),
  }) => ToolbarDropdownButton(
    id: 'slides.toolbar.$keyName',
    priority: priority,
    label: label,
    icon: icon,
    tooltip: tooltip,
    minWidth: minWidth,
    enabled: enabled ?? true,
    entries: () => MenuResolver(s, custom: custom).entries(context, items()),
  );

  /// A menu entry bound to [id].
  WonkyMenuEntry item(
    String id, {
    Map<String, Object?> args = const {},
    String? label,
    IconData? icon,
    bool radio = false,
    String? keyName,
  }) =>
      MenuResolver(s).commandEntry(
        context,
        id,
        args: args,
        label: label,
        radio: radio,
        key: keyName,
      ) ??
      WonkyMenuItem(label: label ?? id, enabled: false);
}
