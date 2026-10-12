import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../data/models_ext.dart';
import '../shell/shell_services.dart';
import 'drive_location.dart';

/// Type filter of the filter bar.
enum DriveTypeFilter { primary, documents, spreadsheets, folders, all }

/// List or grid.
enum DriveLayout { list, grid }

/// State of the home screen (suite 05 §3): items of the current location,
/// paging, filters, sort, layout and selection; live updates from
/// `drive.watch`.
class DriveController extends ChangeNotifier {
  DriveController({required this.services, required this._location}) {
    _sub = services.driveChanges.listen(_onChange);
    services.driveRefresh.addListener(reload);
    _layout = services.prefs.device<String>('drive.layout') == 'grid'
        ? DriveLayout.grid
        : DriveLayout.list;
    services.driveSelectAll = selectAll;
  }

  final ShellServices services;
  DriveLocation _location;
  StreamSubscription<DriveChange>? _sub;

  List<DriveItemView> _items = const [];
  List<DriveItemView> _path = const [];
  DriveItemView? _folder;
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _generation = 0;
  DriveTypeFilter _type = DriveTypeFilter.primary;
  DriveOwnerFilter _owner = DriveOwnerFilter.anyone;
  DriveSortField _sortField = DriveSortField.modifiedAt;
  bool _descending = true;
  bool _foldersFirst = true;
  late DriveLayout _layout;
  final Set<String> _selected = {};
  String? _anchor;
  String? _focused;
  bool _disposed = false;

  DriveLocation get location => _location;
  List<DriveItemView> get items => _items;
  List<DriveItemView> get path => _path;
  DriveItemView? get folder => _folder;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _cursor != null;
  Object? get error => _error;
  DriveTypeFilter get typeFilter => _type;
  DriveOwnerFilter get ownerFilter => _owner;
  DriveSortField get sortField => _sortField;
  bool get descending => _descending;
  bool get foldersFirst => _foldersFirst;
  DriveLayout get layout => _layout;
  String? get focusedId => _focused;

  List<DriveItemView> get selection => [
    for (final i in _items)
      if (_selected.contains(i.uuid.uuid)) i,
  ];
  bool isSelected(DriveItemView i) => _selected.contains(i.uuid.uuid);

  /// Whether the folder allows creating items (My Drive or an editable folder).
  bool get canCreateHere => switch (_location.kind) {
    DriveLocationKind.folder => _folder?.canEdit ?? false,
    DriveLocationKind.trash ||
    DriveLocationKind.shared ||
    DriveLocationKind.search => false,
    _ => true,
  };

  void setLocation(DriveLocation l) {
    if (l == _location) return;
    _location = l;
    _selected.clear();
    _anchor = null;
    _folder = null;
    _path = const [];
    _publishSelection();
    unawaited(reload());
  }

  List<DriveItemKind>? get _kinds => switch (_type) {
    DriveTypeFilter.primary =>
      _location.kind == DriveLocationKind.folder ||
              _location.kind == DriveLocationKind.myDrive
          ? [services.config.primaryKind, DriveItemKind.folder]
          : [services.config.primaryKind],
    DriveTypeFilter.documents => [DriveItemKind.document],
    DriveTypeFilter.spreadsheets => [DriveItemKind.spreadsheet],
    DriveTypeFilter.folders => [DriveItemKind.folder],
    DriveTypeFilter.all => null,
  };

  DriveSort get _sort {
    final field =
        _location.groupsByDate && _sortField == DriveSortField.modifiedAt
        ? DriveSortField.lastOpenedByMe
        : _sortField;
    return DriveSort(
      field: field,
      descending: _descending,
      foldersFirst: _foldersFirst,
    );
  }

  Future<void> reload() async {
    final gen = ++_generation;
    _loading = true;
    _error = null;
    _notify();
    try {
      final loc = _location;
      if (loc.kind == DriveLocationKind.folder) {
        final f = await services.drive.get(loc.folder!);
        final p = await services.drive.path(loc.folder!);
        if (gen != _generation) return;
        _folder = f;
        _path = p;
        services.currentFolder.value = f;
      } else {
        services.currentFolder.value = null;
      }
      final page = await _fetch(null);
      if (gen != _generation) return;
      _items = page.items;
      _cursor = page.nextCursor;
      _selected.removeWhere((id) => !_items.any((i) => i.uuid.uuid == id));
      _publishSelection();
    } catch (e) {
      if (gen != _generation) return;
      _error = e;
      _items = const [];
    } finally {
      if (gen == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<DriveListPage> _fetch(String? cursor) {
    final loc = _location;
    if (loc.kind == DriveLocationKind.search) {
      return services.drive.search(
        loc.query ?? '',
        filters: DriveSearchFilters(kinds: _kinds, owner: _owner),
        cursor: cursor,
        limit: 50,
      );
    }
    return services.drive.list(
      folderUuid: loc.kind == DriveLocationKind.folder ? loc.folder : null,
      filter: DriveListFilter(view: loc.view, kinds: _kinds, owner: _owner),
      sort: _sort,
      cursor: cursor,
      limit: 100,
    );
  }

  Future<void> loadMore() async {
    if (_cursor == null || _loadingMore) return;
    _loadingMore = true;
    _notify();
    final gen = _generation;
    try {
      final page = await _fetch(_cursor);
      if (gen != _generation) return;
      _items = [..._items, ...page.items];
      _cursor = page.nextCursor;
    } catch (_) {
      // Keep what we have; the next scroll retries.
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  void _onChange(DriveChange c) {
    final i = _items.indexWhere((x) => x.uuid == c.itemUuid);
    switch (c.kind) {
      case DriveChangeKind.trashed:
      case DriveChangeKind.removed:
      case DriveChangeKind.unshared:
        if (_location.isTrash && c.kind == DriveChangeKind.trashed) {
          unawaited(reload());
          return;
        }
        if (i >= 0) {
          _items = [..._items]..removeAt(i);
          _selected.remove(c.itemUuid.uuid);
          _publishSelection();
          _notify();
        }
      case DriveChangeKind.restored:
        if (_location.isTrash && i >= 0) {
          _items = [..._items]..removeAt(i);
          _notify();
        } else {
          unawaited(reload());
        }
      case DriveChangeKind.created:
      case DriveChangeKind.moved:
      case DriveChangeKind.updated:
      case DriveChangeKind.modified:
      case DriveChangeKind.shared:
        final item = c.item;
        if (item == null) {
          unawaited(reload());
          return;
        }
        final belongs = _belongsHere(item);
        if (i >= 0 && !belongs) {
          _items = [..._items]..removeAt(i);
        } else if (i >= 0) {
          _items = [..._items]..[i] = item;
        } else if (belongs) {
          _items = [item, ..._items];
        }
        if (_folder?.uuid == item.uuid) _folder = item;
        _publishSelection();
        _notify();
    }
  }

  bool _belongsHere(DriveItemView item) {
    if (item.isTrashed != _location.isTrash) return false;
    final kinds = _kinds;
    if (kinds != null && !kinds.contains(item.kind)) return false;
    return switch (_location.kind) {
      DriveLocationKind.folder => item.parentUuid?.uuid == _location.folderUuid,
      DriveLocationKind.myDrive =>
        item.parentUuid == null && item.owner.id == services.me?.id,
      DriveLocationKind.starred => item.starred,
      DriveLocationKind.offline => item.pinnedOffline,
      DriveLocationKind.shared => item.owner.id != services.me?.id,
      DriveLocationKind.home || DriveLocationKind.recent =>
        item.lastOpenedAt != null || item.owner.id == services.me?.id,
      DriveLocationKind.trash => true,
      DriveLocationKind.search => false,
    };
  }

  // ---- Filters ----

  void setTypeFilter(DriveTypeFilter t) {
    _type = t;
    unawaited(reload());
  }

  void setOwnerFilter(DriveOwnerFilter o) {
    _owner = o;
    unawaited(reload());
  }

  void setSort(DriveSortField field, {bool? descending}) {
    if (field == _sortField && descending == null) {
      _descending = !_descending;
    } else {
      _sortField = field;
      _descending = descending ?? (field != DriveSortField.name);
    }
    unawaited(reload());
  }

  void setFoldersFirst(bool v) {
    _foldersFirst = v;
    unawaited(reload());
  }

  void setLayout(DriveLayout l) {
    _layout = l;
    unawaited(services.prefs.setDevice('drive.layout', l.name));
    _notify();
  }

  // ---- Selection ----

  /// Click: select one; Mod-click: toggle; Shift-click: range.
  void select(DriveItemView item, {bool toggle = false, bool range = false}) {
    final id = item.uuid.uuid;
    if (range && _anchor != null) {
      final a = _items.indexWhere((x) => x.uuid.uuid == _anchor);
      final b = _items.indexWhere((x) => x.uuid.uuid == id);
      if (a >= 0 && b >= 0) {
        if (!toggle) _selected.clear();
        for (var k = a < b ? a : b; k <= (a < b ? b : a); k++) {
          _selected.add(_items[k].uuid.uuid);
        }
      }
    } else if (toggle) {
      if (!_selected.remove(id)) _selected.add(id);
      _anchor = id;
    } else {
      _selected
        ..clear()
        ..add(id);
      _anchor = id;
    }
    _focused = id;
    _publishSelection();
    _notify();
  }

  void selectAll() {
    _selected
      ..clear()
      ..addAll(_items.map((i) => i.uuid.uuid));
    _publishSelection();
    _notify();
  }

  void selectIds(Iterable<String> ids) {
    _selected
      ..clear()
      ..addAll(ids);
    _publishSelection();
    _notify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _publishSelection();
    _notify();
  }

  /// Arrow-key navigation (with Shift extends the selection).
  void moveFocus(int delta, {bool extend = false}) {
    if (_items.isEmpty) return;
    var i = _items.indexWhere((x) => x.uuid.uuid == _focused);
    i = (i < 0 ? (delta > 0 ? 0 : _items.length - 1) : (i + delta)).clamp(
      0,
      _items.length - 1,
    );
    select(_items[i], range: extend);
  }

  void _publishSelection() => services.driveSelection.value = selection;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    services.driveRefresh.removeListener(reload);
    if (services.driveSelectAll == selectAll) services.driveSelectAll = null;
    services.driveSelection.value = const [];
    services.currentFolder.value = null;
    super.dispose();
  }
}
