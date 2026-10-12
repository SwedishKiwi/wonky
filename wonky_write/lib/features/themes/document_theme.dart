import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart' show ShellServices;
import 'package:wonky_client/wonky_client.dart' show UuidValue, WriteThemeView;
import 'package:wonky_write_core/wonky_write_core.dart';

import '../editor/styles/editor_theme.dart';
import 'theme_adapter.dart';
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
  });

  final String uuid;
  final String name;
  final WriteThemeData data;
  final String? builtinKey;
  final String? description;

  bool get isBuiltin => builtinKey != null;
}

/// Loads themes: built-ins locally (`BuiltinThemes`, stable UUIDv5 ids) and
/// the user's own themes from the server (`writeTheme`).
class WriteThemeCatalog extends ChangeNotifier {
  WriteThemeCatalog({this.fetch, this.fetchMine});

  /// Loads a non-built-in theme by uuid (server).
  final Future<ThemeOption?> Function(String uuid)? fetch;

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

  /// Loads [uuid] (server themes); null when unavailable.
  Future<ThemeOption?> load(String uuid) {
    final known = lookup(uuid);
    if (known != null) return Future.value(known);
    final f = fetch;
    if (f == null) return Future.value(null);
    return _pending.putIfAbsent(uuid, () async {
      try {
        final t = await f(uuid);
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
  }

  final WriteThemeCatalog catalog;

  String? _themeUuid;
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
    final known = uuid == null ? null : catalog.lookup(uuid);
    if (known != null || uuid == null) {
      _apply(known ?? WriteThemeCatalog.builtins.first);
      return;
    }
    unawaited(
      catalog.load(uuid).then((t) {
        if (_themeUuid != uuid) return;
        _missing = t == null;
        _apply(t ?? WriteThemeCatalog.builtins.first);
      }),
    );
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
      fetch: (uuid) async {
        final client = s.client;
        if (client == null) return null;
        final v = await client.writeTheme.get(
          UuidValue.withValidation(uuid),
          null,
        );
        return _option(v);
      },
      fetchMine: () async {
        final client = s.client;
        if (client == null) return const [];
        final mine = await client.writeTheme.listMine();
        return [
          for (final v in mine)
            if (v.deletedAt == null && !v.isBuiltin) ?_option(v),
        ];
      },
    );

ThemeOption? _option(WriteThemeView v) {
  try {
    return ThemeOption(
      uuid: v.uuid.uuid,
      name: v.name,
      description: v.description,
      data: WriteThemeData.fromJsonString(v.json),
      builtinKey: v.builtinKey,
    );
  } catch (e) {
    debugPrint('Theme ${v.uuid} is invalid: $e');
    return null;
  }
}
