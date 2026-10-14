import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/named_commands.dart';
import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// The name box chevron (03 §9): a dropdown of the named ranges (selecting
/// one goes there) and *Manage named ranges*.
class NamedRangeMenuButton extends StatelessWidget {
  const NamedRangeMenuButton({super.key, required this.editor});

  final SheetEditorController editor;

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    return WonkyDropdownMenu(
      constraints: const BoxConstraints(maxHeight: 360, minWidth: 220),
      entries: () {
        final m = editor.model;
        final ranges = namedRangesOf(m);
        return [
          if (ranges.isEmpty)
            WonkyMenuItem(label: l.namedRangesNone, enabled: false),
          for (final n in ranges)
            WonkyMenuItem(
              key: ValueKey<String>('nameBox.named.${n.name}'),
              label: '${n.name}  ·  ${namedRangeA1(m, n) ?? '#REF!'}',
              onSelected: () => unawaited(
                editor.invokeCommand('sheets.namedRanges.goTo', {
                  'name': n.name,
                }),
              ),
            ),
          const WonkyMenuSeparator(),
          WonkyMenuItem(
            key: const ValueKey<String>('nameBox.manage'),
            label: l.namedRangesManage,
            icon: LucideIcons.bookmark,
            onSelected: () =>
                unawaited(editor.invokeCommand('sheets.namedRanges.openPanel')),
          ),
        ];
      },
      builder: (context, c) => ShadIconButton.ghost(
        key: const ValueKey<String>('sheets.nameBox.menu'),
        width: 22,
        height: 26,
        icon: const Icon(LucideIcons.chevronDown, size: 14),
        onPressed: c.toggle,
      ),
    );
  }
}
