import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/find.dart';

import '../features/editor_screen/deck_editor_controller.dart';
import '../features/find/find_controller.dart';
import '../features/find/find_replace_panel.dart';
import '../features/text_editing/text_editing_host.dart';
import '../l10n/slides_l10n.dart' show slidesL10nOf;
import 'slides_command.dart';

/// Find and replace (Slides 03 §13, SL-18): the find bar (⌘F), the *Find
/// and replace* panel (⇧⌘H), next/previous, replace and *Replace all*
/// (one undo step "Replace all"; bodies soft-locked by others are skipped
/// and reported). Agents pass the query and options as arguments.
List<Command<CommandArgs>> findCommands(ShellServices s) => [
  SlidesCommand(
    'slides.find.open',
    label: (l) => l.cmdFindOpen,
    icon: LucideIcons.search,
    categoryOf: SlidesCategory.edit,
    defaultBindings: const [KeyBinding('F', mod: true)],
    argsSchema: const JsonSchema.object(
      properties: {'query': JsonSchema.string(description: 'Text to find.')},
    ),
    run: (ctx, ed, a) {
      final f = DeckFindController.of(ed);
      f.openBar(query: a.string('query') ?? _selectedText(ed));
      return ok(_state(f));
    },
  ),
  SlidesCommand(
    'slides.find.openReplace',
    label: (l) => l.cmdFindOpenReplace,
    icon: LucideIcons.replace,
    categoryOf: SlidesCategory.edit,
    defaultBindings: const [KeyBinding('H', mod: true, shift: true)],
    argsSchema: const JsonSchema.object(
      properties: {'find': JsonSchema.string(), 'replace': JsonSchema.string()},
    ),
    run: (ctx, ed, a) {
      final f = DeckFindController.of(ed);
      f.openPanel(
        query: a.string('find') ?? _selectedText(ed),
        replace: a.string('replace'),
      );
      return ok(_state(f));
    },
  ),
  _step('slides.find.next', (l) => l.cmdFindNext, forward: true),
  _step('slides.find.previous', (l) => l.cmdFindPrevious, forward: false),
  SlidesCommand(
    'slides.find.replace',
    label: (l) => l.cmdFindReplace,
    icon: LucideIcons.replace,
    categoryOf: SlidesCategory.edit,
    mutates: true,
    showInPalette: false,
    argsSchema: _replaceSchema,
    run: (ctx, ed, a) {
      final f = _configured(ed, a);
      if (f.error != null) return CommandResult.failed(f.error!);
      final replace = a.string('replace') ?? f.replacement;
      f.replacement = replace;
      final done = f.replaceCurrent(ctx, replace);
      return ok({..._state(f), 'replaced': done ? 1 : 0});
    },
  ),
  SlidesCommand(
    'slides.find.replaceAll',
    label: (l) => l.cmdFindReplaceAll,
    icon: LucideIcons.replaceAll,
    categoryOf: SlidesCategory.edit,
    mutates: true,
    showInPalette: false,
    argsSchema: _replaceSchema,
    undoLabelOf: (l, a) => l.undoReplaceAll,
    run: (ctx, ed, a) {
      final l = slidesL10nOf(ed.services);
      final f = _configured(ed, a);
      if (f.error != null) return CommandResult.failed(f.error!);
      if (f.query.isEmpty) return CommandResult.failed(l.findNoResults);
      final replace = a.string('replace') ?? f.replacement;
      f.replacement = replace;
      final find = f.query;
      final (n, skipped, holder) = f.replaceAll(ctx, replace);
      final message = l.toastReplacedAll(n, find, replace);
      final skippedMessage = skipped == 0
          ? null
          : l.toastReplaceSkipped(skipped, holder ?? '');
      if (!ctx.source.isAgent) {
        ed.services.toasts.show(message, description: skippedMessage);
      }
      if (n == 0) {
        return CommandResult.failed(skippedMessage ?? l.findNoResults);
      }
      return ok({
        'replaced': n,
        'skipped': skipped,
        'message': message,
        'skippedMessage': ?skippedMessage,
      });
    },
  ),
  SlidesCommand(
    'slides.find.close',
    label: (l) => l.findClose,
    icon: LucideIcons.x,
    categoryOf: SlidesCategory.edit,
    showInPalette: false,
    enabled: (ed, a) => DeckFindController.maybeOf(ed)?.isOpen ?? false,
    run: (ctx, ed, a) {
      DeckFindController.of(ed).close();
      return ok();
    },
  ),
];

const _optionProps = <String, JsonSchema>{
  'query': JsonSchema.string(description: 'Text to find (default: current).'),
  'matchCase': JsonSchema.boolean(),
  'wholeWords': JsonSchema.boolean(),
  'useRegex': JsonSchema.boolean(),
  'includeNotes': JsonSchema.boolean(description: 'Default true.'),
  'includeSkipped': JsonSchema.boolean(description: 'Default true.'),
  'scope': JsonSchema.string(enumValues: ['all', 'current', 'selected']),
};

const _replaceSchema = JsonSchema.object(
  properties: {
    ..._optionProps,
    'find': JsonSchema.string(description: 'Alias of query.'),
    'replace': JsonSchema.string(
      description: r'Replacement; with useRegex, $1…$9 insert groups.',
    ),
  },
);

/// Applies the query/options of [a] (agents, the panel) to the find state.
DeckFindController _configured(DeckEditorController ed, JsonArgs a) {
  final f = DeckFindController.of(ed);
  final o = f.options;
  final scope = findScopeOf(a.string('scope'));
  f.search(
    a.string('query') ?? a.string('find') ?? f.query,
    options: o.copyWith(
      matchCase: a.boolean('matchCase'),
      wholeWords: a.boolean('wholeWords'),
      useRegex: a.boolean('useRegex'),
      includeNotes: a.boolean('includeNotes'),
      includeSkipped: a.boolean('includeSkipped'),
      scope: scope,
    ),
  );
  return f;
}

SlidesCommand _step(String id, SlidesText label, {required bool forward}) =>
    SlidesCommand(
      id,
      label: label,
      icon: forward ? LucideIcons.chevronDown : LucideIcons.chevronUp,
      categoryOf: SlidesCategory.edit,
      showInPalette: false,
      argsSchema: const JsonSchema.object(properties: _optionProps),
      enabled: (ed, a) =>
          a.string('query') != null ||
          (DeckFindController.maybeOf(ed)?.query.isNotEmpty ?? false),
      reason: (l, ed) => l.findNoResults,
      run: (ctx, ed, a) {
        final l = slidesL10nOf(ed.services);
        final f = _configured(ed, a);
        if (f.error != null) return CommandResult.failed(f.error!);
        final m = f.step(forward: forward);
        if (m == null) return CommandResult.failed(l.findNoResults);
        return ok({..._state(f), 'slideId': m.slideId, 'text': m.text});
      },
    );

Map<String, Object?> _state(DeckFindController f) {
  final m = f.currentMatch;
  return {
    'query': f.query,
    'matches': f.matches.length,
    'current': f.currentIndex + 1,
    if (m != null)
      'match': {
        'slideId': m.slideId,
        'body': m.bodyKey,
        'start': m.start,
        'length': m.length,
      },
  };
}

/// The selected text of the body being edited (one line), else null.
String? _selectedText(DeckEditorController ed) {
  final c = textEditingOf(ed).active;
  final r = c?.selectionRange;
  if (c == null || r == null || r.$1 == r.$2) return null;
  final plain = DeckFind.plainOf(c.json);
  if (r.$2 > plain.length) return null;
  final t = plain.substring(r.$1, r.$2);
  return t.contains('\n') ? null : t;
}
