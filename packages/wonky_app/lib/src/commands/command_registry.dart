import 'package:flutter/foundation.dart';
import 'package:wonky_core/wonky_core.dart';

import 'command.dart';

/// All commands of the running app (suite 08 §1.1). Shell commands are
/// registered by `wonky_app`, app commands by the app config; dynamic
/// registration is reserved for Sheets script macros (`sheets.macro.*`).
class CommandRegistry extends ChangeNotifier {
  final Map<CommandId, Command<CommandArgs>> _commands = {};

  /// Registers [command]. Re-registering an id throws unless [replace]
  /// (apps must never re-register shell ids).
  void register(Command<CommandArgs> command, {bool replace = false}) {
    if (!command.id.isValid) {
      throw ArgumentError.value(command.id.value, 'id', 'Invalid command id');
    }
    if (!replace && _commands.containsKey(command.id)) {
      throw StateError('Command ${command.id.value} is already registered');
    }
    _commands[command.id] = command;
    notifyListeners();
  }

  void registerAll(Iterable<Command<CommandArgs>> commands) {
    for (final c in commands) {
      if (_commands.containsKey(c.id)) {
        throw StateError('Command ${c.id.value} is already registered');
      }
      _commands[c.id] = c;
    }
    notifyListeners();
  }

  /// Removes a dynamic command (script macros).
  void unregister(CommandId id) {
    if (_commands.remove(id) != null) notifyListeners();
  }

  Command<CommandArgs>? operator [](CommandId id) => _commands[id];

  Command<CommandArgs>? byId(String id) => _commands[CommandId(id)];

  bool contains(String id) => _commands.containsKey(CommandId(id));

  Iterable<Command<CommandArgs>> get all => _commands.values;

  /// Signals that enabled/checked states may have changed (selection moved,
  /// role changed) so command widgets rebuild.
  void notifyStateChanged() => notifyListeners();
}
