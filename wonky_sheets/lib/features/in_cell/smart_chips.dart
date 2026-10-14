import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide RichText;
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import '../formatting/cell_fonts.dart';
import '../grid/paint/grid_layer.dart';
import '../grid/paint/text_layout_cache.dart';
import '../protection/file_editors.dart';
import '../protection/protection_dialogs.dart' show ProtectionEditorOption;
import 'cell_cards.dart' show CellPopoverSurface;
import 'in_cell_controller.dart';
import 'in_cell_paint.dart' show neutralChipColors;

/// `yyyy-mm-dd` of [d] (typed input that parses as a date everywhere).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A people smart chip (03 §14.3): rich text whose single run carries
/// `{"chip": {"kind": "person", "email": …, "userId": …}}`.
@immutable
class PersonChip {
  const PersonChip({required this.email, required this.name, this.userId});

  final String email;
  final String name;
  final String? userId;

  /// The cell content of the chip.
  RichTextContent get content => RichTextContent(
    RichText(name, [
      RichRun(0, name.length, {
        RichRunKeys.chip: {'kind': 'person', 'email': email, 'userId': ?userId},
      }),
    ]),
  );

  /// The person chip of a cell's content, or null.
  static PersonChip? of(CellContent? content) {
    if (content is! RichTextContent) return null;
    final rich = content.rich;
    if (rich.runs.length != 1) return null;
    final chip = rich.runs.single.format[RichRunKeys.chip];
    if (chip is! Map || chip['kind'] != 'person') return null;
    final email = chip['email'];
    if (email is! String) return null;
    final userId = chip['userId'];
    return PersonChip(
      email: email,
      name: rich.text,
      userId: userId is String ? userId : null,
    );
  }

  /// Fast check on stored content (`r:{…"chip"…}`) before decoding.
  static bool mayBe(String? stored) =>
      stored != null && stored.startsWith('r:') && stored.contains('"chip"');

  @override
  bool operator ==(Object other) =>
      other is PersonChip && other.email == email && other.name == name;

  @override
  int get hashCode => Object.hash(email, name);
}

/// Avatar colors of person chips (name hash).
const _avatarColors = [
  Color(0xFF1A73E8),
  Color(0xFF188038),
  Color(0xFFC5221F),
  Color(0xFFE37400),
  Color(0xFF9334E6),
  Color(0xFF007B83),
  Color(0xFFB80672),
  Color(0xFF5F6368),
];

/// Paints people chips (03 §14.3) over their cells: a rounded pill with an
/// avatar initial and the name, in the neutral chip colors.
class PersonChipLayer extends GridLayer {
  const PersonChipLayer();

  @override
  int get zOrder => GridZ.decorations - 10;

  @override
  void paint(GridPaintContext ctx, Canvas canvas) {
    final sheet = ctx.sheet;
    final tokens = ctx.tokens;
    final z = ctx.zoom;
    final neutral = neutralChipColors(tokens);
    ctx.forEachPane(canvas, (pane) {
      if (pane.isEmpty) return;
      final window = GridRect(
        pane.rowStart,
        pane.colStart,
        pane.rowEnd,
        pane.colEnd,
      );
      for (final (r, c, cell) in sheet.cellsIn(window, contentOnly: true)) {
        if (!PersonChip.mayBe(cell.content)) continue;
        final chip = PersonChip.of(cell.decoded);
        if (chip == null) continue;
        if (sheet.rows.sizeAt(r) <= 0 || sheet.columns.sizeAt(c) <= 0) {
          continue;
        }
        final m = sheet.mergeAt(r, c);
        if (m != null && (m.top != r || m.left != c)) continue;
        final rect = m == null ? pane.cellRect(r, c) : pane.rangeRect(m);
        final d = ctx.cells.displayAt(sheet.id, r, c);
        final fill = d?.fillColor;
        final bg = fill == null ? tokens.sheetBackground : _hex(fill);
        canvas.save();
        canvas.clipRect(rect);
        canvas.drawRect(rect.deflate(1), Paint()..color = bg);
        final f = d?.format;
        final style = GridTextStyle(
          fontFamily: CellFonts.screenFamily(f?.fontFamily ?? CellFonts.inter),
          fontSize: (f?.fontSize ?? 10) * 4 / 3 * z,
          color: neutral.fg,
          bold: f?.bold ?? false,
          italic: f?.italic ?? false,
        );
        final p = ctx.text.layout(chip.name, style);
        final h = (rect.height - 4 * z).clamp(8.0, 22 * z);
        final avatar = h - 4 * z;
        final w = (p.maxIntrinsicWidth + avatar + 14 * z).clamp(
          0.0,
          rect.width - 6 * z,
        );
        final pill = Rect.fromLTWH(
          rect.left + 3 * z,
          rect.center.dy - h / 2,
          w,
          h,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(pill, Radius.circular(h / 2)),
          Paint()..color = neutral.bg,
        );
        final ac = Offset(pill.left + 2 * z + avatar / 2, pill.center.dy);
        final color = _avatarColors[chip.email.hashCode.abs() % 8];
        canvas.drawCircle(ac, avatar / 2, Paint()..color = color);
        final initial = chip.name.isEmpty
            ? '?'
            : String.fromCharCode(chip.name.runes.first).toUpperCase();
        final ip = ctx.text.layout(
          initial,
          GridTextStyle(
            fontFamily: style.fontFamily,
            fontSize: avatar * 0.6,
            color: const Color(0xFFFFFFFF),
            bold: true,
          ),
        );
        canvas.drawParagraph(
          ip,
          Offset(ac.dx - ip.maxIntrinsicWidth / 2, ac.dy - ip.height / 2),
        );
        final textLeft = pill.left + avatar + 6 * z;
        canvas.clipRect(
          Rect.fromLTRB(textLeft, pill.top, pill.right - 6 * z, pill.bottom),
        );
        canvas.drawParagraph(
          p,
          Offset(textLeft, pill.center.dy - p.height / 2),
        );
        canvas.restore();
      }
    });
  }

  static Color _hex(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0xFFFFFF;
    return Color(0xFF000000 | v);
  }
}

/// One entry of the smart chip menu.
sealed class _ChipEntry {
  const _ChipEntry();
}

final class _PersonEntry extends _ChipEntry {
  const _PersonEntry(this.person);
  final ProtectionEditorOption person;
}

final class _ActionEntry extends _ChipEntry {
  const _ActionEntry(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

/// The smart chip menu (03 §14.3): typing `@` into an empty cell (or
/// Insert › Smart chips) opens it at the cell. Search; *People* (the
/// spreadsheet's editors, cached for offline), *Date* (date picker),
/// *Dropdown*, and the typed text as plain text. ↑/↓/Enter, Esc closes.
class SmartChipMenu extends StatefulWidget {
  const SmartChipMenu({
    super.key,
    required this.controller,
    required this.popup,
  });

  final InCellController controller;
  final CellPopup popup;

  @override
  State<SmartChipMenu> createState() => _SmartChipMenuState();
}

class _SmartChipMenuState extends State<SmartChipMenu> {
  final _search = TextEditingController();
  final _focus = FocusNode(debugLabel: 'sheets.smartChipMenu');
  List<ProtectionEditorOption> _people = const [];
  int _highlight = 0;

  InCellController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _highlight = 0));
    unawaited(_loadPeople());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _loadPeople() async {
    final ed = c.editor;
    final s = ed.services;
    final cached = await FileEditors.cached(s, ed.session.itemUuid);
    if (mounted && cached.isNotEmpty) setState(() => _people = cached);
    final loaded = await FileEditors.load(s, ed.session.itemUuid);
    if (!mounted) return;
    final me = s.me;
    final people = [
      ...loaded.editors,
      if (me != null && !loaded.editors.any((e) => e.userId == me.uuid.uuid))
        ProtectionEditorOption(
          userId: me.uuid.uuid,
          label: me.displayName,
          email: me.email,
        ),
    ];
    setState(() => _people = people);
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_ChipEntry> _entries(SheetsLocalizations l) {
    final q = _search.text.trim().toLowerCase();
    final people = [
      for (final p in _people)
        if (p.email != null &&
            (q.isEmpty ||
                p.label.toLowerCase().contains(q) ||
                p.email!.toLowerCase().contains(q)))
          _PersonEntry(p),
    ].take(6);
    bool match(String label) => q.isEmpty || label.toLowerCase().contains(q);
    return [
      ...people,
      if (match(l.smartChipDate))
        _ActionEntry('date', l.smartChipDate, LucideIcons.calendar),
      if (match(l.smartChipDropdown))
        _ActionEntry('dropdown', l.smartChipDropdown, LucideIcons.listChecks),
      if (q.isNotEmpty)
        _ActionEntry(
          'text',
          l.smartChipAsText('@${_search.text.trim()}'),
          LucideIcons.type,
        ),
    ];
  }

  Future<void> _pick(_ChipEntry e) async {
    final p = widget.popup;
    final ed = c.editor;
    c.closePopup();
    final cell = GridRect.cell(p.row, p.col).a1;
    switch (e) {
      case _PersonEntry(:final person):
        await ed.invokeCommand('sheets.insert.smartChip', {
          'kind': 'person',
          'email': person.email,
          'name': person.label,
          'userId': person.userId,
          'cell': cell,
        });
      case _ActionEntry(id: 'date'):
        c.openDatePicker(p.sheetId, p.row, p.col);
      case _ActionEntry(id: 'dropdown'):
        await ed.invokeCommand('sheets.insert.smartChip', {'kind': 'dropdown'});
      case _ActionEntry():
        final s = ed.model.sheet(p.sheetId);
        if (s == null) return;
        await ed.invokeCommand('sheets.cell.setInput', {
          'input': '@${_search.text.trim()}',
          'sheetId': p.sheetId,
          'rowId': s.rows.idAt(p.row),
          'colId': s.columns.idAt(p.col),
        });
    }
  }

  KeyEventResult _keys(FocusNode node, KeyEvent e, List<_ChipEntry> entries) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (e.logicalKey) {
      case LogicalKeyboardKey.escape:
        c.closePopup();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        if (entries.isNotEmpty) {
          setState(() => _highlight = (_highlight + 1) % entries.length);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (entries.isNotEmpty) {
          setState(
            () =>
                _highlight = (_highlight - 1 + entries.length) % entries.length,
          );
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (entries.isNotEmpty) {
          unawaited(_pick(entries[_highlight.clamp(0, entries.length - 1)]));
        }
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final entries = _entries(l);
    final people = entries.whereType<_PersonEntry>().toList();
    return TapRegion(
      onTapOutside: (_) => c.closePopup(),
      child: Semantics(
        label: l.cmdInsertSmartChip,
        container: true,
        child: CellPopoverSurface(
          padding: const EdgeInsets.all(6),
          child: Focus(
            onKeyEvent: (n, e) => _keys(n, e, entries),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShadInput(
                  key: const ValueKey<String>('sheets.smartChip.search'),
                  controller: _search,
                  focusNode: _focus,
                  placeholder: Text(l.smartChipSearch),
                  leading: const Icon(LucideIcons.atSign, size: 14),
                ),
                const SizedBox(height: 4),
                if (people.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                    child: Text(
                      l.smartChipPeople,
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                  ),
                for (final (i, e) in entries.indexed) ...[
                  if (i == people.length && people.isNotEmpty)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: cs.border,
                    ),
                  _row(context, i, e, i == _highlight),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int i, _ChipEntry e, bool selected) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final (label, detail, Widget icon) = switch (e) {
      _PersonEntry(:final person) => (
        person.label,
        person.email,
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _avatarColors[(person.email ?? '').hashCode.abs() % 8],
            shape: BoxShape.circle,
          ),
          child: Text(
            person.label.isEmpty
                ? '?'
                : String.fromCharCode(person.label.runes.first).toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      _ActionEntry(:final label, :final icon) => (
        label,
        null,
        Icon(icon, size: 16, color: cs.mutedForeground),
      ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        key: ValueKey<String>('sheets.smartChip.entry.$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_pick(e)),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _highlight = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? cs.accent : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small,
                  ),
                ),
                if (detail != null && detail != label) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
