import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/command_icons.dart';
import '../editor/commands/write_editor_commands.dart';
import '../editor/controller/editor_types.dart';
import 'command_invoke.dart';
import 'write_document_controller.dart';

/// Resolves command state/titles/shortcuts for controls and invokes them
/// (every control is bound to a command id — Write 05 §1).
class CommandUi {
  CommandUi(this.context, this.s);

  final BuildContext context;
  final ShellServices s;

  CommandState state(String id, [Map<String, Object?> args = const {}]) =>
      s.dispatcher.stateOf(id, args);

  String title(String id) => s.registry.byId(id)?.title(context) ?? id;

  List<String>? shortcut(String id) => s.keymap.labelsOf(id);

  void run(
    String id, [
    Map<String, Object?> args = const {},
    InvocationSource source = InvocationSource.toolbar,
  ]) => invokeWith(s, id, args: args, source: source, context: context);

  /// A toolbar button bound to [id].
  ToolbarItem button(
    String id, {
    IconData? icon,
    int priority = 3,
    Map<String, Object?> args = const {},
    String? label,
    VoidCallback? onLongPress,
  }) {
    final st = state(id, args);
    return ToolbarButton(
      id: 'write.toolbar.${id.split('.').skip(1).join('.')}',
      priority: priority,
      icon:
          icon ??
          commandIcons[id] ??
          s.registry.byId(id)?.icon ??
          LucideIcons.circle,
      label: label ?? title(id),
      shortcut: args.isEmpty ? shortcut(id) : null,
      enabled: st.enabled,
      disabledReason: st.disabledReason,
      onPressed: () => run(id, args),
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
    );
  }

  /// A toggle bound to [id] (checked state from the command).
  ToolbarItem toggle(
    String id, {
    IconData? icon,
    int priority = 3,
    Map<String, Object?> args = const {},
    String? label,
    String? keyName,
  }) {
    final st = state(id, args);
    return ToolbarToggleButton(
      id: 'write.toolbar.${keyName ?? id.split('.').skip(1).join('.')}',
      priority: priority,
      icon: icon ?? commandIcons[id] ?? LucideIcons.circle,
      label: label ?? title(id),
      value: st.checked ?? false,
      shortcut: shortcut(id),
      enabled: st.enabled,
      disabledReason: st.disabledReason,
      onChanged: (_) => run(id, args),
    );
  }

  /// A menu entry bound to [id].
  WonkyMenuEntry item(
    String id, {
    Map<String, Object?> args = const {},
    String? label,
    IconData? icon,
    bool radio = false,
    String? keyName,
  }) {
    final st = state(id, args);
    final l = label ?? title(id);
    final k = ValueKey<String>('menu.${keyName ?? id}');
    final sc = args.isEmpty ? shortcut(id) : null;
    void go() => run(id, args, InvocationSource.menu);
    if (st.checked != null) {
      return radio
          ? WonkyMenuRadioItem(
              key: k,
              label: l,
              selected: st.checked!,
              shortcut: sc,
              enabled: st.enabled,
              disabledReason: st.disabledReason,
              onSelected: go,
            )
          : WonkyMenuCheckItem(
              key: k,
              label: l,
              checked: st.checked!,
              shortcut: sc,
              enabled: st.enabled,
              disabledReason: st.disabledReason,
              onSelected: go,
            );
    }
    return WonkyMenuItem(
      key: k,
      label: l,
      icon: icon ?? commandIcons[id],
      shortcut: sc,
      enabled: st.enabled,
      disabledReason: st.disabledReason,
      onSelected: go,
    );
  }
}

/// Paragraph styles of the style dropdown (Write 05 §4.1).
const paragraphStyles = <(BlockKind, String)>[
  (BlockKind.paragraph, 'Normal text'),
  (BlockKind.heading1, 'Heading 1'),
  (BlockKind.heading2, 'Heading 2'),
  (BlockKind.heading3, 'Heading 3'),
  (BlockKind.heading4, 'Heading 4'),
  (BlockKind.heading5, 'Heading 5'),
  (BlockKind.heading6, 'Heading 6'),
  (BlockKind.quote, 'Quote'),
  (BlockKind.codeBlock, 'Code block'),
];

/// Label of the current paragraph style ('' when mixed / not a text block).
String paragraphStyleLabel(BlockKind? kind) {
  if (kind == null) return 'Normal text';
  for (final (k, label) in paragraphStyles) {
    if (k == kind) return label;
  }
  return switch (kind) {
    BlockKind.bulleted ||
    BlockKind.numbered ||
    BlockKind.checklist => 'Normal text',
    _ => 'Normal text',
  };
}

/// Zoom presets of the zoom dropdown (Write 05 §4 item 6).
const zoomPresets = [50, 75, 90, 100, 125, 150, 200];

/// Paragraph style menu entries (toolbar dropdown, Format menu, selection
/// toolbar).
List<WonkyMenuEntry> paragraphStyleEntries(
  CommandUi ui,
  BlockKind? current,
) => [
  for (final (kind, label) in paragraphStyles)
    WonkyMenuRadioItem(
      key: ValueKey<String>('menu.style.${kind.name}'),
      label: label,
      selected: current == kind,
      shortcut: ui.shortcut('write.format.blockType.${kind.name}'),
      enabled: ui.state('write.format.blockType', {'type': kind.name}).enabled,
      onSelected: () => ui.run('write.format.blockType', {
        'type': kind.name,
      }, InvocationSource.menu),
    ),
];

/// The formatting toolbar of the editor screen (Write 05 §4).
class WriteToolbar extends StatelessWidget {
  const WriteToolbar({
    super.key,
    required this.services,
    required this.doc,
    this.controller,
  });

  final ShellServices services;
  final WriteDocumentController doc;
  final WonkyToolbarController? controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        doc,
        services.registry,
        services.undo,
        services.panels,
      ]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final ui = CommandUi(context, services);
    final viewing = doc.editor.mode == EditorMode.viewing;
    final zoom = (doc.view.zoom * 100).round();
    final undoLabel = services.undo.undoLabel.value;
    final redoLabel = services.undo.redoLabel.value;
    final kind = doc.commands.selectedBlockKind;

    final history = ToolbarGroup([
      ui.button(
        'shell.edit.undo',
        icon: LucideIcons.undo2,
        priority: 1,
        label: undoLabel == null ? 'Undo' : 'Undo $undoLabel',
        onLongPress: () => ui.run('shell.edit.undoHistory'),
      ),
      ui.button(
        'shell.edit.redo',
        icon: LucideIcons.redo2,
        priority: 1,
        label: redoLabel == null ? 'Redo' : 'Redo $redoLabel',
      ),
      ui.button(
        'shell.help.searchMenus',
        icon: LucideIcons.search,
        priority: 5,
      ),
      ui.button('write.file.print', icon: LucideIcons.printer, priority: 4),
    ], id: 'history');

    final zoomGroup = ToolbarGroup([
      ToolbarDropdownButton(
        id: 'write.toolbar.zoom',
        priority: 3,
        label: '$zoom%',
        tooltip: 'Zoom',
        minWidth: 34,
        entries: () => [
          for (final p in zoomPresets)
            WonkyMenuRadioItem(
              key: ValueKey<String>('menu.zoom.$p'),
              label: '$p%',
              selected: zoom == p,
              onSelected: () => ui.run('write.view.zoomSet', {'percent': p}),
            ),
          const WonkyMenuSeparator(),
          ui.item(
            'write.view.zoomFit',
            args: {'mode': 'width'},
            label: 'Fit width',
          ),
          ui.item(
            'write.view.zoomFit',
            args: {'mode': 'page'},
            label: 'Fit page',
          ),
        ],
      ),
    ], id: 'zoom');

    if (viewing) {
      return WonkyToolbar(
        controller: controller,
        semanticLabel: 'Formatting toolbar',
        onEscape: doc.focusEditor,
        groups: [history, zoomGroup],
        trailing: [_modeItem(context, ui)],
      );
    }

    final styleState = ui.state('write.format.blockType', {
      'type': 'paragraph',
    });
    return WonkyToolbar(
      controller: controller,
      semanticLabel: 'Formatting toolbar',
      onEscape: doc.focusEditor,
      groups: [
        history,
        zoomGroup,
        ToolbarGroup([
          ToolbarDropdownButton(
            id: 'write.toolbar.style',
            priority: 1,
            label: paragraphStyleLabel(kind),
            tooltip: 'Styles',
            minWidth: 96,
            enabled: styleState.enabled,
            entries: () => paragraphStyleEntries(ui, kind),
          ),
        ], id: 'style'),
        ToolbarGroup([
          ui.toggle('write.format.bold', priority: 1),
          ui.toggle('write.format.italic', priority: 1),
          ui.toggle('write.format.strikethrough', priority: 2),
          ui.toggle('write.format.inlineCode', priority: 2),
        ], id: 'inline'),
        ToolbarGroup([
          _linkToggle(ui),
          ui.button(
            'shell.comments.create',
            icon: LucideIcons.messageSquarePlus,
            priority: 2,
          ),
          ui.toggle(
            'write.suggestions.togglePanel',
            icon: LucideIcons.fileDiff,
            label: 'Suggestions',
            priority: 3,
          ),
          ToolbarSplitButton(
            id: 'write.toolbar.image',
            priority: 2,
            icon: LucideIcons.image,
            label: 'Insert image',
            enabled: ui.state('write.insert.image').enabled,
            onPressed: () => ui.run('write.insert.image'),
            entries: () => [
              ui.item('write.insert.image', label: 'Upload from computer'),
              ui.item('write.insert.imageFromUrl', label: 'By URL…'),
            ],
          ),
          ToolbarDropdownButton(
            id: 'write.toolbar.table',
            priority: 3,
            label: '',
            icon: LucideIcons.table,
            tooltip: 'Insert table',
            enabled: ui.state('write.insert.table').enabled,
            entries: () => [
              WonkyMenuCustom(
                label: 'Table size',
                builder: (context, close) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: WonkyTableSizePicker(
                    key: const ValueKey<String>('write.toolbar.tablePicker'),
                    onSelected: (rows, cols) {
                      close();
                      ui.run('write.insert.table', {
                        'rows': rows,
                        'cols': cols,
                      });
                    },
                  ),
                ),
              ),
              const WonkyMenuSeparator(),
              ui.item('write.insert.tableDialog', label: 'Custom size…'),
            ],
          ),
          ui.button('write.insert.divider', priority: 6, label: 'Divider'),
        ], id: 'insert'),
        ToolbarGroup([
          ui.toggle('write.list.toggleBulleted', priority: 1),
          ui.toggle('write.list.toggleNumbered', priority: 1),
          ui.toggle('write.list.toggleChecklist', priority: 2),
          ui.button('write.list.outdent', priority: 3),
          ui.button('write.list.indent', priority: 3),
        ], id: 'lists'),
        ToolbarGroup([
          ui.toggle(
            'write.format.blockType.quote',
            priority: 4,
            keyName: 'quote',
            label: 'Quote',
          ),
          ui.toggle(
            'write.format.blockType.codeBlock',
            priority: 4,
            keyName: 'codeBlock',
            label: 'Code block',
          ),
          ui.button('write.format.clearFormatting', priority: 4),
        ], id: 'blocks'),
        ToolbarGroup([
          ui.button('write.theme.openPicker', priority: 5, label: 'Theme'),
        ], id: 'theme'),
      ],
      trailing: [_modeItem(context, ui)],
    );
  }

  ToolbarItem _linkToggle(CommandUi ui) {
    final st = ui.state('write.link.insert');
    final inLink = doc.commands.linkAt() != null;
    return ToolbarToggleButton(
      id: 'write.toolbar.link',
      priority: 1,
      icon: LucideIcons.link,
      label: inLink ? 'Edit link' : 'Insert link',
      value: inLink,
      shortcut: ui.shortcut('write.link.insert'),
      enabled: st.enabled,
      disabledReason: st.disabledReason,
      onChanged: (_) => ui.run('write.link.insert'),
    );
  }

  ToolbarItem _modeItem(BuildContext context, CommandUi ui) => ToolbarCustom(
    id: 'write.toolbar.mode',
    pinned: true,
    priority: 1,
    builder: (context) => ModeSwitcher(doc: doc, ui: ui),
    overflow: modeEntries(ui, doc),
  );
}

/// Mode menu entries (View › Mode, mode switcher).
List<WonkyMenuEntry> modeEntries(CommandUi ui, WriteDocumentController doc) => [
  for (final (mode, label) in const [
    (EditorMode.editing, 'Editing'),
    (EditorMode.suggesting, 'Suggesting'),
    (EditorMode.viewing, 'Viewing'),
  ])
    ui.item('write.mode.${mode.name}', label: label, radio: true),
];

/// The Editing / Suggesting / Viewing switcher (Write 05 §15).
class ModeSwitcher extends StatelessWidget {
  const ModeSwitcher({super.key, required this.doc, required this.ui});

  final WriteDocumentController doc;
  final CommandUi ui;

  static (IconData, String, String) describe(EditorMode m) => switch (m) {
    EditorMode.editing => (
      LucideIcons.pencil,
      'Editing',
      'Edit document directly',
    ),
    EditorMode.suggesting => (
      LucideIcons.messageSquareDiff,
      'Suggesting',
      'Edits become suggestions',
    ),
    EditorMode.viewing => (
      LucideIcons.eye,
      'Viewing',
      'Read or print final document',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final mode = doc.editor.mode;
    final (icon, label, _) = describe(mode);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final suggesting = mode == EditorMode.suggesting;
    return WonkyDropdownMenu(
      anchor: const ShadAnchor(
        childAlignment: AlignmentDirectional.bottomEnd,
        overlayAlignment: AlignmentDirectional.topEnd,
        offset: Offset(0, 4),
      ),
      constraints: const BoxConstraints(minWidth: 280),
      entries: () => [
        for (final m in EditorMode.values)
          WonkyMenuCustom(
            label: describe(m).$2,
            builder: (context, close) =>
                _ModeRow(mode: m, ui: ui, current: mode, close: close),
          ),
      ],
      builder: (context, c) => ShadTooltip(
        builder: (_) => const Text('Mode'),
        child: ShadButton.outline(
          key: const ValueKey<String>('write.toolbar.modeSwitcher'),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: suggesting
              ? ShadDecoration(
                  border: ShadBorder.all(color: cs.success, width: 1),
                )
              : null,
          foregroundColor: suggesting ? cs.success : null,
          leading: Icon(icon, size: 15),
          trailing: Icon(
            LucideIcons.chevronDown,
            size: 14,
            color: cs.mutedForeground,
          ),
          onPressed: c.toggle,
          child: wide ? Text(label) : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.mode,
    required this.ui,
    required this.current,
    required this.close,
  });

  final EditorMode mode;
  final CommandUi ui;
  final EditorMode current;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final (icon, label, description) = ModeSwitcher.describe(mode);
    final st = ui.state('write.mode.set', {'mode': mode.name});
    final selected = mode == current;
    final shortcut = ui.s.keymap.labelsOf('write.mode.${mode.name}');
    final row = Opacity(
      opacity: st.enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? cs.primary : cs.foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.small),
                  Text(
                    description,
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (shortcut != null) ...[
              const SizedBox(width: 8),
              ShadKbd.group(shortcut, height: 18),
            ],
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              child: selected
                  ? Icon(LucideIcons.check, size: 16, color: cs.primary)
                  : null,
            ),
          ],
        ),
      ),
    );
    return ShadTooltip(
      builder: (_) =>
          Text(st.enabled ? label : (st.disabledReason ?? 'Not available')),
      child: MouseRegion(
        cursor: st.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          key: ValueKey<String>('write.mode.option.${mode.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: st.enabled
              ? () {
                  close();
                  ui.run('write.mode.set', {'mode': mode.name});
                }
              : null,
          child: row,
        ),
      ),
    );
  }
}
