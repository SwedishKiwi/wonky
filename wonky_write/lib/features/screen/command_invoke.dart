import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

/// Invokes a command from a control of the Write screen (menus, toolbar,
/// panels and dialogs never call business logic directly — Write 05).
///
/// Failures are shown as a toast; the future completes with the result (or
/// a failed result) and never throws.
Future<CommandResult> invokeCommand(
  BuildContext context,
  String id, {
  Map<String, Object?> args = const {},
  InvocationSource source = InvocationSource.ui,
}) {
  final s = ShellScope.of(context);
  return invokeWith(s, id, args: args, source: source, context: context);
}

/// [invokeCommand] with explicit [services].
Future<CommandResult> invokeWith(
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
    s.toasts.error('Something went wrong', description: errorMessage(e));
    return CommandResult.failed('$e');
  }
}

/// The enabled/checked state of a command for controls.
CommandState commandState(
  BuildContext context,
  String id, [
  Map<String, Object?> args = const {},
]) => ShellScope.of(context).dispatcher.stateOf(id, args);

/// The shortcut labels of a command (tooltips, menus).
List<String>? shortcutOf(BuildContext context, String id) =>
    ShellScope.of(context).keymap.labelsOf(id);
