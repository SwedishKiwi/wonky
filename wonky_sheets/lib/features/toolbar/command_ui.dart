import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';

/// Binds controls to commands (every toolbar/menu/tab control invokes a
/// command id — no control calls business logic).
class CommandUi {
  CommandUi(this.context, this.s);

  final BuildContext context;
  final ShellServices s;

  SheetsLocalizations get l => sheetsL10n(context);

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
  ]) => unawaited(invoke(s, id, args: args, source: source, context: context));

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
      id: 'sheets.toolbar.${keyName ?? id.split('.').skip(1).join('.')}',
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
      id: 'sheets.toolbar.${keyName ?? id.split('.').skip(1).join('.')}',
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

  /// A menu entry bound to [id].
  WonkyMenuEntry item(
    String id, {
    Map<String, Object?> args = const {},
    String? label,
    IconData? icon,
    bool radio = false,
    String? keyName,
    InvocationSource source = InvocationSource.menu,
  }) {
    final st = state(id, args);
    final text = label ?? title(id);
    final k = ValueKey<String>('menu.${keyName ?? id}');
    final sc = shortcut(id, args);
    void go() => run(id, args, source);
    if (st.checked != null) {
      return radio
          ? WonkyMenuRadioItem(
              key: k,
              label: text,
              selected: st.checked!,
              shortcut: sc,
              enabled: st.enabled,
              disabledReason: st.disabledReason,
              onSelected: go,
            )
          : WonkyMenuCheckItem(
              key: k,
              label: text,
              checked: st.checked!,
              shortcut: sc,
              enabled: st.enabled,
              disabledReason: st.disabledReason,
              onSelected: go,
            );
    }
    return WonkyMenuItem(
      key: k,
      label: text,
      icon: icon ?? s.registry.byId(id)?.icon,
      shortcut: sc,
      enabled: st.enabled,
      disabledReason: st.disabledReason,
      onSelected: go,
    );
  }
}

/// Invokes a command; failures are shown as toasts and never thrown.
Future<CommandResult> invoke(
  ShellServices s,
  String id, {
  Map<String, Object?> args = const {},
  InvocationSource source = InvocationSource.ui,
  BuildContext? context,
}) async {
  s.noteRecentCommand(id);
  try {
    final r = await s.dispatcher.invoke(
      id,
      args: args,
      source: source,
      context: context != null && context.mounted ? context : null,
    );
    if (r.status == CommandStatus.failed && r.message != null) {
      s.toasts.error(r.message!);
    }
    return r;
  } on CommandDisabled catch (e) {
    if (e.reason != null) s.toasts.show(e.reason!);
    return CommandResult.failed(e.message);
  } on CommandException catch (e) {
    s.toasts.error(e.message);
    return CommandResult.failed(e.message);
  } catch (e) {
    s.toasts.error(sheetsL10nOf(s).toastCommandFailed, description: '$e');
    return CommandResult.failed('$e');
  }
}
