import 'dart:async';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../features/editor/applier/delta_applier.dart' show DeltaSelection;
import '../features/editor/commands/editor_command_catalog.dart';
import '../features/editor/dnd/external_drop.dart';
import '../features/editor/popovers/editor_popovers.dart';
import '../features/emoji/emoji_catalog.dart';
import '../features/emoji/emoji_picker.dart';
import '../features/emoji/emoji_prefs.dart';
import '../features/images/image_services.dart';
import '../features/import/import_service.dart';
import '../features/lightbox/image_lightbox.dart';
import '../features/screen/write_document_controller.dart';
import '../features/special_chars/special_chars_dialog.dart';
import '../features/spellcheck/spelling_dialogs.dart';
import '../features/spellcheck/write_spellcheck.dart';
import 'editor_commands.dart';
import 'write_command.dart';

/// Commands of the editor extras (Write 04 §17.4 lightbox, §18.4 in-place
/// table editing, §20 emoji and special characters, §30 focus mode and
/// typewriter scrolling).
List<Command<CommandArgs>> extrasCommands(ShellServices s) => [
  WriteCommand(
    'write.insert.emoji',
    label: 'Emoji…',
    icon: LucideIcons.smile,
    categoryName: 'Insert',
    requiredRole: Role.commenter,
    isUndoable: true,
    needsEditable: true,
    descriptionText: 'Pick an emoji to insert at the cursor',
    argsSchema: const JsonSchema.object(
      properties: {'emoji': JsonSchema.string()},
    ),
    enabled: (d, a) => d.commands.canEdit,
    undoLabelOf: (_) => 'Insert emoji',
    run: (ctx, d, a) async {
      final direct = a.string('emoji');
      if (direct != null && direct.isNotEmpty) {
        return okIf(d.commands.insertText(direct, label: 'Insert emoji'));
      }
      final c = ctx.dialogContext;
      if (c == null) return const CommandResult.failed('emoji is required');
      var chosen = false;
      await showEmojiPickerDialog(
        c,
        prefs: emojiPrefsOf(s),
        anchor: _caretAnchor(d),
        onSelected: (emoji) {
          chosen = d.commands.insertText(emoji, label: 'Insert emoji');
        },
      );
      d.focusEditor();
      return chosen ? const CommandResult.ok() : const CommandResult.cancelled();
    },
  ),
  WriteCommand(
    'write.image.preview',
    label: 'View full size',
    icon: LucideIcons.maximize,
    categoryName: 'Images',
    descriptionText: 'Show the image in a full-screen viewer',
    argsSchema: const JsonSchema.object(
      properties: {'nodeId': JsonSchema.string()},
    ),
    enabled: (d, a) => d.embedData('image', a.string('nodeId')) != null,
    run: (ctx, d, a) async {
      final data = d.embedData('image', a.string('nodeId'));
      final c = ctx.dialogContext;
      if (data == null) return const CommandResult.failed('No image selected');
      if (c == null) return const CommandResult.failed('No window');
      final ok = await openLightbox(
        c,
        resolve: () => d.images.resolve('${data['src'] ?? ''}'),
        alt: '${data['alt'] ?? ''}',
        title: data['title'] as String?,
      );
      d.focusEditor();
      return okIf(ok, 'The image isn’t available');
    },
  ),
  WriteCommand(
    'write.table.editCell',
    label: 'Edit table cell',
    categoryName: 'Tables',
    requiredRole: Role.editor,
    descriptionText: 'Edit a table cell in place',
    argsSchema: const JsonSchema.object(
      properties: {
        'nodeId': JsonSchema.string(),
        'row': JsonSchema.integer(minimum: 0),
        'col': JsonSchema.integer(minimum: 0),
      },
    ),
    needsEditable: true,
    enabled: (d, a) =>
        d.editor.tableEditing != null &&
        d.commands.canEditTable(nodeId: a.string('nodeId')),
    run: (ctx, d, a) {
      final table = d.commands.tableOf(nodeId: a.string('nodeId'));
      final editing = d.editor.tableEditing;
      if (table == null || editing == null) {
        return const CommandResult.failed('No table selected');
      }
      return okIf(
        editing.activate(
          table.id,
          a.integer('row') ?? 0,
          a.integer('col') ?? 0,
          selectAll: true,
        ),
      );
    },
  ),
  WriteCommand(
    'write.view.toggleFocusMode',
    label: 'Focus mode',
    icon: LucideIcons.focus,
    categoryName: 'View',
    descriptionText: 'Dim everything but the paragraph you are writing',
    checked: (d, a) => d.viewPrefs.focusMode,
    run: (ctx, d, a) {
      d.viewPrefs.focusMode = !d.viewPrefs.focusMode;
      d.focusEditor();
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.view.toggleTypewriter',
    label: 'Typewriter scrolling',
    categoryName: 'View',
    descriptionText: 'Keep the line you are typing in the middle of the screen',
    checked: (d, a) => d.viewPrefs.typewriter,
    run: (ctx, d, a) {
      d.viewPrefs.typewriter = !d.viewPrefs.typewriter;
      d.focusEditor();
      return const CommandResult.ok();
    },
  ),
];

/// Spellcheck commands (Write 04 §28.2).
List<Command<CommandArgs>> spellCommands(ShellServices s) {
  bool pref(String key, bool fallback) =>
      s.prefs.writeDefaults[key] as bool? ?? fallback;
  return [
    WriteGlobalCommand(
      'write.spell.toggle',
      label: 'Underline spelling errors',
      categoryName: 'Tools',
      argsSchema: const JsonSchema.object(
        properties: {'enabled': JsonSchema.boolean()},
      ),
      checked: (ctx, a) => pref('spellcheck', true),
      run: (ctx, a) async {
        await s.prefs.setWriteDefault(
          'spellcheck',
          a.boolean('enabled') ?? !pref('spellcheck', true),
        );
        return const CommandResult.ok();
      },
    ),
    WriteGlobalCommand(
      'write.spell.toggleIgnoreUppercase',
      label: 'Ignore words in UPPERCASE',
      categoryName: 'Tools',
      checked: (ctx, a) => pref('spellcheckIgnoreUppercase', true),
      run: (ctx, a) async {
        await s.prefs.setWriteDefault(
          'spellcheckIgnoreUppercase',
          !pref('spellcheckIgnoreUppercase', true),
        );
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.spell.replace',
      label: 'Correct spelling',
      categoryName: 'Tools',
      requiredRole: Role.commenter,
      isUndoable: true,
      needsEditable: true,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'start': JsonSchema.integer(minimum: 0),
          'length': JsonSchema.integer(minimum: 1),
          'word': JsonSchema.string(),
        },
        required: ['start', 'length', 'word'],
      ),
      undoLabelOf: (_) => 'Correct spelling',
      run: (ctx, d, a) {
        final ok = d.commands.replaceRangeWithTextLabelled(
          a.integer('start')!,
          a.integer('length')!,
          a.requireString('word'),
          label: 'Correct spelling',
        );
        d.focusEditor();
        return okIf(ok);
      },
    ),
    WriteCommand(
      'write.spell.ignore',
      label: 'Ignore',
      categoryName: 'Tools',
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {'word': JsonSchema.string()},
        required: ['word'],
      ),
      run: (ctx, d, a) {
        d.spellcheck.ignore(a.requireString('word'));
        d.focusEditor();
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.spell.addToDictionary',
      label: 'Add to dictionary',
      categoryName: 'Tools',
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {'word': JsonSchema.string()},
        required: ['word'],
      ),
      run: (ctx, d, a) async {
        await addToPersonalDictionary(s, d, a.requireString('word'));
        d.focusEditor();
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.spell.nextError',
      label: 'Next spelling error',
      categoryName: 'Tools',
      defaultBindings: const [KeyBinding("'", mod: true)],
      keyScope: KeyScope.editor,
      enabled: (d, a) => d.spellcheck.errors.isNotEmpty,
      run: (ctx, d, a) {
        final errors = d.spellcheck.errors;
        if (errors.isEmpty) {
          return const CommandResult.failed('No spelling errors');
        }
        final from = d.editor.selection?.end ?? 0;
        final next = errors.firstWhere(
          (e) => e.start >= from,
          orElse: () => errors.first,
        );
        d.editor.select(DeltaSelection(next.start, next.end));
        d.revealOffset?.call(next.start);
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.spell.check',
      label: 'Check spelling…',
      icon: LucideIcons.spellCheck,
      categoryName: 'Tools',
      run: (ctx, d, a) async {
        final c = ctx.dialogContext;
        if (c == null) return const CommandResult.failed('No window');
        if (d.spellcheck.state == SpellcheckState.off) {
          await s.prefs.setWriteDefault('spellcheck', true);
        }
        await d.spellcheck.whenSettled();
        d.spellcheck.checkAllNow();
        if (!c.mounted) return const CommandResult.cancelled();
        await showSpellingDialog(
          c,
          spellcheck: d.spellcheck,
          controller: d.editor,
          commands: d.commands,
          addToDictionary: (w) => addToPersonalDictionary(s, d, w),
        );
        d.focusEditor();
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.spell.personalDictionary',
      label: 'Personal dictionary…',
      categoryName: 'Tools',
      run: (ctx, d, a) async {
        final c = ctx.dialogContext;
        if (c == null) return const CommandResult.failed('No window');
        await showPersonalDictionaryDialog(
          c,
          words: () => d.personalDictionary,
          onAdd: (w) => addToPersonalDictionary(s, d, w),
          onRemove: (w) => s.prefs.setWriteDefault('personalDictionary', [
            for (final x in d.personalDictionary)
              if (x != w) x,
          ]),
        );
        return const CommandResult.ok();
      },
    ),
  ];
}

/// Adds [word] to the synced personal dictionary (max 10,000 words).
Future<void> addToPersonalDictionary(
  ShellServices s,
  WriteDocumentController d,
  String word,
) async {
  final words = d.personalDictionary;
  if (words.contains(word)) return;
  if (words.length >= 10000) {
    s.toasts.error('Your personal dictionary is full (10,000 words)');
    return;
  }
  d.spellcheck.wordAdded(word);
  await s.prefs.setWriteDefault('personalDictionary', [...words, word]);
}

/// The spelling section at the top of the canvas context menu (Write 04
/// §28.2): suggestions for the misspelled word at the caret, Ignore, Add to
/// dictionary.
List<WonkyMenuEntry> spellingMenuEntries(
  WriteDocumentController d,
  void Function(String id, Map<String, Object?> args) run,
) {
  final sel = d.editor.selection;
  if (sel == null || !d.editable) return const [];
  final error = d.spellcheck.errorAt(sel.start);
  if (error == null) return const [];
  final suggestions = d.spellcheck.suggestionsFor(error.word);
  return [
    if (suggestions.isEmpty)
      const WonkyMenuLabel('No spelling suggestions')
    else
      for (var i = 0; i < suggestions.length; i += 1)
        WonkyMenuItem(
          key: ValueKey<String>('menu.spell.suggestion.$i'),
          label: suggestions[i],
          icon: i == 0 ? LucideIcons.spellCheck : null,
          onSelected: () => run('write.spell.replace', {
            'start': error.start,
            'length': error.length,
            'word': suggestions[i],
          }),
        ),
    WonkyMenuItem(
      key: const ValueKey<String>('menu.spell.ignore'),
      label: 'Ignore',
      onSelected: () => run('write.spell.ignore', {'word': error.word}),
    ),
    WonkyMenuItem(
      key: const ValueKey<String>('menu.spell.add'),
      label: 'Add “${error.word}” to dictionary',
      onSelected: () =>
          run('write.spell.addToDictionary', {'word': error.word}),
    ),
    const WonkyMenuSeparator(),
  ];
}

/// Overrides of catalog commands (merged into `editorCommands`).
Map<String, WriteRun Function(EditorCommandSpec spec)> extrasOverrides(
  ShellServices s,
) => {
  // Without a character (menus, palette) the dialog opens (Write 04 §20.2).
  'write.insert.specialCharacter': (spec) => (ctx, d, a) async {
    if (a.string('char') != null) return runSpec(spec, d, a);
    final c = ctx.dialogContext;
    if (c == null) return const CommandResult.failed('char is required');
    var inserted = 0;
    await showSpecialCharactersDialog(
      c,
      store: s.userStore,
      onInsert: (char) {
        if (d.commands.insertText(char, label: 'Insert special character')) {
          inserted += 1;
        }
      },
    );
    d.focusEditor();
    return inserted > 0
        ? const CommandResult.ok()
        : const CommandResult.cancelled();
  },
};

EmojiPrefs? _emojiPrefs;
LocalStore? _emojiPrefsStore;

/// The per-user emoji preferences (recents, skin tone).
EmojiPrefs emojiPrefsOf(ShellServices s) {
  if (_emojiPrefs == null || !identical(_emojiPrefsStore, s.userStore)) {
    _emojiPrefsStore = s.userStore;
    _emojiPrefs = EmojiPrefs(s.userStore);
    unawaited(_emojiPrefs!.load());
  }
  return _emojiPrefs!;
}

Rect? _caretAnchor(WriteDocumentController d) {
  final s = d.editor.selection;
  return s == null ? null : d.globalRectForOffset(s.end);
}

/// The `:` emoji trigger's suggestions (Write 04 §20.1); empty until the
/// catalog is loaded (it loads on the first query).
EmojiSuggester emojiSuggester(ShellServices s) {
  EmojiCatalog? catalog;
  var loading = false;
  return (query) {
    final c = catalog;
    if (c == null) {
      if (!loading) {
        loading = true;
        unawaited(
          EmojiCatalog.load().then((value) => catalog = value).catchError((
            Object _,
          ) {
            loading = false;
            return EmojiCatalog.fromJson('{"categories":[],"emoji":[]}');
          }),
        );
      }
      return const [];
    }
    final tone = emojiPrefsOf(s).skinTone;
    final q = query.toLowerCase();
    return [
      for (final e in c.search(q, limit: 8))
        EmojiSuggestion(
          emoji: e.withSkinTone(tone),
          name: e.name,
          shortcode:
              e.shortcodes.where((x) => x.startsWith(q)).firstOrNull ??
              e.shortcodes.firstOrNull,
        ),
    ];
  };
}

/// Files dropped onto the canvas before block [index] (Write 04 §24):
/// images upload, documents import after a confirmation, anything else is
/// refused with a toast.
Future<void> handleDroppedFiles(
  ShellServices s,
  WriteDocumentController d,
  List<DroppedFile> files,
  int index, {
  BuildContext? context,
}) async {
  if (!d.editable || files.isEmpty) return;
  final images = <PickedImage>[];
  final documents = <DroppedFile>[];
  for (final f in files) {
    if (writeImportExtensions.contains(f.extension) &&
        !ImageRules.extensions.contains(f.extension)) {
      documents.add(f);
      continue;
    }
    try {
      final mime = ImageRules.validate(f.name, f.bytes);
      images.add(PickedImage(name: f.name, bytes: f.bytes, mimeType: mime));
    } on ImageRejected catch (e) {
      s.toasts.error(
        ImageRules.extensions.contains(f.extension) || f.extension == 'svg'
            ? e.message
            : 'Can’t insert this file type',
        description: f.name,
      );
    }
  }
  if (images.isNotEmpty) {
    final values = [
      for (final p in images.take(20))
        {
          'image': {
            'id': d.editor.newEmbedId(),
            'src': d.images.startUpload(p),
            'alt': '',
          },
        },
    ];
    final lines = Delta();
    for (final v in values) {
      lines
        ..insert(v)
        ..insert('\n');
    }
    final change = d.commands.insertBlocksAt(
      index,
      lines,
      label: values.length == 1 ? 'Insert image' : 'Insert images',
    );
    if (change == null) {
      for (final v in values) {
        d.images.cancel('${(v['image'] as Map)['src']}');
      }
    }
  }
  for (final f in documents.take(1)) {
    final c = context;
    if (c == null || !c.mounted) return;
    final ok = await confirmDialog(
      c,
      title: 'Insert contents of “${f.name}” here?',
      confirmLabel: 'Insert',
    );
    if (!ok) continue;
    try {
      final converted = await convertImport(
        f.name,
        f.bytes,
        uploadImage: importImageUploader(s, itemUuid: d.itemUuid),
      );
      var delta = converted.result.delta;
      final last = delta.isEmpty ? null : delta.last.data;
      if (last is! String || !last.endsWith('\n')) {
        delta = delta.compose(Delta()..retain(delta.length)..insert('\n'));
      }
      d.commands.insertBlocksAt(index, delta, label: 'Insert file');
      if (converted.warnings.isNotEmpty) {
        s.toasts.show(
          'Inserted “${f.name}”',
          description: converted.warnings.take(5).join('\n'),
        );
      }
    } catch (e) {
      s.toasts.error('Couldn’t insert “${f.name}”', description: '$e');
    }
  }
  d.focusEditor();
}
