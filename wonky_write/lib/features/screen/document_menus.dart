import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../editor/commands/write_editor_commands.dart';
import '../editor/controller/editor_types.dart';
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
    return ShadContextMenu(
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
      child: widget.child,
    );
  }
}

/// "Turn into" entries (paragraph styles + lists).
List<WonkyMenuEntry> turnIntoEntries(CommandUi ui, BlockKind? current) => [
  ...paragraphStyleEntries(ui, current),
  const WonkyMenuSeparator(),
  for (final (kind, label) in const [
    (BlockKind.bulleted, 'Bulleted list'),
    (BlockKind.numbered, 'Numbered list'),
    (BlockKind.checklist, 'Checklist'),
  ])
    WonkyMenuRadioItem(
      key: ValueKey<String>('menu.turnInto.${kind.name}'),
      label: label,
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
  final out = <WonkyMenuEntry>[];

  WonkyMenuEntry copyAs() => WonkyMenuSubmenu(
    label: 'Copy as',
    icon: LucideIcons.clipboardCopy,
    children: [
      ui.item('write.edit.copyAsMarkdown', label: 'Markdown'),
      ui.item('write.edit.copyAsPlainText', label: 'Plain text'),
      ui.item('write.edit.copyAsHtml', label: 'HTML'),
    ],
  );

  WonkyMenuEntry search() => ui.item(
    'write.find.open',
    args: {'query': ?selected},
    label: selected == null
        ? 'Search document'
        : 'Search document for “${selected.length > 24 ? '${selected.substring(0, 24)}…' : selected}”',
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
      ui.item('shell.comments.create', label: 'Comment'),
      const WonkyMenuSeparator(),
      search(),
    ];
  }

  if (doc.onImage) {
    return [
      ...out,
      ui.item('write.image.editAlt'),
      ui.item('write.image.replace'),
      ui.item('write.image.download', icon: LucideIcons.download),
      const WonkyMenuSeparator(),
      ui.item('shell.comments.create', label: 'Comment'),
      ui.item('write.edit.cut'),
      ui.item('write.edit.copy'),
      ui.item('write.block.delete', label: 'Delete image'),
      const WonkyMenuSeparator(),
      ui.item('write.block.moveUp', label: 'Move up'),
      ui.item('write.block.moveDown', label: 'Move down'),
    ];
  }

  if (doc.inTable) {
    return [
      ...out,
      ui.item('write.table.edit'),
      const WonkyMenuSeparator(),
      ui.item('write.edit.copyAsMarkdown', label: 'Copy (Markdown)'),
      ui.item('write.table.copyAsTsv'),
      ui.item('shell.comments.create', label: 'Comment'),
      const WonkyMenuSeparator(),
      ui.item('write.block.moveUp', label: 'Move up'),
      ui.item('write.block.moveDown', label: 'Move down'),
      ui.item('write.table.delete'),
    ];
  }

  if (doc.inCode) {
    out.addAll([
      WonkyMenuSubmenu(
        label: 'Language',
        icon: LucideIcons.code,
        children: codeLanguageEntries(ui, doc),
      ),
      ui.item('write.code.copy'),
      ui.item('write.code.exit', label: 'Exit code block'),
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
      ui.item('shell.comments.create', label: 'Comment'),
      ui.item(
        'write.link.insert',
        label: link == null ? 'Insert link' : 'Edit link',
      ),
      const WonkyMenuSeparator(),
      ui.item('write.format.bold'),
      ui.item('write.format.italic'),
      ui.item('write.format.strikethrough'),
      ui.item('write.format.inlineCode'),
      ui.item('write.format.clearFormatting'),
      WonkyMenuSubmenu(
        label: 'Turn into',
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
    ui.item('shell.comments.create', label: 'Comment'),
    const WonkyMenuSeparator(),
    WonkyMenuSubmenu(
      label: 'Turn into',
      icon: LucideIcons.pilcrow,
      children: turnIntoEntries(ui, kind),
    ),
    WonkyMenuSubmenu(
      label: 'Insert',
      icon: LucideIcons.plus,
      children: [
        ui.item('write.insert.image', label: 'Image'),
        ui.item('write.insert.imageFromUrl', label: 'Image by URL…'),
        ui.item(
          'write.insert.table',
          args: {'rows': 3, 'cols': 3},
          label: 'Table',
          keyName: 'context.insertTable',
        ),
        ui.item('write.insert.divider'),
        ui.item(
          'write.format.blockType',
          args: {'type': 'codeBlock'},
          label: 'Code block',
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
  return [
    if (isText)
      WonkyMenuSubmenu(
        label: 'Turn into',
        icon: LucideIcons.pilcrow,
        children: turnIntoEntries(ui, kind),
      ),
    ui.item(
      'write.block.duplicate',
      args: {'nodeId': nodeId},
      label: 'Duplicate',
      keyName: 'block.duplicate',
    ),
    ui.item(
      'write.edit.copyAsMarkdown',
      label: 'Copy as Markdown',
      keyName: 'block.copyMarkdown',
    ),
    ui.item(
      'shell.comments.create',
      label: 'Comment',
      keyName: 'block.comment',
    ),
    const WonkyMenuSeparator(),
    ui.item(
      'write.block.moveUp',
      args: {'nodeId': nodeId},
      label: 'Move up',
      keyName: 'block.moveUp',
    ),
    ui.item(
      'write.block.moveDown',
      args: {'nodeId': nodeId},
      label: 'Move down',
      keyName: 'block.moveDown',
    ),
    if (doc.embedData('table', nodeId) != null) ...[
      const WonkyMenuSeparator(),
      ui.item(
        'write.table.edit',
        args: {'nodeId': nodeId},
        label: 'Edit table…',
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
      label: 'Delete',
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
  final names = CodeLanguages.displayNames.entries.toList()
    ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
  return [
    WonkyMenuRadioItem(
      key: const ValueKey<String>('menu.code.plain'),
      label: 'Plain text',
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
