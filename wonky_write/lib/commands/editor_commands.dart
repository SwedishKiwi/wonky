import 'dart:async';

import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../features/editor/commands/editor_command_catalog.dart';
import '../features/editor/controller/editor_types.dart';
import '../features/screen/write_document_controller.dart';
import 'command_icons.dart';
import 'write_command.dart';

/// Wraps every editor command of the Write 04 §40 catalog
/// (`editorCommandCatalog()`) as a shell command, adding role/mode rules,
/// icons, categories and screen behaviour for a few ids ([overrides]).
List<Command<CommandArgs>> editorCommands(
  ShellServices s, {
  Map<String, WriteRun Function(EditorCommandSpec spec)> overrides = const {},
}) => [
  for (final spec in editorCommandCatalog())
    _wrap(spec, overrides[spec.id]?.call(spec)),
];

String _categoryOf(String id) {
  final area = id.split('.')[1];
  return switch (area) {
    'edit' => 'Edit',
    'format' => 'Format',
    'list' => 'Format',
    'link' => 'Insert',
    'insert' => 'Insert',
    'block' => 'Blocks',
    'code' => 'Code blocks',
    'image' => 'Images',
    'table' => 'Tables',
    'view' => 'View',
    'mode' => 'View',
    'nav' => 'Navigation',
    _ => 'Write',
  };
}

KeyScope _scopeOf(String id) =>
    id.startsWith('write.view.') || id.startsWith('write.mode.')
    ? KeyScope.global
    : KeyScope.editor;

WriteCommand _wrap(EditorCommandSpec spec, WriteRun? override) {
  final content = spec.isUndoable && spec.requiredRole >= Role.commenter;
  bool roleAllows(WriteDocumentController d) {
    if (!content) return true;
    if (d.role >= Role.editor) return true;
    // Commenters run content commands only as suggestions (`C*`).
    return d.role >= Role.commenter &&
        spec.suggestable &&
        d.editor.mode == EditorMode.suggesting;
  }

  return WriteCommand(
    spec.id,
    label: spec.title,
    icon: commandIcons[spec.id],
    categoryName: spec.category ?? _categoryOf(spec.id),
    defaultBindings: spec.bindings,
    keyScope: _scopeOf(spec.id),
    requiredRole: spec.requiredRole,
    isUndoable: spec.isUndoable,
    argsSchema: spec.argsSchema,
    needsEditable: content,
    enabled: (d, a) => roleAllows(d) && spec.isEnabled(d.target, a),
    checked: spec.checked == null ? null : (d, a) => spec.checked!(d.target, a),
    reason: (d, a) {
      if (!roleAllows(d)) {
        return spec.suggestable
            ? 'Switch to Suggesting to propose changes'
            : 'You need edit access';
      }
      if (!spec.suggestable && d.editor.mode == EditorMode.suggesting) {
        return "This can't be suggested — switch to Editing";
      }
      return null;
    },
    run:
        override ??
        (ctx, d, a) async {
          final r = await spec.run(d.target, a);
          return r;
        },
  );
}

/// Convenience to run the catalog implementation from an override.
FutureOr<CommandResult> runSpec(
  EditorCommandSpec spec,
  WriteDocumentController doc,
  JsonArgs args,
) => spec.run(doc.target, args);
