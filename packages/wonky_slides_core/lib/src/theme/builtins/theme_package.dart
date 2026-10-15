/// A theme package: a theme with its masters, layouts and their elements
/// (Slides 05 §1, §6) — the form of the built-in themes, theme imports and
/// templates. Rows reference each other by **part keys** (`master:default`,
/// `layout:titleBody`, `el:titleBody/title`); the copier derives row ids
/// with `SlidesIds.themePartId(themeId, partKey)` (02 §2.1).
library;

import 'dart:convert';

import '../json/json_util.dart';
import '../layout/placeholder_type.dart';
import '../layout/slide_size.dart';
import '../model/background.dart';
import '../model/box_text_style.dart';
import '../model/common.dart';
import '../model/deck_theme_data.dart';
import '../model/paint.dart';
import '../schema/validator.dart';

/// The `SlideElementKind` names (02 §3.11).
const Set<String> slideElementKinds = {
  'text',
  'shape',
  'line',
  'image',
  'table',
  'icon',
  'code',
  'chart',
  'group',
};

/// An element owned by a master or layout (placeholder or decoration).
final class ThemeElementSpec {
  /// Creates an element.
  const ThemeElementSpec({
    required this.partKey,
    required this.kind,
    this.name,
    this.placeholderType,
    this.placeholderOf,
    required this.frame,
    this.rotation,
    this.text,
    this.textStyle,
    this.fill,
    this.stroke,
    this.effects,
    this.opacity,
    this.data,
    this.decorative = false,
    this.locked = false,
  });

  /// Part key (`el:<layoutKey>/<name>`, `el:master/<name>`).
  final String partKey;

  /// `SlideElementKind` name.
  final String kind;

  /// Layers-panel name.
  final String? name;

  /// Placeholder type (placeholders only).
  final SlidePlaceholderType? placeholderType;

  /// Part key of the master placeholder this layout placeholder refines.
  final String? placeholderOf;

  /// Frame (su).
  final SuRect frame;

  /// Rotation (degrees).
  final double? rotation;

  /// Rich text Delta (JSON string): the prompt for placeholders.
  final String? text;

  /// `textStyleJson`.
  final BoxTextStyle? textStyle;

  /// `fillJson`.
  final SlideFill? fill;

  /// `strokeJson`.
  final SlideStroke? stroke;

  /// `effectsJson`.
  final JsonMap? effects;

  /// `opacity`.
  final double? opacity;

  /// `dataJson`.
  final JsonMap? data;

  /// `decorative` (excluded from alt-text checks).
  final bool decorative;

  /// `locked`.
  final bool locked;

  /// Whether this is a placeholder.
  bool get isPlaceholder => placeholderType != null;

  /// The prompt text of a placeholder (plain text of [text]).
  String? get promptText {
    if (text == null) return null;
    final ops = jsonDecode(text!) as List<Object?>;
    final out = StringBuffer();
    for (final op in ops) {
      final insert = (op as Map)['insert'];
      if (insert is String) out.write(insert);
    }
    final s = out.toString();
    return s.endsWith('\n') ? s.substring(0, s.length - 1) : s;
  }

  /// The `SlideElement` column values (02 §3.5) with JSON columns encoded;
  /// `placeholderOf` holds a part key (`placeholderOfPart`) for the copier.
  Map<String, Object?> toColumns() => {
    'kind': kind,
    'name': name,
    'placeholderType': placeholderType?.name,
    'placeholderOfPart': placeholderOf,
    'x': frame.x,
    'y': frame.y,
    'width': frame.width,
    'height': frame.height,
    'rotation': rotation,
    'text': text,
    'textStyleJson': textStyle == null ? null : jsonEncode(textStyle!.toJson()),
    'fillJson': fill == null ? null : jsonEncode(fill!.toJson()),
    'strokeJson': stroke == null ? null : jsonEncode(stroke!.toJson()),
    'effectsJson': effects == null ? null : jsonEncode(effects),
    'opacity': opacity,
    'dataJson': data == null ? null : jsonEncode(data),
    'decorative': decorative,
    'locked': locked,
  };

  /// JSON form.
  JsonMap toJson() {
    final out = <String, Object?>{'partKey': partKey, 'kind': kind};
    putIfNotNull(out, 'name', name);
    putIfNotNull(out, 'placeholderType', placeholderType?.name);
    putIfNotNull(out, 'placeholderOf', placeholderOf);
    out['frame'] = frame.toList();
    putIfNotNull(out, 'rotation', rotation);
    putIfNotNull(out, 'text', text);
    putIfNotNull(out, 'textStyle', textStyle?.toJson());
    putIfNotNull(out, 'fill', fill?.toJson());
    putIfNotNull(out, 'stroke', stroke?.toJson());
    putIfNotNull(out, 'effects', effects);
    putIfNotNull(out, 'opacity', opacity);
    putIfNotNull(out, 'data', data);
    if (decorative) out['decorative'] = true;
    if (locked) out['locked'] = true;
    return out;
  }

  static ThemeElementSpec? _fromJson(
    Object? json,
    String path,
    IssueSink sink,
  ) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {
        'partKey',
        'kind',
        'name',
        'placeholderType',
        'placeholderOf',
        'frame',
        'rotation',
        'text',
        'textStyle',
        'fill',
        'stroke',
        'effects',
        'opacity',
        'data',
        'decorative',
        'locked',
      },
    );
    if (r == null) return null;
    final before = sink.errors.length;
    final partKey = r.string('partKey', required: true);
    final kind = r.string('kind', required: true, allowed: slideElementKinds);
    final typeName = r.string('placeholderType');
    final type = SlidePlaceholderType.fromName(typeName);
    if (typeName != null && type == null) {
      sink.error(
        r.at('placeholderType'),
        'out_of_range',
        'Unknown placeholder type "$typeName".',
      );
    }
    final rawFrame = r.list('frame', required: true);
    SuRect? frame;
    if (rawFrame != null) {
      if (rawFrame.length == 4 && rawFrame.every((v) => v is num)) {
        final v = [for (final n in rawFrame) (n as num).toDouble()];
        if (v[2] > 0 && v[3] > 0) frame = SuRect(v[0], v[1], v[2], v[3]);
      }
      if (frame == null) {
        sink.error(
          r.at('frame'),
          'wrong_type',
          'Expected [x, y, width > 0, height > 0].',
        );
      }
    }
    final text = r.string('text');
    if (text != null) {
      try {
        final ops = jsonDecode(text);
        if (ops is! List) throw const FormatException('not a list');
      } on FormatException {
        sink.error(
          r.at('text'),
          'invalid_text',
          'Expected a Delta JSON string.',
        );
      }
    }
    final effects = r.has('effects')
        ? r.child(
            'effects',
            known: {'v', 'shadow', 'glow', 'blur', 'reflection', 'blendMode'},
          )
        : null;
    final data = r.map['data'];
    if (data != null && data is! Map) {
      sink.error(r.at('data'), 'wrong_type', 'Expected an object.');
    }
    final spec = ThemeElementSpec(
      partKey: partKey ?? '',
      kind: kind ?? 'shape',
      name: r.string('name'),
      placeholderType: type,
      placeholderOf: r.string('placeholderOf'),
      frame: frame ?? const SuRect(0, 0, 1, 1),
      rotation: r.number('rotation', min: -360, max: 360),
      text: text,
      textStyle: r.has('textStyle')
          ? BoxTextStyle.fromJson(r.map['textStyle'], r.at('textStyle'), sink)
          : null,
      fill: r.has('fill')
          ? SlideFill.fromJson(r.map['fill'], r.at('fill'), sink)
          : null,
      stroke: r.has('stroke')
          ? SlideStroke.fromJson(r.map['stroke'], r.at('stroke'), sink)
          : null,
      effects: effects == null
          ? null
          : {for (final e in effects.map.entries) e.key: deepCopyJson(e.value)},
      opacity: r.number('opacity', min: 0, max: 1),
      data: data is Map ? deepCopyJson(data) as JsonMap : null,
      decorative: r.boolean('decorative') ?? false,
      locked: r.boolean('locked') ?? false,
    );
    return sink.errors.length > before ? null : spec;
  }
}

/// A layout of a master.
final class ThemeLayoutSpec {
  /// Creates a layout.
  const ThemeLayoutSpec({
    required this.partKey,
    this.key,
    required this.name,
    this.background,
    this.hideMasterElements = false,
    this.hidden = false,
    required this.elements,
  });

  /// Part key (`layout:<key>`).
  final String partKey;

  /// Built-in layout key (`SlideLayout.key`).
  final String? key;

  /// Display name.
  final String name;

  /// `backgroundJson` (null = master background).
  final SlideBackground? background;

  /// `hideMasterElements`.
  final bool hideMasterElements;

  /// `hidden` (not offered in the layout picker).
  final bool hidden;

  /// Elements in z-order (back to front).
  final List<ThemeElementSpec> elements;

  /// The placeholders in order.
  List<ThemeElementSpec> get placeholders => [
    for (final e in elements)
      if (e.isPlaceholder) e,
  ];

  /// JSON form.
  JsonMap toJson() => {
    'partKey': partKey,
    if (key != null) 'key': key,
    'name': name,
    if (background != null) 'background': background!.toJson(),
    if (hideMasterElements) 'hideMasterElements': true,
    if (hidden) 'hidden': true,
    'elements': [for (final e in elements) e.toJson()],
  };
}

/// A master of a theme.
final class ThemeMasterSpec {
  /// Creates a master.
  const ThemeMasterSpec({
    required this.partKey,
    required this.name,
    this.background,
    required this.elements,
    required this.layouts,
  });

  /// Part key (`master:default`).
  final String partKey;

  /// Display name.
  final String name;

  /// `backgroundJson` (null = theme background).
  final SlideBackground? background;

  /// Master elements in z-order (decorations and master placeholders).
  final List<ThemeElementSpec> elements;

  /// Layouts in picker order.
  final List<ThemeLayoutSpec> layouts;

  /// The layout with [key], or `null`.
  ThemeLayoutSpec? layout(String key) {
    for (final l in layouts) {
      if (l.key == key) return l;
    }
    return null;
  }

  /// JSON form.
  JsonMap toJson() => {
    'partKey': partKey,
    'name': name,
    if (background != null) 'background': background!.toJson(),
    'elements': [for (final e in elements) e.toJson()],
    'layouts': [for (final l in layouts) l.toJson()],
  };
}

/// Result of [ThemePackage.fromJson].
final class ThemePackageResult {
  /// Creates a result.
  const ThemePackageResult(this.package, this.errors, this.warnings);

  /// The parsed package, or `null` on errors.
  final ThemePackage? package;

  /// Blocking issues.
  final List<ThemeIssue> errors;

  /// Repairs.
  final List<ThemeIssue> warnings;
}

/// A theme with its masters and layouts.
final class ThemePackage {
  /// Creates a package.
  const ThemePackage({
    this.key,
    this.version = 1,
    required this.theme,
    this.defaultAppearance = SlideAppearance.light,
    this.size = SlideSize.widescreen,
    required this.masters,
  });

  /// Built-in key (`wonky`), or `null`.
  final String? key;

  /// Definition version (built-ins: `builtin:<key>@<version>`).
  final int version;

  /// The theme row content.
  final DeckThemeData theme;

  /// The appearance new decks start with.
  final SlideAppearance defaultAppearance;

  /// The slide size the geometry was generated for.
  final SlideSize size;

  /// Masters (built-ins have one: `master:default`).
  final List<ThemeMasterSpec> masters;

  /// The display name.
  String get name => theme.name;

  /// Every element of the package by part key.
  Map<String, ThemeElementSpec> get elementsByPart => {
    for (final m in masters) ...{
      for (final e in m.elements) e.partKey: e,
      for (final l in m.layouts)
        for (final e in l.elements) e.partKey: e,
    },
  };

  /// JSON form.
  JsonMap toJson() => {
    'v': 1,
    if (key != null) 'key': key,
    'version': version,
    'defaultAppearance': defaultAppearance.name,
    'size': {
      'preset': size.kind.name,
      'width': normalizeJsonNumber(size.width),
      'height': normalizeJsonNumber(size.height),
    },
    'theme': theme.toJson(),
    'masters': [for (final m in masters) m.toJson()],
  };

  /// Parses and validates a package (theme columns through
  /// [DeckThemeValidator]).
  static ThemePackageResult fromJson(Object? json) {
    final sink = IssueSink();
    final r = JsonReader.object(
      json,
      '',
      sink,
      known: {
        'v',
        'key',
        'version',
        'defaultAppearance',
        'size',
        'theme',
        'masters',
      },
    );
    if (r == null) return ThemePackageResult(null, sink.errors, sink.warnings);
    r.version(required: true);
    final key = r.string('key');
    final version = r.integer('version', min: 1) ?? 1;
    final appearance = SlideAppearance.fromName(r.map['defaultAppearance']);
    if (r.has('defaultAppearance') && appearance == null) {
      sink.error(
        r.at('defaultAppearance'),
        'out_of_range',
        'Expected light or dark.',
      );
    }
    var size = SlideSize.widescreen;
    final s = r.child('size', known: {'preset', 'width', 'height'});
    if (s != null) {
      final w = s.number('width', required: true);
      final h = s.number('height', required: true);
      final kind =
          SlideSizeKind.fromName(s.map['preset']) ?? SlideSizeKind.custom;
      final problem = w == null || h == null ? null : SlideSize.validate(w, h);
      if (problem != null) sink.error(r.at('size'), 'invalid_size', problem);
      if (w != null && h != null && problem == null) {
        size = SlideSize(kind, w, h);
      }
    }
    final themeJson = r.map['theme'];
    DeckThemeData? theme;
    if (themeJson is Map) {
      final t = const DeckThemeValidator().validateTheme(
        themeJson.cast<String, Object?>(),
      );
      for (final i in [...t.errors, ...t.warnings]) {
        sink.issues.add(
          ThemeIssue(i.severity, 'theme.${i.path}', i.code, i.message),
        );
      }
      theme = t.theme;
    } else {
      sink.error('theme', 'missing', 'A theme is required.');
    }
    final masters = <ThemeMasterSpec>[];
    final rawMasters = r.list('masters', required: true) ?? const [];
    for (var i = 0; i < rawMasters.length; i++) {
      final m = JsonReader.object(
        rawMasters[i],
        'masters[$i]',
        sink,
        known: {'partKey', 'name', 'background', 'elements', 'layouts'},
      );
      if (m == null) continue;
      final layouts = <ThemeLayoutSpec>[];
      final rawLayouts = m.list('layouts') ?? const [];
      for (var j = 0; j < rawLayouts.length; j++) {
        final l = JsonReader.object(
          rawLayouts[j],
          '${m.at('layouts')}[$j]',
          sink,
          known: {
            'partKey',
            'key',
            'name',
            'background',
            'hideMasterElements',
            'hidden',
            'elements',
          },
        );
        if (l == null) continue;
        layouts.add(
          ThemeLayoutSpec(
            partKey: l.string('partKey', required: true) ?? '',
            key: l.string('key'),
            name: l.string('name', required: true) ?? '',
            background: l.has('background')
                ? SlideBackground.fromJson(
                    l.map['background'],
                    sink,
                    path: l.at('background'),
                  )
                : null,
            hideMasterElements: l.boolean('hideMasterElements') ?? false,
            hidden: l.boolean('hidden') ?? false,
            elements: _elements(l, sink),
          ),
        );
      }
      masters.add(
        ThemeMasterSpec(
          partKey: m.string('partKey', required: true) ?? '',
          name: m.string('name', required: true) ?? '',
          background: m.has('background')
              ? SlideBackground.fromJson(
                  m.map['background'],
                  sink,
                  path: m.at('background'),
                )
              : null,
          elements: _elements(m, sink),
          layouts: List.unmodifiable(layouts),
        ),
      );
    }
    if (masters.isEmpty && !sink.hasErrors) {
      sink.error('masters', 'missing', 'A theme needs at least one master.');
    }
    final partKeys = <String>{};
    for (final m in masters) {
      for (final p in [m.partKey, for (final l in m.layouts) l.partKey]) {
        if (!partKeys.add(p)) {
          sink.error('masters', 'duplicate_part', 'Duplicate part key "$p".');
        }
      }
    }
    final elements = <String>{};
    for (final m in masters) {
      for (final e in [
        ...m.elements,
        for (final l in m.layouts) ...l.elements,
      ]) {
        if (!elements.add(e.partKey)) {
          sink.error(
            'masters',
            'duplicate_part',
            'Duplicate part key "${e.partKey}".',
          );
        }
      }
    }
    if (sink.hasErrors || theme == null) {
      return ThemePackageResult(null, sink.errors, sink.warnings);
    }
    return ThemePackageResult(
      ThemePackage(
        key: key,
        version: version,
        theme: theme,
        defaultAppearance: appearance ?? SlideAppearance.light,
        size: size,
        masters: List.unmodifiable(masters),
      ),
      const [],
      sink.warnings,
    );
  }

  static List<ThemeElementSpec> _elements(JsonReader r, IssueSink sink) {
    final raw = r.list('elements') ?? const [];
    return List.unmodifiable([
      for (var i = 0; i < raw.length; i++)
        ?ThemeElementSpec._fromJson(raw[i], '${r.at('elements')}[$i]', sink),
    ]);
  }
}

/// A Delta JSON string holding [text] as one paragraph.
String plainDelta(String text) => jsonEncode([
  {'insert': '$text\n'},
]);
