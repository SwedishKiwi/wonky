import 'package:wonky_app/wonky_app.dart';

/// Settings › Sheets user defaults (04 §11.24), stored in
/// `UserPreferences.sheetsDefaults` (synced per user). Read through this
/// class so every feature agrees on the keys.
class SheetsUserDefaults {
  const SheetsUserDefaults(this.prefs);

  /// The defaults of the signed-in user of [services].
  factory SheetsUserDefaults.of(ShellServices services) =>
      SheetsUserDefaults(services.prefs);

  final PreferencesController prefs;

  // Keys of `sheetsDefaults`.
  static const keyLocale = 'defaultLocale';
  static const keyTimeZone = 'defaultTimeZone';
  static const keyFontFamily = 'defaultFontFamily';
  static const keyFontSize = 'defaultFontSize';
  static const keyEnterStartsEditing = 'enterStartsEditing';
  static const keyFormulaAutocomplete = 'formulaAutocomplete';
  static const keyFormulaHelp = 'formulaHelp';
  static const keyShowEditorMode = 'showEditorMode';
  static const keyCustomFillLists = 'customFillLists';
  static const keyScriptsEnabled = 'scriptsEnabled';
  static const keyReduceAnimations = 'reduceAnimations';

  /// Column-value autocomplete while typing (03 §8.5, Tools › Autocomplete).
  static const keyColumnAutocomplete = 'autocomplete';

  Map<String, Object?> get _m => prefs.sheetsDefaults;

  /// Locale of new spreadsheets (null = `en_US`).
  String? get locale => _m[keyLocale] as String?;

  /// Time zone of new spreadsheets (null = UTC).
  String? get timeZone => _m[keyTimeZone] as String?;

  /// Default font family of new spreadsheets (null = the theme's, Inter).
  String? get fontFamily => _m[keyFontFamily] as String?;

  /// Default font size of new spreadsheets (null = 10).
  double? get fontSize => (_m[keyFontSize] as num?)?.toDouble();

  /// Enter on a selected cell starts editing (default off: Enter moves
  /// down, 03 §7.1).
  bool get enterStartsEditing => _m[keyEnterStartsEditing] as bool? ?? false;

  bool get formulaAutocomplete => _m[keyFormulaAutocomplete] as bool? ?? true;
  bool get formulaHelp => _m[keyFormulaHelp] as bool? ?? true;

  /// Column-value autocomplete while typing text (03 §8.5).
  bool get columnAutocomplete => _m[keyColumnAutocomplete] as bool? ?? true;
  bool get showEditorMode => _m[keyShowEditorMode] as bool? ?? true;
  bool get scriptsEnabled => _m[keyScriptsEnabled] as bool? ?? true;

  /// Fewer grid animations (marching ants, flashes); the appearance
  /// setting *Reduce motion* implies it.
  bool get reduceAnimations =>
      (_m[keyReduceAnimations] as bool? ?? false) || prefs.reduceMotion;

  /// Custom fill lists (each a list of at least two items), used by the
  /// fill handle and series fill before the built-in lists.
  List<List<String>> get customFillLists {
    final raw = _m[keyCustomFillLists];
    if (raw is! List) return const [];
    return [
      for (final l in raw)
        if (l is List)
          [
            for (final x in l)
              if (x is String && x.trim().isNotEmpty) x.trim(),
          ],
    ].where((l) => l.length >= 2).toList();
  }

  Future<void> set(String key, Object? value) =>
      prefs.setSheetsDefault(key, value);

  /// Parses the text of the fill-lists editor: one list per line, items
  /// separated by commas.
  static List<List<String>> parseFillLists(String text) => [
    for (final line in text.split('\n'))
      [
        for (final x in line.split(','))
          if (x.trim().isNotEmpty) x.trim(),
      ],
  ].where((l) => l.length >= 2).toList();

  /// The editor text of [lists].
  static String formatFillLists(List<List<String>> lists) =>
      lists.map((l) => l.join(', ')).join('\n');
}
