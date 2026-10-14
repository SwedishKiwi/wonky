import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/sheets_l10n.dart';
import '../../theme/sheets_tokens.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'filter_condition_editor.dart';
import 'filter_controller.dart';

enum _Section { color, condition, valueList }

/// Width of [FilterColumnPopover].
const double kFilterPopoverWidth = 280;

/// The filter column popover (07 §3.5): sort, filter by color, by condition
/// and by values (with search, *Select all* · *Clear*). Changes preview live
/// (local draft); *OK* commits one step, *Cancel*/Esc discards.
class FilterColumnPopover extends StatefulWidget {
  const FilterColumnPopover({
    super.key,
    required this.editor,
    required this.filters,
    required this.filter,
    required this.colId,
    required this.onClose,
    this.maxHeight = 520,
  });

  final SheetEditorController editor;
  final FilterController filters;
  final EffectiveFilter filter;
  final String colId;
  final VoidCallback onClose;
  final double maxHeight;

  @override
  State<FilterColumnPopover> createState() => _FilterColumnPopoverState();
}

class _FilterColumnPopoverState extends State<FilterColumnPopover> {
  static const _maxListed = 1000;

  SheetEditorController get ed => widget.editor;
  FilterController get filters => widget.filters;
  EffectiveFilter get f => widget.filter;

  late final int _col = ed.model
      .sheet(f.sheetId)!
      .columns
      .indexOf(widget.colId);
  late final ColumnCriteria? _initial = filters.criteriaOf(f, widget.colId);
  late final Set<String> _hidden = {...?_initial?.hiddenValues};
  late List<ChecklistEntry> _entries;
  late ({List<String> fills, List<String> texts}) _colors;
  late String? _fill = _initial?.visibleBackgroundColor;
  late String? _text = _initial?.visibleForegroundColor;
  late Condition? _condition = _initial?.condition;
  late _Section _open = _initial?.condition != null
      ? _Section.condition
      : (_initial?.hasColor ?? false)
      ? _Section.color
      : _Section.valueList;
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'filter.search');
  final _scroll = ScrollController();
  final _listScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _entries = filters.checklist(f, _col);
    _colors = filters.colorsOf(f, _col);
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open == _Section.valueList) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  ColumnCriteria? get _draft {
    final c = ColumnCriteria(
      hiddenValues: _hidden,
      condition: _condition,
      visibleBackgroundColor: _fill,
      visibleForegroundColor: _text,
    );
    return c.isEmpty ? null : c;
  }

  void _preview() {
    filters.setDraft(FilterDraft(f.sheetId, f.viewId, widget.colId, _draft));
    setState(() {});
  }

  void _cancel() {
    filters.clearDraft();
    widget.onClose();
  }

  Future<void> _ok() async {
    final c = _draft;
    filters.clearDraft();
    widget.onClose();
    if (!ed.canEdit && !f.isView) {
      // Viewers filter in a temporary view (07 §3.6).
      final view = filters.createTemporary(
        f.sheetId,
        ed.model.sheet(f.sheetId)!.gridRange(f.range),
        criteria: f.criteria,
      );
      filters.updateTemporary(
        view.id,
        criteria: f.criteria.withColumn(widget.colId, c),
      );
      return;
    }
    final args = <String, Object?>{
      'colId': widget.colId,
      'criteria': c?.toJson(),
      if (f.isView) 'viewId': f.viewId,
    };
    unawaited(
      ed.invokeCommand(
        f.isView
            ? 'sheets.filterView.setColumnCriteria'
            : 'sheets.filter.setColumnCriteria',
        args,
      ),
    );
  }

  bool _sortColorOpen = false;

  /// Sort by color (07 §3.5, P2): rows with [fill] / [text] color first.
  void _sortColor({String? fill, String? text}) {
    filters.clearDraft();
    widget.onClose();
    unawaited(
      ed.invokeCommand('sheets.filter.sortColumn', {
        'colId': widget.colId,
        'fillColor': ?fill,
        'textColor': ?text,
      }),
    );
  }

  Widget _sortColorSection(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    Widget group(String title, List<String> colors, bool fill) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.muted.copyWith(fontSize: 12)),
        const SizedBox(height: 6),
        if (colors.isEmpty)
          Text(l.filterNoColors, style: theme.textTheme.small)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in colors)
                _Swatch(
                  key: ValueKey<String>(
                    'filter.sortColor.${fill ? 'fill' : 'text'}.$c',
                  ),
                  color: hexToColor(c) ?? const Color(0x00000000),
                  label: c,
                  selected: false,
                  onTap: () => fill ? _sortColor(fill: c) : _sortColor(text: c),
                ),
            ],
          ),
        const SizedBox(height: 8),
      ],
    );
    return Padding(
      key: const ValueKey<String>('filter.sortColor.section'),
      padding: const EdgeInsets.fromLTRB(36, 2, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          group(l.filterFillColor, _colors.fills, true),
          group(l.filterTextColor, _colors.texts, false),
        ],
      ),
    );
  }

  void _sort(bool ascending) {
    filters.clearDraft();
    widget.onClose();
    unawaited(
      // In a filter view the sort is view-only (07 §4.4).
      f.isView
          ? ed.invokeCommand('sheets.filterView.sortColumn', {
              'viewId': f.viewId,
              'colId': widget.colId,
              'ascending': ascending,
            })
          : ed.invokeCommand('sheets.filter.sortColumn', {
              'colId': widget.colId,
              'ascending': ascending,
            }),
    );
  }

  List<ChecklistEntry> get _visibleEntries {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return [
      for (final e in _entries)
        if (e.text.toLowerCase().contains(q)) e,
    ];
  }

  void _setAll(bool visible) {
    for (final e in _visibleEntries) {
      visible ? _hidden.remove(e.text) : _hidden.add(e.text);
    }
    _preview();
  }

  KeyEventResult _keys(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter &&
        (_searchFocus.hasFocus ||
            HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed)) {
      unawaited(_ok());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final canSort = f.isView ? (f.temporary || ed.canEdit) : ed.canEdit;
    return Focus(
      onKeyEvent: _keys,
      child: SizedBox(
        width: kFilterPopoverWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: Column(
            key: const ValueKey<String>('filter.popover'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MenuRow(
                keyName: 'filter.sortAsc',
                icon: LucideIcons.arrowDownAZ,
                label: l.sortAtoZ,
                enabled: canSort,
                onTap: () => _sort(true),
              ),
              _MenuRow(
                keyName: 'filter.sortDesc',
                icon: LucideIcons.arrowDownZA,
                label: l.sortZtoA,
                enabled: canSort,
                onTap: () => _sort(false),
              ),
              _MenuRow(
                keyName: 'filter.sortByColor',
                icon: LucideIcons.palette,
                label: l.filterSortByColor,
                enabled:
                    canSort &&
                    !f.isView &&
                    (_colors.fills.isNotEmpty || _colors.texts.isNotEmpty),
                tooltip: f.isView ? l.filterViewSortUnavailable : null,
                onTap: () => setState(() => _sortColorOpen = !_sortColorOpen),
              ),
              if (_sortColorOpen) _sortColorSection(context),
              const ShadSeparator.horizontal(
                margin: EdgeInsets.symmetric(vertical: 4),
              ),
              Flexible(
                child: WonkyScrollArea(
                  controller: _scroll,
                  // The sections scroll (and clip) when they don't fit: the
                  // value list of a big column overflowed onto the buttons.
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(
                          _Section.color,
                          l.filterByColor,
                          active: _fill != null || _text != null,
                        ),
                        if (_open == _Section.color) _colorSection(context),
                        _header(
                          _Section.condition,
                          l.filterByCondition,
                          active: _condition != null,
                        ),
                        if (_open == _Section.condition)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                            child: FilterConditionEditor(
                              editor: ed,
                              sheetId: f.sheetId,
                              anchorRow: f.dataTop,
                              anchorCol: _col,
                              initial: _condition,
                              onChanged: (c) {
                                _condition = c;
                                _preview();
                              },
                            ),
                          ),
                        _header(
                          _Section.valueList,
                          l.filterByValues,
                          active: _hidden.isNotEmpty,
                        ),
                        if (_open == _Section.valueList)
                          _valuesSection(context),
                      ],
                    ),
                  ),
                ),
              ),
              const ShadSeparator.horizontal(margin: EdgeInsets.only(top: 4)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ShadButton.outline(
                      key: const ValueKey<String>('filter.cancel'),
                      size: ShadButtonSize.sm,
                      onPressed: _cancel,
                      child: Text(la.actionCancel),
                    ),
                    const SizedBox(width: 8),
                    ShadButton(
                      key: const ValueKey<String>('filter.ok'),
                      size: ShadButtonSize.sm,
                      onPressed: () => unawaited(_ok()),
                      child: Text(la.actionOk),
                    ),
                  ],
                ),
              ),
              if (!ed.canEdit && !f.isView)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Text(
                    l.filterViewerHint,
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(_Section s, String label, {required bool active}) {
    final theme = ShadTheme.of(context);
    final open = _open == s;
    return Semantics(
      button: true,
      expanded: open,
      label: label,
      child: ShadButton.ghost(
        key: ValueKey<String>('filter.section.${s.name}'),
        size: ShadButtonSize.sm,
        width: double.infinity,
        mainAxisAlignment: MainAxisAlignment.start,
        onPressed: () => setState(() => _open = s),
        leading: Icon(
          open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
          size: 16,
        ),
        trailing: active
            ? Icon(
                LucideIcons.funnel,
                size: 14,
                color: theme.colorScheme.primary,
              )
            : null,
        child: Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: theme.textTheme.small.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorSection(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    Widget group(
      String title,
      List<String> colors,
      String? selected,
      ValueChanged<String?> pick,
      String keyName,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.muted.copyWith(fontSize: 12)),
        const SizedBox(height: 6),
        if (colors.isEmpty)
          Text(l.filterNoColors, style: theme.textTheme.small)
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in colors)
                _Swatch(
                  key: ValueKey<String>('filter.$keyName.$c'),
                  color: hexToColor(c) ?? const Color(0x00000000),
                  label: c,
                  selected: selected?.toUpperCase() == c,
                  onTap: () => pick(selected?.toUpperCase() == c ? null : c),
                ),
            ],
          ),
        const SizedBox(height: 10),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          group(l.filterFillColor, _colors.fills, _fill, (c) {
            _fill = c;
            _preview();
          }, 'fill'),
          group(l.filterTextColor, _colors.texts, _text, (c) {
            _text = c;
            _preview();
          }, 'text'),
        ],
      ),
    );
  }

  Widget _valuesSection(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final all = _visibleEntries;
    final listed = all.length > _maxListed ? all.sublist(0, _maxListed) : all;
    final visible = [
      for (final e in listed)
        if (!e.hiddenByOthers) e,
    ];
    final others = [
      for (final e in listed)
        if (e.hiddenByOthers) e,
    ];
    final rows = <Widget>[
      for (final e in visible) _valueRow(e),
      if (others.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text(
            l.filterHiddenByOthers,
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
        ),
      for (final e in others) _valueRow(e),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Link(
                keyName: 'filter.selectAll',
                label: l.filterSelectAll(all.length),
                onTap: () => _setAll(true),
              ),
              Text(' · ', style: theme.textTheme.muted),
              _Link(
                keyName: 'filter.clear',
                label: l.filterClear,
                onTap: () => _setAll(false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ShadInput(
            key: const ValueKey<String>('filter.search'),
            controller: _search,
            focusNode: _searchFocus,
            placeholder: Text(l.filterSearch),
            leading: Icon(
              LucideIcons.search,
              size: 14,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: (rows.length * 28.0).clamp(28, 220),
            child: rows.isEmpty
                ? Center(
                    child: Text(l.filterNoValues, style: theme.textTheme.muted),
                  )
                : ListView(
                    controller: _listScroll,
                    itemExtent: 28,
                    children: rows,
                  ),
          ),
          if (all.length > _maxListed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.filterShowingOf(_maxListed, all.length),
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _valueRow(ChecklistEntry e) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final checked = !_hidden.contains(e.text);
    final label = e.text.isEmpty ? l.filterBlanks : e.text;
    final muted = e.hiddenByOthers;
    return Semantics(
      checked: checked,
      label: label,
      child: Row(
        children: [
          Expanded(
            child: ShadCheckbox(
              key: ValueKey<String>('filter.value.${e.text}'),
              value: checked,
              onChanged: (v) {
                v ? _hidden.remove(e.text) : _hidden.add(e.text);
                _preview();
              },
              label: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted
                    ? theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      )
                    : theme.textTheme.small,
              ),
            ),
          ),
          Text(
            '${e.count}',
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.keyName,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.tooltip,
  });

  final String keyName;
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final b = ShadButton.ghost(
      key: ValueKey<String>(keyName),
      size: ShadButtonSize.sm,
      width: double.infinity,
      mainAxisAlignment: MainAxisAlignment.start,
      enabled: enabled,
      leading: Icon(icon, size: 16),
      onPressed: onTap,
      child: Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.start,
        ),
      ),
    );
    if (tooltip == null) return b;
    return ShadTooltip(builder: (_) => Text(tooltip!), child: b);
  }
}

class _Link extends StatelessWidget {
  const _Link({
    required this.keyName,
    required this.label,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey<String>(keyName),
        onTap: onTap,
        child: Text(
          label,
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    return ShadTooltip(
      builder: (_) => Text(label),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: selected ? cs.primary : cs.border,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
