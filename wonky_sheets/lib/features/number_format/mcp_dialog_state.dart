import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

/// Base state of the custom formatting dialogs (04 §11.1–11.4, 11.21): it
/// registers the dialog with the shell so the MCP UI bridge can describe,
/// fill and press it (suite 09 §6.2).
abstract class McpDialogState<T extends StatefulWidget> extends State<T>
    implements McpDescribableDialog {
  ShellServices? _registeredIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = ShellScope.maybeOf(context);
    if (s == _registeredIn) return;
    _registeredIn?.openDialogs.remove(this);
    _registeredIn = s;
    if (s != null && !s.openDialogs.contains(this)) s.openDialogs.add(this);
  }

  @override
  void dispose() {
    _registeredIn?.openDialogs.remove(this);
    super.dispose();
  }

  /// Closes the dialog with [result].
  void close([Object? result]) => Navigator.of(context).pop(result);
}
