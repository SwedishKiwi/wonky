/// Reads the parts of a WordprocessingML package (07 §3.6): relationships,
/// styles (with `w:basedOn` inheritance), numbering and core properties.
library;

import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../xml_support.dart';

/// Namespace URIs used by DOCX packages (Transitional; Strict URIs are
/// aliased by [XmlElementAccess]).
abstract final class OoxmlNs {
  /// WordprocessingML main.
  static const w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

  /// Office relationships (`r:id`, `r:embed`).
  static const r =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// Package relationships (`.rels` parts).
  static const rels =
      'http://schemas.openxmlformats.org/package/2006/relationships';

  /// DrawingML main (`a:blip`, `a:graphicData`).
  static const a = 'http://schemas.openxmlformats.org/drawingml/2006/main';

  /// DrawingML word processing (`wp:inline`, `wp:docPr`).
  static const wp =
      'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';

  /// DrawingML picture (`pic:pic`).
  static const pic = 'http://schemas.openxmlformats.org/drawingml/2006/picture';

  /// Word 2010 (`w14:checkbox`).
  static const w14 = 'http://schemas.microsoft.com/office/word/2010/wordml';

  /// Word 2010 shapes (`wps:txbx`).
  static const wps =
      'http://schemas.microsoft.com/office/word/2010/wordprocessingShape';

  /// Markup compatibility (`mc:AlternateContent`).
  static const mc =
      'http://schemas.openxmlformats.org/markup-compatibility/2006';

  /// VML (`v:imagedata`, `v:textbox`).
  static const v = 'urn:schemas-microsoft-com:vml';

  /// Office VML extensions (`o:hr`).
  static const o = 'urn:schemas-microsoft-com:office:office';

  /// Office math (`m:oMath`).
  static const m = 'http://schemas.openxmlformats.org/officeDocument/2006/math';

  /// Charts.
  static const c = 'http://schemas.openxmlformats.org/drawingml/2006/chart';

  /// SmartArt diagrams.
  static const dgm = 'http://schemas.openxmlformats.org/drawingml/2006/diagram';

  /// Dublin Core elements (`dc:title`, `dc:language`).
  static const dc = 'http://purl.org/dc/elements/1.1/';

  /// Content types.
  static const ct =
      'http://schemas.openxmlformats.org/package/2006/content-types';
}

/// One relationship of a part.
final class OoxmlRelationship {
  /// Creates a relationship.
  const OoxmlRelationship(this.id, this.type, this.target, {this.external = false});

  /// `Id`.
  final String id;

  /// Relationship type URI (only the last path segment matters).
  final String type;

  /// Resolved part name, or the raw URL for external targets.
  final String target;

  /// `TargetMode="External"`.
  final bool external;

  /// The last segment of [type] (`officeDocument`, `image`, `hyperlink`…).
  String get kind => type.substring(type.lastIndexOf('/') + 1);
}

/// A DOCX package.
final class OoxmlPackage {
  OoxmlPackage._(this.zip);

  /// The underlying ZIP.
  final ZipPackage zip;

  final _relsCache = <String, Map<String, OoxmlRelationship>>{};

  /// Opens [bytes]; `null` unless they are a ZIP with `[Content_Types].xml`.
  static OoxmlPackage? open(Uint8List bytes) {
    final zip = ZipPackage.open(bytes);
    if (zip == null || !zip.has('[Content_Types].xml')) return null;
    return OoxmlPackage._(zip);
  }

  /// Relationships of [part] (`dir/_rels/name.rels`).
  Map<String, OoxmlRelationship> relationships(String part) =>
      _relsCache.putIfAbsent(part, () {
        final dir = part.contains('/')
            ? part.substring(0, part.lastIndexOf('/') + 1)
            : '';
        final name = part.substring(dir.length);
        final relsPart = part.isEmpty ? '_rels/.rels' : '${dir}_rels/$name.rels';
        final doc = zip.xml(relsPart);
        final out = <String, OoxmlRelationship>{};
        if (doc == null) return out;
        for (final e in doc.rootElement.childElements) {
          if (e.name.local != 'Relationship') continue;
          final id = e.getAttribute('Id');
          final type = e.getAttribute('Type') ?? '';
          final target = e.getAttribute('Target');
          if (id == null || target == null) continue;
          final external = e.getAttribute('TargetMode') == 'External';
          out[id] = OoxmlRelationship(
            id,
            type,
            external ? target : ZipPackage.resolve(part, target),
            external: external,
          );
        }
        return out;
      });

  /// The first relationship of [part] whose kind is [kind].
  OoxmlRelationship? relationshipOfKind(String part, String kind) {
    for (final r in relationships(part).values) {
      if (r.kind == kind) return r;
    }
    return null;
  }

  /// The main document part (`word/document.xml` by default).
  String get mainDocumentPart {
    final r = relationshipOfKind('', 'officeDocument');
    if (r != null && zip.has(r.target)) return r.target;
    for (final n in zip.names) {
      if (n.toLowerCase() == 'word/document.xml') return n;
    }
    return 'word/document.xml';
  }
}

/// Resolved formatting of a style (after `w:basedOn` inheritance).
final class OoxmlStyle {
  /// Creates a style.
  OoxmlStyle({
    required this.id,
    required this.type,
    this.name,
    this.basedOn,
    this.isDefault = false,
    this.outlineLevel,
    this.numId,
    this.ilvl,
    this.bold,
    this.italic,
    this.strike,
    this.font,
    this.underline = false,
    this.color = false,
    this.highlight = false,
    this.hidden = false,
  });

  /// `w:styleId`.
  final String id;

  /// `paragraph`, `character`, `table`, `numbering`.
  final String type;

  /// `w:name` (built-in names are English: `heading 1`, `Title`…).
  String? name;

  /// `w:basedOn`.
  String? basedOn;

  /// `w:default="1"`.
  bool isDefault;

  /// `w:outlineLvl` (0–8; 9 = body text).
  int? outlineLevel;

  /// Numbering from the style (`w:numPr`).
  int? numId;

  /// Numbering level from the style.
  int? ilvl;

  /// `w:b`.
  bool? bold;

  /// `w:i`.
  bool? italic;

  /// `w:strike`/`w:dstrike`.
  bool? strike;

  /// `w:rFonts` (ascii/hAnsi).
  String? font;

  /// `w:u` other than `none`.
  bool underline;

  /// A non-automatic `w:color`.
  bool color;

  /// `w:highlight`/`w:shd`.
  bool highlight;

  /// `w:vanish`.
  bool hidden;

  /// Lower-case [name] (or id).
  String get lowerName => (name ?? id).toLowerCase();
}

/// Run properties read from a `w:rPr` element.
final class OoxmlRunProps {
  /// Creates run properties.
  OoxmlRunProps();

  /// Character style id.
  String? style;

  /// Bold.
  bool? bold;

  /// Italic.
  bool? italic;

  /// Strike.
  bool? strike;

  /// Font.
  String? font;

  /// Underline.
  bool underline = false;

  /// Text color.
  bool color = false;

  /// Highlight / shading.
  bool highlight = false;

  /// Superscript / subscript.
  bool script = false;

  /// Hidden text.
  bool hidden = false;

  /// Parses [rPr] (may be `null`).
  static OoxmlRunProps parse(XmlElement? rPr) {
    final p = OoxmlRunProps();
    if (rPr == null) return p;
    const w = OoxmlNs.w;
    for (final e in rPr.childElements) {
      if (_canonicalW(e) != w) continue;
      switch (e.name.local) {
        case 'rStyle':
          p.style = e.attr(w, 'val');
        case 'b':
          p.bold = toggle(e);
        case 'i':
          p.italic = toggle(e);
        case 'strike' || 'dstrike':
          final t = toggle(e);
          p.strike = (p.strike ?? false) || t;
        case 'rFonts':
          p.font =
              e.attr(w, 'ascii') ??
              e.attr(w, 'hAnsi') ??
              e.attr(w, 'cs') ??
              e.attr(w, 'eastAsia');
        case 'u':
          final v = e.attr(w, 'val');
          p.underline = v != 'none';
        case 'color':
          final v = (e.attr(w, 'val') ?? 'auto').toLowerCase();
          p.color = v != 'auto' && v != '000000';
        case 'highlight':
          p.highlight = (e.attr(w, 'val') ?? 'none') != 'none';
        case 'shd':
          final fill = (e.attr(w, 'fill') ?? 'auto').toLowerCase();
          p.highlight = p.highlight || (fill != 'auto' && fill != 'ffffff');
        case 'vertAlign':
          final v = e.attr(w, 'val');
          p.script = v == 'superscript' || v == 'subscript';
        case 'vanish' || 'webHidden' || 'specVanish':
          p.hidden = toggle(e);
      }
    }
    return p;
  }

  static String? _canonicalW(XmlElement e) =>
      e.isA(OoxmlNs.w, e.name.local) ? OoxmlNs.w : e.name.namespaceUri;

  /// Value of an on/off property (`w:val` absent, `1`, `true`, `on` → true).
  static bool toggle(XmlElement e) {
    final v = e.attr(OoxmlNs.w, 'val')?.toLowerCase();
    return !(v == '0' || v == 'false' || v == 'off' || v == 'none');
  }
}

/// `styles.xml` with resolved inheritance.
final class OoxmlStyles {
  OoxmlStyles._(this._raw, this.defaultLanguage);

  /// No styles.
  factory OoxmlStyles.empty() => OoxmlStyles._({}, null);

  final Map<String, OoxmlStyle> _raw;
  final _resolved = <String, OoxmlStyle>{};

  /// `w:docDefaults/w:rPrDefault/w:rPr/w:lang/@w:val`.
  final String? defaultLanguage;

  /// Parses [doc].
  static OoxmlStyles parse(XmlDocument? doc) {
    if (doc == null) return OoxmlStyles.empty();
    const w = OoxmlNs.w;
    final raw = <String, OoxmlStyle>{};
    final root = doc.rootElement;
    String? lang;
    final defaults = root.kid(w, 'docDefaults');
    final lng = defaults
        ?.kid(w, 'rPrDefault')
        ?.kid(w, 'rPr')
        ?.kid(w, 'lang');
    lang = lng?.attr(w, 'val');
    for (final s in root.kids(w, 'style')) {
      final id = s.attr(w, 'styleId');
      if (id == null) continue;
      final pPr = s.kid(w, 'pPr');
      final numPr = pPr?.kid(w, 'numPr');
      final rp = OoxmlRunProps.parse(s.kid(w, 'rPr'));
      raw[id] = OoxmlStyle(
        id: id,
        type: s.attr(w, 'type') ?? 'paragraph',
        name: s.kid(w, 'name')?.attr(w, 'val'),
        basedOn: s.kid(w, 'basedOn')?.attr(w, 'val'),
        isDefault: const {'1', 'true', 'on'}.contains(s.attr(w, 'default')),
        outlineLevel: int.tryParse(
          pPr?.kid(w, 'outlineLvl')?.attr(w, 'val') ?? '',
        ),
        numId: int.tryParse(numPr?.kid(w, 'numId')?.attr(w, 'val') ?? ''),
        ilvl: int.tryParse(numPr?.kid(w, 'ilvl')?.attr(w, 'val') ?? ''),
        bold: rp.bold,
        italic: rp.italic,
        strike: rp.strike,
        font: rp.font,
        underline: rp.underline,
        color: rp.color,
        highlight: rp.highlight || rp.script,
        hidden: rp.hidden,
      );
    }
    return OoxmlStyles._(raw, lang);
  }

  /// The style [id] with inherited properties, or `null`.
  OoxmlStyle? operator [](String? id) {
    if (id == null) return null;
    final cached = _resolved[id];
    if (cached != null) return cached;
    final own = _raw[id];
    if (own == null) return null;
    final chain = <OoxmlStyle>[];
    final seen = <String>{};
    OoxmlStyle? s = own;
    while (s != null && seen.add(s.id) && chain.length < 32) {
      chain.add(s);
      s = s.basedOn == null ? null : _raw[s.basedOn];
    }
    final r = OoxmlStyle(id: own.id, type: own.type, name: own.name)
      ..isDefault = own.isDefault;
    for (final c in chain.reversed) {
      r.outlineLevel = c.outlineLevel ?? r.outlineLevel;
      if (c.numId != null) {
        r.numId = c.numId;
        r.ilvl = c.ilvl ?? r.ilvl;
      } else if (c.ilvl != null) {
        r.ilvl = c.ilvl;
      }
      r.bold = c.bold ?? r.bold;
      r.italic = c.italic ?? r.italic;
      r.strike = c.strike ?? r.strike;
      r.font = c.font ?? r.font;
      r.underline = c.underline || r.underline;
      r.color = c.color || r.color;
      r.highlight = c.highlight || r.highlight;
      r.hidden = c.hidden || r.hidden;
    }
    // A font inherited only from the default paragraph style does not make
    // text monospace (07 §3.6: "all runs monospace").
    if (chain.isNotEmpty && chain.last.isDefault && chain.last.font == r.font) {
      final explicit = chain
          .take(chain.length - 1)
          .any((c) => c.font != null);
      if (!explicit) r.font = null;
    }
    _resolved[id] = r;
    return r;
  }

  /// The default paragraph style (`w:default="1"`, type paragraph).
  OoxmlStyle? get defaultParagraph {
    for (final s in _raw.values) {
      if (s.type == 'paragraph' && s.isDefault) return this[s.id];
    }
    return null;
  }
}

/// One numbering level.
final class OoxmlLevel {
  /// Creates a level.
  const OoxmlLevel({this.format = 'decimal', this.start = 1, this.text = ''});

  /// `w:numFmt` (`bullet`, `decimal`, `lowerLetter`, …).
  final String format;

  /// `w:start`.
  final int start;

  /// `w:lvlText`.
  final String text;

  /// Whether the level is a bullet level.
  bool get isBullet => format == 'bullet' || format == 'none';
}

/// `numbering.xml`.
final class OoxmlNumbering {
  OoxmlNumbering._(this._abstract, this._nums);

  /// No numbering.
  factory OoxmlNumbering.empty() => OoxmlNumbering._({}, {});

  final Map<int, Map<int, OoxmlLevel>> _abstract;
  final Map<int, (int, Map<int, int>)> _nums;

  /// Parses [doc].
  static OoxmlNumbering parse(XmlDocument? doc) {
    if (doc == null) return OoxmlNumbering.empty();
    const w = OoxmlNs.w;
    final abstract = <int, Map<int, OoxmlLevel>>{};
    final nums = <int, (int, Map<int, int>)>{};
    final root = doc.rootElement;
    for (final a in root.kids(w, 'abstractNum')) {
      final id = int.tryParse(a.attr(w, 'abstractNumId') ?? '');
      if (id == null) continue;
      final levels = <int, OoxmlLevel>{};
      for (final l in a.kids(w, 'lvl')) {
        final ilvl = int.tryParse(l.attr(w, 'ilvl') ?? '');
        if (ilvl == null) continue;
        levels[ilvl] = OoxmlLevel(
          format: l.kid(w, 'numFmt')?.attr(w, 'val') ?? 'decimal',
          start: int.tryParse(l.kid(w, 'start')?.attr(w, 'val') ?? '') ?? 1,
          text: l.kid(w, 'lvlText')?.attr(w, 'val') ?? '',
        );
      }
      abstract[id] = levels;
    }
    for (final n in root.kids(w, 'num')) {
      final id = int.tryParse(n.attr(w, 'numId') ?? '');
      final abs = int.tryParse(
        n.kid(w, 'abstractNumId')?.attr(w, 'val') ?? '',
      );
      if (id == null || abs == null) continue;
      final overrides = <int, int>{};
      for (final o in n.kids(w, 'lvlOverride')) {
        final ilvl = int.tryParse(o.attr(w, 'ilvl') ?? '');
        final start = int.tryParse(
          o.kid(w, 'startOverride')?.attr(w, 'val') ?? '',
        );
        if (ilvl != null && start != null) overrides[ilvl] = start;
      }
      nums[id] = (abs, overrides);
    }
    return OoxmlNumbering._(abstract, nums);
  }

  /// The level [ilvl] of list [numId] (with start overrides), or `null`.
  OoxmlLevel? level(int numId, int ilvl) {
    final n = _nums[numId];
    if (n == null) return null;
    final lvl = _abstract[n.$1]?[ilvl] ?? _abstract[n.$1]?[0];
    if (lvl == null) return const OoxmlLevel(format: 'bullet');
    final start = n.$2[ilvl];
    return start == null
        ? lvl
        : OoxmlLevel(format: lvl.format, start: start, text: lvl.text);
  }

  /// Whether [numId] is defined.
  bool has(int numId) => _nums.containsKey(numId);
}
