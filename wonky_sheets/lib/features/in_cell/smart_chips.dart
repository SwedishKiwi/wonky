import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide RichText;
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart' show DriveKindIcon;
import 'package:wonky_client/wonky_client.dart'
    show
        DriveItemView,
        DriveListFilter,
        DriveSearchFilters,
        DriveSort,
        DriveSortField,
        DriveView;
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import '../formatting/rich_text_paint.dart' show chipAvatarColor;
import '../protection/file_editors.dart';
import '../protection/protection_dialogs.dart' show ProtectionEditorOption;
import 'cell_cards.dart' show CellPopoverSurface;
import 'in_cell_controller.dart';

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

  /// The first person chip run of a cell's content, or null.
  static PersonChip? of(CellContent? content) {
    if (content is! RichTextContent) return null;
    final rich = content.rich;
    for (final run in rich.runs) {
      final chip = run.format[RichRunKeys.chip];
      if (chip is! Map || chip['kind'] != 'person') continue;
      final email = chip['email'];
      if (email is! String) continue;
      final userId = chip['userId'];
      final s = run.start.clamp(0, rich.text.length);
      final e = run.end.clamp(s, rich.text.length);
      return PersonChip(
        email: email,
        name: rich.text.substring(s, e),
        userId: userId is String ? userId : null,
      );
    }
    return null;
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

/// A file smart chip (03 §14.3): a link to a drive item (document,
/// spreadsheet or folder) as a rich run
/// `{"chip": {"kind": "file", "uuid": …, "itemKind": …}}` labelled with the
/// item's name. The hover card opens it in this window.
@immutable
class FileChip {
  const FileChip({
    required this.uuid,
    required this.name,
    required this.itemKind,
  });

  /// The drive item.
  final String uuid;
  final String name;

  /// `document`, `spreadsheet` or `folder`.
  final String itemKind;

  /// The cell content of the chip.
  RichTextContent get content => RichTextContent(
    RichText(name, [
      RichRun(0, name.length, {
        RichRunKeys.chip: {'kind': 'file', 'uuid': uuid, 'itemKind': itemKind},
      }),
    ]),
  );

  /// The first file chip run of a cell's content, or null.
  static FileChip? of(CellContent? content) {
    if (content is! RichTextContent) return null;
    final rich = content.rich;
    for (final run in rich.runs) {
      final chip = run.format[RichRunKeys.chip];
      if (chip is! Map || chip['kind'] != 'file') continue;
      final uuid = chip['uuid'];
      if (uuid is! String) continue;
      final kind = chip['itemKind'];
      final s = run.start.clamp(0, rich.text.length);
      final e = run.end.clamp(s, rich.text.length);
      return FileChip(
        uuid: uuid,
        name: rich.text.substring(s, e),
        itemKind: kind is String ? kind : 'document',
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is FileChip && other.uuid == uuid && other.name == name;

  @override
  int get hashCode => Object.hash(uuid, name);
}

/// One entry of the smart chip menu.
sealed class _ChipEntry {
  const _ChipEntry();
}

final class _PersonEntry extends _ChipEntry {
  const _PersonEntry(this.person);
  final ProtectionEditorOption person;
}

final class _FileEntry extends _ChipEntry {
  const _FileEntry(this.item);
  final DriveItemView item;
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
  List<DriveItemView> _recentFiles = const [];
  List<DriveItemView> _foundFiles = const [];
  String _fileQuery = '';
  Timer? _fileSearch;
  int _highlight = 0;

  InCellController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      setState(() => _highlight = 0);
      _searchFiles();
    });
    unawaited(_loadPeople());
    unawaited(_loadRecentFiles());
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

  /// Recently opened drive files for file chips (03 §14.3).
  Future<void> _loadRecentFiles() async {
    try {
      final page = await c.editor.services.drive.list(
        filter: DriveListFilter(view: DriveView.recent),
        sort: DriveSort(field: DriveSortField.lastOpenedByMe),
        limit: 12,
      );
      if (!mounted) return;
      setState(() => _recentFiles = page.items);
    } catch (_) {
      // Offline: no file suggestions.
    }
  }

  void _searchFiles() {
    final q = _search.text.trim();
    if (q == _fileQuery) return;
    _fileQuery = q;
    _fileSearch?.cancel();
    if (q.isEmpty) {
      setState(() => _foundFiles = const []);
      return;
    }
    _fileSearch = Timer(const Duration(milliseconds: 200), () async {
      try {
        final page = await c.editor.services.drive.search(
          q,
          filters: DriveSearchFilters(),
          limit: 8,
        );
        if (!mounted || q != _fileQuery) return;
        setState(() => _foundFiles = page.items);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _fileSearch?.cancel();
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
    final self = c.editor.session.itemUuid.uuid;
    final seen = <String>{};
    final files = [
      for (final f in [..._recentFiles, ..._foundFiles])
        if (f.uuid.uuid != self && match(f.name) && seen.add(f.uuid.uuid))
          _FileEntry(f),
    ].take(4);
    return [
      ...people,
      ...files,
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
      case _FileEntry(:final item):
        await ed.invokeCommand('sheets.insert.smartChip', {
          'kind': 'file',
          'uuid': item.uuid.uuid,
          'name': item.name,
          'itemKind': item.kind.name,
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
    final files = entries.whereType<_FileEntry>().toList();
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
                  if (i == people.length && files.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                      child: Text(
                        l.smartChipFiles,
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
                      ),
                    ),
                  if (i == people.length + files.length &&
                      (people.isNotEmpty || files.isNotEmpty))
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
            color: chipAvatarColor(person.email ?? ''),
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
      _FileEntry(:final item) => (
        item.name,
        null,
        DriveKindIcon(item.kind, size: 18),
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
