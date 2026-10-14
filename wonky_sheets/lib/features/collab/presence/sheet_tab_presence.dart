import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/sheets_l10n.dart';
import '../../sheet_editor/sheet_editor_controller.dart';
import '../sheets_collab.dart';
import 'sheets_presence_controller.dart';

/// Presence dots on a sheet tab (Sheets 10 §1.3): up to 3 dots in the
/// presence colors of the participants on that sheet, then "+N"; hover
/// lists the names; clicking a dot jumps to that participant.
class SheetTabPresence extends StatelessWidget {
  const SheetTabPresence({
    super.key,
    required this.controller,
    required this.sheetId,
  });

  final SheetEditorController controller;
  final String sheetId;

  @override
  Widget build(BuildContext context) {
    final collab = SheetsCollab.of(controller);
    if (collab == null) return const SizedBox.shrink();
    return ValueListenableBuilder<List<RemoteCursorView>>(
      valueListenable: collab.presence.cursors,
      builder: (context, cursors, _) {
        final here = [
          for (final c in cursors)
            if (c.cursor.sheetId == sheetId) c,
        ];
        if (here.isEmpty) return const SizedBox.shrink();
        final theme = ShadTheme.of(context);
        final l = sheetsL10n(context);
        final shown = here.take(3).toList();
        return ShadTooltip(
          builder: (_) => Text(here.map((c) => c.displayName).join(', ')),
          child: Semantics(
            label: l.tabPresence(here.map((c) => c.displayName).join(', ')),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in shown)
                    GestureDetector(
                      key: ValueKey<String>(
                        'sheets.tab.presence.$sheetId.${c.sessionId}',
                      ),
                      onTap: () => unawaited(
                        controller.invokeCommand('sheets.presence.jumpTo', {
                          'sessionId': c.sessionId,
                        }),
                      ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.presence(c.colorIndex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.background,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (here.length > 3)
                    Text(
                      '+${here.length - 3}',
                      style: theme.textTheme.muted.copyWith(fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
