import 'dart:async';

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

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
