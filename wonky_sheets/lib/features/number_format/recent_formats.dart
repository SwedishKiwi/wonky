import 'package:wonky_sheets_core/model.dart';

/// Recently used custom number formats of a spreadsheet (06 §5.1, ≤ 5):
/// patterns applied in this session first, then the custom patterns found in
/// the spreadsheet (most used first). Menu presets and preset ids are never
/// listed. No extra storage.
abstract final class RecentNumberFormats {
  static const max = 5;

  static final Expando<List<String>> _session = Expando('recentFormats');

  /// Notes that [pattern] was just applied in [model].
  static void note(WorkbookModel model, String pattern) {
    if (!isCustom(pattern)) return;
    final list = _session[model] ??= [];
    list
      ..remove(pattern)
      ..insert(0, pattern);
    if (list.length > max) list.removeRange(max, list.length);
  }

  /// Whether [pattern] is a custom pattern (not a menu preset).
  static bool isCustom(String? pattern) {
    if (pattern == null || pattern.isEmpty) return false;
    if (NumberFormatPresets.isPreset(pattern)) return false;
    if (NumberFormatPresets.isAutomatic(pattern)) return false;
    return !NumberFormatPresets.menu.any((m) => m.stored == pattern);
  }

  /// Up to [max] recent custom patterns of [model].
  static List<String> of(WorkbookModel model) {
    final out = <String>[...?_session[model]];
    if (out.length >= max) return out.take(max).toList();
    final counts = <String, int>{};
    void add(Object? p) {
      if (p is String && isCustom(p)) counts[p] = (counts[p] ?? 0) + 1;
    }

    for (final s in model.sheets) {
      add(s.record?.format[FormatAttr.numberFormat]);
      for (final r in s.rowRecords.values) {
        add(r.format[FormatAttr.numberFormat]);
      }
      for (final c in s.columnRecords.values) {
        add(c.format[FormatAttr.numberFormat]);
      }
      var scanned = 0;
      for (final c in s.cells.all) {
        add(c.format[FormatAttr.numberFormat]);
        // Bounded: huge sheets don't stall the menu.
        if (++scanned > 200000) break;
      }
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    for (final p in sorted) {
      if (out.length >= max) break;
      if (!out.contains(p)) out.add(p);
    }
    return out;
  }
}
