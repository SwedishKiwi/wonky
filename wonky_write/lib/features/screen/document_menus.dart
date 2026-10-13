import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../editor/commands/write_editor_commands.dart';
import '../editor/controller/editor_types.dart';
import '../../commands/extras_commands.dart' show spellingMenuEntries;
import '../editor/model/code_languages.dart';
import 'write_document_controller.dart';
import 'write_toolbar.dart';

/// Hosts programmatic menus (context menu, block menu, code language
/// picker) anchored at a global position inside the canvas.
class PopupMenuHost extends StatefulWidget {
  const PopupMenuHost({super.key, required this.child});

  final Widget child;

  static PopupMenuHostState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<PopupMenuHostState>();

  @override
  State<PopupMenuHost> createState() => PopupMenuHostState();
}

class PopupMenuHostState extends State<PopupMenuHost> {
  final _controller = ShadContextMenuController();
  Offset? _at;
  List<WonkyMenuEntry> Function()? _entries;
  VoidCallback? _onClosed;
  bool _wasOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() {
    if (_wasOpen && !_controller.isOpen) {
      final cb = _onClosed;
      _onClosed = null;
      cb?.call();
    }
    _wasOpen = _controller.isOpen;
    if (mounted) setState(() {});
  }

  /// Opens a menu of [entries] at the global [position].
  void show(
    Offset position,
    List<WonkyMenuEntry> Function() entries, {
    VoidCallback? onClosed,
  }) {
    setState(() {
      _at = position;
      _entries = entries;
      _onClosed = onClosed;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.show();
    });
  }

  void hide() => _controller.hide();

  bool get isOpen => _controller.isOpen;

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    // The menu is anchored globally, so its trigger is an empty box beside
    // the canvas rather than a wrapper around it: `ShadContextMenu` puts its
    // child in the shared context-menu tap group, and a wrapped canvas would
    // count as "inside" every other context menu (menubar menus would no
    // longer close when clicking into the document).
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          width: 0,
          height: 0,
          child: ShadContextMenu(
            controller: _controller,
            anchor: _at == null ? null : ShadGlobalAnchor(_at!),
            constraints: const BoxConstraints(minWidth: 220),
            onTapOutside: (_) => _controller.hide(),
            items: _controller.isOpen && entries != null
                ? buildWonkyMenuItems(
                    context,
                    entries(),
                    onClose: _controller.hide,
                    requestFocus: true,
                  )
                : const [SizedBox.shrink()],
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// "Turn into" entries (paragraph styles + lists).
List<WonkyMenuEntry> turnIntoEntries(CommandUi ui, BlockKind? current) => [
  ...paragraphStyleEntries(ui, current),
  const WonkyMenuSeparator(),
  for (final kind in const [
    BlockKind.bulleted,
    BlockKind.numbered,
    BlockKind.checklist,
  ])
    WonkyMenuRadioItem(
      key: ValueKey<String>('menu.turnInto.${kind.name}'),
      label: blockKindLabel(ui.l, kind),
      selected: current == kind,
      enabled: ui.state('write.format.blockType', {'type': kind.name}).enabled,
      onSelected: () => ui.run('write.format.blockType', {'type': kind.name}),
    ),
];

/// The canvas context menu for the current selection (Write 05 §6).
List<WonkyMenuEntry> contextMenuEntries(
  CommandUi ui,
  WriteDocumentController doc,
) {
  final viewing = doc.editor.mode == EditorMode.viewing;
  final sel = doc.editor.selection;
  final hasSelection = sel != null && !sel.isCollapsed;
  final link = doc.commands.linkAt();
  final kind = doc.commands.selectedBlockKind;
  final selected = doc.selectedText;
  final l = ui.l;
  final out = <WonkyMenuEntry>[
    // Suggestions for a misspelled word at the caret (Write 04 §28.2).
    ...spellingMenuEntries(doc, (id, args) => ui.run(id, args)),
  ];

  WonkyMenuEntry copyAs() => WonkyMenuSubmenu(
    label: l.menuCopyAs,
    icon: LucideIcons.clipboardCopy,
    children: [
      ui.item('write.edit.copyAsMarkdown', label: l.menuCopyAsMarkdown),
      ui.item('write.edit.copyAsPlainText', label: l.menuCopyAsPlainText),
      ui.item('write.edit.copyAsHtml', label: l.menuCopyAsHtml),
    ],
  );

  WonkyMenuEntry search() => ui.item(
    'write.find.open',
    args: {'query': ?selected},
    label: selected == null
        ? l.docMenuSearchDocument
        : l.docMenuSearchDocumentFor(
            selected.length > 24 ? '${selected.substring(0, 24)}…' : selected,
          ),
    icon: LucideIcons.search,
    keyName: 'context.search',
  );

  if (link != null) {
    out.addAll([
      ui.item('write.link.open', icon: LucideIcons.externalLink),
      ui.item('write.link.copy', icon: LucideIcons.copy),
      if (!viewing) ...[
        ui.item('write.link.edit', icon: LucideIcons.pencil),
        ui.item('write.link.remove'),
      ],
      const WonkyMenuSeparator(),
    ]);
  }

  if (viewing) {
    return [
      ...out,
      ui.item('write.edit.copy'),
      copyAs(),
      ui.item('shell.comments.create', label: l.menuComment),
      const WonkyMenuSeparator(),
      search(),
    ];
  }

  if (doc.onImage) {
    return [
      ...out,
      ui.item('write.image.preview', icon: LucideIcons.maximize),
      ui.item('write.image.editAlt'),
      ui.item('write.image.replace'),
      ui.item('write.image.download', icon: LucideIcons.download),
      const WonkyMenuSeparator(),
      ui.item('shell.comments.create', label: l.menuComment),
      ui.item('write.edit.cut'),
      ui.item('write.edit.copy'),
      ui.item('write.block.delete', label: l.docMenuDeleteImage),
      const WonkyMenuSeparator(),
      ui.item('write.block.moveUp', label: l.docMenuMoveUp),
      ui.item('write.block.moveDown', label: l.docMenuMoveDown),
    ];
  }

  if (doc.inTable) {
    return [
      ...out,
      ui.item('write.table.editCell', label: l.menuEditCells),
      ui.item('write.table.edit'),
      const WonkyMenuSeparator(),
      ui.item('write.edit.copyAsMarkdown', label: l.docMenuCopyMarkdown),
      ui.item('write.table.copyAsTsv'),
      ui.item('shell.comments.create', label: l.menuComment),
      const WonkyMenuSeparator(),
      ui.item('write.block.moveUp', label: l.docMenuMoveUp),
      ui.item('write.block.moveDown', label: l.docMenuMoveDown),
      ui.item('write.table.delete'),
    ];
  }

  if (doc.inCode) {
    out.addAll([
      WonkyMenuSubmenu(
        label: l.docMenuLanguage,
        icon: LucideIcons.code,
        children: codeLanguageEntries(ui, doc),
      ),
      ui.item('write.code.copy'),
      ui.item('write.code.exit', label: l.cmdCodeExit),
      const WonkyMenuSeparator(),
    ]);
  }

  if (hasSelection) {
    return [
      ...out,
      ui.item('write.edit.cut'),
      ui.item('write.edit.copy'),
      copyAs(),
      ui.item('write.edit.paste'),
      ui.item('write.edit.pasteWithoutFormatting'),
      const WonkyMenuSeparator(),
      ui.item('shell.comments.create', label: l.menuComment),
      ui.item(
        'write.link.insert',
        label: link == null ? l.cmdLinkInsert : l.toolbarEditLink,
      ),
      const WonkyMenuSeparator(),
      ui.item('write.format.bold'),
      ui.item('write.format.italic'),
      ui.item('write.format.strikethrough'),
      ui.item('write.format.inlineCode'),
      ui.item('write.format.clearFormatting'),
      WonkyMenuSubmenu(
        label: l.docMenuTurnInto,
        icon: LucideIcons.pilcrow,
        children: turnIntoEntries(ui, kind),
      ),
      const WonkyMenuSeparator(),
      search(),
    ];
  }

  return [
    ...out,
    ui.item('write.edit.paste'),
    ui.item('write.edit.pasteWithoutFormatting'),
    const WonkyMenuSeparator(),
    ui.item('write.link.insert'),
    ui.item('shell.comments.create', label: l.menuComment),
    const WonkyMenuSeparator(),
    WonkyMenuSubmenu(
      label: l.docMenuTurnInto,
      icon: LucideIcons.pilcrow,
      children: turnIntoEntries(ui, kind),
    ),
    WonkyMenuSubmenu(
      label: l.menuInsert,
      icon: LucideIcons.plus,
      children: [
        ui.item('write.insert.image', label: l.menuImage),
        ui.item('write.insert.imageFromUrl', label: l.docMenuImageByUrl),
        ui.item(
          'write.insert.table',
          args: {'rows': 3, 'cols': 3},
          label: l.menuTable,
          keyName: 'context.insertTable',
        ),
        ui.item('write.insert.divider'),
        ui.item(
          'write.format.blockType',
          args: {'type': 'codeBlock'},
          label: l.cmdFormatBlockTypeCodeBlock,
          keyName: 'context.codeBlock',
        ),
      ],
    ),
    const WonkyMenuSeparator(),
    ui.item('write.edit.selectAll'),
  ];
}

/// The block menu of the ⋮⋮ handle (Write 05 §8.2).
List<WonkyMenuEntry> blockMenuEntries(
  CommandUi ui,
  WriteDocumentController doc,
  String nodeId,
) {
  final block = doc.block(nodeId);
  final kind = block == null ? null : WriteEditorCommands.kindOf(block);
  final isText = block?.isText ?? false;
  final l = ui.l;
  return [
    if (isText)
      WonkyMenuSubmenu(
        label: l.docMenuTurnInto,
        icon: LucideIcons.pilcrow,
        children: turnIntoEntries(ui, kind),
      ),
    ui.item(
      'write.block.duplicate',
      args: {'nodeId': nodeId},
      label: l.docMenuDuplicate,
      keyName: 'block.duplicate',
    ),
    ui.item(
      'write.edit.copyAsMarkdown',
      label: l.cmdEditCopyAsMarkdown,
      keyName: 'block.copyMarkdown',
    ),
    ui.item(
      'shell.comments.create',
      label: l.menuComment,
      keyName: 'block.comment',
    ),
    const WonkyMenuSeparator(),
    ui.item(
      'write.block.moveUp',
      args: {'nodeId': nodeId},
      label: l.docMenuMoveUp,
      keyName: 'block.moveUp',
    ),
    ui.item(
      'write.block.moveDown',
      args: {'nodeId': nodeId},
      label: l.docMenuMoveDown,
      keyName: 'block.moveDown',
    ),
    if (doc.embedData('table', nodeId) != null) ...[
      const WonkyMenuSeparator(),
      ui.item(
        'write.table.edit',
        args: {'nodeId': nodeId},
        label: l.cmdTableEdit,
        keyName: 'block.editTable',
      ),
      ui.item(
        'write.table.copyAsTsv',
        args: {'nodeId': nodeId},
        keyName: 'block.tsv',
      ),
    ],
    if (doc.embedData('image', nodeId) != null) ...[
      const WonkyMenuSeparator(),
      ui.item(
        'write.image.preview',
        args: {'nodeId': nodeId},
        keyName: 'block.preview',
      ),
      ui.item(
        'write.image.editAlt',
        args: {'nodeId': nodeId},
        keyName: 'block.alt',
      ),
      ui.item(
        'write.image.replace',
        args: {'nodeId': nodeId},
        keyName: 'block.replace',
      ),
    ],
    const WonkyMenuSeparator(),
    ui.item(
      'write.block.delete',
      args: {'nodeId': nodeId},
      label: l.commonDelete,
      keyName: 'block.delete',
    ),
  ];
}

/// Code language entries (Write 05 §9.4).
List<WonkyMenuEntry> codeLanguageEntries(
  CommandUi ui,
  WriteDocumentController doc, {
  String? nodeId,
}) {
  final current = doc.block(nodeId)?.blockAttributes?['code-block'];
  final names = [
    for (final id in CodeLanguages.grammars.keys)
      MapEntry(id, CodeLanguages.displayName(id)),
  ]..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
  return [
    WonkyMenuRadioItem(
      key: const ValueKey<String>('menu.code.plain'),
      label: ui.l.docMenuPlainText,
      selected: current == null || current == '' || current == true,
      onSelected: () =>
          ui.run('write.code.setLanguage', {'language': '', 'nodeId': ?nodeId}),
    ),
    const WonkyMenuSeparator(),
    for (final e in names)
      WonkyMenuRadioItem(
        key: ValueKey<String>('menu.code.${e.key}'),
        label: e.value,
        selected: current == e.key,
        onSelected: () => ui.run('write.code.setLanguage', {
          'language': e.key,
          'nodeId': ?nodeId,
        }),
      ),
  ];
}
