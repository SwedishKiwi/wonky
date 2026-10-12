import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart' show ShellServices;
import 'package:wonky_write_core/wonky_write_core.dart';

import '../editor/styles/editor_theme.dart';
import 'theme_adapter.dart';
import 'theme_repository.dart';
import 'write_fonts.dart';

/// A theme the user can pick (built-in or own).
@immutable
class ThemeOption {
  const ThemeOption({
    required this.uuid,
    required this.name,
    required this.data,
    this.builtinKey,
    this.description,
    this.version = 1,
    this.deleted = false,
  });

  final String uuid;
  final String name;
  final WriteThemeData data;
  final String? builtinKey;
  final String? description;

  /// Server version of the theme (live link, Write 06 §5.3).
  final int version;

  /// Soft-deleted by its owner (still readable through documents).
  final bool deleted;

  bool get isBuiltin => builtinKey != null;

  /// The option of a theme library record (null for invalid JSON).
  static ThemeOption? fromRecord(ThemeRecord r) {
    try {
      return ThemeOption(
        uuid: r.uuid,
        name: r.name,
        description: r.description,
        data: r.data,
        builtinKey: r.builtinKey,
        version: r.version,
        deleted: r.isDeleted,
      );
    } catch (e) {
      debugPrint('Theme ${r.uuid} is invalid: $e');
      return null;
    }
  }
}

/// Loads themes: built-ins locally (`BuiltinThemes`, stable UUIDv5 ids) and
/// the user's own themes from the server (`writeTheme`).
class WriteThemeCatalog extends ChangeNotifier {
  WriteThemeCatalog({this.fetch, this.fetchMine});

  /// Loads a non-built-in theme by uuid (server); [viaDocumentUuid] grants
  /// read access to a collaborator's theme used by that document (§5.4).
  final Future<ThemeOption?> Function(String uuid, {String? viaDocumentUuid})?
  fetch;

  /// Lists the user's own themes (server).
  final Future<List<ThemeOption>> Function()? fetchMine;

  static final List<ThemeOption> builtins = [
    for (final b in BuiltinThemes.all)
      ThemeOption(
        uuid: b.uuid,
        name: b.name,
        data: b.theme,
        builtinKey: b.key,
        description: b.theme.description,
      ),
  ];

  final Map<String, ThemeOption> _custom = {};
  final Map<String, Future<ThemeOption?>> _pending = {};
  List<ThemeOption> _mine = const [];

  /// The user's own themes (after [loadMine]).
  List<ThemeOption> get mine => _mine;

  Future<void> loadMine() async {
    final f = fetchMine;
    if (f == null) return;
    try {
      _mine = await f();
      for (final t in _mine) {
        _custom[t.uuid] = t;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Loading themes failed: $e');
    }
  }

  /// The theme for [uuidOrKey] if known now (built-ins always are).
  ThemeOption? lookup(String uuidOrKey) {
    for (final b in builtins) {
      if (b.uuid == uuidOrKey || b.builtinKey == uuidOrKey) return b;
    }
    return _custom[uuidOrKey];
  }

  /// Adds or replaces a theme the app saved, created or duplicated, so
  /// every open document using it updates (Write 06 §5.3).
  void put(ThemeOption option) {
    if (option.isBuiltin) return;
    _custom[option.uuid] = option;
    final i = _mine.indexWhere((t) => t.uuid == option.uuid);
    if (option.deleted) {
      if (i >= 0) _mine = [..._mine]..removeAt(i);
    } else if (i >= 0) {
      _mine = [..._mine]..[i] = option;
    } else {
      _mine = [..._mine, option]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    notifyListeners();
  }

  /// Marks [uuid] deleted (it leaves "My themes" but stays readable).
  void markDeleted(String uuid) {
    final t = _custom[uuid];
    if (t == null) return;
    put(
      ThemeOption(
        uuid: t.uuid,
        name: t.name,
        description: t.description,
        data: t.data,
        version: t.version,
        deleted: true,
      ),
    );
  }

  /// Refetches [uuid] when [version] is newer than the cached one (a
  /// `themeVersion` notification of an open document).
  Future<void> refresh(
    String uuid, {
    int? version,
    String? viaDocumentUuid,
  }) async {
    final known = _custom[uuid];
    if (lookup(uuid)?.isBuiltin ?? false) return;
    if (known != null && version != null && known.version >= version) return;
    final f = fetch;
    if (f == null) return;
    try {
      final t = await f(uuid, viaDocumentUuid: viaDocumentUuid);
      if (t != null) {
        _custom[uuid] = t;
        final i = _mine.indexWhere((m) => m.uuid == uuid);
        if (i >= 0) _mine = [..._mine]..[i] = t;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refreshing theme $uuid failed: $e');
    }
  }

  /// Loads [uuid] (server themes); null when unavailable.
  Future<ThemeOption?> load(String uuid, {String? viaDocumentUuid}) {
    final known = lookup(uuid);
    if (known != null) return Future.value(known);
    final f = fetch;
    if (f == null) return Future.value(null);
    return _pending.putIfAbsent(uuid, () async {
      try {
        final t = await f(uuid, viaDocumentUuid: viaDocumentUuid);
        if (t != null) {
          _custom[uuid] = t;
          notifyListeners();
        }
        return t;
      } catch (e) {
        debugPrint('Loading theme $uuid failed: $e');
        return null;
      } finally {
        unawaited(Future(() => _pending.remove(uuid)));
      }
    });
  }
}

/// The theme of the open document: resolves the referenced theme for the
/// app brightness and adapts it for the editor (Write 06 §3, §6).
class DocumentThemeController extends ChangeNotifier {
  DocumentThemeController(this.catalog) {
    WriteFonts.generation.addListener(_onFonts);
    catalog.addListener(_onCatalog);
  }

  final WriteThemeCatalog catalog;

  /// The document whose theme this is (read access to foreign themes).
  String? documentUuid;

  String? _themeUuid;
  String? _previewUuid;
  ThemeOption _option = WriteThemeCatalog.builtins.first;
  bool _missing = false;

  /// The theme option in use (Wonky Default until a custom theme loads).
  ThemeOption get option => _option;

  /// The referenced theme could not be loaded (deleted / no access).
  bool get missing => _missing;

  String? get themeUuid => _themeUuid;

  /// The uuid of [option] as a listenable that needs no disposal (so a
  /// closing dialog may keep listening during its exit animation).
  late final ValueListenable<String?> selectedUuid = _SelectedUuid(this);

  set themeUuid(String? uuid) {
    if (uuid == _themeUuid) return;
    _themeUuid = uuid;
    if (_previewUuid == null) _show(uuid);
  }

  /// A theme previewed locally (*View › Preview theme*, view state only,
  /// Write 06 §5.2); null shows the document's theme again.
  String? get previewUuid => _previewUuid;

  set previewUuid(String? uuid) {
    if (uuid == _previewUuid) return;
    _previewUuid = uuid;
    _show(uuid ?? _themeUuid);
  }

  String? get _shownUuid => _previewUuid ?? _themeUuid;

  void _show(String? uuid) {
    final known = uuid == null ? null : catalog.lookup(uuid);
    if (known != null || uuid == null) {
      _missing = false;
      _apply(known ?? WriteThemeCatalog.builtins.first);
      return;
    }
    unawaited(
      catalog.load(uuid, viaDocumentUuid: documentUuid).then((t) {
        if (_shownUuid != uuid) return;
        _missing = t == null;
        _apply(t ?? WriteThemeCatalog.builtins.first);
      }),
    );
  }

  /// A saved theme (here or elsewhere) replaces the cached one.
  void _onCatalog() {
    final uuid = _shownUuid;
    if (uuid == null) return;
    final t = catalog.lookup(uuid);
    if (t != null && !identical(t, _option)) {
      _missing = false;
      _apply(t);
    }
  }

  void _apply(ThemeOption option) {
    _option = option;
    for (final v in ThemeVariant.values) {
      unawaited(
        WriteFonts.ensureLoaded(EditorThemeAdapter.screenFamilies(resolved(v))),
      );
    }
    notifyListeners();
  }

  void _onFonts() => notifyListeners();

  /// The resolved theme for [variant].
  ResolvedWriteTheme resolved(ThemeVariant variant) =>
      ThemeResolver.instance.resolve(_option.data, variant);

  /// The editor theme for the app [brightness].
  EditorTheme editorTheme(Brightness brightness) =>
      const EditorThemeAdapter().adapt(
        resolved(
          brightness == Brightness.dark
              ? ThemeVariant.dark
              : ThemeVariant.light,
        ),
      );

  @override
  void dispose() {
    WriteFonts.generation.removeListener(_onFonts);
    catalog.removeListener(_onCatalog);
    super.dispose();
  }
}

class _SelectedUuid implements ValueListenable<String?> {
  _SelectedUuid(this._theme);

  final DocumentThemeController _theme;

  @override
  String? get value => _theme.option.uuid;

  @override
  void addListener(VoidCallback listener) => _theme.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _theme.removeListener(listener);
}

final Expando<WriteThemeCatalog> _catalogs = Expando();

/// The theme catalog of the app session (built-ins + the server's themes).
WriteThemeCatalog themeCatalogFor(ShellServices s) =>
    _catalogs[s] ??= WriteThemeCatalog(
      fetch: (uuid, {viaDocumentUuid}) async {
        final repo = themeRepositoryFor(s);
        if (repo == null) return null;
        return ThemeOption.fromRecord(
          await repo.get(uuid, viaDocumentUuid: viaDocumentUuid),
        );
      },
      fetchMine: () async {
        final repo = themeRepositoryFor(s);
        if (repo == null) return const [];
        return [
          for (final r in await repo.listMine())
            if (!r.isDeleted) ?ThemeOption.fromRecord(r),
        ];
      },
    );

final Expando<ThemeRepository> _repositories = Expando();

/// The theme repository of the app session (null without a server client,
/// unless a test installed one with [setThemeRepository]).
ThemeRepository? themeRepositoryFor(ShellServices s) {
  final r = _repositories[s];
  if (r != null) return r;
  final client = s.client;
  return client == null
      ? null
      : _repositories[s] = ServerThemeRepository(client);
}

/// Installs [repository] for [s] (tests).
@visibleForTesting
void setThemeRepository(ShellServices s, ThemeRepository repository) =>
    _repositories[s] = repository;

/// Key of the user's default theme in `UserPreferences.writeDefaults`
/// (Write 06 §1). [legacyDefaultThemeKey] was written by older clients.
const defaultThemeKey = 'defaultThemeId';
const legacyDefaultThemeKey = 'themeUuid';

/// The user's default theme uuid from [writeDefaults], if set.
String? defaultThemeUuidOf(Map<String, Object?> writeDefaults) =>
    (writeDefaults[defaultThemeKey] ?? writeDefaults[legacyDefaultThemeKey])
        as String?;
