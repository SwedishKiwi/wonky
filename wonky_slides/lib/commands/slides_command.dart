import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/ops.dart' show PlanException;

import '../features/editor_screen/deck_document_controller.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../l10n/slides_l10n.dart';

export '../l10n/slides_l10n.dart' show SlidesLocalizations;

/// A localized text from the Slides strings.
typedef SlidesText = String Function(SlidesLocalizations l);

/// Runs a Slides command against the open deck.
typedef SlidesRun =
    FutureOr<CommandResult> Function(
      CommandContext ctx,
      DeckEditorController ed,
      JsonArgs args,
    );

/// The Slides keyboard scopes (03 §1.2, suite 08 §1.2). Each is handled by
/// a `KeymapScope` around its surface; more specific scopes win.
abstract final class SlidesKeyScopes {
  /// The canvas has focus, no text editing (arrows nudge, Delete, T/S/L).
  static const canvas = KeyScope('slidesCanvas');

  /// A text body is being edited (SL-13).
  static const text = KeyScope('slidesText');

  /// A table cell range is selected (SL-15).
  static const table = KeyScope('slidesTable');

  /// Image crop mode (SL-15).
  static const crop = KeyScope('slidesCrop');

  /// The slide navigator (SL-16).
  static const navigator = KeyScope('slidesNavigator');

  /// The speaker notes editor (SL-16).
  static const notes = KeyScope('slidesNotes');

  /// Presenting (SL-19).
  static const present = KeyScope('present');

  /// A line of the outline view (SL-34).
  static const outline = KeyScope('slidesOutline');
}

/// Categories of the keyboard shortcuts help (04 §13.15).
enum SlidesCategory {
  file,
  edit,
  view,
  insert,
  format,
  text,
  tables,
  slides,
  arrange,
  canvas,
  present,
  animations,
  tools,
  ai;

  String label(SlidesLocalizations l) => switch (this) {
    file => l.categoryFile,
    edit => l.categoryEdit,
    view => l.categoryView,
    insert => l.categoryInsert,
    format => l.categoryFormat,
    text => l.categoryText,
    tables => l.categoryTables,
    slides => l.categorySlides,
    arrange => l.categoryArrange,
    canvas => l.categoryCanvas,
    present => l.categoryPresent,
    animations => l.categoryAnimations,
    tools => l.categoryTools,
    ai => l.categoryAi,
  };
}

/// The open deck editor of [ctx], or null.
DeckEditorController? editorOf(CommandContext ctx) {
  final doc = ctx.document;
  return doc is DeckDocumentController ? doc.editor : null;
}

/// The open deck editor, from the shell services.
DeckEditorController? editorOfServices(ShellServices s) {
  final doc = s.activeDocument.value;
  return doc is DeckDocumentController ? doc.editor : null;
}

/// A Slides command on the open deck (04, suite 08): titles from the Slides localizations;
/// [mutates] commands need edit access (role ≥ Editor, Editing mode, the
/// deck loaded) and record their changes through
/// `DeckEditorController.apply` (one `slides.rows` undo step);
/// [placeholder] commands belong to features that are not built yet: they
/// are listed in menus, the palette and MCP, always disabled with the
/// reason "Not available yet" (the work package that builds the feature
/// registers a real command with the same id, `commands.dart`).
class SlidesCommand extends JsonCommand {
  SlidesCommand(
    String id, {
    required this.label,
    required this.run,
    this.icon,
    this.categoryOf,
    this.descriptionText,
    this.dynamicLabel,
    this.defaultBindings = const [],
    this.argBindings = const [],
    this.keyScope = KeyScope.global,
    this.mutates = false,
    this.argsSchema = JsonSchema.empty,
    this.showInPalette = true,
    this.enabled,
    this.checked,
    this.reason,
    this.undoLabelOf,
    this._requiredRole,
  }) : id = CommandId(id),
       placeholder = false,
       owner = null;

  /// A command of a feature that isn't built yet (always disabled).
  SlidesCommand.placeholder(
    String id, {
    required this.label,
    this.icon,
    this.categoryOf,
    this.mutates = false,
    this.defaultBindings = const [],
    this.keyScope = KeyScope.global,
    this.owner,
  }) : id = CommandId(id),
       run = _notAvailable,
       descriptionText = null,
       dynamicLabel = null,
       argBindings = const [],
       argsSchema = const JsonSchema.object(additionalProperties: true),
       showInPalette = true,
       enabled = null,
       checked = null,
       reason = null,
       placeholder = true,
       undoLabelOf = null,
       _requiredRole = null;

  static CommandResult _notAvailable(
    CommandContext ctx,
    DeckEditorController ed,
    JsonArgs args,
  ) => const CommandResult.failed('Not available yet');

  @override
  final CommandId id;
  final SlidesText label;

  /// A label computed from the editor state ("Delete 3 slides").
  final String Function(SlidesLocalizations l, DeckEditorController ed)?
  dynamicLabel;
  @override
  final IconData? icon;
  final SlidesCategory? categoryOf;
  final SlidesText? descriptionText;
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

  /// Extra enabled predicate (selection, mode …).
  final bool Function(DeckEditorController ed, JsonArgs args)? enabled;

  /// Checked state of toggles and radio items.
  final bool? Function(DeckEditorController ed, JsonArgs args)? checked;

  /// The reason shown when [enabled] is false ("Select an object").
  final String? Function(SlidesLocalizations l, DeckEditorController ed)?
  reason;

  final String Function(SlidesLocalizations l, JsonArgs args)? undoLabelOf;
  final bool placeholder;

  /// The work package that builds a placeholder (Slides 12 §4).
  final String? owner;
  final Role? _requiredRole;
  final SlidesRun run;

  @override
  Role get requiredRole =>
      _requiredRole ?? (mutates ? Role.editor : Role.viewer);

  @override
  bool get isUndoable => mutates;

  @override
  String title(BuildContext context) {
    final l = slidesL10n(context);
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
      descriptionText?.call(slidesL10n(context));

  @override
  String? category(BuildContext context) =>
      categoryOf?.label(slidesL10n(context));

  @override
  String undoLabel(BuildContext context, JsonArgs args) {
    final l = slidesL10n(context);
    return undoLabelOf?.call(l, args) ?? label(l);
  }

  @override
  bool isEnabled(CommandContext ctx, JsonArgs args) {
    if (placeholder) return false;
    final ed = editorOf(ctx);
    if (ed == null) return false;
    if (mutates && !ed.canEdit) return false;
    return enabled?.call(ed, args) ?? true;
  }

  @override
  String? disabledReason(CommandContext ctx, JsonArgs args) {
    final l = slidesL10nOf(ctx.services);
    if (placeholder) return l.reasonNotAvailableYet;
    final ed = editorOf(ctx);
    if (ed == null) return l.reasonDeckLoading;
    if (mutates && !ed.canEdit) {
      if (!ed.isReady) return l.reasonDeckLoading;
      return ed.roleCanEdit ? l.reasonViewingMode : l.reasonViewAccess;
    }
    if (enabled != null && !enabled!(ed, args)) return reason?.call(l, ed);
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
      return const CommandResult.failed('No presentation is open');
    }
    try {
      return await run(ctx, ed, args);
    } on PlanException catch (e) {
      return CommandResult.failed(e.message);
    }
  }
}

/// `ok` with optional data.
CommandResult ok([Object? data]) =>
    data == null ? const CommandResult.ok() : CommandResult.ok(data);
