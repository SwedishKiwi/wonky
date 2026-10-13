import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show BuiltinThemes;

/// Menu ids of the Write menus (stable: used by MCP `ui.get_menu_tree`).
abstract final class WriteMenuIds {
  static const insert = 'insert';
  static const format = 'format';
  static const tablePicker = 'insert.table.picker';
}

MenuCommand _c(
  String id, {
  String? label,
  Map<String, Object?> args = const {},
  String? menuId,
  bool radio = false,
}) => MenuSpec.command(id, label: label, args: args, id: menuId, radio: radio);

/// The Write menubar (Write 05 §7): the shell's shared menus extended with
/// Write items, plus the Insert and Format menus.
MenuRoot writeMenus(ShellMenus shell) {
  var root = shell.root;

  // ---- File (§7.1) ----
  root = root
      .insertAfter('shell.file.import', [
        _c('write.insert.fromFile', label: 'Insert from file…'),
      ])
      .replace('shell.file.details', [
        _c('write.doc.properties', label: 'Details'),
      ])
      .insertAfter(ShellMenuIds.fileEndOfVersions, [
        _c('write.doc.languageDialog', label: 'Language…'),
        _c('write.doc.pageSetup', label: 'Page setup…'),
        _c('write.doc.settings', label: 'Settings…'),
        MenuSpec.separator(),
      ]);

  // ---- Edit (§7.2) ----
  root = root
      .insertAfter('shell.edit.pasteWithoutFormatting', [
        MenuSpec.submenu('edit.copyAs', 'Copy as', [
          _c('write.edit.copyAsMarkdown', label: 'Markdown'),
          _c('write.edit.copyAsPlainText', label: 'Plain text'),
          _c('write.edit.copyAsHtml', label: 'HTML'),
        ]),
        _c('write.edit.pasteAsMarkdown', label: 'Paste as Markdown'),
      ])
      .insertAfter('shell.edit.selectAll', [_c('write.edit.delete')])
      .appendTo(ShellMenuIds.edit, [
        MenuSpec.separator(),
        _c('write.find.open', label: 'Find'),
        _c('write.find.openReplace', label: 'Find and replace'),
        _c('write.find.next'),
        _c('write.find.previous'),
        _c('write.nav.goToHeading'),
      ]);

  // ---- View (§7.3) ----
  root = root
      .appendTo(ShellMenuIds.viewMode, [
        _c('write.mode.editing', label: 'Editing', radio: true),
        _c('write.mode.suggesting', label: 'Suggesting', radio: true),
        _c('write.mode.viewing', label: 'Viewing', radio: true),
      ])
      .insertAfter(ShellMenuIds.viewMode, [
        MenuSpec.submenu('view.layout', 'Page layout', [
          _c(
            'write.doc.setLayout',
            label: 'Pages',
            args: {'layout': 'pages'},
            menuId: 'view.layout.pages',
            radio: true,
          ),
          _c(
            'write.doc.setLayout',
            label: 'Pageless',
            args: {'layout': 'pageless'},
            menuId: 'view.layout.pageless',
            radio: true,
          ),
        ]),
        MenuSpec.submenu('view.suggestions', 'Suggestions', [
          _c(
            'write.view.suggestionPreview',
            label: 'Show suggestions',
            args: {'mode': 'show'},
            menuId: 'view.suggestions.show',
          ),
          _c(
            'write.view.suggestionPreview',
            label: 'Preview accepted',
            args: {'mode': 'accepted'},
            menuId: 'view.suggestions.accepted',
          ),
          _c(
            'write.view.suggestionPreview',
            label: 'Preview original',
            args: {'mode': 'original'},
            menuId: 'view.suggestions.original',
          ),
        ]),
        // View-only preview of another theme (Write 06 §5.2).
        MenuSpec.submenu('view.previewTheme', 'Preview theme', [
          _c(
            'write.theme.previewLocal',
            label: 'Document theme',
            args: {'themeUuid': null},
            menuId: 'view.previewTheme.none',
            radio: true,
          ),
          MenuSpec.separator(),
          for (final b in BuiltinThemes.all)
            _c(
              'write.theme.previewLocal',
              label: b.name,
              args: {'themeUuid': b.uuid},
              menuId: 'view.previewTheme.${b.key}',
              radio: true,
            ),
        ]),
      ])
      .appendTo(ShellMenuIds.viewShow, [
        _c('write.view.toggleWordCount', label: 'Word count'),
        _c('write.view.toggleCommentMargin', label: 'Comments in margin'),
        _c('write.view.toggleRemoteCursors', label: 'Collaborator cursors'),
        _c('write.view.toggleSelectionToolbar', label: 'Toolbar on selection'),
      ])
      .insertAfter('view.layout', [
        _c('write.view.toggleFocusMode', label: 'Focus mode'),
        _c('write.view.toggleTypewriter', label: 'Typewriter scrolling'),
      ])
      .replace(ShellMenuIds.viewZoom, [
        MenuSpec.submenu(ShellMenuIds.viewZoom, 'Zoom', [
          _c('write.view.zoomIn'),
          _c('write.view.zoomOut'),
          MenuSpec.separator(),
          for (final p in const [50, 75, 90, 100, 125, 150, 200])
            _c(
              'shell.view.zoom',
              label: '$p%',
              args: {'percent': p},
              menuId: 'view.zoom.$p',
              radio: true,
            ),
          MenuSpec.separator(),
          _c(
            'write.view.zoomFit',
            label: 'Fit width',
            args: {'mode': 'width'},
            menuId: 'view.zoom.fitWidth',
          ),
          _c(
            'write.view.zoomFit',
            label: 'Fit page',
            args: {'mode': 'page'},
            menuId: 'view.zoom.fitPage',
          ),
          _c('write.view.zoomReset', label: 'Reset to 100%'),
        ]),
      ])
      .insertBefore('shell.comments.togglePanel', [
        _c('write.view.toggleOutline', label: 'Outline'),
      ])
      .insertAfter('shell.comments.togglePanel', [
        _c(
          'write.suggestions.togglePanel',
          label: 'Suggestions',
          menuId: 'view.panels.suggestions',
        ),
      ])
      .appendTo(ShellMenuIds.viewPanels, [
        _c(
          'write.find.open',
          label: 'Find and replace',
          menuId: 'view.panels.find',
        ),
      ]);

  // ---- Insert (§7.4) and Format (§7.5) ----
  root = root.insertMenusBefore(ShellMenuIds.tools, [insertMenu, formatMenu]);

  // ---- Tools (§7.6) ----
  root = root
      .insertAfter('tools.assistant', [
        _c('write.ai.summarizeDocument', menuId: 'tools.ai.summarize'),
        _c('write.ai.generateOutline', menuId: 'tools.ai.outline'),
        _c('write.ai.proofreadDocument', menuId: 'tools.ai.proofread'),
      ])
      .insertBefore('tools.assistant', [
        _c('write.tools.wordCount', label: 'Word count'),
        _c(
          'write.doc.languageDialog',
          label: 'Language…',
          menuId: 'tools.language',
        ),
        _c('write.tools.viewMarkdown', label: 'View Markdown source'),
        MenuSpec.separator(),
      ])
      .insertBefore('tools.preferences', [
        MenuSpec.submenu('tools.writePrefs', 'Preferences', [
          _c('write.prefs.setMarkdownShortcuts'),
          _c('write.prefs.setSmartTypography'),
          _c('write.prefs.setAutoPair'),
          _c('write.prefs.setAutolink'),
          _c('write.prefs.setCopyAsMarkdown'),
          _c('write.prefs.setSelectionToolbar'),
          MenuSpec.separator(),
          _c(
            'shell.settings.open',
            label: 'All preferences…',
            args: {'section': 'write'},
            menuId: 'tools.writePrefs.all',
          ),
        ]),
      ])
      .remove('tools.preferences');

  // ---- Help (§7.7) ----
  root = root.insertAfter('shell.help.open', [_c('write.help.markdownGuide')]);
  return root;
}

/// Insert (Write 05 §7.4).
MenuSubmenu get insertMenu => MenuSpec.submenu(WriteMenuIds.insert, 'Insert', [
  MenuSpec.submenu('insert.image', 'Image', [
    _c('write.insert.image', label: 'Upload from computer…'),
    _c('write.insert.imageFromUrl', label: 'By URL…'),
  ]),
  MenuSpec.submenu('insert.table', 'Table', [
    MenuSpec.custom(WriteMenuIds.tablePicker, label: 'Table size'),
    MenuSpec.separator(),
    _c('write.insert.tableDialog', label: 'Custom size…'),
  ]),
  _c('write.insert.divider', label: 'Divider (horizontal line)'),
  _c(
    'write.format.blockType.codeBlock',
    label: 'Code block',
    menuId: 'insert.codeBlock',
  ),
  _c('write.format.blockType.quote', label: 'Quote', menuId: 'insert.quote'),
  _c(
    'write.list.toggleChecklist',
    label: 'Checklist',
    menuId: 'insert.checklist',
  ),
  MenuSpec.separator(),
  _c('write.link.insert', label: 'Link…'),
  _c('write.insert.mentionTrigger', label: 'Mention a person'),
  _c('write.insert.emoji', label: 'Emoji…'),
  _c('write.insert.specialCharacter', label: 'Special characters…'),
  MenuSpec.separator(),
  _c('shell.comments.create', label: 'Comment', menuId: 'insert.comment'),
  _c('write.insert.fromFile', label: 'From file…', menuId: 'insert.fromFile'),
]);

/// Format (Write 05 §7.5).
MenuSubmenu get formatMenu => MenuSpec.submenu(WriteMenuIds.format, 'Format', [
  MenuSpec.submenu('format.text', 'Text', [
    _c('write.format.bold'),
    _c('write.format.italic'),
    _c('write.format.strikethrough'),
    _c('write.format.inlineCode', label: 'Code'),
  ]),
  MenuSpec.submenu('format.styles', 'Paragraph styles', [
    _c('write.format.blockType.paragraph', label: 'Normal text', radio: true),
    for (var i = 1; i <= 6; i++)
      _c('write.format.blockType.heading$i', label: 'Heading $i', radio: true),
    _c('write.format.blockType.quote', label: 'Quote', radio: true),
    _c('write.format.blockType.codeBlock', label: 'Code block', radio: true),
  ]),
  MenuSpec.submenu('format.lists', 'Bullets & numbering', [
    _c('write.list.toggleBulleted', label: 'Bulleted list'),
    _c('write.list.toggleNumbered', label: 'Numbered list'),
    _c('write.list.toggleChecklist', label: 'Checklist'),
    MenuSpec.separator(),
    _c('write.list.indent', label: 'Increase indent'),
    _c('write.list.outdent', label: 'Decrease indent'),
    _c('write.list.toggleChecked', label: 'Mark as done / not done'),
  ]),
  MenuSpec.submenu('format.link', 'Link', [
    _c(
      'write.link.insert',
      label: 'Insert or edit link…',
      menuId: 'format.link.insert',
    ),
    _c('write.link.remove', label: 'Remove link'),
  ]),
  _c('write.format.clearFormatting'),
  MenuSpec.separator(),
  MenuSpec.submenu('format.table', 'Table', [
    _c('write.table.editCell', label: 'Edit cells'),
    _c('write.table.edit', label: 'Edit table…'),
    _c('write.table.copyAsTsv', label: 'Copy as TSV'),
    _c('write.table.delete', label: 'Delete table'),
  ]),
  MenuSpec.submenu('format.image', 'Image', [
    _c('write.image.preview', label: 'View full size'),
    _c('write.image.editAlt', label: 'Alt text…'),
    _c('write.image.replace', label: 'Replace…'),
    _c('write.image.download', label: 'Download'),
  ]),
  MenuSpec.submenu('format.code', 'Code block', [
    _c('write.code.copy', label: 'Copy code'),
    _c('write.code.exit', label: 'Exit code block'),
  ]),
  MenuSpec.separator(),
  MenuSpec.submenu('format.theme', 'Theme', [
    for (final b in BuiltinThemes.all)
      _c(
        'write.theme.apply',
        label: b.name,
        args: {'themeId': b.uuid},
        menuId: 'format.theme.${b.key}',
        radio: true,
      ),
    _c(
      'write.theme.useDefault',
      label: 'Use my default theme',
      menuId: 'format.theme.useDefault',
      radio: true,
    ),
    MenuSpec.separator(),
    _c('write.theme.openPicker', label: 'More themes…'),
    _c('write.theme.openEditor', label: 'Customize theme…'),
    _c('write.theme.openManager', label: 'Manage themes…'),
    MenuSpec.separator(),
    _c('write.theme.setUserDefault', label: 'Save as my default theme'),
  ]),
  _c(
    'write.help.markdownGuide',
    label: 'What formatting is supported?',
    menuId: 'format.guide',
  ),
]);
