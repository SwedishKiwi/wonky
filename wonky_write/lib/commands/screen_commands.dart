import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_write_core/wonky_write_core.dart'
    hide DeltaSelection, ThemeCatalog;

import '../features/editor/applier/delta_applier.dart' show DeltaSelection;
import '../features/editor/commands/editor_command_catalog.dart';
import '../features/editor/commands/write_editor_commands.dart';
import '../features/editor/controller/editor_types.dart';
import '../features/editor/model/document_queries.dart';
import '../features/editor/model/table_model.dart';
import '../features/export/export_service.dart';
import '../features/images/image_dialogs.dart';
import '../features/images/image_services.dart';
import '../features/import/import_service.dart';
import '../features/links/link_editor.dart';
import '../features/screen/anchored_popover.dart';
import '../features/screen/dialogs/document_dialogs.dart';
import '../features/screen/dialogs/document_settings_dialog.dart';
import '../features/screen/dialogs/page_setup_dialog.dart';
import '../features/screen/write_document_controller.dart';
import '../features/tables/table_editor.dart';
import '../features/themes/document_theme.dart';
import '../features/themes/theme_adapter.dart';
import '../features/themes/theme_picker.dart';
import '../features/themes/write_fonts.dart';
import '../features/word_count/word_count_dialog.dart';
import 'editor_commands.dart';
import 'extras_commands.dart';
import 'write_command.dart';

const _mod = true;

/// All Write commands: the wrapped editor catalog plus the screen, file,
/// view, insert, format and tools commands of Write 05 §24 / 07 §12.
List<Command<CommandArgs>> writeCommands(
  ShellServices s,
  WriteThemeCatalog themes,
) => [
  ...editorCommands(s, overrides: {..._overrides(s), ...extrasOverrides(s)}),
  ...extrasCommands(s),
  ...fileCommands(s),
  ...findCommands(s),
  ...viewCommands(s),
  ...insertCommands(s),
  ...documentCommands(s, themes),
  ...prefCommands(s),
];

BuildContext? _ctx(CommandContext ctx) => ctx.dialogContext;

bool _ui(CommandContext ctx) => !ctx.source.isAgent;

// ---------------------------------------------------------------------------
// Overrides of catalog commands (screen behaviour on top of the editor).

Map<String, WriteRun Function(EditorCommandSpec spec)> _overrides(
  ShellServices s,
) => {
  // Without a URL (menus, toolbar) the dialog asks for it (Write 05 §12.1).
  'write.insert.imageFromUrl': (spec) => (ctx, d, a) async {
    if (a.string('url') != null) return runSpec(spec, d, a);
    final c = _ctx(ctx);
    if (c == null) return const CommandResult.failed('url is required');
    final r = await showImageUrlDialog(c);
    if (r == null) return const CommandResult.cancelled();
    d.focusEditor();
    return runSpec(spec, d, JsonArgs({'url': r.url, 'alt': r.alt}));
  },
  // Inserting from the UI opens the table editor on the new table (04 §18.3).
  'write.insert.table': (spec) => (ctx, d, a) async {
    final r = await runSpec(spec, d, a);
    final c = _ctx(ctx);
    final data = r.data;
    if (r.isOk && _ui(ctx) && c != null && data is Map) {
      final id = data['id'] as String?;
      // In-place cell editing (SE-4) starts on the first cell; without it
      // the table editor opens.
      final inline = d.editor.tableEditing;
      if (id != null && inline != null) {
        scheduleMicrotask(() => inline.activate(id, 0, 0, selectAll: true));
      } else if (id != null) {
        scheduleMicrotask(() {
          if (c.mounted) {
            unawaited(_editTable(c, d, nodeId: id, label: 'Insert table'));
          }
        });
      }
    }
    return r;
  },
  // Modes are clamped to the role (Write 04 §31).
  'write.mode.set': (spec) => (ctx, d, a) {
    final mode = EditorMode.values
        .where((m) => m.name == a.string('mode'))
        .firstOrNull;
    if (mode == null) return const CommandResult.failed('Unknown mode');
    if (!d.session.canUseMode(mode)) {
      return CommandResult.failed(
        mode == EditorMode.editing
            ? 'You need edit access to edit directly'
            : 'You need comment access to suggest',
      );
    }
    d.session.setMode(mode);
    d.focusEditor();
    return const CommandResult.ok();
  },
};

Future<CommandResult> _editTable(
  BuildContext context,
  WriteDocumentController d, {
  String? nodeId,
  int row = 0,
  int col = 0,
  String label = 'Edit table',
}) async {
  final data = d.embedData('table', nodeId);
  if (data == null) return const CommandResult.failed('No table selected');
  final table = TableModel.fromEmbed(data);
  final edited = await showTableEditor(context, table, row: row, column: col);
  d.focusEditor();
  if (edited == null) return const CommandResult.cancelled();
  return okIf(d.commands.replaceTable(edited, nodeId: table.id));
}

// ---------------------------------------------------------------------------
// File (Write 05 §7.1, 07 §12).

List<Command<CommandArgs>> fileCommands(ShellServices s) => [
  WriteCommand(
    'write.file.download',
    label: 'Download',
    categoryName: 'File',
    argsSchema: JsonSchema.object(
      properties: {
        'format': JsonSchema.string(
          enumValues: [for (final f in WriteDownloadFormat.values) f.id],
        ),
        'options': const JsonSchema.object(properties: {}),
      },
      required: const ['format'],
    ),
    enabled: (d, a) => d.copyAllowed,
    reason: (d, a) => d.copyAllowed ? null : 'The owner turned off downloads',
    run: (ctx, d, a) async {
      final f = WriteDownloadFormat.tryParse(a.string('format'));
      if (f == null) return const CommandResult.failed('Unknown format');
      final o = a.values['options'];
      final ok = await d.downloadAs(
        f,
        options: o is Map
            ? WriteExportOptions.fromJson(Map<String, Object?>.from(o))
            : const WriteExportOptions(),
      );
      return ok ? const CommandResult.ok() : const CommandResult.cancelled();
    },
  ),
  WriteCommand(
    'write.file.print',
    label: 'Print',
    categoryName: 'File',
    enabled: (d, a) => d.copyAllowed,
    run: (ctx, d, a) async {
      await d.print();
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.insert.fromFile',
    label: 'Insert from file…',
    categoryName: 'Insert',
    requiredRole: Role.commenter,
    isUndoable: true,
    needsEditable: true,
    descriptionText:
        'Insert a Markdown, text, HTML, Word, OpenDocument or RTF file at the cursor',
    run: (ctx, d, a) async {
      final files = await pickImportFiles(multiple: false);
      if (files.isEmpty) return const CommandResult.cancelled();
      final f = files.single;
      try {
        final converted = await convertImport(
          f.name,
          Uint8List.fromList(f.bytes),
          uploadImage: importImageUploader(s, itemUuid: d.itemUuid),
        );
        final change = d.commands.insertFragment(
          converted.result.delta,
          label: 'Insert file',
        );
        if (converted.warnings.isNotEmpty) {
          s.toasts.show(
            'Inserted “${f.name}”',
            description: converted.warnings.take(5).join('\n'),
          );
        }
        return okIf(change != null);
      } catch (e) {
        return CommandResult.failed(errorMessage(e));
      }
    },
  ),
];

// ---------------------------------------------------------------------------
// Find and replace, navigation (Write 04 §25–26, 05 §10.5).

List<Command<CommandArgs>> findCommands(ShellServices s) {
  void openFind(
    WriteDocumentController d, {
    String? query,
    bool replace = false,
  }) {
    d.find.open(query: query ?? d.selectedText, replace: replace);
    s.panels.open(WritePanels.find);
  }

  return [
    WriteCommand(
      'write.find.open',
      label: 'Find',
      categoryName: 'Edit',
      defaultBindings: const [KeyBinding('F', mod: _mod)],
      argsSchema: const JsonSchema.object(
        properties: {'query': JsonSchema.string()},
      ),
      checked: (d, a) => s.panels.isOpen(WritePanels.find),
      run: (ctx, d, a) {
        openFind(d, query: a.string('query'));
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.find.openReplace',
      label: 'Find and replace',
      categoryName: 'Edit',
      defaultBindings: const [
        KeyBinding('H', mod: _mod, shift: true, mac: true),
        KeyBinding('H', mod: _mod, mac: false),
      ],
      run: (ctx, d, a) {
        openFind(d, replace: true);
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.find.close',
      label: 'Close find',
      categoryName: 'Edit',
      showInPalette: false,
      run: (ctx, d, a) {
        d.find.close();
        s.panels.close(WritePanels.find);
        d.focusEditor();
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.find.next',
      label: 'Find next',
      categoryName: 'Edit',
      defaultBindings: const [
        KeyBinding('G', mod: _mod),
        KeyBinding('F3', mac: false),
      ],
      enabled: (d, a) => d.find.hasQuery,
      run: (ctx, d, a) {
        if (!d.find.isActive) openFind(d, query: d.find.query);
        d.find.next();
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.find.previous',
      label: 'Find previous',
      categoryName: 'Edit',
      defaultBindings: const [
        KeyBinding('G', mod: _mod, shift: true),
        KeyBinding('F3', shift: true, mac: false),
      ],
      enabled: (d, a) => d.find.hasQuery,
      run: (ctx, d, a) {
        if (!d.find.isActive) openFind(d, query: d.find.query);
        d.find.previous();
        return const CommandResult.ok();
      },
    ),
    WriteCommand(
      'write.find.replace',
      label: 'Replace',
      categoryName: 'Edit',
      requiredRole: Role.commenter,
      isUndoable: true,
      needsEditable: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'replacement': JsonSchema.string(),
          'query': JsonSchema.string(),
        },
      ),
      enabled: (d, a) => d.find.hasQuery || a.string('query') != null,
      run: (ctx, d, a) {
        final q = a.string('query');
        if (q != null) d.find.open(query: q);
        final r = a.string('replacement');
        if (r != null) d.find.replacement = r;
        return okIf(d.find.replace(), 'No match to replace');
      },
    ),
    WriteCommand(
      'write.find.replaceAll',
      label: 'Replace all',
      categoryName: 'Edit',
      requiredRole: Role.commenter,
      isUndoable: true,
      needsEditable: true,
      defaultBindings: const [KeyBinding('Enter', mod: _mod, alt: true)],
      keyScope: KeyScope.global,
      argsSchema: const JsonSchema.object(
        properties: {
          'replacement': JsonSchema.string(),
          'query': JsonSchema.string(),
          'matchCase': JsonSchema.boolean(),
          'wholeWord': JsonSchema.boolean(),
          'regex': JsonSchema.boolean(),
        },
      ),
      enabled: (d, a) => d.find.hasQuery || a.string('query') != null,
      run: (ctx, d, a) {
        final f = d.find;
        final q = a.string('query');
        if (q != null) {
          f
            ..matchCase = a.boolean('matchCase', false)!
            ..wholeWord = a.boolean('wholeWord', false)!
            ..regex = a.boolean('regex', false)!
            ..open(query: q);
        }
        final r = a.string('replacement');
        if (r != null) f.replacement = r;
        final n = f.replaceAll();
        if (n == 0) return const CommandResult.failed('No matches');
        if (_ui(ctx)) {
          s.toasts.show(
            'Replaced $n ${n == 1 ? 'occurrence' : 'occurrences'}',
            actionLabel: 'Undo',
            onAction: () => unawaited(
              s.dispatcher.invoke(
                'shell.edit.undo',
                source: InvocationSource.ui,
              ),
            ),
          );
        }
        return CommandResult.ok({'replaced': n});
      },
    ),
    WriteCommand(
      'write.nav.goToHeading',
      label: 'Go to heading…',
      categoryName: 'Navigation',
      defaultBindings: const [KeyBinding('G', mod: _mod, alt: true)],
      argsSchema: const JsonSchema.object(
        properties: {
          'index': JsonSchema.integer(minimum: 0),
          'text': JsonSchema.string(),
        },
      ),
      enabled: (d, a) => d.insights.outline.isNotEmpty,
      run: (ctx, d, a) async {
        final outline = d.insights.outline;
        var index = a.integer('index');
        final text = a.string('text');
        if (index == null && text != null) {
          index = outline.indexWhere(
            (e) => e.text.toLowerCase().contains(text.toLowerCase()),
          );
          if (index < 0) return const CommandResult.failed('No such heading');
        }
        if (index == null) {
          final c = _ctx(ctx);
          if (c == null) return const CommandResult.failed('index is required');
          final e = await showGoToHeadingDialog(c, outline);
          if (e == null) return const CommandResult.cancelled();
          index = e.index;
        }
        return okIf(d.goToHeading(index), 'No such heading');
      },
    ),
  ];
}

// ---------------------------------------------------------------------------
// View (Write 05 §7.3, local prefs, not undoable).

List<Command<CommandArgs>> viewCommands(ShellServices s) => [
  WriteCommand(
    'write.view.toggleOutline',
    label: 'Outline',
    categoryName: 'View',
    defaultBindings: const [KeyBinding('O', mod: _mod, alt: true, shift: true)],
    checked: (d, a) => s.panels.isOpen(WritePanels.outline),
    run: (ctx, d, a) {
      s.panels.toggle(WritePanels.outline);
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.view.toggleWordCount',
    label: 'Word count',
    categoryName: 'View',
    checked: (d, a) => d.viewPrefs.showWordCount,
    run: (ctx, d, a) {
      d.viewPrefs.showWordCount = !d.viewPrefs.showWordCount;
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.view.toggleCommentMargin',
    label: 'Comments in margin',
    categoryName: 'View',
    checked: (d, a) => d.viewPrefs.showCommentMargin,
    run: (ctx, d, a) {
      d.viewPrefs.showCommentMargin = !d.viewPrefs.showCommentMargin;
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.view.toggleSelectionToolbar',
    label: 'Toolbar on selection',
    categoryName: 'View',
    showInPalette: false,
    checked: (d, a) => d.viewPrefs.showSelectionToolbar,
    run: (ctx, d, a) {
      d.viewPrefs.showSelectionToolbar = !d.viewPrefs.showSelectionToolbar;
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.view.focusToolbar',
    label: 'Focus the toolbar',
    categoryName: 'View',
    defaultBindings: const [
      KeyBinding('F10', alt: true),
      KeyBinding('.', mod: _mod, alt: true),
    ],
    run: (ctx, d, a) {
      d.focusToolbar?.call();
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.view.zoomFit',
    label: 'Fit',
    categoryName: 'View',
    argsSchema: const JsonSchema.object(
      properties: {
        'mode': JsonSchema.string(enumValues: ['width', 'page']),
      },
      required: ['mode'],
    ),
    enabled: (d, a) =>
        a.string('mode') != 'page' || d.view.layout == LayoutMode.pages,
    run: (ctx, d, a) {
      final c = _ctx(ctx);
      final size = c == null ? null : MediaQuery.maybeSizeOf(c);
      if (size == null) return const CommandResult.failed('No window');
      final panel = s.panels.activePanelId == null ? 360.0 : 0.0;
      final available = size.width - 96 - (360 - panel);
      final page = d.view.pageSetup.size;
      final pages = d.view.layout == LayoutMode.pages;
      double zoom;
      if (a.string('mode') == 'page' && pages) {
        final h = size.height - 220;
        zoom = (h / page.height).clamp(0.5, 2.0);
        zoom = zoom > available / page.width ? available / page.width : zoom;
      } else {
        final width = pages ? page.width : 816.0;
        zoom = (available / width);
      }
      d.view.zoom = zoom.clamp(0.5, 2.0);
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.outline.setMaxLevel',
    label: 'Outline levels',
    categoryName: 'View',
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'level': JsonSchema.integer(minimum: 1, maximum: 6)},
      required: ['level'],
    ),
    checked: (d, a) => a.integer('level') == null
        ? null
        : d.outlineView.maxLevel == a.integer('level'),
    run: (ctx, d, a) {
      d.outlineView.maxLevel = a.integer('level')!;
      return const CommandResult.ok();
    },
  ),
  for (final (mode, label, key) in const [
    (EditorMode.editing, 'Editing mode', 'Z'),
    (EditorMode.suggesting, 'Suggesting mode', 'X'),
    (EditorMode.viewing, 'Viewing mode', 'C'),
  ])
    WriteCommand(
      'write.mode.${mode.name}',
      label: label,
      categoryName: 'View',
      defaultBindings: [KeyBinding(key, mod: _mod, alt: true, shift: true)],
      enabled: (d, a) => d.session.canUseMode(mode),
      reason: (d, a) => d.session.canUseMode(mode)
          ? null
          : mode == EditorMode.editing
          ? 'You need edit access'
          : 'You need comment access',
      checked: (d, a) => d.editor.mode == mode,
      run: (ctx, d, a) {
        d.session.setMode(mode);
        d.focusEditor();
        return const CommandResult.ok();
      },
    ),
];

// ---------------------------------------------------------------------------
// Insert, links, images, tables, code (Write 04 §11, §17, §18, 05 §7.4).

List<Command<CommandArgs>> insertCommands(ShellServices s) => [
  WriteCommand(
    'write.insert.image',
    label: 'Image',
    descriptionText: 'Upload images from your computer',
    categoryName: 'Insert',
    requiredRole: Role.commenter,
    isUndoable: true,
    needsEditable: true,
    enabled: (d, a) => d.commands.canInsertBlock(),
    run: (ctx, d, a) async {
      final picked = await pickImageFiles(
        onRejected: (name, reason) => s.toasts.error(reason, description: name),
      );
      if (picked.isEmpty) return const CommandResult.cancelled();
      return insertPickedImages(d, picked);
    },
  ),
  WriteCommand(
    'write.insert.tableDialog',
    label: 'Table…',
    descriptionText: 'Insert a table of a custom size',
    categoryName: 'Insert',
    needsEditable: true,
    requiredRole: Role.editor,
    enabled: (d, a) =>
        d.commands.canInsertBlock() && d.editor.mode == EditorMode.editing,
    run: (ctx, d, a) async {
      final c = _ctx(ctx);
      if (c == null) return const CommandResult.failed('No window');
      final size = await showTableSizeDialog(c);
      if (size == null) return const CommandResult.cancelled();
      return s.dispatcher.invoke(
        'write.insert.table',
        args: {'rows': size.rows, 'cols': size.cols},
        source: ctx.source,
        context: c.mounted ? c : null,
      );
    },
  ),
  WriteCommand(
    'write.insert.mentionTrigger',
    label: 'Mention a person',
    categoryName: 'Insert',
    requiredRole: Role.commenter,
    isUndoable: true,
    needsEditable: true,
    enabled: (d, a) => d.commands.canInsertLink(),
    run: (ctx, d, a) {
      d.focusEditor();
      return okIf(d.commands.insertText('@', label: 'Mention'));
    },
  ),
  WriteCommand(
    'write.link.insert',
    label: 'Insert link',
    categoryName: 'Insert',
    defaultBindings: const [KeyBinding('K', mod: _mod)],
    keyScope: KeyScope.editor,
    requiredRole: Role.commenter,
    isUndoable: true,
    needsEditable: true,
    enabled: (d, a) => d.commands.canInsertLink(),
    run: (ctx, d, a) => _linkEditor(ctx, d),
  ),
  WriteCommand(
    'write.link.edit',
    label: 'Edit link',
    categoryName: 'Insert',
    requiredRole: Role.commenter,
    isUndoable: true,
    needsEditable: true,
    enabled: (d, a) => d.commands.linkAt() != null,
    run: (ctx, d, a) => _linkEditor(ctx, d),
  ),
  WriteCommand(
    'write.link.open',
    label: 'Open link',
    categoryName: 'Insert',
    enabled: (d, a) => d.commands.linkAt() != null,
    run: (ctx, d, a) async {
      final link = d.commands.linkAt();
      if (link == null) return const CommandResult.failed('No link here');
      await openWriteLink(s, d, link.url, context: _ctx(ctx));
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.link.copy',
    label: 'Copy link',
    categoryName: 'Insert',
    enabled: (d, a) => d.commands.linkAt() != null,
    run: (ctx, d, a) async {
      final link = d.commands.linkAt();
      if (link == null) return const CommandResult.failed('No link here');
      await Clipboard.setData(ClipboardData(text: link.url));
      s.toasts.show('Link copied');
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.image.editAlt',
    label: 'Alt text…',
    categoryName: 'Images',
    requiredRole: Role.commenter,
    isUndoable: true,
    needsEditable: true,
    argsSchema: const JsonSchema.object(
      properties: {'nodeId': JsonSchema.string()},
    ),
    enabled: (d, a) => d.embedData('image', a.string('nodeId')) != null,
    run: (ctx, d, a) async {
      final nodeId = a.string('nodeId');
      final data = d.embedData('image', nodeId);
      final c = _ctx(ctx);
      if (data == null || c == null) {
        return const CommandResult.failed('No image selected');
      }
      final r = await showImageAltDialog(
        c,
        alt: '${data['alt'] ?? ''}',
        title: data['title'] as String?,
      );
      d.focusEditor();
      if (r == null) return const CommandResult.cancelled();
      return okIf(
        d.commands.setImageAlt(
          r.alt,
          title: r.title,
          nodeId: nodeId ?? d.block()?.id,
        ),
      );
    },
  ),
  WriteCommand(
    'write.image.replace',
    label: 'Replace image…',
    categoryName: 'Images',
    requiredRole: Role.commenter,
    isUndoable: true,
    needsEditable: true,
    argsSchema: const JsonSchema.object(
      properties: {'nodeId': JsonSchema.string()},
    ),
    enabled: (d, a) => d.embedData('image', a.string('nodeId')) != null,
    run: (ctx, d, a) async {
      final nodeId = a.string('nodeId') ?? d.block()?.id;
      final picked = await pickImageFiles(
        multiple: false,
        onRejected: (name, reason) => s.toasts.error(reason, description: name),
      );
      if (picked.isEmpty || nodeId == null) {
        return const CommandResult.cancelled();
      }
      final src = d.images.startUpload(picked.single);
      return okIf(d.commands.replaceImage(src, nodeId: nodeId));
    },
  ),
  WriteCommand(
    'write.image.download',
    label: 'Download image',
    categoryName: 'Images',
    argsSchema: const JsonSchema.object(
      properties: {'nodeId': JsonSchema.string()},
    ),
    enabled: (d, a) =>
        d.copyAllowed && d.embedData('image', a.string('nodeId')) != null,
    run: (ctx, d, a) async {
      final data = d.embedData('image', a.string('nodeId'));
      if (data == null) return const CommandResult.failed('No image selected');
      final src = '${data['src']}';
      final local = d.images.localBytes(src);
      final resolver = imageResolverFor(s, d.itemUuid.uuid);
      try {
        final bytes = local ?? (await resolver.resolve(src))?.bytes;
        if (bytes == null) {
          return const CommandResult.failed('Image unavailable');
        }
        final mime = ImageRules.sniff(bytes) ?? 'image/png';
        final ext = mime.split('/').last.replaceAll('jpeg', 'jpg');
        final alt = '${data['alt'] ?? ''}'.trim();
        await saveArtifact(
          ExportArtifact(
            fileName: '${sanitizeFileName(alt.isEmpty ? 'image' : alt)}.$ext',
            mimeType: mime,
            bytes: bytes,
          ),
        );
        return const CommandResult.ok();
      } finally {
        resolver.dispose();
      }
    },
  ),
  WriteCommand(
    'write.table.edit',
    label: 'Edit table…',
    categoryName: 'Tables',
    requiredRole: Role.editor,
    isUndoable: true,
    needsEditable: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'nodeId': JsonSchema.string(),
        'row': JsonSchema.integer(minimum: 0),
        'col': JsonSchema.integer(minimum: 0),
      },
    ),
    enabled: (d, a) => d.commands.canEditTable(nodeId: a.string('nodeId')),
    reason: (d, a) => d.editor.mode == EditorMode.suggesting
        ? "Tables can't be edited in Suggesting mode"
        : null,
    run: (ctx, d, a) async {
      final c = _ctx(ctx);
      if (c == null) return const CommandResult.failed('No window');
      return _editTable(
        c,
        d,
        nodeId: a.string('nodeId'),
        row: a.integer('row', 0)!,
        col: a.integer('col', 0)!,
      );
    },
  ),
  WriteCommand(
    'write.table.copyAsTsv',
    label: 'Copy as TSV',
    categoryName: 'Tables',
    argsSchema: const JsonSchema.object(
      properties: {'nodeId': JsonSchema.string()},
    ),
    enabled: (d, a) =>
        d.copyAllowed && d.embedData('table', a.string('nodeId')) != null,
    run: (ctx, d, a) async {
      final data = d.embedData('table', a.string('nodeId'));
      if (data == null) return const CommandResult.failed('No table selected');
      await Clipboard.setData(
        ClipboardData(text: TableModel.fromEmbed(data).toTsv()),
      );
      s.toasts.show('Table copied as tab-separated values');
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.code.copy',
    label: 'Copy code',
    categoryName: 'Code blocks',
    argsSchema: const JsonSchema.object(
      properties: {'nodeId': JsonSchema.string()},
    ),
    enabled: (d, a) =>
        d.copyAllowed &&
        d.commands.codeText(nodeId: a.string('nodeId')) != null,
    run: (ctx, d, a) async {
      final text = d.commands.codeText(nodeId: a.string('nodeId'));
      if (text == null) return const CommandResult.failed('No code block');
      await Clipboard.setData(ClipboardData(text: text));
      s.toasts.show('Code copied');
      return const CommandResult.ok();
    },
  ),
];

/// Inserts picked images as `wonky-file://` embeds (one undo step) and
/// starts their uploads (Write 04 §17.2).
CommandResult insertPickedImages(
  WriteDocumentController d,
  List<PickedImage> picked,
) {
  final images = [
    for (final p in picked)
      (src: d.images.startUpload(p), alt: '', title: null),
  ];
  final ids = d.commands.insertImages(
    images,
    label: images.length == 1 ? 'Insert image' : 'Insert images',
  );
  if (ids.isEmpty) {
    for (final i in images) {
      d.images.cancel(i.src);
    }
    return const CommandResult.failed('Images can’t be inserted here');
  }
  return CommandResult.ok({'ids': ids});
}

Future<CommandResult> _linkEditor(
  CommandContext ctx,
  WriteDocumentController d,
) async {
  final c = _ctx(ctx);
  if (c == null) return const CommandResult.failed('No window');
  final existing = d.commands.linkAt();
  var sel = d.editor.selection;
  if (existing != null && (sel == null || sel.isCollapsed)) {
    d.editor.select(DeltaSelection(existing.start, existing.end));
    sel = d.editor.selection;
  }
  if (sel == null) return const CommandResult.failed('Place the cursor first');
  final blocks = d.editor.mirror.blocksInSelection(sel);
  final single = blocks.length <= 1;
  final text = sel.isCollapsed
      ? ''
      : PlainTextRenderer.render(
          d.editor.mirror.slice(sel.start, sel.end),
        ).trimRight();
  final anchor =
      d.selectionRect() ??
      Rect.fromLTWH(MediaQuery.sizeOf(c).width / 2 - 180, 160, 1, 1);
  final services = ShellScope.of(c);
  final result = await showAnchoredPopover<LinkEdit>(
    c,
    anchor: anchor,
    width: 380,
    builder: (_) => LinkEditor(
      policy: d.commands.linkPolicy,
      headings: d.insights.outline,
      initialUrl: existing?.url,
      initialText: text,
      showText: single,
      searchDocuments: LinkEditor.driveSearch(services),
    ),
  );
  d.focusEditor();
  final range = d.editor.selection ?? sel;
  switch (result) {
    case null:
      return const CommandResult.cancelled();
    case RemoveLink():
      return okIf(
        d.commands.removeLink(
          start: range.start,
          length: range.end - range.start,
        ),
      );
    case ApplyLink(:final url, text: final newText):
      try {
        final t = newText ?? (range.isCollapsed ? null : null);
        return okIf(
          d.commands.setLink(
            url,
            text: t ?? (range.isCollapsed ? null : null),
            start: range.start,
            length: range.end - range.start,
          ),
        );
      } on EditorCommandError catch (e) {
        return CommandResult.failed(e.message);
      }
  }
}

/// Opens a link from the document (Write 04 §11.6): internal document links
/// navigate in the same window, heading links scroll, others ask first.
Future<void> openWriteLink(
  ShellServices s,
  WriteDocumentController d,
  String url, {
  BuildContext? context,
}) async {
  final doc = RegExp(
    r'^wonky://doc/([0-9a-fA-F-]{36})(?:#(.*))?$',
  ).firstMatch(url);
  if (doc != null) {
    final uuid = doc.group(1)!;
    final slug = doc.group(2);
    if (uuid == d.itemUuid.uuid) {
      if (slug != null) {
        final i = d.insights.outline.indexWhere((e) => e.anchorId == slug);
        if (i >= 0) d.goToHeading(i);
      }
      return;
    }
    s.router.go('/d/$uuid${slug == null ? '' : '?heading=$slug'}');
    return;
  }
  final sheet = RegExp(r'^wonky://sheet/([0-9a-fA-F-]{36})').firstMatch(url);
  if (sheet != null) {
    await s.openPath('/s/${sheet.group(1)}');
    return;
  }
  final c = context ?? s.navigatorContext;
  if (c == null) return;
  final uri = Uri.tryParse(url);
  final ok = await confirmDialog(
    c,
    title: 'Open external link?',
    description: uri?.host.isNotEmpty == true ? '${uri!.host}\n$url' : url,
    confirmLabel: 'Open',
  );
  if (ok) await s.crossApp.openExternal(url);
}

// ---------------------------------------------------------------------------
// Document settings, themes, tools (Write 05 §7, §12–13, 06 §11).

List<Command<CommandArgs>> documentCommands(
  ShellServices s,
  WriteThemeCatalog themes,
) => [
  WriteCommand(
    'write.doc.pageSetup',
    label: 'Page setup…',
    categoryName: 'File',
    argsSchema: const JsonSchema.object(
      properties: {
        'tab': JsonSchema.string(enumValues: ['page', 'headerFooter']),
      },
    ),
    run: (ctx, d, a) async {
      final c = _ctx(ctx);
      if (c == null) return const CommandResult.failed('No window');
      final r = await showPageSetupDialog(
        c,
        setup: d.pageSetup,
        themeMargins: d.themeMargins,
        readOnly: !d.canChangeSettings,
        initialTab: a.string('tab') == 'headerFooter' ? 1 : 0,
      );
      if (r == null || !c.mounted) return const CommandResult.cancelled();
      if (r.setAsDefault) {
        await s.prefs.setWriteDefault('pageSetup', r.setup.toJson());
      }
      return s.dispatcher.invoke(
        'write.doc.setPageSetup',
        args: {'pageSetup': r.setup.toJson()},
        source: ctx.source,
        context: c.mounted ? c : null,
      );
    },
  ),
  WriteCommand(
    'write.doc.setPageSetup',
    label: 'Change page setup',
    categoryName: 'File',
    requiredRole: Role.editor,
    isUndoable: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'pageSetup': JsonSchema.object(properties: {})},
      required: ['pageSetup'],
    ),
    enabled: (d, a) => d.canChangeSettings,
    run: (ctx, d, a) async {
      final raw = a.values['pageSetup'];
      if (raw is! Map) return const CommandResult.failed('pageSetup required');
      final setup = PageSetup.fromJson(Map<String, dynamic>.from(raw));
      final errors = setup.validate(themeMargins: d.themeMargins);
      if (errors.isNotEmpty) return CommandResult.failed(errors.join('; '));
      await d.setMeta('pageSetup', setup, label: 'Change page setup');
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.doc.setLayout',
    label: 'Page layout',
    categoryName: 'View',
    requiredRole: Role.editor,
    isUndoable: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'layout': JsonSchema.string(enumValues: ['pages', 'pageless']),
      },
      required: ['layout'],
    ),
    enabled: (d, a) => d.canChangeSettings,
    checked: (d, a) => a.string('layout') == null
        ? null
        : d.pageSetup.layout.name == a.string('layout'),
    undoLabelOf: (a) => a.string('layout') == 'pages'
        ? 'Switch to Pages'
        : 'Switch to Pageless',
    run: (ctx, d, a) async {
      final layout = a.string('layout') == 'pages'
          ? PageLayoutMode.pages
          : PageLayoutMode.pageless;
      if (d.pageSetup.layout == layout) return const CommandResult.ok();
      final json = d.pageSetup.toJson()..['layout'] = layout.name;
      await d.setMeta(
        'pageSetup',
        PageSetup.fromJson(json),
        label: layout == PageLayoutMode.pages
            ? 'Switch to Pages'
            : 'Switch to Pageless',
      );
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.doc.languageDialog',
    label: 'Language…',
    categoryName: 'File',
    requiredRole: Role.editor,
    enabled: (d, a) => d.canChangeSettings,
    run: (ctx, d, a) async {
      final c = _ctx(ctx);
      if (c == null) return const CommandResult.failed('No window');
      final tag = await showLanguageDialog(c, current: d.language);
      if (tag == null || !c.mounted) return const CommandResult.cancelled();
      return s.dispatcher.invoke(
        'write.doc.setLanguage',
        args: {'language': tag},
        source: ctx.source,
        context: c,
      );
    },
  ),
  WriteCommand(
    'write.doc.setLanguage',
    label: 'Change language',
    categoryName: 'File',
    requiredRole: Role.editor,
    isUndoable: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'language': JsonSchema.string()},
      required: ['language'],
    ),
    enabled: (d, a) => d.canChangeSettings,
    run: (ctx, d, a) async {
      await d.setMeta(
        'language',
        a.requireString('language'),
        label: 'Change language',
      );
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.doc.setFrontMatter',
    label: 'Change front matter',
    categoryName: 'File',
    requiredRole: Role.editor,
    isUndoable: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'text': JsonSchema.string()},
      required: ['text'],
    ),
    enabled: (d, a) => d.canChangeSettings,
    run: (ctx, d, a) async {
      final text = a.requireString('text').trimRight();
      await d.setMeta(
        'frontMatter',
        text.isEmpty ? null : text,
        label: 'Change front matter',
      );
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.doc.properties',
    label: 'Details',
    categoryName: 'File',
    run: (ctx, d, a) async {
      final c = _ctx(ctx);
      if (c == null) return const CommandResult.failed('No window');
      d.insights.refresh();
      final i = d.item;
      var location = 'My Drive';
      if (i?.parentUuid != null) {
        try {
          final path = await s.drive.path(i!.uuid);
          if (path.isNotEmpty) {
            location = ['My Drive', for (final p in path) p.name].join(' › ');
          }
        } catch (_) {}
      }
      if (!c.mounted) return const CommandResult.cancelled();
      final fm = await showDocumentDetailsDialog(
        c,
        item: i,
        location: location,
        words: d.insights.stats.words,
        language: languageName(d.language),
        themeName: d.documentTheme.option.name,
        revision: d.session.sync?.revision ?? 0,
        frontMatter: d.frontMatter,
        canEdit: d.canChangeSettings,
      );
      if (fm == null || !c.mounted) return const CommandResult.cancelled();
      return s.dispatcher.invoke(
        'write.doc.setFrontMatter',
        args: {'text': fm},
        source: ctx.source,
        context: c,
      );
    },
  ),
  WriteCommand(
    'write.doc.settings',
    label: 'Settings…',
    descriptionText: 'Document language, layout, theme and page setup',
    categoryName: 'File',
    argsSchema: const JsonSchema.object(
      properties: {
        'tab': JsonSchema.string(
          enumValues: ['general', 'theme', 'pageSetup', 'markdown'],
        ),
      },
    ),
    run: (ctx, d, a) async {
      final c = _ctx(ctx);
      if (c == null) return const CommandResult.failed('No window');
      await showDocumentSettingsDialog(c, d, tab: a.string('tab'));
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.theme.openPicker',
    label: 'Choose theme…',
    categoryName: 'Format',
    run: (ctx, d, a) async {
      final c = _ctx(ctx);
      if (c == null) return const CommandResult.failed('No window');
      unawaited(themes.loadMine());
      for (final o in WriteThemeCatalog.builtins) {
        for (final v in ThemeVariant.values) {
          unawaited(
            WriteFonts.ensureLoaded(
              EditorThemeAdapter.screenFamilies(
                ThemeResolver.instance.resolve(o.data, v),
              ),
            ),
          );
        }
      }
      await showThemePicker(
        c,
        catalog: themes,
        selected: d.documentTheme.selectedUuid,
        readOnly: !d.canChangeSettings,
        onSelect: (o) => unawaited(
          s.dispatcher.invoke(
            'write.theme.apply',
            args: {'themeId': o.uuid},
            source: InvocationSource.ui,
          ),
        ),
        onSetDefault: () => unawaited(
          s.dispatcher.invoke(
            'write.theme.setUserDefault',
            source: InvocationSource.ui,
          ),
        ),
        onCustomize: () => unawaited(
          s.dispatcher.invoke(
            'write.theme.openEditor',
            source: InvocationSource.ui,
          ),
        ),
        onNewTheme: () => unawaited(
          s.dispatcher.invoke(
            'write.theme.create',
            args: {'fromThemeUuid': d.documentTheme.option.uuid},
            source: InvocationSource.ui,
            context: c,
          ),
        ),
      );
      d.focusEditor();
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.theme.apply',
    label: 'Apply theme',
    categoryName: 'Format',
    requiredRole: Role.editor,
    isUndoable: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'themeId': JsonSchema.nullable(JsonSchema.string()),
        'themeUuid': JsonSchema.nullable(JsonSchema.string()),
      },
    ),
    enabled: (d, a) => d.canChangeSettings,
    checked: (d, a) {
      final id = a.string('themeId') ?? a.string('themeUuid');
      return id == null ? null : d.themeUuid == id;
    },
    run: (ctx, d, a) async {
      final id = a.string('themeId') ?? a.string('themeUuid');
      if (id == null) {
        // `null` = *Use my default theme* (Write 06 §11).
        await d.setMeta('themeId', null, label: 'Use my default theme');
        return const CommandResult.ok();
      }
      final option =
          themes.lookup(id) ??
          await themes.load(id, viaDocumentUuid: d.session.documentUuid?.uuid);
      if (option == null) return const CommandResult.failed('Unknown theme');
      if (d.themeUuid == option.uuid) return const CommandResult.ok();
      await d.setMeta('themeId', option.uuid, label: 'Change theme');
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.theme.setUserDefault',
    label: 'Save as my default theme',
    categoryName: 'Format',
    run: (ctx, d, a) async {
      final option = d.documentTheme.option;
      await s.prefs.setWriteDefault(defaultThemeKey, option.uuid);
      s.toasts.show('“${option.name}” is now your default theme');
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.tools.wordCount',
    label: 'Word count',
    categoryName: 'Tools',
    defaultBindings: const [KeyBinding('C', mod: _mod, shift: true)],
    run: (ctx, d, a) async {
      final c = _ctx(ctx);
      if (c == null) {
        return CommandResult.ok(d.insights.stats.toJson());
      }
      await showWordCountDialog(
        c,
        d,
        pageCount: d.view.layout == LayoutMode.pages ? d.pageCount.value : null,
      );
      return const CommandResult.ok();
    },
  ),
  WriteCommand(
    'write.tools.viewMarkdown',
    label: 'View Markdown source',
    categoryName: 'Tools',
    enabled: (d, a) => d.copyAllowed,
    run: (ctx, d, a) async {
      final markdown = const MarkdownCodec().exportMarkdown(
        d.editor.delta,
        frontMatter: d.frontMatter,
      );
      final c = _ctx(ctx);
      if (c == null) return CommandResult.ok({'markdown': markdown});
      await showMarkdownSourceDialog(
        c,
        markdown: markdown,
        onDownload: () => unawaited(d.downloadAs(WriteDownloadFormat.md)),
      );
      return const CommandResult.ok();
    },
  ),
  WriteGlobalCommand(
    'write.help.markdownGuide',
    label: 'Markdown & formatting guide',
    categoryName: 'Help',
    run: (ctx, a) async {
      final c = ctx.dialogContext;
      if (c != null) await showMarkdownGuide(c);
      return const CommandResult.ok();
    },
  ),
];

// ---------------------------------------------------------------------------
// Preferences (Tools › Preferences, `UserPreferences.writeDefaults`).

List<Command<CommandArgs>> prefCommands(ShellServices s) {
  WriteGlobalCommand pref(String id, String key, String label) =>
      WriteGlobalCommand(
        id,
        label: label,
        categoryName: 'Preferences',
        argsSchema: const JsonSchema.object(
          properties: {'enabled': JsonSchema.boolean()},
        ),
        checked: (ctx, a) => s.prefs.writeDefaults[key] as bool? ?? true,
        run: (ctx, a) async {
          final current = s.prefs.writeDefaults[key] as bool? ?? true;
          await s.prefs.setWriteDefault(key, a.boolean('enabled') ?? !current);
          return const CommandResult.ok();
        },
      );

  return [
    pref(
      'write.prefs.setMarkdownShortcuts',
      'markdownShortcuts',
      'Markdown shortcuts',
    ),
    pref(
      'write.prefs.setSmartTypography',
      'smartQuotes',
      'Smart quotes and dashes',
    ),
    pref('write.prefs.setAutoPair', 'autoPairBrackets', 'Auto-pair brackets'),
    pref('write.prefs.setAutolink', 'autolink', 'Automatically detect links'),
    pref(
      'write.prefs.setCopyAsMarkdown',
      'copyAsMarkdown',
      'Copy plain text as Markdown',
    ),
    pref(
      'write.prefs.setSelectionToolbar',
      'selectionToolbar',
      'Show toolbar on selection',
    ),
    WriteGlobalCommand(
      'write.prefs.setDefaultMode',
      label: 'Default mode',
      categoryName: 'Preferences',
      argsSchema: const JsonSchema.object(
        properties: {
          'mode': JsonSchema.string(
            enumValues: ['editing', 'suggesting', 'viewing'],
          ),
        },
        required: ['mode'],
      ),
      checked: (ctx, a) => a.string('mode') == null
          ? null
          : (s.prefs.writeDefaults['defaultMode'] ?? 'editing') ==
                a.string('mode'),
      run: (ctx, a) async {
        await s.prefs.setWriteDefault('defaultMode', a.requireString('mode'));
        return const CommandResult.ok();
      },
    ),
  ];
}

/// JSON-encodes [v] (helpers for tests).
String encodeMeta(Object? v) => jsonEncode(v);
