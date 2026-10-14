import 'package:flutter/foundation.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../commands/sheets_command.dart';
import '../scripts/script_project.dart';
import '../scripts/script_service.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// The file macros are recorded into (09 §15).
const macrosFileName = 'macros.dart';

/// The dynamic command id of the macro [macroId] (`sheets.macro.<id>`, 09
/// §15). Command id segments are camelCase identifiers, so the UUID is
/// written as `m` + its 32 hex digits.
String macroCommandId(String macroId) =>
    'sheets.macro.m${macroId.replaceAll('-', '')}';

/// The key of shortcut slot [slot] (1..10 → `1`…`9`, `0`).
String macroSlotKey(int slot) => '${slot % 10}';

/// `Mod+Alt+Shift+<n>` of shortcut slot [slot].
KeyBinding macroSlotBinding(int slot) =>
    KeyBinding(macroSlotKey(slot), mod: true, alt: true, shift: true);

/// Sources whose operations the recorder captures (09 §15 step 2).
const _recordedSources = {
  InvocationSource.menu,
  InvocationSource.toolbar,
  InvocationSource.shortcut,
  InvocationSource.contextMenu,
  InvocationSource.palette,
  InvocationSource.ui,
};

/// Macros of one open spreadsheet (09 §15): the recorder (a write gate
/// that sees every operation of a person's command before it is applied),
/// saving into `macros.dart` + a `Macro` row, and the dynamic
/// `sheets.macro.<id>` commands with their `Mod+Alt+Shift+0…9` shortcuts.
class MacroService extends ChangeNotifier {
  MacroService._(this.editor);

  static const _key = #wonkySheetsMacroService;

  /// The service of [editor] (created on first use).
  static MacroService of(SheetEditorController editor) =>
      editor.extension<MacroService>(_key, () {
        final s = MacroService._(editor);
        editor.onDispose(s.dispose);
        s._start();
        return s;
      });

  /// The service of [editor] if it was started.
  static MacroService? maybeOf(SheetEditorController? editor) =>
      editor?.extensionOrNull<MacroService>(_key);

  final SheetEditorController editor;
  late final ScriptService scripts = ScriptService.of(editor);

  ShellServices get services => editor.services;

  MacroRecorder? _recorder;
  MacroReferenceMode _mode = MacroReferenceMode.absolute;
  final Map<String, String> _registered = {};
  bool _disposed = false;

  /// The running recording, if any.
  MacroRecorder? get recorder => _recorder;

  /// Whether a recording runs.
  bool get recording => _recorder != null;

  /// Reference mode of the recording.
  MacroReferenceMode get mode => _mode;

  /// Statements recorded so far.
  int get recordedCount => _recorder?.statements.length ?? 0;

  void _start() {
    scripts.addListener(_syncCommands);
    _syncCommands();
  }

  // ------------------------------------------------------------ recording

  /// Starts recording with [mode] (09 §15 step 1).
  void startRecording([MacroReferenceMode mode = MacroReferenceMode.absolute]) {
    if (_recorder != null) return;
    _mode = mode;
    _recorder = _newRecorder(mode);
    editor.writeGates.add(_gate);
    notifyListeners();
  }

  MacroRecorder _newRecorder(MacroReferenceMode mode) => MacroRecorder(
    context: MacroContext(
      mode: mode,
      sheetId: editor.activeSheetId,
      anchor: editor.activeRange.rect,
    ),
  );

  /// Switches the reference mode; only before anything was recorded (the
  /// generated code uses one mode).
  void setMode(MacroReferenceMode mode) {
    final r = _recorder;
    if (r == null || mode == _mode || r.statements.isNotEmpty) return;
    _mode = mode;
    _recorder = _newRecorder(mode);
    notifyListeners();
  }

  /// Stops recording without saving.
  void cancelRecording() {
    if (_recorder == null) return;
    _recorder = null;
    editor.writeGates.remove(_gate);
    notifyListeners();
  }

  void _gate(CommandContext? ctx, SheetsOperation op) {
    final r = _recorder;
    if (r == null || ctx == null || !_recordedSources.contains(ctx.source)) {
      return;
    }
    if (op is GenericRowWrite) return; // script rows, settings: not recorded
    r.record(op, editor.model);
    notifyListeners();
  }

  /// Function names in use (exports of the last build and a scan of the
  /// project's sources).
  Set<String> existingFunctionNames() {
    final names = {for (final f in scripts.exports.functions) f.name};
    final decl = RegExp(
      r'^[A-Za-z_][\w<>?, ]*\s+([A-Za-z_]\w*)\s*\(',
      multiLine: true,
    );
    for (final f in ScriptProjectRows.files(editor.model)) {
      for (final m in decl.allMatches(ScriptProjectRows.sourceOf(f))) {
        names.add(m.group(1)!);
      }
    }
    return names;
  }

  /// Saves the recording (09 §15 step 4): appends the function to
  /// `macros.dart` and creates the `Macro` row, both in [ctx]'s undo step.
  /// Returns the new macro id.
  String saveRecording(
    CommandContext ctx, {
    required String name,
    int? shortcutSlot,
  }) {
    final r = _recorder;
    if (r == null) throw StateError('No recording.');
    final writer = ScriptProjectWriter(editor)..ensureProject(ctx);
    final fn = MacroRecorder.functionNameFor(name, existingFunctionNames());
    final function = r.functionSource(fn, name, DateTime.now());
    final file = ScriptProjectRows.fileNamed(editor.model, macrosFileName);
    final source = MacroRecorder.appendTo(
      file == null ? null : ScriptProjectRows.sourceOf(file),
      function,
    );
    writer.writeFileInStep(ctx, macrosFileName, source);
    final id = writer.createMacro(
      ctx,
      name: name,
      functionName: fn,
      shortcutSlot: shortcutSlot,
    );
    cancelRecording();
    return id;
  }

  // -------------------------------------------------------------- macros

  /// The macro rows.
  List<GenericRecord> get macros => scripts.macros;

  /// The macro using [slot], other than [exceptId].
  GenericRecord? macroWithSlot(int slot, {String? exceptId}) => macros
      .where(
        (m) => m.id != exceptId && m.columns[ScriptCols.shortcutSlot] == slot,
      )
      .firstOrNull;

  /// Registers/unregisters the dynamic macro commands (08 §1.1).
  void _syncCommands() {
    if (_disposed) return;
    final want = <String, GenericRecord>{
      for (final m in macros) macroCommandId(m.id): m,
    };
    for (final id in List.of(_registered.keys)) {
      if (!want.containsKey(id)) {
        services.registry.unregister(CommandId(id));
        _registered.remove(id);
      }
    }
    final usedSlots = <int>{};
    for (final e in want.entries) {
      final m = e.value;
      final slot = m.columns[ScriptCols.shortcutSlot] as int?;
      final bound = slot != null && usedSlots.add(slot) ? slot : null;
      final sig =
          '${ScriptProjectRows.nameOf(m)}|${m.columns[ScriptCols.functionName]}|$bound';
      if (_registered[e.key] == sig) continue;
      _registered[e.key] = sig;
      services.registry.register(
        _macroCommand(e.key, m.id, bound),
        replace: true,
      );
    }
  }

  SheetsCommand _macroCommand(String commandId, String macroId, int? slot) =>
      SheetsCommand(
        commandId,
        label: (l) {
          final m = ScriptProjectRows.macro(editor.model, macroId);
          return m == null ? l.cmdMacroRun : ScriptProjectRows.nameOf(m);
        },
        icon: LucideIcons.keyboard,
        categoryName: (l) => l.categoryScripts,
        defaultBindings: slot == null ? const [] : [macroSlotBinding(slot)],
        enabled: (ed, a) {
          final m = ScriptProjectRows.macro(ed.model, macroId);
          final svc = ScriptService.maybeOf(ed);
          return ed.canEdit &&
              m != null &&
              svc?.exports.function('${m.columns[ScriptCols.functionName]}') !=
                  null;
        },
        run: (ctx, ed, a) async {
          final m = ScriptProjectRows.macro(ed.model, macroId);
          if (m == null) return CommandResult.failed(ed.l10n.macroNotFound);
          final r = await ScriptService.of(ed).run(
            '${m.columns[ScriptCols.functionName]}',
            kind: ExecutionKind.macro,
            context: ctx.dialogContext,
          );
          if (r == null) return const CommandResult.cancelled();
          return r.ok
              ? const CommandResult.ok()
              : CommandResult.failed(r.error?.message ?? r.status.name);
        },
      );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelRecording();
    scripts.removeListener(_syncCommands);
    for (final id in _registered.keys) {
      services.registry.unregister(CommandId(id));
    }
    _registered.clear();
    super.dispose();
  }
}
