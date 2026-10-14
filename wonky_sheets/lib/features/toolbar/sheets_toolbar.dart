import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/format_commands.dart';
import '../../l10n/sheets_l10n.dart';
import '../../theme/sheets_tokens.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import '../formatting/format_menus.dart';
import '../formatting/sheets_colors.dart';
import 'border_picker.dart';
import 'command_ui.dart';

/// Number format menu entries with live examples (04 §4.2
/// `NumberFormatMenu`); shared by the toolbar "123 ▾" and Format › Number.
List<WonkyMenuEntry> numberFormatEntries(
  CommandUi ui,
  SheetEditorController ed,
) {
  final l = ui.l;
  final current = ed.activeFormat().numberFormat;
  return [
    for (final m in NumberFormatPresets.menu)
      WonkyMenuRadioItem(
        key: ValueKey<String>('menu.numberFormat.${m.id}'),
        label:
            '${numberFormatLabel(l, m.id)}   ${m.example(locale: ed.locale)}',
        selected: m.stored == current,
        shortcut: ui.shortcut('sheets.format.numberFormat', {'preset': m.id}),
        enabled: ed.canEdit,
        onSelected: () => ui.run('sheets.format.numberFormat', {
          'preset': m.id,
        }, InvocationSource.menu),
      ),
    const WonkyMenuSeparator(),
    ...recentNumberFormatEntries(ui, ed),
    const WonkyMenuSeparator(),
    ui.item('sheets.format.openCustomNumberFormat'),
    ui.item('sheets.format.openCustomCurrency'),
    ui.item('sheets.format.openCustomDateTime'),
  ];
}

/// The color most recently applied from the split buttons (session).
String? _lastText = '#D93025';
String? _lastFill = '#FFF2CC';

/// The Sheets toolbar (04 §4).
class SheetsToolbar extends StatelessWidget {
  const SheetsToolbar({
    super.key,
    required this.services,
    required this.editor,
    this.controller,
  });

  final ShellServices services;
  final SheetEditorController editor;
  final WonkyToolbarController? controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      editor,
      services.registry,
      services.undo,
      editor.paintFormat,
    ]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final ui = CommandUi(context, services);
    final l = ui.l;
    final ed = editor;
    final zoom = (ed.scroll.zoom * 100).round();
    final undoLabel = services.undo.undoLabel.value;
    final redoLabel = services.undo.redoLabel.value;
    final f = ed.activeFormat();
    final tokens = GridPaintTokens.ofContext(context);

    final history = ToolbarGroup([
      ui.button(
        'shell.edit.undo',
        icon: LucideIcons.undo2,
        priority: 1,
        keyName: 'undo',
        label: undoLabel == null
            ? l.toolbarUndo
            : l.toolbarUndoLabel(undoLabel),
        onLongPress: () => ui.run('shell.edit.undoHistory'),
      ),
      ui.button(
        'shell.edit.redo',
        icon: LucideIcons.redo2,
        priority: 1,
        keyName: 'redo',
        label: redoLabel == null
            ? l.toolbarRedo
            : l.toolbarRedoLabel(redoLabel),
      ),
      ui.button('sheets.print.open', icon: LucideIcons.printer, priority: 6),
      if (!ed.viewMode)
        ui.toggle(
          'sheets.format.paintFormat',
          icon: LucideIcons.paintbrush,
          priority: 3,
        ),
    ], id: 'history');

    final zoomGroup = ToolbarGroup([
      ToolbarDropdownButton(
        id: 'sheets.toolbar.zoom',
        priority: 5,
        label: l.zoomPercent(zoom),
        tooltip: l.toolbarZoom,
        minWidth: 34,
        entries: () => [
          for (final p in const [50, 75, 90, 100, 125, 150, 200])
            ui.item(
              'sheets.view.zoom',
              args: {'percent': p},
              label: l.zoomPercent(p),
              radio: true,
              keyName: 'zoom.$p',
            ),
        ],
      ),
    ], id: 'zoom');

    if (ed.viewMode) {
      return WonkyToolbar(
        controller: controller,
        semanticLabel: l.toolbarLabel,
        onEscape: ed.gridFocus.requestFocus,
        groups: [history, zoomGroup],
        trailing: [
          ToolbarCustom(
            id: 'sheets.toolbar.viewOnly',
            pinned: true,
            builder: (context) => ShadBadge.secondary(
              child: Text(
                ed.itemRole == Role.commenter
                    ? l.badgeCommentOnly
                    : l.badgeViewOnly,
              ),
            ),
          ),
        ],
      );
    }

    final numbers = ToolbarGroup([
      ui.button(
        'sheets.format.numberFormat',
        args: {'preset': 'currency'},
        icon: LucideIcons.dollarSign,
        label: l.toolbarCurrency,
        keyName: 'currency',
        priority: 4,
      ),
      ui.button(
        'sheets.format.numberFormat',
        args: {'preset': 'percent'},
        icon: LucideIcons.percent,
        label: l.toolbarPercent,
        keyName: 'percent',
        priority: 4,
      ),
      ui.button('sheets.format.decreaseDecimals', priority: 4),
      ui.button('sheets.format.increaseDecimals', priority: 4),
      ToolbarDropdownButton(
        id: 'sheets.toolbar.moreFormats',
        enabled: ui.state('sheets.format.numberFormat').enabled,
        priority: 4,
        label: '123',
        tooltip: l.toolbarMoreFormats,
        entries: () => numberFormatEntries(ui, ed),
      ),
    ], id: 'numbers');

    final font = ToolbarGroup([
      ToolbarDropdownButton(
        id: 'sheets.toolbar.font',
        enabled: ui.state('sheets.format.fontFamily').enabled,
        priority: 3,
        label: f.fontFamily,
        tooltip: l.toolbarFont,
        minWidth: 64,
        entries: () => fontMenuEntries(ui, ed),
      ),
      ToolbarNumberField(
        id: 'sheets.toolbar.fontSize',
        enabled: ui.state('sheets.format.fontSize').enabled,
        priority: 2,
        label: l.toolbarFontSize,
        value: f.fontSize,
        min: 1,
        max: 400,
        onChanged: (v) =>
            ui.run('sheets.format.fontSize', {'size': v.toDouble()}),
      ),
    ], id: 'font');

    final textColor = hexToColor(
      f.textColor == null ? null : ed.model.theme.resolveColor(f.textColor),
    );
    final fillColor = hexToColor(
      f.fillColor == null ? null : ed.model.theme.resolveColor(f.fillColor),
    );
    final text = ToolbarGroup([
      ui.toggle('sheets.format.bold', priority: 1),
      ui.toggle('sheets.format.italic', priority: 1),
      ui.toggle('sheets.format.strikethrough', priority: 2),
      ToolbarSplitButton(
        id: 'sheets.toolbar.textColor',
        enabled: ui.state('sheets.format.textColor').enabled,
        priority: 2,
        icon: LucideIcons.baseline,
        label: l.toolbarTextColor,
        indicatorColor: textColor ?? tokens.autoText,
        onPressed: () =>
            ui.run('sheets.format.textColor', {'color': _lastText}),
        entries: () => [
          WonkyMenuCustom(
            label: l.toolbarTextColor,
            builder: (context, close) => WonkyColorPicker(
              value: pickerValueOf(f.textColor, ed.model.theme),
              themeColors: sheetsThemeSwatches(ed.model.theme, l),
              resetLabel: l.colorAutomatic,
              onChanged: (c) {
                close();
                final hex = c == null ? null : storedColorOf(c);
                if (hex != null) _lastText = hex;
                ui.run('sheets.format.textColor', {'color': hex});
              },
            ),
          ),
        ],
      ),
    ], id: 'text');

    final cellGroup = ToolbarGroup([
      ToolbarSplitButton(
        id: 'sheets.toolbar.fillColor',
        enabled: ui.state('sheets.format.fillColor').enabled,
        priority: 2,
        icon: LucideIcons.paintBucket,
        label: l.toolbarFillColor,
        indicatorColor: fillColor ?? tokens.sheetBackground,
        onPressed: () =>
            ui.run('sheets.format.fillColor', {'color': _lastFill}),
        entries: () => [
          WonkyMenuCustom(
            label: l.toolbarFillColor,
            builder: (context, close) => WonkyColorPicker(
              value: pickerValueOf(f.fillColor, ed.model.theme),
              themeColors: sheetsThemeSwatches(ed.model.theme, l),
              resetLabel: l.colorNone,
              onChanged: (c) {
                close();
                final hex = c == null ? null : storedColorOf(c);
                if (hex != null) _lastFill = hex;
                ui.run('sheets.format.fillColor', {'color': hex});
              },
            ),
          ),
          const WonkyMenuSeparator(),
          ui.item('sheets.banding.openPanel'),
          ui.item('sheets.cf.openPanel'),
        ],
      ),
      ToolbarDropdownButton(
        id: 'sheets.toolbar.borders',
        enabled: ui.state('sheets.format.borders').enabled,
        priority: 3,
        icon: LucideIcons.grid2x2,
        label: '',
        tooltip: l.toolbarBorders,
        entries: () => [
          WonkyMenuCustom(
            label: l.toolbarBorders,
            builder: (context, close) => BorderPicker(
              onApply: (preset, style, color) {
                close();
                ui.run('sheets.format.borders', {
                  'preset': preset.name,
                  'style': style.name,
                  'color': color,
                });
              },
            ),
          ),
        ],
      ),
      ToolbarSplitButton(
        id: 'sheets.toolbar.merge',
        priority: 3,
        icon: LucideIcons.combine,
        label: l.toolbarMerge,
        enabled:
            ui.state('sheets.format.merge').enabled ||
            ui.state('sheets.format.unmerge').enabled,
        onPressed: () {
          final r = ed.selection.resolved.activeRange.rect;
          final m = ed.activeSheet?.mergeAt(r.top, r.left);
          if (m != null && m == r) {
            ui.run('sheets.format.unmerge');
          } else {
            ui.run('sheets.format.merge', {'mode': 'all'});
          }
        },
        entries: () => [
          ui.item(
            'sheets.format.merge',
            args: {'mode': 'all'},
            label: l.mergeAll,
            keyName: 'merge.all',
          ),
          ui.item(
            'sheets.format.merge',
            args: {'mode': 'horizontal'},
            label: l.mergeHorizontally,
            keyName: 'merge.horizontal',
          ),
          ui.item(
            'sheets.format.merge',
            args: {'mode': 'vertical'},
            label: l.mergeVertically,
            keyName: 'merge.vertical',
          ),
          ui.item('sheets.format.unmerge'),
        ],
      ),
    ], id: 'cell');

    IconData hIcon(HorizontalAlign? a) => switch (a) {
      HorizontalAlign.center => LucideIcons.alignCenter,
      HorizontalAlign.right => LucideIcons.alignRight,
      _ => LucideIcons.alignLeft,
    };
    final align = ToolbarGroup([
      ToolbarDropdownButton(
        id: 'sheets.toolbar.hAlign',
        enabled: ui.state('sheets.format.hAlign').enabled,
        priority: 3,
        icon: hIcon(f.hAlign),
        label: '',
        tooltip: l.toolbarHAlign,
        entries: () => [
          for (final (v, label) in [
            ('left', l.alignLeft),
            ('center', l.alignCenter),
            ('right', l.alignRight),
          ])
            ui.item(
              'sheets.format.hAlign',
              args: {'align': v},
              label: label,
              radio: true,
              keyName: 'hAlign.$v',
            ),
        ],
      ),
      ToolbarDropdownButton(
        id: 'sheets.toolbar.vAlign',
        enabled: ui.state('sheets.format.vAlign').enabled,
        priority: 5,
        icon: switch (f.vAlign) {
          VerticalAlign.top => LucideIcons.alignVerticalJustifyStart,
          VerticalAlign.middle => LucideIcons.alignVerticalJustifyCenter,
          VerticalAlign.bottom => LucideIcons.alignVerticalJustifyEnd,
        },
        label: '',
        tooltip: l.toolbarVAlign,
        entries: () => [
          for (final (v, label) in [
            ('top', l.alignTop),
            ('middle', l.alignMiddle),
            ('bottom', l.alignBottom),
          ])
            ui.item(
              'sheets.format.vAlign',
              args: {'align': v},
              label: label,
              radio: true,
              keyName: 'vAlign.$v',
            ),
        ],
      ),
      ToolbarDropdownButton(
        id: 'sheets.toolbar.wrap',
        enabled: ui.state('sheets.format.wrap').enabled,
        priority: 4,
        icon: LucideIcons.wrapText,
        label: '',
        tooltip: l.toolbarWrap,
        entries: () => [
          for (final (v, label) in [
            ('overflow', l.wrapOverflow),
            ('wrap', l.wrapWrap),
            ('clip', l.wrapClip),
          ])
            ui.item(
              'sheets.format.wrap',
              args: {'strategy': v},
              label: label,
              radio: true,
              keyName: 'wrap.$v',
            ),
        ],
      ),
      ToolbarDropdownButton(
        id: 'sheets.toolbar.rotation',
        enabled: ui.state('sheets.format.rotation').enabled,
        priority: 6,
        icon: LucideIcons.rotateCcw,
        label: '',
        tooltip: l.toolbarRotation,
        entries: () => rotationEntries(ui),
      ),
    ], id: 'align');

    final insert = ToolbarGroup([
      ui.button('sheets.insert.link', icon: LucideIcons.link, priority: 5),
      ui.button(
        'shell.comments.create',
        icon: LucideIcons.messageSquarePlus,
        priority: 5,
        keyName: 'comment',
      ),
      ui.button(
        'sheets.chart.insert',
        icon: LucideIcons.chartColumn,
        priority: 6,
      ),
      ui.button('sheets.filter.toggle', icon: LucideIcons.funnel, priority: 4),
      ToolbarDropdownButton(
        id: 'sheets.toolbar.functions',
        enabled: ui.state('sheets.insert.function').enabled,
        priority: 5,
        icon: LucideIcons.sigma,
        label: '',
        tooltip: l.toolbarFunctions,
        entries: () => functionEntries(ui),
      ),
    ], id: 'insert');

    return WonkyToolbar(
      controller: controller,
      semanticLabel: l.toolbarLabel,
      onEscape: ed.gridFocus.requestFocus,
      groups: [
        history,
        zoomGroup,
        numbers,
        font,
        text,
        cellGroup,
        align,
        insert,
      ],
    );
  }
}

/// Rotation choices (04 §4 item 24).
List<WonkyMenuEntry> rotationEntries(CommandUi ui) {
  final l = ui.l;
  return [
    for (final (angle, label) in [
      (0, l.rotationNone),
      (45, l.rotationTiltUp),
      (-45, l.rotationTiltDown),
      (255, l.rotationStack),
      (90, l.rotationUp),
      (-90, l.rotationDown),
    ])
      ui.item(
        'sheets.format.rotation',
        args: {'angle': angle},
        label: label,
        radio: true,
        keyName: 'rotation.$angle',
      ),
    ui.item(
      'sheets.format.rotation',
      label: l.rotationCustom,
      keyName: 'rotation.custom',
    ),
  ];
}

/// The Σ menu (04 §4 item 29).
List<WonkyMenuEntry> functionEntries(CommandUi ui) => [
  for (final name in const ['SUM', 'AVERAGE', 'COUNT', 'MAX', 'MIN'])
    ui.item(
      'sheets.insert.function',
      args: {'name': name},
      label: name,
      keyName: 'function.$name',
    ),
  const WonkyMenuSeparator(),
  ui.item('sheets.help.functionList'),
];

/// Localized "Automatic" etc. for tests.
String colorResetLabel(SheetsLocalizations l) => l.colorAutomatic;
