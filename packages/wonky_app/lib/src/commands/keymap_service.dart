import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../bootstrap/platform.dart';
import 'command.dart';
import 'command_dispatcher.dart';
import 'command_registry.dart';

/// One binding of a chord to a command (+ fixed args) in a scope.
class KeymapEntry {
  const KeymapEntry({
    required this.binding,
    required this.commandId,
    required this.scope,
    this.args = const {},
    this.isOverride = false,
  });

  final KeyBinding binding;
  final String commandId;
  final KeyScope scope;
  final Map<String, Object?> args;
  final bool isOverride;
}

/// A conflict found when assigning a binding.
class KeymapConflict {
  const KeymapConflict(this.binding, this.commandIds);

  final KeyBinding binding;
  final List<String> commandIds;
}

/// Maps key chords to commands (suite 08 §1.2).
///
/// - Platform-aware (`Mod` = ⌘ on macOS, Ctrl elsewhere); browser-reserved
///   chords (⌘W, ⌘T, ⌘N, ⌘L) are never bound on web.
/// - Scopes: `global`, `editor`, `grid`, `cellEditor`, `dialog`, `drive`;
///   [handle] is called by each `KeymapScope` for its own scope as key events
///   bubble up from the focused widget, so more specific scopes win.
/// - Contextual bindings: several commands may share a chord within a scope;
///   the first one whose `isEnabled` is true runs.
/// - User overrides (`UserPreferences.keymapOverrides`, JSON
///   `{commandId: ["Mod+Shift+K", …]}`) replace a command's defaults.
class KeymapService extends ChangeNotifier {
  KeymapService({
    required this.registry,
    required this.dispatcher,
    KeyPlatform? platform,
  }) : platform = platform ?? currentKeyPlatform {
    registry.addListener(_rebuild);
    _rebuild();
  }

  final CommandRegistry registry;
  final CommandDispatcher dispatcher;
  final KeyPlatform platform;

  Map<String, List<KeyBinding>> _overrides = {};
  final Map<String, List<KeyBinding>> _extra = {};
  List<KeymapEntry> _entries = const [];

  /// Called with the new overrides JSON after an edit (persist it).
  void Function(String json)? onOverridesChanged;

  List<KeymapEntry> get entries => _entries;

  Map<String, List<KeyBinding>> get overrides => Map.unmodifiable(_overrides);

  /// Loads overrides from preferences JSON (invalid entries are ignored).
  void loadOverrides(String? json) {
    final out = <String, List<KeyBinding>>{};
    if (json != null && json.isNotEmpty) {
      try {
        final map = jsonDecode(json);
        if (map is Map) {
          for (final e in map.entries) {
            final list = e.value;
            if (list is! List) continue;
            out['${e.key}'] = [
              for (final b in list) ?KeyBinding.fromJson(b),
            ];
          }
        }
      } catch (_) {}
    }
    _overrides = out;
    _rebuild();
  }

  String get overridesJson => jsonEncode({
    for (final e in _overrides.entries) e.key: [for (final b in e.value) b.canonical],
  });

  /// Adds bindings that carry fixed args or extra chords for a command
  /// (e.g. `shell.view.zoom {percent: 100}` on Mod+0).
  void addBinding(String commandId, KeyBinding binding) {
    _extra.putIfAbsent(commandId, () => []).add(binding);
    _rebuild();
  }

  /// The effective bindings of [commandId] on this platform.
  List<KeyBinding> bindingsOf(String commandId) {
    final o = _overrides[commandId];
    if (o != null) return o;
    final c = registry.byId(commandId);
    return [
      ...?c?.defaultBindings,
      ...?_extra[commandId],
    ].where((b) => b.appliesTo(platform) && !b.isBrowserReserved(platform)).toList();
  }

  /// Key-cap labels of the primary binding (menus, tooltips, palette).
  List<String>? labelsOf(String commandId) {
    final b = bindingsOf(commandId);
    return b.isEmpty ? null : b.first.labels(platform);
  }

  /// Human text of the primary binding ("⌘⇧Z" / "Ctrl+Shift+Z").
  String? shortcutTextOf(String commandId) {
    final b = bindingsOf(commandId);
    return b.isEmpty ? null : b.first.format(platform);
  }

  /// Replaces the bindings of [commandId] (empty list = unbound).
  void setOverride(String commandId, List<KeyBinding> bindings) {
    _overrides[commandId] = bindings;
    _rebuild();
    onOverridesChanged?.call(overridesJson);
  }

  void resetOverride(String commandId) {
    if (_overrides.remove(commandId) == null) return;
    _rebuild();
    onOverridesChanged?.call(overridesJson);
  }

  void resetAll() {
    if (_overrides.isEmpty) return;
    _overrides = {};
    _rebuild();
    onOverridesChanged?.call(overridesJson);
  }

  /// Commands in [scope] (or global) that already use [binding], except
  /// [exceptCommandId]. Contextual lists count as one binding.
  List<String> conflictsFor(KeyBinding binding, KeyScope scope, {String? exceptCommandId}) {
    final chord = binding.resolve(platform);
    return [
      for (final e in _entries)
        if (e.commandId != exceptCommandId &&
            (e.scope == scope || e.scope == KeyScope.global || scope == KeyScope.global) &&
            e.binding.resolve(platform) == chord)
          e.commandId,
    ].toSet().toList();
  }

  void _rebuild() {
    final out = <KeymapEntry>[];
    for (final c in registry.all) {
      final id = c.id.value;
      for (final b in bindingsOf(id)) {
        out.add(
          KeymapEntry(
            binding: b,
            commandId: id,
            scope: c.keyScope,
            isOverride: _overrides.containsKey(id),
          ),
        );
      }
    }
    _entries = out;
    notifyListeners();
  }

  /// The chord pressed in [event], or null (modifier-only / unsupported).
  ResolvedChord? chordOf(KeyEvent event) {
    final name = WonkyKeyNames.nameOf(event.logicalKey);
    if (name == null) return null;
    final kb = HardwareKeyboard.instance;
    return ResolvedChord(
      key: name,
      control: kb.isControlPressed,
      meta: kb.isMetaPressed,
      alt: kb.isAltPressed,
      shift: kb.isShiftPressed,
    );
  }

  /// Handles [event] for [scope]: runs the first enabled command bound to
  /// the chord. Returns whether it was handled.
  KeyEventResult handle(KeyEvent event, KeyScope scope, {BuildContext? context}) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final chord = chordOf(event);
    if (chord == null) return KeyEventResult.ignored;
    if (scope == KeyScope.global && _isTextEditingChord(chord)) {
      return KeyEventResult.ignored;
    }
    for (final e in _entries) {
      if (e.scope != scope) continue;
      if (e.binding.resolve(platform) != chord) continue;
      final state = dispatcher.stateOf(e.commandId, e.args);
      if (!state.enabled) continue;
      if (event is KeyRepeatEvent && !_repeatable(e.commandId)) return KeyEventResult.handled;
      dispatcher
          .invoke(
            e.commandId,
            args: e.args,
            source: InvocationSource.shortcut,
            context: context,
          )
          .catchError((Object err) {
            debugPrint('Shortcut ${e.commandId} failed: $err');
            return const CommandResult.failed('error');
          });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static bool _repeatable(String id) =>
      id.contains('zoom') || id.contains('undo') || id.contains('redo') || id.contains('move');

  /// Inside a plain text field, editing chords belong to the field.
  bool _isTextEditingChord(ResolvedChord chord) {
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus == null) return false;
    final inText = focus.widget is EditableText ||
        focus.findAncestorWidgetOfExactType<EditableText>() != null;
    if (!inText) return false;
    final primary = platform.isMac ? chord.meta : chord.control;
    const editing = {'Z', 'Y', 'X', 'C', 'V', 'A', 'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End', 'Backspace', 'Delete'};
    if (!primary && !chord.alt) return true; // plain typing
    return editing.contains(chord.key) && !chord.alt;
  }

  @override
  void dispose() {
    registry.removeListener(_rebuild);
    super.dispose();
  }
}

/// Handles key bindings of [scope] for its subtree (suite 08 §1.2).
class KeymapScope extends StatelessWidget {
  const KeymapScope({
    super.key,
    required this.scope,
    required this.keymap,
    required this.child,
    this.focusNode,
    this.autofocus = false,
  });

  final KeyScope scope;
  final KeymapService keymap;
  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: focusNode,
    autofocus: autofocus,
    canRequestFocus: focusNode != null,
    skipTraversal: focusNode == null,
    onKeyEvent: (node, event) => keymap.handle(event, scope, context: context),
    child: child,
  );
}

/// Convenience for `KeymapScope` lookups.
extension CommandBindingLabels on Command<CommandArgs> {
  /// The id as a plain string.
  String get idString => id.value;
}
