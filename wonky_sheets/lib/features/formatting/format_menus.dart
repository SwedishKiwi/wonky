import 'package:flutter/widgets.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../number_format/recent_formats.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import '../toolbar/command_ui.dart';
import 'cell_fonts.dart';

/// Recently used custom number formats (06 §5.1) as menu items with the
/// active cell's value as example; empty when there are none.
List<WonkyMenuEntry> recentNumberFormatEntries(
  CommandUi ui,
  SheetEditorController ed,
) {
  final recent = RecentNumberFormats.of(ed.model);
  if (recent.isEmpty) return const [];
  final current = ed.activeFormat().numberFormat;
  return [
    WonkyMenuLabel(ui.l.numFmtRecent),
    for (final p in recent)
      WonkyMenuRadioItem(
        key: ValueKey<String>('menu.numberFormat.recent.$p'),
        label: p,
        selected: p == current,
        enabled: ed.canEdit,
        onSelected: () => ui.run('sheets.format.numberFormat', {
          'pattern': p,
        }, InvocationSource.menu),
      ),
  ];
}

/// Font menu (04 §4 item 12, 06 §6.1): *Theme font*, *Recent* (this
/// session) and *All fonts* (the bundled cell fonts), each item showing
/// "Aa" in its face; a non-bundled current font says what it's displayed as.
List<WonkyMenuEntry> fontMenuEntries(CommandUi ui, SheetEditorController ed) {
  final l = ui.l;
  final current = ed.activeFormat().fontFamily;
  final themeFont = ed.model.theme.textFont;
  WonkyMenuEntry item(String family, String section) {
    final bundled = CellFonts.isBundled(family);
    return WonkyMenuRadioItem(
      key: ValueKey<String>('menu.font.$section.$family'),
      label: bundled
          ? family
          : l.fontDisplayedAs(family, CellFonts.displayFamily(family)),
      selected: family == current,
      enabled: ed.canEdit,
      trailing: Text(
        'Aa',
        key: ValueKey<String>('menu.font.$section.$family.preview'),
        style: TextStyle(
          fontFamily: CellFonts.screenFamily(family),
          fontFamilyFallback: CellFonts.fallback,
          fontSize: 14,
        ),
      ),
      onSelected: () {
        CellFonts.noteRecent(family);
        ui.run('sheets.format.fontFamily', {
          'family': family,
        }, InvocationSource.menu);
      },
    );
  }

  final recent = [
    for (final f in CellFonts.recent)
      if (f != themeFont) f,
  ];
  return [
    WonkyMenuLabel(l.fontThemeSection),
    item(themeFont, 'theme'),
    if (recent.isNotEmpty) ...[
      const WonkyMenuSeparator(),
      WonkyMenuLabel(l.fontRecentSection),
      for (final f in recent) item(f, 'recent'),
    ],
    const WonkyMenuSeparator(),
    WonkyMenuLabel(l.fontAllSection),
    if (!CellFonts.isBundled(current) && current != themeFont)
      item(current, 'all'),
    for (final f in CellFonts.bundled) item(f, 'all'),
  ];
}
