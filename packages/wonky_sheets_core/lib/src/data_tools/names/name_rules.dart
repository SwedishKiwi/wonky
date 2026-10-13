import '../../addressing/sheet_names.dart';

/// Named range / named function name rules (07 §8.2, §9.3) and sheet name
/// rules (01 §3, 02 §3.1). All functions are pure; messages use Sheets wording.
abstract final class NameRules {
  static const String invalidChars =
      'Range names must contain only letters, numbers, and underscores.';
  static const String badStart =
      'Range names cannot start with a number, or the words "true" or "false".';
  static const String cellLike =
      'Range names can\'t look like a cell reference (e.g. "A1" or "R1C1").';
  static const String duplicate = 'A range with this name already exists.';

  static const String functionInvalid =
      'Function names can only contain letters, numbers and underscores, and must start with a letter.';
  static const String functionExists =
      'A function with this name already exists.';
  static const String functionCellLike = "The name can't be a cell reference.";
  static const String rangeReferences =
      "The formula definition can't contain range references. Use argument placeholders instead.";

  /// Invalid parameter message.
  static String invalidParam(String name) =>
      'Invalid argument placeholder "$name".';

  static final RegExp _chars = RegExp(r'^[A-Za-z0-9_]+$');
  static final RegExp _fn = RegExp(r'^[A-Z][A-Z0-9_]*$');

  /// Whether [name] looks like an A1 or R1C1 reference (05 §3.4 limits).
  static bool looksLikeReference(String name) =>
      SheetNames.looksLikeCell(name) || SheetNames.looksLikeR1C1(name);

  /// Validates a named range name; [existing] are the names of all named
  /// ranges and named functions (case-insensitive), [current] the name being
  /// renamed (allowed to stay). Returns the message, or null when valid.
  static String? validateRangeName(
    String name, {
    Iterable<String> existing = const [],
    String? current,
  }) {
    if (name.isEmpty || name.length > 250 || !_chars.hasMatch(name)) {
      return invalidChars;
    }
    final lower = name.toLowerCase();
    final c = name.codeUnitAt(0);
    if ((c >= 0x30 && c <= 0x39) ||
        lower.startsWith('true') ||
        lower.startsWith('false')) {
      return badStart;
    }
    if (looksLikeReference(name)) return cellLike;
    if (_taken(lower, existing, current)) return duplicate;
    return null;
  }

  static bool _taken(String lower, Iterable<String> existing, String? current) {
    final cur = current?.toLowerCase();
    for (final e in existing) {
      final l = e.toLowerCase();
      if (l == lower && l != cur) return true;
    }
    return false;
  }

  /// Validates a named function name (auto-uppercased by the editor).
  /// [isBuiltIn] reports built-in function names.
  static String? validateFunctionName(
    String name, {
    Iterable<String> existing = const [],
    String? current,
    bool Function(String upperName)? isBuiltIn,
  }) {
    final upper = name.toUpperCase();
    if (upper.isEmpty || upper.length > 255 || !_fn.hasMatch(upper)) {
      return functionInvalid;
    }
    if (looksLikeReference(upper)) return functionCellLike;
    if ((isBuiltIn?.call(upper) ?? false) ||
        _taken(upper.toLowerCase(), existing, current)) {
      return functionExists;
    }
    return null;
  }

  /// Validates argument placeholders (identifier rules, unique case-insensitive,
  /// not cell-like, ≤ 30). Returns the first message, or null.
  static String? validateParams(List<String> params) {
    if (params.length > 30) {
      return 'A function can have at most 30 argument placeholders.';
    }
    final seen = <String>{};
    for (final p in params) {
      final ok =
          RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(p) &&
          !looksLikeReference(p) &&
          !const {'true', 'false'}.contains(p.toLowerCase());
      if (!ok || !seen.add(p.toLowerCase())) return invalidParam(p);
    }
    return null;
  }

  /// Duplicate-name invariant (07 §8.3): names equal case-insensitively keep
  /// the row with the smaller id; others are renamed `Name_2`, `Name_3`, …
  /// (the larger id gets the higher suffix), avoiding every existing name.
  /// [entries] are `(id, name)`; returns id → new name. Idempotent.
  static Map<String, String> dedupeRenames(
    Iterable<(String id, String name)> entries,
  ) => _dedupe(entries, (base, n) => '${base}_$n');

  static Map<String, String> _dedupe(
    Iterable<(String, String)> entries,
    String Function(String base, int n) suffix,
  ) {
    final list = entries.toList()..sort((a, b) => a.$1.compareTo(b.$1));
    final taken = {for (final e in list) e.$2.toLowerCase()};
    final byName = <String, List<(String, String)>>{};
    for (final e in list) {
      (byName[e.$2.toLowerCase()] ??= []).add(e);
    }
    final keys = byName.keys.toList()..sort();
    final out = <String, String>{};
    for (final k in keys) {
      final group = byName[k]!;
      for (var i = 1; i < group.length; i++) {
        final (id, name) = group[i];
        var n = 2;
        while (taken.contains(suffix(name, n).toLowerCase())) {
          n++;
        }
        final newName = suffix(name, n);
        taken.add(newName.toLowerCase());
        out[id] = newName;
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Sheet names.

  static const String sheetNameLength =
      'Sheet names must be between 1 and 100 characters.';
  static const String sheetNameChars =
      r"Sheet names can't contain any of these characters: [ ] * ? / \ :";

  /// Duplicate sheet name message.
  static String sheetNameTaken(String name) =>
      'A sheet with the name "$name" already exists. Please enter another name.';

  static final RegExp _badSheetChars = RegExp(r'[\[\]*?/\\:]');

  /// Validates a sheet name (01 §3): 1–100 characters, none of `[ ] * ? / \ :`,
  /// unique case-insensitively among [existing] (except [current]).
  static String? validateSheetName(
    String name, {
    Iterable<String> existing = const [],
    String? current,
  }) {
    final t = name.trim();
    if (t.isEmpty || t.length > 100) return sheetNameLength;
    if (_badSheetChars.hasMatch(t)) return sheetNameChars;
    if (_taken(t.toLowerCase(), existing, current)) return sheetNameTaken(t);
    return null;
  }

  /// Duplicate sheet names after merges (02 §3.1): the sheet with the larger
  /// id gets ` (2)` (` (3)`, … when taken). [sheets] are `(id, name)`;
  /// returns id → new name. Deterministic and idempotent.
  static Map<String, String> sheetRenames(
    Iterable<(String id, String name)> sheets,
  ) => _dedupe(sheets, (base, n) => '$base ($n)');
}
