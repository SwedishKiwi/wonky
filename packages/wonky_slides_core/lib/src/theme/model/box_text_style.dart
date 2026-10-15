/// Box-level text properties (`textStyleJson`, Slides 02 §5.1), used by
/// placeholders and the theme's default object styles.
library;

import '../json/json_util.dart';
import 'common.dart';
import 'text_styles.dart';

/// Run and paragraph attributes allowed in `defaults` (02 §4.1).
const Set<String> textDefaultsKeys = {
  // inline
  'bold', 'italic', 'underline', 'strike', 'code', 'font', 'weight', 'size',
  'color', 'highlight', 'script', 'caps', 'letterSpacing', 'link',
  // block
  'style', 'align', 'list', 'listStyle', 'listStart', 'indent',
  'lineHeight', 'spaceBefore', 'spaceAfter', 'dir',
};

/// Box text properties. Null fields inherit (placeholder chain, 05 §5.3).
final class BoxTextStyle {
  /// Creates box text properties.
  const BoxTextStyle({
    this.anchor,
    this.insets,
    this.autofit,
    this.wrap,
    this.columns,
    this.columnGap,
    this.defaults = const {},
    this.verticalText,
  });

  /// Empty (inherits everything).
  static const BoxTextStyle empty = BoxTextStyle();

  /// `top`, `middle`, `bottom`.
  final String? anchor;

  /// Insets `[t, r, b, l]` in su.
  final List<double>? insets;

  /// `none`, `shrink`, `resize`.
  final String? autofit;

  /// Whether text wraps.
  final bool? wrap;

  /// Columns 1–3 (P2).
  final int? columns;

  /// Gap between columns (su).
  final double? columnGap;

  /// Default run/paragraph attributes (02 §4.1 keys).
  final JsonMap defaults;

  /// Vertical text (P2).
  final bool? verticalText;

  /// The default paragraph style key, if set.
  String? get styleKey => defaults['style'] as String?;

  /// This style with [over]'s non-null values on top (defaults merged by
  /// key).
  BoxTextStyle merge(BoxTextStyle? over) {
    if (over == null) return this;
    return BoxTextStyle(
      anchor: over.anchor ?? anchor,
      insets: over.insets ?? insets,
      autofit: over.autofit ?? autofit,
      wrap: over.wrap ?? wrap,
      columns: over.columns ?? columns,
      columnGap: over.columnGap ?? columnGap,
      defaults: {...defaults, ...over.defaults},
      verticalText: over.verticalText ?? verticalText,
    );
  }

  /// A copy with lengths and sizes multiplied by [s] (05 §7).
  BoxTextStyle scaled(double s) {
    final d = {...defaults};
    for (final k in ['size', 'spaceBefore', 'spaceAfter']) {
      final v = d[k];
      if (v is num) {
        final scaled = v * s;
        d[k] = normalizeJsonNumber(
          k == 'size' ? scaled.clamp(minFontSize, maxFontSize) : scaled,
        );
      }
    }
    return BoxTextStyle(
      anchor: anchor,
      insets: insets == null ? null : [for (final i in insets!) i * s],
      autofit: autofit,
      wrap: wrap,
      columns: columns,
      columnGap: columnGap == null ? null : columnGap! * s,
      defaults: d,
      verticalText: verticalText,
    );
  }

  /// JSON form (with `"v": 1`; null fields omitted).
  JsonMap toJson() {
    final out = <String, Object?>{'v': 1};
    putIfNotNull(out, 'anchor', anchor);
    if (insets != null) {
      out['insets'] = [for (final i in insets!) normalizeJsonNumber(i)];
    }
    putIfNotNull(out, 'autofit', autofit);
    putIfNotNull(out, 'wrap', wrap);
    putIfNotNull(out, 'columns', columns);
    putIfNotNull(out, 'columnGap', columnGap);
    if (defaults.isNotEmpty) out['defaults'] = deepCopyJson(defaults);
    putIfNotNull(out, 'verticalText', verticalText);
    return out;
  }

  /// Parses box text properties (`"v"` optional). Errors → `null`.
  static BoxTextStyle? fromJson(Object? json, String path, IssueSink sink) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {
        'v',
        'anchor',
        'insets',
        'autofit',
        'wrap',
        'columns',
        'columnGap',
        'defaults',
        'verticalText',
      },
    );
    if (r == null) return null;
    r.version();
    final before = sink.errors.length;
    List<double>? insets;
    final rawInsets = r.list('insets');
    if (rawInsets != null) {
      if (rawInsets.length == 4 &&
          rawInsets.every((v) => v is num && v >= 0 && v <= 2000)) {
        insets = [for (final v in rawInsets) (v as num).toDouble()];
      } else {
        sink.error(r.at('insets'), 'wrong_type', 'Expected [t, r, b, l] su.');
      }
    }
    final d = r.child('defaults', known: textDefaultsKeys);
    final defaults = <String, Object?>{};
    if (d != null) {
      for (final e in d.map.entries) {
        if (!textDefaultsKeys.contains(e.key)) continue;
        if (_validDefault(d, e.key)) defaults[e.key] = deepCopyJson(e.value);
      }
    }
    final style = BoxTextStyle(
      anchor: r.string('anchor', allowed: {'top', 'middle', 'bottom'}),
      insets: insets,
      autofit: r.string('autofit', allowed: {'none', 'shrink', 'resize'}),
      wrap: r.boolean('wrap'),
      columns: r.integer('columns', min: 1, max: 3),
      columnGap: r.number('columnGap', min: 0, max: 400),
      defaults: Map.unmodifiable(defaults),
      verticalText: r.boolean('verticalText'),
    );
    return sink.errors.length > before ? null : style;
  }

  static bool _validDefault(JsonReader d, String key) {
    final before = d.sink.errors.length;
    switch (key) {
      case 'style':
        d.string(key, allowed: themeTextStyleKeys.toSet());
      case 'align':
        d.string(key, allowed: alignValues);
      case 'caps':
        d.string(key, allowed: capsValues);
      case 'list':
        d.string(key, allowed: {'bullet', 'ordered', 'check', 'unchecked'});
      case 'script':
        d.string(key, allowed: {'super', 'sub'});
      case 'dir':
        d.string(key, allowed: {'rtl'});
      case 'listStyle' || 'link':
        d.string(key);
      case 'font':
        readFontRef(d, key);
      case 'color' || 'highlight':
        readColor(d, key);
      case 'size':
        d.number(key, min: minFontSize, max: maxFontSize);
      case 'weight':
        d.integer(key, min: 100, max: 900);
      case 'letterSpacing':
        d.number(key, min: -0.2, max: 1);
      case 'lineHeight':
        d.number(key, min: 0.7, max: 3);
      case 'spaceBefore' || 'spaceAfter':
        d.number(key, min: 0, max: 400);
      case 'indent':
        d.integer(key, min: 0, max: 8);
      case 'listStart':
        d.integer(key, min: 0);
      default:
        d.boolean(key);
    }
    return d.sink.errors.length == before;
  }

  @override
  bool operator ==(Object other) =>
      other is BoxTextStyle && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}
