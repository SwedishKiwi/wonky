import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters;
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import 'print_controller.dart';

/// The settings side of the print route (11 §7.1–7.2, 360 px): scope,
/// paper, orientation, scale, margins, *Formatting* and *Headers &
/// footers* accordions, custom page breaks and pagination warnings. Every
/// change is one `sheets.print.updateSettings` step (editors) or a local
/// override (viewers).
class PrintSettingsPanel extends StatefulWidget {
  const PrintSettingsPanel({super.key, required this.controller});

  final PrintController controller;

  @override
  State<PrintSettingsPanel> createState() => _PrintSettingsPanelState();
}

class _PrintSettingsPanelState extends State<PrintSettingsPanel> {
  final _scroll = ScrollController();
  final _fields = <String, TextEditingController>{};
  final _breakRow = TextEditingController();
  final _breakCol = TextEditingController();
  String? _breakError;

  PrintController get c => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    for (final f in _fields.values) {
      f.dispose();
    }
    _breakRow.dispose();
    _breakCol.dispose();
    super.dispose();
  }

  /// A text controller showing [value] unless the user is editing it.
  TextEditingController _field(String id, String value) {
    final f = _fields.putIfAbsent(id, () => TextEditingController(text: value));
    return f;
  }

  final _synced = <String, String>{};

  /// Shows a changed stored [value] (not on every rebuild: typing stays).
  void _syncField(String id, String value) {
    final f = _fields[id];
    if (f != null && _synced[id] != value && f.text != value) f.text = value;
    _synced[id] = value;
  }

  void _patch(Map<String, Object?> p) => c.update(p);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final st = c.settings;
    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        t,
        style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    String fmt(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    final selA1 = c.selection.rect.a1;

    return WonkyScrollArea(
      controller: _scroll,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (!c.persists)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.printViewerLocal, style: theme.textTheme.muted),
            ),
          if (c.breakMode)
            ..._breaks(context, label)
          else ...[
            label(l.printScope),
            _select<PrintScope>(
              id: 'print.scope',
              value: c.scope,
              values: PrintScope.values
                  .where((s) => s != PrintScope.namedRange)
                  .toList(),
              text: (s) => switch (s) {
                PrintScope.currentSheet => l.printScopeSheet,
                PrintScope.workbook => l.printScopeWorkbook,
                PrintScope.selection => l.printScopeSelection(selA1),
                PrintScope.namedRange => '',
              },
              onChanged: (v) => c.scope = v,
            ),
            if (c.scope == PrintScope.workbook && c.persists) ...[
              const SizedBox(height: 10),
              ShadCheckbox(
                key: const ValueKey<String>('print.applyToAll'),
                value: c.applyToAll,
                onChanged: (v) => c.applyToAll = v,
                label: Text(l.printApplyToAll),
              ),
            ],
            label(l.printPaperSize),
            _select<PaperSize>(
              id: 'print.paper',
              value: st.paper,
              values: PaperSize.values,
              text: (p) => p == PaperSize.custom
                  ? l.printPaperCustom
                  : '${p.label} (${fmt(p.widthPt / 72)} × '
                        '${fmt(p.heightPt / 72)} in)',
              onChanged: (p) => _patch({
                'paper': p.id,
                if (p == PaperSize.custom && st.customSize == null)
                  'customSize': {'w': 8.5, 'h': 11, 'unit': 'in'},
              }),
            ),
            if (st.paper == PaperSize.custom) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _number(
                      'print.customW',
                      l.printWidth,
                      st.customSize?.width ?? 8.5,
                      (v) => _patch({
                        'customSize': {
                          'w': v,
                          'h': st.customSize?.height ?? 11,
                          'unit': st.customSize?.unit ?? 'in',
                        },
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _number(
                      'print.customH',
                      l.printHeight,
                      st.customSize?.height ?? 11,
                      (v) => _patch({
                        'customSize': {
                          'w': st.customSize?.width ?? 8.5,
                          'h': v,
                          'unit': st.customSize?.unit ?? 'in',
                        },
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    child: _select<String>(
                      id: 'print.customUnit',
                      value: st.customSize?.unit ?? 'in',
                      values: const ['in', 'cm'],
                      text: (u) => u == 'cm' ? l.printUnitCm : l.printUnitIn,
                      onChanged: (u) => _patch({
                        'customSize': {
                          'w': st.customSize?.width ?? 8.5,
                          'h': st.customSize?.height ?? 11,
                          'unit': u,
                        },
                      }),
                    ),
                  ),
                ],
              ),
            ],
            label(l.printOrientation),
            ShadRadioGroup<PageOrientation>(
              key: ValueKey<String>('print.orientation.${st.orientation.name}'),
              initialValue: st.orientation,
              axis: Axis.horizontal,
              spacing: 16,
              onChanged: (v) {
                if (v != null) _patch({'orientation': v.name});
              },
              items: [
                ShadRadio(
                  key: const ValueKey<String>('print.portrait'),
                  value: PageOrientation.portrait,
                  label: Text(l.printPortrait),
                ),
                ShadRadio(
                  key: const ValueKey<String>('print.landscape'),
                  value: PageOrientation.landscape,
                  label: Text(l.printLandscape),
                ),
              ],
            ),
            label(l.printScale),
            _select<PrintScaleMode>(
              id: 'print.scale',
              value: st.scaleMode,
              values: PrintScaleMode.values,
              text: (m) => switch (m) {
                PrintScaleMode.normal => l.printScaleNormal,
                PrintScaleMode.fitWidth => l.printScaleFitWidth,
                PrintScaleMode.fitHeight => l.printScaleFitHeight,
                PrintScaleMode.fitPage => l.printScaleFitPage,
                PrintScaleMode.custom => l.printScaleCustom,
              },
              onChanged: (m) => _patch({
                'scale': m == PrintScaleMode.custom
                    ? {'mode': 'custom', 'percent': st.scalePercent}
                    : {'mode': m.name},
              }),
            ),
            if (st.scaleMode == PrintScaleMode.custom) ...[
              const SizedBox(height: 8),
              _number(
                'print.scalePercent',
                l.printScalePercent,
                st.scalePercent,
                (v) => _patch({
                  'scale': {'mode': 'custom', 'percent': v.clamp(10, 400)},
                }),
              ),
            ],
            label(l.printMargins),
            _select<MarginPreset>(
              id: 'print.margins',
              value: st.margins.preset,
              values: MarginPreset.values,
              text: (m) => switch (m) {
                MarginPreset.normal => l.printMarginsNormal,
                MarginPreset.narrow => l.printMarginsNarrow,
                MarginPreset.wide => l.printMarginsWide,
                MarginPreset.custom => l.printMarginsCustom,
              },
              onChanged: (m) => _patch({
                'margins': m == MarginPreset.custom
                    ? {
                        'preset': 'custom',
                        'top': st.margins.top,
                        'bottom': st.margins.bottom,
                        'left': st.margins.left,
                        'right': st.margins.right,
                        'unit': st.margins.unit,
                      }
                    : {'preset': m.name},
              }),
            ),
            if (st.margins.preset == MarginPreset.custom) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (key, text, v) in [
                    ('top', l.printMarginTop, st.margins.top),
                    ('bottom', l.printMarginBottom, st.margins.bottom),
                    ('left', l.printMarginLeft, st.margins.left),
                    ('right', l.printMarginRight, st.margins.right),
                  ])
                    SizedBox(
                      width: 150,
                      child: _number(
                        'print.margin.$key',
                        '$text (${st.margins.unit})',
                        v,
                        (x) => _patch({
                          'margins': {
                            ...st.margins.toJson(),
                            key: x.clamp(0, 10),
                          },
                        }),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            ShadAccordion<String>.multiple(
              children: [
                ShadAccordionItem<String>(
                  value: 'formatting',
                  title: Text(l.printFormatting),
                  child: _formatting(context, st, label),
                ),
                ShadAccordionItem<String>(
                  value: 'headers',
                  title: Text(l.printHeadersFooters),
                  child: _headersFooters(context, st, label),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ShadCheckbox(
              key: const ValueKey<String>('print.darkTheme'),
              value: c.darkTheme,
              onChanged: (v) => c.darkTheme = v,
              label: Text(l.printDarkTheme),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (c.scope != PrintScope.workbook && c.persists)
                  ShadButton.outline(
                    key: const ValueKey<String>('print.setBreaks'),
                    leading: const Icon(
                      LucideIcons.separatorHorizontal,
                      size: 16,
                    ),
                    onPressed: () => c.breakMode = true,
                    child: Flexible(
                      child: Text(
                        l.printSetBreaks,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ShadButton.ghost(
                  key: const ValueKey<String>('print.reset'),
                  onPressed: c.reset,
                  child: Text(l.printResetSettings),
                ),
              ],
            ),
          ],
          ..._warnings(context),
        ],
      ),
    );
  }

  List<Widget> _warnings(BuildContext context) {
    final theme = ShadTheme.of(context);
    final warnings = c.pagination?.warnings ?? const [];
    return [
      for (final w in warnings)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ShadAlert(
            key: ValueKey<String>('print.warning.${w.kind.name}'),
            icon: const Icon(LucideIcons.triangleAlert),
            description: Text(w.message, style: theme.textTheme.small),
          ),
        ),
    ];
  }

  Widget _formatting(
    BuildContext context,
    PrintSettings st,
    Widget Function(String) label,
  ) {
    final l = sheetsL10n(context);
    Widget check(String id, String text, bool v, String key) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShadCheckbox(
        key: ValueKey<String>('print.$id'),
        value: v,
        onChanged: (x) => _patch({key: x}),
        label: Text(text),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        check('gridlines', l.printGridlines, st.gridlines, 'gridlines'),
        check('notes', l.printNotes, st.notes, 'notes'),
        check('headings', l.printHeadings, st.headings, 'headings'),
        check(
          'repeatFrozen',
          l.printRepeatFrozen,
          st.repeatFrozen,
          'repeatFrozen',
        ),
        label(l.printPageOrder),
        ShadRadioGroup<PageOrder>(
          key: ValueKey<String>('print.pageOrder.${st.pageOrder.name}'),
          initialValue: st.pageOrder,
          onChanged: (v) {
            if (v != null) _patch({'pageOrder': v.name});
          },
          items: [
            ShadRadio(
              value: PageOrder.downThenOver,
              label: Text(l.printDownThenOver),
            ),
            ShadRadio(
              value: PageOrder.overThenDown,
              label: Text(l.printOverThenDown),
            ),
          ],
        ),
        label(l.printAlignment),
        Row(
          children: [
            Expanded(
              child: _select<PrintHAlign>(
                id: 'print.alignH',
                value: st.hAlign,
                values: PrintHAlign.values,
                text: (a) => switch (a) {
                  PrintHAlign.left => l.printAlignLeft,
                  PrintHAlign.center => l.printAlignCenter,
                  PrintHAlign.right => l.printAlignRight,
                },
                onChanged: (a) => _patch({
                  'align': {'h': a.name, 'v': st.vAlign.name},
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _select<PrintVAlign>(
                id: 'print.alignV',
                value: st.vAlign,
                values: PrintVAlign.values,
                text: (a) => switch (a) {
                  PrintVAlign.top => l.printAlignTop,
                  PrintVAlign.middle => l.printAlignMiddle,
                  PrintVAlign.bottom => l.printAlignBottom,
                },
                onChanged: (a) => _patch({
                  'align': {'h': st.hAlign.name, 'v': a.name},
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _headersFooters(
    BuildContext context,
    PrintSettings st,
    Widget Function(String) label,
  ) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final hf = st.headerFooter;
    final f = hf.flags;
    Widget check(String id, String text, bool v) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShadCheckbox(
        key: ValueKey<String>('print.hf.$id'),
        value: v,
        onChanged: (x) => _patch({
          'headerFooter': {
            'flags': {id: x},
          },
        }),
        label: Text(text),
      ),
    );
    Widget section(String which, String title, HeaderFooterSections sec) {
      final values = {
        'left': sec.left,
        'center': sec.center,
        'right': sec.right,
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(title),
          for (final e in values.entries) ...[
            () {
              final id = 'print.hf.$which.${e.key}';
              _syncField(id, e.value);
              return ShadInput(
                key: ValueKey<String>(id),
                controller: _field(id, e.value),
                placeholder: Text(switch (e.key) {
                  'left' => l.printFieldLeft,
                  'center' => l.printFieldCenter,
                  _ => l.printFieldRight,
                }),
                onSubmitted: (v) => _patch({
                  'headerFooter': {
                    which: {e.key: v},
                  },
                }),
                onEditingComplete: () {
                  final v = _fields[id]!.text;
                  if (v != e.value) {
                    _patch({
                      'headerFooter': {
                        which: {e.key: v},
                      },
                    });
                  }
                },
              );
            }(),
            const SizedBox(height: 6),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        check('pageNumbers', l.printPageNumbers, f.pageNumbers),
        check('title', l.printWorkbookTitle, f.title),
        check('sheetName', l.printSheetName, f.sheetName),
        check('date', l.printCurrentDate, f.date),
        check('time', l.printCurrentTime, f.time),
        label(l.printCustomFields),
        Text(
          '${l.printFieldsHint} {page} {pages} {title} {sheet} {date} {time}',
          style: theme.textTheme.muted.copyWith(fontSize: 12),
        ),
        section('header', l.printHeader, hf.header),
        section('footer', l.printFooter, hf.footer),
        const SizedBox(height: 8),
      ],
    );
  }

  // ------------------------------------------------------------- breaks

  List<Widget> _breaks(BuildContext context, Widget Function(String) label) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final sheet = c.model.sheet(c.sheetId);
    if (sheet == null) return const [];
    final rows = c.draftRowBreaks;
    final cols = c.draftColBreaks;
    String rowLabel(String id) {
      final i = sheet.rows.indexOf(id);
      return i < 0 ? '—' : '${i + 1}';
    }

    String colLabel(String id) {
      final i = sheet.columns.indexOf(id);
      return i < 0 ? '—' : ColumnLetters.fromIndex(i);
    }

    Widget chips(List<String> ids, String Function(String) text) => ids.isEmpty
        ? Text(l.printNoBreaks, style: theme.textTheme.muted)
        : Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in ids)
                ShadBadge.secondary(
                  key: ValueKey<String>('print.break.$id'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(text(id)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => c.setDraftBreaks(
                          rows: identical(ids, rows)
                              ? (rows..remove(id))
                              : null,
                          cols: identical(ids, cols)
                              ? (cols..remove(id))
                              : null,
                        ),
                        child: Semantics(
                          button: true,
                          label: l.printRemoveBreak,
                          child: const Icon(LucideIcons.x, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );

    void addRow() {
      final n = int.tryParse(_breakRow.text.trim());
      if (n == null || n < 2 || n > sheet.rows.length) {
        setState(() => _breakError = l.printInvalidRow(sheet.rows.length));
        return;
      }
      final id = sheet.rows.idAt(n - 1);
      setState(() {
        _breakError = null;
        _breakRow.clear();
      });
      c.setDraftBreaks(rows: [...rows, id]);
    }

    void addCol() {
      final t = _breakCol.text.trim().toUpperCase();
      final i = RegExp(r'^[A-Z]{1,3}$').hasMatch(t)
          ? ColumnLetters.toIndex(t)
          : -1;
      if (i < 1 || i >= sheet.columns.length) {
        setState(() => _breakError = l.printInvalidColumn);
        return;
      }
      final id = sheet.columns.idAt(i);
      setState(() {
        _breakError = null;
        _breakCol.clear();
      });
      c.setDraftBreaks(cols: [...cols, id]);
    }

    Widget adder(
      String id,
      TextEditingController ctl,
      String hint,
      VoidCallback add,
    ) => Row(
      children: [
        Expanded(
          child: ShadInput(
            key: ValueKey<String>(id),
            controller: ctl,
            placeholder: Text(hint),
            onSubmitted: (_) => add(),
          ),
        ),
        const SizedBox(width: 8),
        ShadButton.outline(
          key: ValueKey<String>('$id.add'),
          onPressed: add,
          child: Text(l.printAddBreak),
        ),
      ],
    );

    return [
      const SizedBox(height: 8),
      Text(l.printBreaksTitle, style: theme.textTheme.large),
      const SizedBox(height: 4),
      Text(l.printBreaksHint, style: theme.textTheme.muted),
      label(l.printBreakRows),
      chips(rows, rowLabel),
      const SizedBox(height: 8),
      adder('print.breakRow', _breakRow, l.printBreakRowPlaceholder, addRow),
      label(l.printBreakCols),
      chips(cols, colLabel),
      const SizedBox(height: 8),
      adder('print.breakCol', _breakCol, l.printBreakColPlaceholder, addCol),
      if (_breakError != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _breakError!,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.destructive,
            ),
          ),
        ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ShadButton(
            key: const ValueKey<String>('print.confirmBreaks'),
            onPressed: c.confirmBreaks,
            child: Text(l.printConfirmBreaks),
          ),
          ShadButton.outline(
            key: const ValueKey<String>('print.resetBreaks'),
            onPressed: () => c.setDraftBreaks(rows: const [], cols: const []),
            child: Text(l.printResetBreaks),
          ),
          ShadButton.ghost(
            key: const ValueKey<String>('print.cancelBreaks'),
            onPressed: () => c.breakMode = false,
            child: Text(l.printCancelBreaks),
          ),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------ helpers

  Widget _select<T>({
    required String id,
    required T value,
    required List<T> values,
    required String Function(T) text,
    required void Function(T) onChanged,
  }) => ShadSelect<T>(
    key: ValueKey<String>('$id.$value'),
    initialValue: value,
    minWidth: 120,
    options: [
      for (final v in values)
        ShadOption<T>(
          key: ValueKey<String>('$id.option.$v'),
          value: v,
          child: Text(text(v)),
        ),
    ],
    selectedOptionBuilder: (context, v) =>
        Text(text(v), overflow: TextOverflow.ellipsis),
    onChanged: (v) {
      if (v != null && v != value) onChanged(v);
    },
  );

  Widget _number(
    String id,
    String text,
    double value,
    void Function(double) onCommit,
  ) {
    final s = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    _syncField(id, s);
    final ctl = _field(id, s);
    void commit() {
      final v = double.tryParse(ctl.text.replaceAll(',', '.').trim());
      if (v == null || !v.isFinite || v <= 0) {
        ctl.text = s;
        return;
      }
      if (v != value) onCommit(v);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: ShadTheme.of(context).textTheme.muted),
        const SizedBox(height: 4),
        ShadInput(
          key: ValueKey<String>(id),
          controller: ctl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (_) => commit(),
          onEditingComplete: commit,
        ),
      ],
    );
  }
}
