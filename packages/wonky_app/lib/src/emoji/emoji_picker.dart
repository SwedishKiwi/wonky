import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../shell/anchored_popover.dart';
import 'emoji_catalog.dart';
import 'emoji_prefs.dart';

/// Stable widget keys of the emoji picker (suite 15 §7).
abstract final class EmojiPickerKeys {
  static const picker = ValueKey<String>('write.emoji.picker');
  static const dialog = ValueKey<String>('write.dialog.emoji');
  static const search = ValueKey<String>('write.emoji.search');
  static const grid = ValueKey<String>('write.emoji.grid');
  static const preview = ValueKey<String>('write.emoji.preview');
  static const skinTone = ValueKey<String>('write.emoji.skinTone');
  static const tabRecent = ValueKey<String>('write.emoji.tab.recent');
  static const empty = ValueKey<String>('write.emoji.empty');
  static const suggestions = ValueKey<String>('write.emoji.suggestions');

  /// Category tab (`EmojiCategory.id`).
  static ValueKey<String> tab(String id) =>
      ValueKey<String>('write.emoji.tab.$id');

  /// Grid cell of the emoji whose base (untoned) char is [char].
  static ValueKey<String> cell(String char) =>
      ValueKey<String>('write.emoji.cell.$char');

  /// Cell in the "Recently used" section (the stored string).
  static ValueKey<String> recent(String char) =>
      ValueKey<String>('write.emoji.recent.$char');

  /// Skin tone option 0..5.
  static ValueKey<String> skinToneOption(int tone) =>
      ValueKey<String>('write.emoji.skinTone.$tone');

  /// Row [index] of [EmojiSuggestionList].
  static ValueKey<String> suggestion(int index) =>
      ValueKey<String>('write.emoji.suggestion.$index');
}

/// Shows [WonkyEmojiPicker] in a dialog (or, with [anchor] in global
/// coordinates, a popover below it) and closes it after an emoji is chosen.
Future<void> showEmojiPickerDialog(
  BuildContext context, {
  required void Function(String emoji) onSelected,
  EmojiPrefs? prefs,
  Rect? anchor,
  EmojiCatalog? catalog,
}) {
  Widget picker(BuildContext ctx) => WonkyEmojiPicker(
    prefs: prefs,
    catalog: catalog,
    onSelected: (e) {
      Navigator.of(ctx).pop();
      onSelected(e);
    },
    onClose: () => Navigator.of(ctx).maybePop(),
  );
  if (anchor != null) {
    return showAnchoredPopoverAt<void>(
      context,
      anchor: anchor,
      width: _pickerWidth,
      barrierLabel: 'Close emoji picker',
      builder: (ctx) => SizedBox(
        height: math.min(_pickerHeight, MediaQuery.sizeOf(ctx).height - 32),
        child: picker(ctx),
      ),
    );
  }
  return showShadDialog<void>(
    context: context,
    builder: (ctx) => ShadDialog(
      key: EmojiPickerKeys.dialog,
      semanticLabel: 'Emoji',
      closeIcon: const SizedBox.shrink(),
      padding: EdgeInsets.zero,
      scrollable: false,
      constraints: const BoxConstraints(maxWidth: _pickerWidth),
      child: SizedBox(
        width: math.min(_pickerWidth, MediaQuery.sizeOf(ctx).width - 32),
        height: math.min(_pickerHeight, MediaQuery.sizeOf(ctx).height - 48),
        child: picker(ctx),
      ),
    ),
  );
}

const _pickerWidth = 360.0;
const _pickerHeight = 420.0;
const _cellExtent = 36.0;
const _headerExtent = 28.0;
const _searchLimit = 240;

/// Emoji picker (Write 04 §20.1): search, category tabs with "Recently used"
/// first, a virtualized grid, skin tone selector and a preview row.
///
/// Keyboard: the search field has focus; ↓ moves into the grid, arrows move
/// the highlight, Enter (in the field or the grid) chooses, typing in the grid
/// goes back to the search, Esc calls [onClose].
class WonkyEmojiPicker extends StatefulWidget {
  const WonkyEmojiPicker({
    super.key,
    required this.onSelected,
    this.prefs,
    this.onClose,
    this.initialQuery = '',
    this.catalog,
    this.bundle,
  });

  /// Called with the chosen emoji (skin tone applied). The pick has already
  /// been recorded in [prefs].
  final void Function(String emoji) onSelected;

  /// Recents and skin tone; an in-memory instance when `null`.
  final EmojiPrefs? prefs;
  final VoidCallback? onClose;
  final String initialQuery;

  /// Preloaded catalog (tests); otherwise loaded from [bundle] or the
  /// ambient [DefaultAssetBundle].
  final EmojiCatalog? catalog;
  final AssetBundle? bundle;

  @override
  State<WonkyEmojiPicker> createState() => _WonkyEmojiPickerState();
}

/// One rendered grid cell.
class _Cell {
  const _Cell(this.text, this.emoji, this.recent);

  /// The string inserted (skin tone applied).
  final String text;
  final Emoji? emoji;
  final bool recent;

  String get name => emoji?.name ?? text;
}

/// A list row: a section header or a row of cells.
class _Row {
  _Row.header(this.title, this.section) : cells = const [], start = -1;
  _Row.cells(this.cells, this.start, this.section) : title = null;

  final String? title;
  final List<_Cell> cells;

  /// Flat index of the first cell.
  final int start;

  /// -1 = recent, 0.. = category index.
  final int section;

  bool get isHeader => title != null;
  double get extent => isHeader ? _headerExtent : _cellExtent;
}

class _WonkyEmojiPickerState extends State<WonkyEmojiPicker> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  final _searchFocus = FocusNode(debugLabel: 'emoji.search');
  final _gridFocus = FocusNode(debugLabel: 'emoji.grid');
  final _scroll = ScrollController();
  final _skinPopover = ShadPopoverController();

  EmojiPrefs? _ownPrefs;
  EmojiPrefs get _prefs => widget.prefs ?? (_ownPrefs ??= EmojiPrefs());

  EmojiCatalog? _catalog;
  Object? _loadError;

  // Layout derived from (catalog, query, recents, columns, tone).
  List<_Row> _rows = const [];
  List<double> _offsets = const [];
  List<int> _rowOfCell = const [];
  List<_Cell> _cells = const [];
  Object? _layoutKey;

  int _active = 0;
  int? _hover;
  int _columns = 9;
  int _section = -1;

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalog;
    _prefs.addListener(_onPrefs);
    if (!_prefs.loaded) _prefs.load();
    _scroll.addListener(_onScroll);
    _gridFocus.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_catalog == null && _loadError == null) {
      final bundle = widget.bundle ?? DefaultAssetBundle.of(context);
      EmojiCatalog.load(bundle).then(
        (c) {
          if (mounted) setState(() => _catalog = c);
        },
        onError: (Object e) {
          if (mounted) setState(() => _loadError = e);
        },
      );
    }
  }

  @override
  void didUpdateWidget(WonkyEmojiPicker old) {
    super.didUpdateWidget(old);
    if (old.prefs != widget.prefs) {
      (old.prefs ?? _ownPrefs)?.removeListener(_onPrefs);
      _prefs.addListener(_onPrefs);
    }
    if (widget.catalog != null && widget.catalog != old.catalog) {
      _catalog = widget.catalog;
    }
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefs);
    _ownPrefs?.dispose();
    _query.dispose();
    _searchFocus.dispose();
    _gridFocus.dispose();
    _scroll.dispose();
    _skinPopover.dispose();
    super.dispose();
  }

  void _onPrefs() {
    if (mounted) setState(() {});
  }

  bool get _searching => _query.text.trim().isNotEmpty;

  // ---------------------------------------------------------------- layout

  void _layout(int columns) {
    final catalog = _catalog;
    if (catalog == null) return;
    final key = (
      catalog,
      _query.text.trim(),
      _prefs.recent,
      _prefs.skinTone,
      columns,
    );
    if (key == _layoutKey) return;
    _layoutKey = key;
    final tone = _prefs.skinTone;
    final rows = <_Row>[];
    final cells = <_Cell>[];
    final rowOfCell = <int>[];

    void addSection(String? title, int section, Iterable<_Cell> items) {
      final list = items.toList();
      if (list.isEmpty) return;
      if (title != null) rows.add(_Row.header(title, section));
      for (var i = 0; i < list.length; i += columns) {
        final chunk = list.sublist(i, math.min(i + columns, list.length));
        final start = cells.length;
        rows.add(_Row.cells(chunk, start, section));
        cells.addAll(chunk);
        for (var j = 0; j < chunk.length; j++) {
          rowOfCell.add(rows.length - 1);
        }
      }
    }

    if (_searching) {
      addSection(null, 0, [
        for (final e in catalog.search(_query.text, limit: _searchLimit))
          _Cell(e.withSkinTone(tone), e, false),
      ]);
    } else {
      addSection('Recently used', -1, [
        for (final r in _prefs.recent) _Cell(r, catalog.byChar(r), true),
      ]);
      for (var c = 0; c < catalog.categories.length; c++) {
        addSection(catalog.categories[c].name, c, [
          for (final e in catalog.inCategory(c))
            _Cell(e.withSkinTone(tone), e, false),
        ]);
      }
    }
    final offsets = <double>[];
    var y = 0.0;
    for (final r in rows) {
      offsets.add(y);
      y += r.extent;
    }
    _rows = rows;
    _cells = cells;
    _rowOfCell = rowOfCell;
    _offsets = offsets;
    if (_active >= cells.length) _active = math.max(0, cells.length - 1);
    if (_hover != null && _hover! >= cells.length) _hover = null;
  }

  void _onScroll() {
    if (_searching || _rows.isEmpty) return;
    final y = _scroll.offset + 1;
    var section = _rows.first.section;
    for (var i = 0; i < _rows.length; i++) {
      if (_offsets[i] > y) break;
      section = _rows[i].section;
    }
    if (section != _section) setState(() => _section = section);
  }

  void _jumpToSection(int section) {
    if (_searching) {
      _query.clear();
      _layoutKey = null;
      setState(() {});
      // The rows are rebuilt on the next frame; jump after layout.
      WidgetsBinding.instance.addPostFrameCallback((_) => _jump(section));
      return;
    }
    _jump(section);
  }

  void _jump(int section) {
    if (!mounted) return;
    final i = _rows.indexWhere((r) => r.section == section);
    if (i < 0) {
      if (section == -1 && _scroll.hasClients) _scroll.jumpTo(0);
      setState(() => _section = section);
      return;
    }
    if (_scroll.hasClients) {
      final max = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(math.min(_offsets[i], max));
    }
    final firstCell = i + 1 < _rows.length ? _rows[i + 1].start : -1;
    setState(() {
      _section = section;
      if (firstCell >= 0) _active = firstCell;
    });
  }

  // -------------------------------------------------------------- keyboard

  void _choose(_Cell cell) {
    _prefs.recordUse(cell.text);
    widget.onSelected(cell.text);
  }

  void _chooseActive() {
    if (_cells.isEmpty) return;
    _choose(_cells[_active.clamp(0, _cells.length - 1)]);
  }

  void _setActive(int index) {
    if (_cells.isEmpty) return;
    final i = index.clamp(0, _cells.length - 1);
    setState(() => _active = i);
    _ensureVisible(_rowOfCell[i]);
  }

  void _ensureVisible(int row) {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    var top = _offsets[row];
    // Keep the section header visible when moving onto a section's first row.
    if (row > 0 && _rows[row - 1].isHeader) top = _offsets[row - 1];
    final bottom = _offsets[row] + _rows[row].extent;
    if (top < pos.pixels) {
      _scroll.jumpTo(top.clamp(0, pos.maxScrollExtent));
    } else if (bottom > pos.pixels + pos.viewportDimension) {
      _scroll.jumpTo(
        (bottom - pos.viewportDimension).clamp(0, pos.maxScrollExtent),
      );
    }
  }

  /// Moves the highlight one row up (-1) or down (+1), keeping the column.
  /// Returns false at the top/bottom edge.
  bool _moveRow(int delta) {
    if (_cells.isEmpty) return false;
    final row = _rowOfCell[_active];
    final col = _active - _rows[row].start;
    var r = row + delta;
    while (r >= 0 && r < _rows.length && _rows[r].isHeader) {
      r += delta;
    }
    if (r < 0 || r >= _rows.length) return false;
    final target = _rows[r];
    _setActive(target.start + math.min(col, target.cells.length - 1));
    return true;
  }

  KeyEventResult _onGridKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _setActive(_active - 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _setActive(_active + 1);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveRow(1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (!_moveRow(-1)) _searchFocus.requestFocus();
    } else if (key == LogicalKeyboardKey.home) {
      _setActive(0);
    } else if (key == LogicalKeyboardKey.end) {
      _setActive(_cells.length - 1);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _chooseActive();
    } else if (key == LogicalKeyboardKey.backspace) {
      _searchFocus.requestFocus();
      final t = _query.text;
      if (t.isNotEmpty) _setQuery(t.characters.skipLast(1).toString());
    } else {
      final ch = event.character;
      final printable =
          ch != null &&
          ch.isNotEmpty &&
          ch.runes.every((r) => r >= 0x20 && r != 0x7F) &&
          !HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isMetaPressed;
      if (!printable) return KeyEventResult.ignored;
      _searchFocus.requestFocus();
      _setQuery(_query.text + ch);
    }
    return KeyEventResult.handled;
  }

  void _setQuery(String text) {
    _query.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _onQueryChanged();
  }

  void _onQueryChanged() {
    setState(() {
      _active = 0;
      _hover = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && _cells.isNotEmpty) {
      _gridFocus.requestFocus();
      _ensureVisible(_rowOfCell[_active]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onRootKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        widget.onClose != null) {
      if (_skinPopover.isOpen) {
        _skinPopover.hide();
      } else {
        widget.onClose!();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    _layout(_columns);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onRootKey,
      child: Semantics(
        key: EmojiPickerKeys.picker,
        container: true,
        label: 'Emoji picker',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: _onSearchKey,
                      child: ShadInput(
                        key: EmojiPickerKeys.search,
                        controller: _query,
                        focusNode: _searchFocus,
                        autofocus: true,
                        placeholder: const Text('Search emoji'),
                        leading: Icon(
                          LucideIcons.search,
                          size: 16,
                          color: cs.mutedForeground,
                        ),
                        onChanged: (_) => _onQueryChanged(),
                        onSubmitted: (_) {
                          _chooseActive();
                          if (mounted) _searchFocus.requestFocus();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _skinToneButton(context),
                ],
              ),
            ),
            if (_catalog != null) _tabs(context),
            ShadSeparator.horizontal(margin: EdgeInsets.zero, color: cs.border),
            Expanded(child: _body(context)),
            ShadSeparator.horizontal(margin: EdgeInsets.zero, color: cs.border),
            _preview(context),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = ShadTheme.of(context);
    final muted = theme.textTheme.muted;
    if (_loadError != null) {
      return Center(child: Text('Emoji could not be loaded', style: muted));
    }
    if (_catalog == null) {
      return const Center(child: ShadSpinner(size: 20));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          ((constraints.maxWidth - 8) / _cellExtent).floor(),
        );
        if (columns != _columns) {
          _columns = columns;
          _layout(columns);
          // The preview row was built with the previous layout.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        }
        if (_rows.isEmpty) {
          return Center(
            key: EmojiPickerKeys.empty,
            child: Text(
              _searching ? 'No emoji found' : 'No emoji',
              style: muted,
            ),
          );
        }
        return Focus(
          focusNode: _gridFocus,
          onKeyEvent: _onGridKey,
          child: Semantics(
            label: _searching ? 'Search results' : 'Emoji',
            child: ListView.builder(
              key: EmojiPickerKeys.grid,
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _rows.length,
              itemExtentBuilder: (i, _) =>
                  i < _rows.length ? _rows[i].extent : null,
              itemBuilder: (context, i) => _row(context, _rows[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, _Row row) {
    final theme = ShadTheme.of(context);
    if (row.isHeader) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Text(
          row.title!,
          style: theme.textTheme.small.copyWith(
            fontSize: 12,
            color: theme.colorScheme.mutedForeground,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Row(
      children: [
        for (var j = 0; j < row.cells.length; j++)
          _EmojiCell(
            key: row.cells[j].recent
                ? EmojiPickerKeys.recent(row.cells[j].text)
                : EmojiPickerKeys.cell(row.cells[j].emoji!.char),
            cell: row.cells[j],
            active: row.start + j == _active,
            highlighted:
                row.start + j == _active && (_gridFocus.hasFocus || _searching),
            hovered: row.start + j == _hover,
            focused: _gridFocus.hasFocus && row.start + j == _active,
            onTap: () {
              setState(() => _active = row.start + j);
              _choose(row.cells[j]);
            },
            onHover: (inside) {
              final index = row.start + j;
              if (inside) {
                setState(() => _hover = index);
              } else if (_hover == index) {
                setState(() => _hover = null);
              }
            },
          ),
      ],
    );
  }

  Widget _tabs(BuildContext context) {
    final catalog = _catalog!;
    final cs = ShadTheme.of(context).colorScheme;
    Widget tab({
      required Key key,
      required String label,
      required Widget icon,
      required int section,
    }) {
      final selected = !_searching && _section == section;
      return Expanded(
        child: ShadTooltip(
          builder: (_) => Text(label),
          child: ShadIconButton.ghost(
            key: key,
            semanticLabel: label,
            width: 32,
            height: 32,
            padding: EdgeInsets.zero,
            backgroundColor: selected ? cs.accent : null,
            icon: icon,
            onPressed: () => _jumpToSection(section),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      child: Row(
        children: [
          tab(
            key: EmojiPickerKeys.tabRecent,
            label: 'Recently used',
            icon: Icon(LucideIcons.clock, size: 16, color: cs.foreground),
            section: -1,
          ),
          for (var c = 0; c < catalog.categories.length; c++)
            tab(
              key: EmojiPickerKeys.tab(catalog.categories[c].id),
              label: catalog.categories[c].name,
              icon: _EmojiGlyph(catalog.categories[c].icon, size: 16),
              section: c,
            ),
        ],
      ),
    );
  }

  Widget _skinToneButton(BuildContext context) {
    final tone = _prefs.skinTone;
    final hand = Emoji(
      char: '✋',
      name: 'raised hand',
      category: 0,
      derivedSkinTones: true,
    );
    return ShadPopover(
      controller: _skinPopover,
      padding: const EdgeInsets.all(4),
      popover: (context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var t = 0; t <= 5; t++)
            ShadIconButton.ghost(
              key: EmojiPickerKeys.skinToneOption(t),
              semanticLabel: '${skinToneNames[t]} skin tone',
              width: 32,
              height: 32,
              padding: EdgeInsets.zero,
              backgroundColor: t == tone
                  ? ShadTheme.of(context).colorScheme.accent
                  : null,
              icon: _EmojiGlyph(hand.withSkinTone(t), size: 18),
              onPressed: () {
                _prefs.skinTone = t;
                _skinPopover.hide();
                _searchFocus.requestFocus();
              },
            ),
        ],
      ),
      child: ShadTooltip(
        builder: (_) => Text('Skin tone: ${skinToneNames[tone]}'),
        child: ShadIconButton.ghost(
          key: EmojiPickerKeys.skinTone,
          semanticLabel: 'Skin tone: ${skinToneNames[tone]}',
          width: 36,
          height: 36,
          padding: EdgeInsets.zero,
          icon: _EmojiGlyph(hand.withSkinTone(tone), size: 18),
          onPressed: _skinPopover.toggle,
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final index =
        _hover ?? (_gridFocus.hasFocus || _searching ? _active : null);
    final cell = index != null && index < _cells.length ? _cells[index] : null;
    final shortcode = cell?.emoji?.shortcodes.firstOrNull;
    return SizedBox(
      key: EmojiPickerKeys.preview,
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: cell == null
            ? Align(
                alignment: Alignment.centerLeft,
                child: Text('Pick an emoji', style: theme.textTheme.muted),
              )
            : Row(
                children: [
                  ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: 32,
                      child: _EmojiGlyph(cell.text, size: 26),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _capitalize(cell.name),
                          style: theme.textTheme.small,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (shortcode != null)
                          Text(
                            ':$shortcode:',
                            style: theme.textTheme.small.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: cs.mutedForeground,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// An emoji scaled down to fit its box (a font without a glyph for a ZWJ
/// sequence renders several glyphs).
class _EmojiGlyph extends StatelessWidget {
  const _EmojiGlyph(this.text, {required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size * 1.35,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size, height: 1.15),
      ),
    ),
  );
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({
    super.key,
    required this.cell,
    required this.active,
    required this.highlighted,
    required this.hovered,
    required this.focused,
    required this.onTap,
    required this.onHover,
  });

  final _Cell cell;
  final bool active;
  final bool highlighted;
  final bool hovered;
  final bool focused;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      selected: active,
      label: cell.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: _cellExtent,
            height: _cellExtent,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: highlighted
                  ? cs.accent
                  : hovered
                  ? cs.muted
                  : null,
              borderRadius: theme.radius,
              border: focused ? Border.all(color: cs.ring, width: 2) : null,
            ),
            child: ExcludeSemantics(child: _EmojiGlyph(cell.text, size: 22)),
          ),
        ),
      ),
    );
  }
}

/// Compact list for the `:` shortcode trigger in the editor (Write 04 §20.1
/// P2): up to [maxRows] [matches], the [highlighted] row marked. It never
/// takes focus — the editor keeps it and drives [highlighted] with ↑/↓ and
/// calls [onChoose] on Enter/Tab itself; a click calls [onChoose] here.
class EmojiSuggestionList extends StatelessWidget {
  const EmojiSuggestionList({
    super.key,
    required this.matches,
    required this.highlighted,
    required this.onChoose,
    this.skinTone = 0,
    this.maxRows = 8,
    this.width = 280,
  });

  final List<Emoji> matches;
  final int highlighted;

  /// Called with the emoji to insert ([skinTone] applied).
  final void Function(String emoji) onChoose;
  final int skinTone;
  final int maxRows;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final shown = matches.take(maxRows).toList();
    return ExcludeFocus(
      child: Container(
        key: EmojiPickerKeys.suggestions,
        width: width,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cs.popover,
          borderRadius: theme.radius,
          border: Border.all(color: cs.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++)
              _suggestionRow(context, i, shown[i]),
          ],
        ),
      ),
    );
  }

  Widget _suggestionRow(BuildContext context, int i, Emoji e) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final selected = i == highlighted;
    final text = e.withSkinTone(skinTone);
    final code = e.shortcodes.firstOrNull;
    return Semantics(
      key: EmojiPickerKeys.suggestion(i),
      button: true,
      selected: selected,
      label: e.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChoose(text),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? cs.accent : null,
              borderRadius: theme.radius,
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 24,
                    child: _EmojiGlyph(text, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (code != null)
                            TextSpan(
                              text: ':$code:  ',
                              style: TextStyle(
                                color: selected
                                    ? cs.accentForeground
                                    : cs.popoverForeground,
                              ),
                            ),
                          TextSpan(
                            text: e.name,
                            style: TextStyle(color: cs.mutedForeground),
                          ),
                        ],
                      ),
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
