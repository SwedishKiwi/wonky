import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../data_validation/dv_controller.dart';
import '../data_validation/dv_panel.dart';
import '../protection/protection_controller.dart';
import '../protection/protection_panel.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'in_cell_controller.dart';

/// Installs data validation, protected ranges and the in-cell widgets on a
/// new editor (write gates, grid layers, hit handlers, cell popovers).
void attachCellFeatures(SheetEditorController editor) {
  DataValidationController.of(editor);
  ProtectionController.of(editor);
  InCellController.of(editor);
}

/// The side panels of these features (04 §10), opened by their commands.
List<SidePanelSpec> cellFeaturePanelSpecs(
  BuildContext context,
  ShellServices services,
  SheetEditorController editor,
) {
  SidePanelSpec hidden(SidePanelSpec p) => SidePanelSpec(
    id: p.id,
    title: p.title,
    icon: p.icon,
    builder: p.builder,
    headerActions: p.headerActions,
    showAsTab: false,
  );
  return [
    hidden(dvPanelSpec(context, services, editor)),
    hidden(protectionPanelSpec(context, services, editor)),
  ];
}
