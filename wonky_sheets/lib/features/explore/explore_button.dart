import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../sheet_editor/sheet_editor_controller.dart';
import '../toolbar/command_ui.dart';
import 'explore_panel.dart';

/// "✨ Explore" in the sheet tab bar (04 §6–7): toggles the Explore panel.
class ExploreButton extends StatelessWidget {
  const ExploreButton({super.key, required this.controller});

  final SheetEditorController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.services;
    return ListenableBuilder(
      listenable: s.panels,
      builder: (context, _) {
        final ui = CommandUi(context, s);
        final open = s.panels.isOpen(explorePanelId);
        final label = ui.title('sheets.explore.toggle');
        final keys = ui.shortcut('sheets.explore.toggle');
        return ShadTooltip(
          builder: (_) => Text(
            keys == null || keys.isEmpty ? label : '$label (${keys.join(' ')})',
          ),
          child: (open ? ShadButton.secondary : ShadButton.ghost)(
            key: const ValueKey<String>('sheets.tab.explore'),
            size: ShadButtonSize.sm,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(LucideIcons.sparkles, size: 14),
            onPressed: () => ui.run('sheets.explore.toggle'),
            child: Text(label),
          ),
        );
      },
    );
  }
}
