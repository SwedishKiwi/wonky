import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../banding/banding_panel.dart';
import '../conditional_format/cf_panel.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import '../theme/theme_panel.dart';
import 'formatting_features.dart';

/// The formatting side panels (04 §10): conditional formatting, alternating
/// colors and themes. They are opened by their commands (Format menu,
/// toolbar fill-color menu), not shown as rail tabs.
List<SidePanelSpec> formattingPanelSpecs(
  BuildContext context,
  ShellServices services,
  SheetEditorController editor,
) {
  final l = sheetsL10n(context);
  return [
    SidePanelSpec(
      id: FormattingPanels.conditionalFormatting,
      title: l.cfPanelTitle,
      icon: LucideIcons.paintRoller,
      showAsTab: false,
      builder: (_) => CfPanel(services: services, editor: editor),
    ),
    SidePanelSpec(
      id: FormattingPanels.alternatingColors,
      title: l.bandingPanelTitle,
      icon: LucideIcons.rows3,
      showAsTab: false,
      builder: (_) => BandingPanel(services: services, editor: editor),
    ),
    SidePanelSpec(
      id: FormattingPanels.theme,
      title: l.themePanelTitle,
      icon: LucideIcons.palette,
      showAsTab: false,
      builder: (_) => ThemePanel(services: services, editor: editor),
    ),
  ];
}

/// Installs the formatting features on a new editor (06 §13–15).
void attachFormatting(SheetEditorController editor) =>
    FormattingFeatures.install(editor);

/// Disposes them with the editor.
void detachFormatting(SheetEditorController editor) =>
    FormattingFeatures.maybeOf(editor)?.dispose();
