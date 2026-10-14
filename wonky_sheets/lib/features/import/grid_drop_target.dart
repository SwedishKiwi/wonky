import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'import_pipeline.dart';

/// Dropping a spreadsheet file on the grid opens the import dialog with
/// *Insert new sheet(s)* preselected (11 §2.1).
class GridFileDropTarget extends StatefulWidget {
  const GridFileDropTarget({
    super.key,
    required this.controller,
    required this.child,
  });

  final SheetEditorController controller;
  final Widget child;

  @override
  State<GridFileDropTarget> createState() => _GridFileDropTargetState();
}

class _GridFileDropTargetState extends State<GridFileDropTarget> {
  bool _over = false;

  Future<void> _drop(DropDoneDetails d) async {
    setState(() => _over = false);
    if (d.files.isEmpty) return;
    final f = d.files.first;
    final data = ImportFileData(name: f.name, bytes: await f.readAsBytes());
    final token = ImportFileRegistry.put(data);
    await widget.controller.invokeCommand('sheets.file.import', {
      'fileToken': token,
      'showDialog': true,
      'options': {
        'location': widget.controller.canEdit
            ? ImportLocation.insertSheets.name
            : ImportLocation.createNew.name,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (d) => unawaited(_drop(d)),
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (_over)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey<String>('sheets.grid.dropOverlay'),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.06),
                    border: Border.all(color: cs.ring, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      sheetsL10n(context).importDropHere,
                      style: theme.textTheme.large,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
