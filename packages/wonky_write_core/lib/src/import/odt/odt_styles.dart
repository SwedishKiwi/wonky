part of 'odt_importer.dart';

/// ODF namespace URIs.
abstract final class _Ns {
  static const office = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
  static const style = 'urn:oasis:names:tc:opendocument:xmlns:style:1.0';
  static const text = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
  static const table = 'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
  static const draw = 'urn:oasis:names:tc:opendocument:xmlns:drawing:1.0';
  static const fo =
      'urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0';
  static const svg = 'urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0';
  static const xlink = 'http://www.w3.org/1999/xlink';
  static const dc = 'http://purl.org/dc/elements/1.1/';
  static const math = 'http://www.w3.org/1998/Math/MathML';
}

/// One `style:style` / `style:default-style`.
final class _OdfStyle {
  _OdfStyle({
    required this.name,
    required this.family,
    required this.automatic,
    this.parent,
    this.display,
    this.listStyle,
    this.outlineLevel,
    this.masterPage,
    this.text = const {},
    this.para = const {},
  });

  /// Parses [e]; `null` without a family.
  static _OdfStyle? parse(XmlElement e, {required bool automatic}) {
    final family = e.attr(_Ns.style, 'family');
    if (family == null) return null;
    Map<String, String> props(String local) {
      final p = e.kid(_Ns.style, local);
      if (p == null) return const {};
      return {for (final a in p.attributes) a.name.local: a.value};
    }

    return _OdfStyle(
      name: e.attr(_Ns.style, 'name') ?? '',
      family: family,
      automatic: automatic,
      parent: e.attr(_Ns.style, 'parent-style-name'),
      display: e.attr(_Ns.style, 'display-name'),
      listStyle: e.attr(_Ns.style, 'list-style-name'),
      outlineLevel: int.tryParse(
        e.attr(_Ns.style, 'default-outline-level') ?? '',
      ),
      masterPage: e.attr(_Ns.style, 'master-page-name'),
      text: props('text-properties'),
      para: props('paragraph-properties'),
    );
  }

  final String name;
  final String family;
  final bool automatic;
  final String? parent;
  final String? display;
  final String? listStyle;
  final int? outlineLevel;
  final String? masterPage;

  /// `style:text-properties` attributes by local name.
  final Map<String, String> text;

  /// `style:paragraph-properties` attributes by local name.
  final Map<String, String> para;

  /// Lower-case names with `_xx_` escapes decoded (`Heading_20_1` →
  /// `heading 1`), including the display name.
  late final List<String> names = [
    _decodeName(name),
    if (display != null) _decodeName(display!),
  ];

  static String _decodeName(String n) => n
      .replaceAllMapped(
        RegExp('_([0-9A-Fa-f]{2})_'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      )
      .trim()
      .toLowerCase();

  bool named(bool Function(String n) test) => names.any(test);
}

/// A resolved font: family and whether it is fixed-pitch.
typedef _Font = ({String family, bool fixed});

/// All styles of a package (`styles.xml` and `content.xml`).
final class _StyleSheet {
  final _content = <String, _OdfStyle>{};
  final _common = <String, _OdfStyle>{};
  final _stylesAuto = <String, _OdfStyle>{};
  final _defaults = <String, _OdfStyle>{};
  final _lists = <String, XmlElement>{};
  final _fonts = <String, _Font>{};
  final masterPages = <XmlElement>[];
  final _pageLayouts = <String, XmlElement>{};

  /// Reads `styles.xml` ([styles]) and `content.xml` ([content]).
  void load({XmlDocument? styles, XmlDocument? content}) {
    final sRoot = styles?.rootElement;
    final cRoot = content?.rootElement;
    for (final root in [sRoot, cRoot]) {
      final decls = root?.kid(_Ns.office, 'font-face-decls');
      if (decls == null) continue;
      for (final f in decls.kids(_Ns.style, 'font-face')) {
        final name = f.attr(_Ns.style, 'name');
        if (name == null) continue;
        final family = _unquote(
          (f.attr(_Ns.svg, 'font-family') ?? name).split(',').first,
        );
        final fixed =
            f.attr(_Ns.style, 'font-pitch') == 'fixed' ||
            f.attr(_Ns.style, 'font-family-generic') == 'modern';
        _fonts[name] = (family: family, fixed: fixed);
      }
    }
    if (sRoot != null) {
      final common = sRoot.kid(_Ns.office, 'styles');
      if (common != null) _readStyles(common, _common, automatic: false);
      final auto = sRoot.kid(_Ns.office, 'automatic-styles');
      if (auto != null) {
        _readStyles(auto, _stylesAuto, automatic: true);
        for (final pl in auto.kids(_Ns.style, 'page-layout')) {
          final n = pl.attr(_Ns.style, 'name');
          if (n != null) _pageLayouts[n] = pl;
        }
      }
      final master = sRoot.kid(_Ns.office, 'master-styles');
      if (master != null) {
        masterPages.addAll(master.kids(_Ns.style, 'master-page'));
      }
    }
    final auto = cRoot?.kid(_Ns.office, 'automatic-styles');
    if (auto != null) _readStyles(auto, _content, automatic: true);
  }

  static String _unquote(String s) =>
      s.trim().replaceAll(RegExp('''^["']|["']\$'''), '').trim();

  void _readStyles(
    XmlElement container,
    Map<String, _OdfStyle> into, {
    required bool automatic,
  }) {
    for (final e in container.childElements) {
      if (e.isA(_Ns.style, 'style')) {
        final s = _OdfStyle.parse(e, automatic: automatic);
        if (s != null) into['${s.family}|${s.name}'] = s;
      } else if (e.isA(_Ns.style, 'default-style')) {
        final s = _OdfStyle.parse(e, automatic: false);
        if (s != null) _defaults[s.family] = s;
      } else if (e.isA(_Ns.text, 'list-style')) {
        final n = e.attr(_Ns.style, 'name');
        if (n != null) _lists.putIfAbsent(n, () => e);
      }
    }
  }

  /// The style [name] of [family] (content automatic styles first).
  _OdfStyle? lookup(String family, String? name) {
    if (name == null) return null;
    final key = '$family|$name';
    return _content[key] ?? _common[key] ?? _stylesAuto[key];
  }

  /// [name] and its ancestors (most specific first), then the family's
  /// default style when [withDefault].
  List<_OdfStyle> chain(
    String family,
    String? name, {
    bool withDefault = true,
  }) {
    final out = <_OdfStyle>[];
    final seen = <String>{};
    var s = lookup(family, name);
    while (s != null && out.length < 32 && seen.add(s.name)) {
      out.add(s);
      final p = s.parent;
      s = p == null
          ? null
          : (_common['$family|$p'] ?? _stylesAuto['$family|$p']);
    }
    final d = _defaults[family];
    if (withDefault && d != null) out.add(d);
    return out;
  }

  /// The first value of text property [key] along [chain].
  static String? textProp(Iterable<_OdfStyle> chain, String key) {
    for (final s in chain) {
      final v = s.text[key];
      if (v != null) return v;
    }
    return null;
  }

  /// The font of a text property map (`style:font-name` via the font face
  /// declarations, else `fo:font-family`).
  _Font? fontOf(Map<String, String> text) {
    final name = text['font-name'];
    if (name != null) {
      return _fonts[name] ?? (family: _unquote(name), fixed: false);
    }
    final family = text['font-family'];
    if (family != null) {
      final generic = text['font-family-generic'];
      return (
        family: _unquote(family.split(',').first),
        fixed: text['font-pitch'] == 'fixed' || generic == 'modern',
      );
    }
    return null;
  }

  /// The first font along [chain].
  _Font? fontAlong(Iterable<_OdfStyle> chain) {
    for (final s in chain) {
      final f = fontOf(s.text);
      if (f != null) return f;
    }
    return null;
  }

  /// A list style by name.
  XmlElement? listStyle(String? name) => name == null ? null : _lists[name];

  /// A page layout of `styles.xml` by name.
  XmlElement? pageLayout(String? name) =>
      name == null ? null : _pageLayouts[name];

  /// The default paragraph language (`fo:language`-`fo:country`).
  String? get defaultLanguage {
    final d = _defaults['paragraph'];
    final lang = d?.text['language'];
    if (lang == null || lang == 'none' || lang == 'zxx') return null;
    final country = d?.text['country'];
    return country == null || country == 'none' ? lang : '$lang-$country';
  }
}

/// Whether [font] is monospace.
bool _isMono(_Font? font) =>
    font != null && (font.fixed || MonospaceFonts.isMonospace(font.family));

/// Parses an ODF length (`2.54cm`, `1in`, `12pt`, `10mm`, `1pc`, `96px`) to
/// points.
double? _length(String? v) {
  if (v == null) return null;
  final m = RegExp(
    r'^\s*(-?\d*\.?\d+)\s*(pt|in|cm|mm|pc|px)?\s*$',
  ).firstMatch(v);
  if (m == null) return null;
  final n = double.tryParse(m.group(1)!);
  if (n == null) return null;
  return switch (m.group(2)) {
    'in' => n * 72,
    'cm' => n * 72 / 2.54,
    'mm' => n * 72 / 25.4,
    'pc' => n * 12,
    'px' => n * 0.75,
    _ => n,
  };
}
