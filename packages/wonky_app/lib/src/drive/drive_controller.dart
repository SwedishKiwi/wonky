import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../config/home_scope.dart';
import '../data/models_ext.dart';
import '../shell/shell_services.dart';
import 'drive_location.dart';

/// Type filter of the filter bar. `primary` is the v1 default of the app
/// homes; Wonky Drive (`HomeScope.all`) starts at `all` and adds
/// presentations and files (with a file category, Drive 04 §3.3).
enum DriveTypeFilter {
  primary,
  documents,
  spreadsheets,
  presentations,
  folders,
  files,
  all,
}

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
    if (scope?.isAll ?? false) {
      _type = DriveTypeFilter.all;
      _readViewPrefs();
    }
    services.driveView.value = this;
  }

  /// Device keys of Drive's view state (Drive 04 §3.3: layout, sort and
  /// *Folders on top* persist per device; the defaults come from Drive
  /// settings, `UserPreferences.driveDefaults`). The v1 homes and the app
  /// homes keep `drive.layout` and an unpersisted sort.
  static const viewLayoutKey = 'drive.view.layout';
  static const viewSortFieldKey = 'drive.view.sortField';
  static const viewSortDescendingKey = 'drive.view.sortDescending';
  static const viewFoldersOnTopKey = 'drive.view.foldersOnTop';

  bool get _persistsView => scope?.isAll ?? false;

  /// Layout, sort and *Folders on top* of Drive: the device's last choice,
  /// else the Drive setting, else list / last modified / on.
  void _readViewPrefs() {
    final p = services.prefs;
    final d = p.driveDefaults;
    T? def<T>(String key) => d[key] is T ? d[key] as T : null;
    _layout =
        (p.device<String>(viewLayoutKey) ?? def<String>('layout')) == 'grid'
        ? DriveLayout.grid
        : DriveLayout.list;
    _sortField =
        DriveSortField.values.asNameMap()[p.device<String>(viewSortFieldKey) ??
            def<String>('sortField')] ??
        DriveSortField.modifiedAt;
    _descending =
        p.device<bool>(viewSortDescendingKey) ??
        def<bool>('sortDescending') ??
        _sortField != DriveSortField.name;
    _foldersFirst =
        p.device<bool>(viewFoldersOnTopKey) ??
        def<bool>('foldersOnTop') ??
        true;
  }

  /// Re-reads Drive's view settings (after `drive.prefs.set`) and reloads
  /// when the sort changed; app homes only repaint (file-name display).
  void applyViewPrefs() {
    if (!_persistsView) {
      _notify();
      return;
    }
    final before = (_sortField, _descending, _foldersFirst);
    _readViewPrefs();
    if (before != (_sortField, _descending, _foldersFirst)) {
      unawaited(reload());
    } else {
      _notify();
    }
  }

  void _saveSort() {
    if (!_persistsView) return;
    final p = services.prefs;
    unawaited(p.setDevice(viewSortFieldKey, _sortField.name));
    unawaited(p.setDevice(viewSortDescendingKey, _descending));
  }

  /// What the home lists (suite 03 §3.3); null = the v1 home.
  HomeScope? get scope => services.config.homeScope;

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
  FileCategory? _fileCategory;
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

  /// The file subtype of [DriveTypeFilter.files] (null = every file).
  FileCategory? get fileCategory => _fileCategory;
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

  List<DriveItemKind>? get _kinds {
    final sc = scope;
    if (sc != null && !sc.isAll) {
      // App homes: their kind, plus the folders that contain it where
      // folders make sense (narrowed by `foldersContaining`).
      return switch (_location.kind) {
        DriveLocationKind.search => sc.searchKinds,
        DriveLocationKind.home ||
        DriveLocationKind.recent ||
        DriveLocationKind.offline ||
        DriveLocationKind.trash => [sc.kind!],
        _ => sc.listKinds,
      };
    }
    return _typeKinds;
  }

  /// `DriveListFilter.foldersContaining` of app homes (suite 05 §3.2).
  DriveItemKind? get _foldersContaining => scope?.foldersContaining;

  List<FileCategory>? get _fileCategories =>
      _type == DriveTypeFilter.files && _fileCategory != null
      ? [_fileCategory!]
      : null;

  List<DriveItemKind>? get _typeKinds => switch (_type) {
    DriveTypeFilter.primary => switch (services.config.primaryKind) {
      null => null,
      final k =>
        _location.kind == DriveLocationKind.folder ||
                _location.kind == DriveLocationKind.myDrive
            ? [k, DriveItemKind.folder]
            : [k],
    },
    DriveTypeFilter.documents => [DriveItemKind.document],
    DriveTypeFilter.spreadsheets => [DriveItemKind.spreadsheet],
    DriveTypeFilter.presentations => [DriveItemKind.presentation],
    DriveTypeFilter.folders => [DriveItemKind.folder],
    DriveTypeFilter.files => [DriveItemKind.file],
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
        if (_isActive) services.currentFolder.value = f;
      } else if (_isActive) {
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
        filters: DriveSearchFilters(
          kinds: _kinds,
          owner: _owner,
          fileCategories: _fileCategories,
        ),
        cursor: cursor,
        limit: 50,
      );
    }
    return services.drive.list(
      folderUuid: loc.kind == DriveLocationKind.folder ? loc.folder : null,
      filter: DriveListFilter(
        view: loc.view,
        kinds: _kinds,
        owner: _owner,
        fileCategories: _fileCategories,
        foldersContaining: _foldersContaining,
      ),
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
      case DriveChangeKind.storageChanged:
        // Not an item change: the StorageController follows it (D-11).
        break;
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
        final belongs = _belongsHere(item, listed: i >= 0);
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

  bool _belongsHere(DriveItemView item, {bool listed = false}) {
    if (item.isTrashed != _location.isTrash) return false;
    final kinds = _kinds;
    if (kinds != null && !kinds.contains(item.kind)) return false;
    final cats = _fileCategories;
    if (cats != null && !cats.contains(item.fileCategory)) return false;
    // App homes: whether a folder contains the home's kind is the server's
    // `kindMask`; a folder not listed yet waits for the next reload.
    if (_foldersContaining != null && item.isFolder && !listed) return false;
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

  /// [category] narrows [DriveTypeFilter.files] to one file subtype.
  void setTypeFilter(DriveTypeFilter t, {FileCategory? category}) {
    _type = t;
    _fileCategory = t == DriveTypeFilter.files ? category : null;
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
    _saveSort();
    unawaited(reload());
  }

  void setFoldersFirst(bool v) {
    _foldersFirst = v;
    if (_persistsView) {
      unawaited(services.prefs.setDevice(viewFoldersOnTopKey, v));
    }
    unawaited(reload());
  }

  void setLayout(DriveLayout l) {
    _layout = l;
    unawaited(
      services.prefs.setDevice(
        _persistsView ? viewLayoutKey : 'drive.layout',
        l.name,
      ),
    );
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

  /// Replaces the selection with [ids]; [focus] (one of them) becomes the
  /// focused row and the range anchor.
  void selectIds(Iterable<String> ids, {String? focus}) {
    _selected
      ..clear()
      ..addAll(ids);
    if (focus != null) {
      _focused = focus;
      _anchor = focus;
    }
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

  void _publishSelection() {
    if (_isActive) services.driveSelection.value = selection;
  }

  /// Whether this is the home on screen. Opening a folder builds a new home
  /// whose controller registers itself; the previous one is disposed after
  /// the route transition — which, offline (cached folder, instant reload),
  /// came after the new folder was published and reset `currentFolder` to
  /// null, so uploads went to My Drive (D-18). A controller that isn't the
  /// active one leaves the shared state alone.
  bool get _isActive =>
      services.driveView.value == this || services.driveView.value == null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    services.driveRefresh.removeListener(reload);
    if (services.driveSelectAll == selectAll) services.driveSelectAll = null;
    if (_isActive) {
      services.driveSelection.value = const [];
      services.currentFolder.value = null;
    }
    if (services.driveView.value == this) services.driveView.value = null;
    super.dispose();
  }
}
