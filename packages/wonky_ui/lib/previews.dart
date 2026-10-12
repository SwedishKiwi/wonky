/// Widget previews (`flutter widget-preview start`) of every custom
/// `wonky_ui` widget in light and dark (suite 02 §4).
library;

import 'package:flutter/widget_previews.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import 'src/preview/wonky_preview_app.dart';
import 'wonky_ui.dart';

/// Wraps a preview in the light Wonky theme.
Widget wonkyLight(Widget child) =>
    WonkyTestApp(child: Center(child: child));

/// Wraps a preview in the dark Wonky theme.
Widget wonkyDark(Widget child) =>
    WonkyTestApp(brightness: Brightness.dark, child: Center(child: child));

@Preview(group: 'Toolbar', name: 'light', wrapper: wonkyLight, size: Size(720, 80))
@Preview(group: 'Toolbar', name: 'dark', wrapper: wonkyDark, size: Size(720, 80))
Widget toolbarPreview() => WonkyToolbar(
  groups: [
    ToolbarGroup([
      ToolbarButton(icon: LucideIcons.undo2, label: 'Undo', onPressed: () {}),
      ToolbarButton(icon: LucideIcons.redo2, label: 'Redo', onPressed: () {}),
    ]),
    ToolbarGroup([
      ToolbarDropdownButton(label: 'Normal text', entries: () => const []),
      ToolbarNumberField(label: 'Font size', value: 11, onChanged: (_) {}),
    ]),
    ToolbarGroup([
      ToolbarToggleButton(icon: LucideIcons.bold, label: 'Bold', value: true, onChanged: (_) {}),
      ToolbarToggleButton(icon: LucideIcons.italic, label: 'Italic', value: false, onChanged: (_) {}),
      ToolbarSplitButton(
        icon: LucideIcons.baseline,
        label: 'Text color',
        indicatorColor: const Color(0xffdc2626),
        onPressed: () {},
        entries: () => const [],
      ),
    ]),
  ],
);

@Preview(group: 'Menu', name: 'light', wrapper: wonkyLight)
@Preview(group: 'Menu', name: 'dark', wrapper: wonkyDark)
Widget dropdownPreview() => WonkyDropdownMenu(
  entries: () => [
    const WonkyMenuLabel('File'),
    WonkyMenuItem(label: 'Open…', icon: LucideIcons.folderOpen, shortcut: const ['⌘', 'O'], onSelected: () {}),
    const WonkyMenuSeparator(),
    WonkyMenuCheckItem(label: 'Show ruler', checked: true, onSelected: () {}),
    WonkyMenuRadioItem(label: 'Light', selected: true, onSelected: () {}),
    const WonkyMenuSubmenu(label: 'Zoom', children: [WonkyMenuItem(label: '100%')]),
  ],
  builder: (context, c) => ShadButton.outline(onPressed: c.toggle, child: const Text('Open menu')),
);

@Preview(group: 'Menubar', name: 'light', wrapper: wonkyLight, size: Size(600, 60))
@Preview(group: 'Menubar', name: 'dark', wrapper: wonkyDark, size: Size(600, 60))
Widget menubarPreview() => WonkyMenubar(
  menus: [
    for (final m in ['File', 'Edit', 'View', 'Insert', 'Format', 'Tools', 'Help'])
      WonkyMenubarMenu(id: m.toLowerCase(), label: m, entries: () => [WonkyMenuItem(label: '$m item')]),
  ],
);

@Preview(group: 'Color picker', name: 'light', wrapper: wonkyLight)
@Preview(group: 'Color picker', name: 'dark', wrapper: wonkyDark)
Widget colorPickerPreview() => WonkyColorPicker(
  resetLabel: 'Automatic',
  value: const WonkyColor('#ff0000'),
  recentColors: const [WonkyColor('#336699')],
  onChanged: (_) {},
);

@Preview(group: 'Split view', name: 'light', wrapper: wonkyLight, size: Size(900, 500))
@Preview(group: 'Split view', name: 'dark', wrapper: wonkyDark, size: Size(900, 500))
Widget splitViewPreview() => WonkySplitView(
  controller: WonkySplitViewController()..open('comments'),
  panels: [
    SidePanelSpec(id: 'comments', title: 'Comments', icon: LucideIcons.messageSquare, builder: (_) => const Center(child: Text('Comments'))),
  ],
  child: const Center(child: Text('Document')),
);

@Preview(group: 'Tree view', name: 'light', wrapper: wonkyLight, size: Size(300, 300))
@Preview(group: 'Tree view', name: 'dark', wrapper: wonkyDark, size: Size(300, 300))
Widget treeViewPreview() => WonkyTreeView<String>(
  controller: WonkyTreeController<String>(
    loader: (parent) async => [
      for (final n in parent == null ? ['Projects', 'Personal'] : ['Notes', 'Archive'])
        WonkyTreeNode(id: '${parent?.id ?? ''}/$n', label: n, value: n, icon: LucideIcons.folder, hasChildren: parent == null),
    ],
  ),
);

@Preview(group: 'Presence', name: 'light', wrapper: wonkyLight)
@Preview(group: 'Presence', name: 'dark', wrapper: wonkyDark)
Widget presencePreview() => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    PresenceAvatarStack(
      participants: [
        for (var i = 0; i < 6; i++)
          PresenceParticipant(sessionId: '$i', userKey: 'u$i', displayName: 'Person ${'ABCDEF'[i]}', colorIndex: i * 2),
      ],
    ),
    const SizedBox(width: 40),
    const RemoteCaret(name: 'Bo Chen', color: Color(0xff16a34a), height: 20),
  ],
);

@Preview(group: 'Inputs', name: 'light', wrapper: wonkyLight, size: Size(500, 360))
@Preview(group: 'Inputs', name: 'dark', wrapper: wonkyDark, size: Size(500, 360))
Widget inputsPreview() => Column(
  mainAxisSize: MainAxisSize.min,
  spacing: 16,
  children: [
    DocumentTitleField(title: 'Q3 planning', onRename: (_) {}),
    WonkyNumberStepper(value: 11, onChanged: (_) {}),
    KeyboardShortcutRecorder(labels: const ['⌘', 'B'], onRecorded: (_) {}),
    FontPicker(value: 'Inter', fonts: const ['Inter', 'Geist'], onChanged: (_) {}),
    const SyncStatusIndicator(status: SyncStatus.saved),
  ],
);

@Preview(group: 'Table size picker', name: 'light', wrapper: wonkyLight)
@Preview(group: 'Table size picker', name: 'dark', wrapper: wonkyDark)
Widget tableSizePreview() => WonkyTableSizePicker(onSelected: (_, _) {});

@Preview(group: 'Status bar', name: 'light', wrapper: wonkyLight, size: Size(800, 40))
@Preview(group: 'Status bar', name: 'dark', wrapper: wonkyDark, size: Size(800, 40))
Widget statusBarPreview() => const StatusBar(
  left: [Text('1,204 words')],
  center: [SyncStatusIndicator(status: SyncStatus.saved, compact: true)],
  right: [StatusBarButton(child: Text('100%'))],
);

@Preview(group: 'Empty state', name: 'light', wrapper: wonkyLight, size: Size(500, 400))
@Preview(group: 'Empty state', name: 'dark', wrapper: wonkyDark, size: Size(500, 400))
Widget emptyStatePreview() => const WonkyEmptyState(
  illustration: EmptyIllustration.starred,
  title: 'No starred files',
  description: 'Add stars to things you want to find easily later.',
);

@Preview(group: 'Loading', name: 'light', wrapper: wonkyLight, size: Size(700, 400))
@Preview(group: 'Loading', name: 'dark', wrapper: wonkyDark, size: Size(700, 400))
Widget loadingPreview() => LoadingShimmer.driveList(rows: 6);
