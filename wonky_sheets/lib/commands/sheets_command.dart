import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/charts/chart_sheet_rules.dart';
import '../features/formatting/rich_text_editing.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import '../features/sheet_editor/sheets_document_controller.dart';
import '../features/sheet_editor/write_gate.dart';
import '../l10n/sheets_l10n.dart';

export '../l10n/sheets_l10n.dart' show SheetsLocalizations, SheetsText;

/// Runs a Sheets command against the open spreadsheet.
typedef SheetsRun =
    FutureOr<CommandResult> Function(
      CommandContext ctx,
      SheetEditorController ed,
      JsonArgs args,
    );

/// A dynamic label computed from the editor state ("Insert 3 rows above").
typedef SheetsDynamicText =
    String Function(SheetsLocalizations l, SheetEditorController ed);

/// The open spreadsheet editor of [ctx], or null.
SheetEditorController? editorOf(CommandContext ctx) {
  final doc = ctx.document;
  return doc is SheetsDocumentController ? doc.editor : null;
}

/// The open spreadsheet editor, from the shell services.
SheetEditorController? editorOfServices(ShellServices s) {
  final doc = s.activeDocument.value;
  return doc is SheetsDocumentController ? doc.editor : null;
}

/// A Sheets command (03 §19, 04): titles from the Sheets localizations;
/// [mutates] commands need edit access, open an undo transaction and record
/// one `sheets.rows` entry per applied plan; [placeholder] commands are
/// registered for features that are not built yet (always disabled) so that
/// menus, MCP and later features only fill in the handler.
class SheetsCommand extends JsonCommand {
  SheetsCommand(
    String id, {
    required this.label,
    required this.run,
    this.icon,
    this.categoryName,
    this.descriptionText,
    this.dynamicLabel,
    this.defaultBindings = const [],
    this.argBindings = const [],
    this.keyScope = KeyScope.grid,
    this.mutates = false,
    this.argsSchema = JsonSchema.empty,
    this.showInPalette = true,
    this.enabled,
    this.checked,
    this.placeholder = false,
    this.needsEditor = true,
    this.undoLabelOf,
    this.repeatable = false,
  }) : id = CommandId(id);

  /// A command of a feature that isn't built yet: listed in menus and the
  /// registry, always disabled.
  SheetsCommand.placeholder(
    String id, {
    required this.label,
    this.icon,
    this.categoryName,
    this.argsSchema = const JsonSchema.object(additionalProperties: true),
    this.mutates = false,
    this.defaultBindings = const [],
  }) : id = CommandId(id),
       run = _notAvailable,
       descriptionText = null,
       dynamicLabel = null,
       argBindings = const [],
       keyScope = KeyScope.grid,
       showInPalette = true,
       enabled = null,
       checked = null,
       placeholder = true,
       needsEditor = true,
       undoLabelOf = null,
       repeatable = false;

  static CommandResult _notAvailable(
    CommandContext ctx,
    SheetEditorController ed,
    JsonArgs args,
  ) => const CommandResult.failed('Not available');

  @override
  final CommandId id;
  final SheetsText label;
  final SheetsDynamicText? dynamicLabel;
  @override
  final IconData? icon;
  final SheetsText? categoryName;
  final SheetsText? descriptionText;
  @override
  final List<KeyBinding> defaultBindings;
  @override
  final List<ArgsKeyBinding> argBindings;
  @override
  final KeyScope keyScope;
  final bool mutates;
  @override
  final JsonSchema argsSchema;
  @override
  final bool showInPalette;
  final bool Function(SheetEditorController ed, JsonArgs args)? enabled;
  final bool? Function(SheetEditorController ed, JsonArgs args)? checked;
  final bool placeholder;
  final bool needsEditor;
  final String Function(SheetsLocalizations l, JsonArgs args)? undoLabelOf;

  /// Whether `sheets.edit.repeatLast` may repeat it (formatting/structure).
  final bool repeatable;
  final SheetsRun run;

  @override
  Role get requiredRole => mutates ? Role.editor : Role.viewer;

  @override
  bool get isUndoable => mutates;

  @override
  String title(BuildContext context) {
    final l = sheetsL10n(context);
    final dyn = dynamicLabel;
    if (dyn != null) {
      final s = ShellScope.maybeOf(context);
      final ed = s == null ? null : editorOfServices(s);
      if (ed != null) return dyn(l, ed);
    }
    return label(l);
  }

  @override
  String? description(BuildContext context) =>
      descriptionText?.call(sheetsL10n(context));

  @override
  String? category(BuildContext context) =>
      categoryName?.call(sheetsL10n(context));

  @override
  String undoLabel(BuildContext context, JsonArgs args) {
    final l = sheetsL10n(context);
    return undoLabelOf?.call(l, args) ?? label(l);
  }

  @override
  bool isEnabled(CommandContext ctx, JsonArgs args) {
    if (placeholder) return false;
    final ed = editorOf(ctx);
    if (ed == null) return !needsEditor;
    if (mutates && !ed.canEdit) return false;
    // Formatting that can't be a run is unavailable while text is selected
    // in the cell editor (06 §11).
    if (mutates &&
        RichTextEditing.hasRunSelection(ed.editor) &&
        RichTextEditing.isCellOnlyFormatting(id.value)) {
      return false;
    }
    // A chart sheet has no grid (08 §11).
    if (ChartSheetRules.blocks(ed, id.value)) return false;
    return enabled?.call(ed, args) ?? true;
  }

  @override
  String? disabledReason(CommandContext ctx, JsonArgs args) {
    final ed = editorOf(ctx);
    final l = sheetsL10nOf(ctx.services);
    if (placeholder) return l.reasonNotAvailableYet;
    if (ed == null) return l.reasonSpreadsheetLoading;
    if (mutates && !ed.canEdit) {
      return ed.roleCanEdit ? l.reasonViewingMode : l.reasonViewAccess;
    }
    if (mutates &&
        RichTextEditing.hasRunSelection(ed.editor) &&
        RichTextEditing.isCellOnlyFormatting(id.value)) {
      return l.reasonTextSelected;
    }
    if (ChartSheetRules.blocks(ed, id.value)) return l.reasonChartSheet;
    return null;
  }

  @override
  bool? isChecked(CommandContext ctx, JsonArgs args) {
    final ed = editorOf(ctx);
    if (ed == null || checked == null) return null;
    return checked!(ed, args);
  }

  @override
  Future<CommandResult> execute(CommandContext ctx, JsonArgs args) async {
    final ed = editorOf(ctx);
    if (ed == null) {
      return const CommandResult.failed('No spreadsheet is open');
    }
    try {
      final r = await run(ctx, ed, args);
      if (repeatable && r.isOk) ed.lastRepeatable = (id.value, args.values);
      return r;
    } on PlanException catch (e) {
      return CommandResult.failed(e.message);
    } on InvalidRangeException catch (e) {
      return CommandResult.failed(e.message);
    } on WriteRefused catch (e) {
      // Protected cells / rejected input (03 §8.4, §16): a dialog for
      // people, an error code for agents.
      final dc = ctx.dialogContext;
      final show = e.show;
      if (show != null && dc != null && dc.mounted && !ctx.source.isAgent) {
        await show(dc);
        return const CommandResult.cancelled();
      }
      return CommandResult.failed(e.resultMessage);
    } on WriteDeclined {
      return const CommandResult.cancelled();
    } on WriteNeedsConfirmation catch (e) {
      // Commands that ask nothing before writing run again once confirmed;
      // commands with dialogs use [ConfirmedApply.applyConfirmed] and resume
      // in place instead.
      final dc = ctx.dialogContext;
      if (dc == null || !dc.mounted || !await e.confirm(dc)) {
        return const CommandResult.cancelled();
      }
      try {
        return await execute(ctx, args);
      } finally {
        e.retryDone?.call();
      }
    }
  }
}

/// The user declined a write confirmation ("Heads up!", 03 §16): the
/// command ends as cancelled.
class WriteDeclined implements Exception {
  const WriteDeclined();
}

/// Applying with the write confirmation in place (03 §16).
extension ConfirmedApply on SheetEditorController {
  /// Like [SheetEditorController.apply], but when a gate asks the user to
  /// confirm the write (warning-only protection) the dialog is shown here
  /// and the same operation is applied after OK, so the command **resumes**
  /// — dialogs it showed before (link, alt text, resize…) aren't asked
  /// again. Throws [WriteDeclined] when the user cancels.
  Future<MutationPlan> applyConfirmed(
    CommandContext ctx,
    SheetsOperation op,
  ) async {
    try {
      return apply(ctx, op);
    } on WriteNeedsConfirmation catch (e) {
      final dc = ctx.dialogContext;
      if (dc == null || !dc.mounted || !await e.confirm(dc)) {
        throw const WriteDeclined();
      }
      try {
        return apply(ctx, op);
      } finally {
        e.retryDone?.call();
      }
    }
  }
}

/// `ok` with optional data.
CommandResult ok([Object? data]) =>
    data == null ? const CommandResult.ok() : CommandResult.ok(data);

/// Ranges from an optional `ranges`/`range` A1 argument, else the selection.
List<ResolvedRange> rangesArg(SheetEditorController ed, JsonArgs a) {
  final list = a.strings('ranges');
  final one = a.string('range');
  final texts = [...list, ?one];
  if (texts.isEmpty) return ed.selectedRanges;
  return [
    for (final t in texts)
      for (final part in t.split(','))
        if (part.trim().isNotEmpty)
          ed.model.parseA1(part.trim(), contextSheetId: ed.activeSheetId),
  ];
}

/// A single range from an A1 argument [key], else the active range.
ResolvedRange rangeArg(
  SheetEditorController ed,
  JsonArgs a, [
  String key = 'range',
]) {
  final t = a.string(key);
  if (t == null || t.trim().isEmpty) return ed.activeRange;
  return ed.model.parseA1(t.trim(), contextSheetId: ed.activeSheetId);
}

/// A rectangle from an A1 argument on the active sheet.
GridRect rectArg(SheetEditorController ed, JsonArgs a, String key) =>
    rangeArg(ed, a, key).rect;

/// JSON schema helpers.
abstract final class Schemas {
  static const ranges = JsonSchema.object(
    properties: {
      'ranges': JsonSchema.array(
        JsonSchema.string(),
        description: 'A1 ranges (default: the selection).',
      ),
    },
  );

  static JsonSchema object(
    Map<String, JsonSchema> properties, {
    List<String> required = const [],
  }) => JsonSchema.object(
    properties: {
      'ranges': const JsonSchema.array(
        JsonSchema.string(),
        description: 'A1 ranges (default: the selection).',
      ),
      ...properties,
    },
    required: required,
  );
}
