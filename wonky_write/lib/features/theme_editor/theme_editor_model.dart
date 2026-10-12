import 'package:wonky_write_core/wonky_write_core.dart' as core;
import 'package:wonky_write_core/wonky_write_core.dart'
    show
        ColorRef,
        FontRef,
        FontRole,
        PaletteKey,
        PropType,
        ObjectProp,
        SyntaxToken,
        ThemeElement,
        ThemePropertyPath,
        ThemeVariant,
        WriteThemeData;

/// Decoded theme JSON.
typedef ThemeJson = Map<String, Object?>;

/// A node of the theme editor's element tree (Write 06 §10.2): a section
/// (Page, Theme colors, Fonts, …) or one element.
enum ThemeNodeKind {
  general,
  palette,
  fonts,
  page,
  element,
  syntax,
  headerFooter,
  advanced,
}

/// One selectable node: `general`, `palette`, `fonts`, `page`, `syntax`,
/// `headerFooter`, `advanced` or `element:<key>`.
class ThemeNode {
  const ThemeNode._(this.kind) : element = null;

  static const general = ThemeNode._(ThemeNodeKind.general);
  static const palette = ThemeNode._(ThemeNodeKind.palette);
  static const fonts = ThemeNode._(ThemeNodeKind.fonts);
  static const page = ThemeNode._(ThemeNodeKind.page);
  static const syntax = ThemeNode._(ThemeNodeKind.syntax);
  static const headerFooter = ThemeNode._(ThemeNodeKind.headerFooter);
  static const advanced = ThemeNode._(ThemeNodeKind.advanced);

  const ThemeNode.element(ThemeElement this.element)
    : kind = ThemeNodeKind.element;

  final ThemeNodeKind kind;
  final ThemeElement? element;

  /// Stable id (`write.theme.selectElement {element}`, widget keys).
  String get id => element == null ? kind.name : element!.name;

  /// Parses [id] (an element key or a section name); null when unknown.
  static ThemeNode? parse(String id) {
    final e = ThemeElement.fromJsonName(id);
    if (e != null) return ThemeNode.element(e);
    for (final k in ThemeNodeKind.values) {
      if (k != ThemeNodeKind.element && k.name == id) return ThemeNode._(k);
    }
    return null;
  }

  String get label => switch (kind) {
    ThemeNodeKind.general => 'Name & variants',
    ThemeNodeKind.palette => 'Theme colors',
    ThemeNodeKind.fonts => 'Fonts',
    ThemeNodeKind.page => 'Page',
    ThemeNodeKind.syntax => 'Syntax colors',
    ThemeNodeKind.headerFooter => 'Page header & footer',
    ThemeNodeKind.advanced => 'Advanced',
    ThemeNodeKind.element => elementLabel(element!),
  };

  @override
  bool operator ==(Object other) =>
      other is ThemeNode && other.kind == kind && other.element == element;

  @override
  int get hashCode => Object.hash(kind, element);

  @override
  String toString() => 'ThemeNode($id)';
}

/// Display name of [e].
String elementLabel(ThemeElement e) => switch (e) {
  ThemeElement.body => 'Body text',
  ThemeElement.headings => 'All headings',
  ThemeElement.h1 => 'Heading 1',
  ThemeElement.h2 => 'Heading 2',
  ThemeElement.h3 => 'Heading 3',
  ThemeElement.h4 => 'Heading 4',
  ThemeElement.h5 => 'Heading 5',
  ThemeElement.h6 => 'Heading 6',
  ThemeElement.paragraphAfterHeading => 'Paragraph after heading',
  ThemeElement.bold => 'Bold',
  ThemeElement.italic => 'Italic',
  ThemeElement.strike => 'Strikethrough',
  ThemeElement.inlineCode => 'Inline code',
  ThemeElement.link => 'Link',
  ThemeElement.mention => 'Mention',
  ThemeElement.blockquote => 'Blockquote',
  ThemeElement.codeBlock => 'Code block',
  ThemeElement.list => 'Lists',
  ThemeElement.task => 'Task lists',
  ThemeElement.rule => 'Horizontal rule',
  ThemeElement.image => 'Image',
  ThemeElement.table => 'Table',
  ThemeElement.header => 'Page header',
  ThemeElement.footer => 'Page footer',
};

/// A group of the element tree.
class ThemeTreeGroup {
  const ThemeTreeGroup(this.label, this.nodes, {this.node});

  final String label;

  /// The group's own node (Headings → all headings), if selectable.
  final ThemeNode? node;
  final List<ThemeNode> nodes;
}

/// The element tree of Write 06 §10.2.
const List<ThemeTreeGroup> themeTree = [
  ThemeTreeGroup('', [
    ThemeNode.general,
    ThemeNode.page,
    ThemeNode.palette,
    ThemeNode.fonts,
    ThemeNode.element(ThemeElement.body),
  ]),
  ThemeTreeGroup('Headings', node: ThemeNode.element(ThemeElement.headings), [
    ThemeNode.element(ThemeElement.h1),
    ThemeNode.element(ThemeElement.h2),
    ThemeNode.element(ThemeElement.h3),
    ThemeNode.element(ThemeElement.h4),
    ThemeNode.element(ThemeElement.h5),
    ThemeNode.element(ThemeElement.h6),
    ThemeNode.element(ThemeElement.paragraphAfterHeading),
  ]),
  ThemeTreeGroup('Inline', [
    ThemeNode.element(ThemeElement.bold),
    ThemeNode.element(ThemeElement.italic),
    ThemeNode.element(ThemeElement.strike),
    ThemeNode.element(ThemeElement.inlineCode),
    ThemeNode.element(ThemeElement.link),
    ThemeNode.element(ThemeElement.mention),
  ]),
  ThemeTreeGroup('Blocks', [
    ThemeNode.element(ThemeElement.blockquote),
    ThemeNode.element(ThemeElement.codeBlock),
    ThemeNode.syntax,
    ThemeNode.element(ThemeElement.list),
    ThemeNode.element(ThemeElement.task),
    ThemeNode.element(ThemeElement.rule),
    ThemeNode.element(ThemeElement.image),
    ThemeNode.element(ThemeElement.table),
  ]),
  ThemeTreeGroup('', [ThemeNode.headerFooter, ThemeNode.advanced]),
];

/// All selectable nodes in tree order.
final List<ThemeNode> allThemeNodes = [
  for (final g in themeTree) ...[?g.node, ...g.nodes],
];

/// The property sections a node edits: `(title, pathPrefix, catalog
/// object)`. A path prefix plus a field name is a `setProperty` path.
List<(String, String, ObjectProp)> sectionsOf(ThemeNode node) =>
    switch (node.kind) {
      ThemeNodeKind.element => [
        ('', 'elements.${node.element!.name}', _catalog(node.element!)),
      ],
      ThemeNodeKind.page => [('', 'page', _pageWithoutHeaderFooter)],
      ThemeNodeKind.headerFooter => [
        ('Header and footer', 'page.headerFooter', _headerFooter),
        ('Header only', 'elements.header', _catalog(ThemeElement.header)),
        ('Footer only', 'elements.footer', _catalog(ThemeElement.footer)),
      ],
      ThemeNodeKind.advanced => [
        ('App overlays', 'overlays', core.ThemeCatalog.overlays),
      ],
      _ => const [],
    };

ObjectProp _catalog(ThemeElement e) => core.ThemeCatalog.elements[e]!;

final ObjectProp _pageWithoutHeaderFooter = ObjectProp({
  for (final f in core.ThemeCatalog.page.fields.entries)
    if (f.key != 'headerFooter') f.key: f.value,
});

final ObjectProp _headerFooter =
    core.ThemeCatalog.page.fields['headerFooter']! as ObjectProp;

/// Property groups of the inspector (Write 06 §10.2: Text, Spacing, Box,
/// element-specific).
enum PropGroup { text, spacing, box, specific }

String propGroupLabel(PropGroup g, ThemeNode node) => switch (g) {
  PropGroup.text => 'Text',
  PropGroup.spacing => 'Spacing',
  PropGroup.box => 'Box',
  PropGroup.specific => switch (node.element) {
    ThemeElement.list => 'Markers',
    ThemeElement.task => 'Checkboxes',
    ThemeElement.table => 'Table',
    ThemeElement.image => 'Image',
    ThemeElement.rule => 'Line',
    ThemeElement.link => 'Link',
    ThemeElement.codeBlock => 'Code',
    ThemeElement.headings => 'Numbering',
    _ => 'More',
  },
};

const _textKeys = {
  'fontFamily',
  'fontSize',
  'fontWeight',
  'fontStyle',
  'lineHeight',
  'letterSpacing',
  'color',
  'caseTransform',
  'fontFeatures',
  'sizeRatio',
  'italic',
};

const _spacingKeys = {
  'spaceBefore',
  'spaceAfter',
  'padding',
  'paddingX',
  'firstLineIndent',
  'indentPerLevel',
  'markerGap',
  'itemSpacing',
  'borderBottomGap',
  'cellPadding',
  'pagelessPadding',
  'defaultMargins',
  'pagelessMaxWidth',
};

const _boxKeys = {
  'background',
  'border',
  'borderRadius',
  'borderBottom',
  'borderTop',
  'bar',
  'align',
  'shadow',
  'keepWithNext',
  'pageBreakBefore',
  'paperColor',
  'canvasColor',
  'pageShadow',
};

PropGroup groupOf(String key) {
  if (_textKeys.contains(key)) return PropGroup.text;
  if (_spacingKeys.contains(key)) return PropGroup.spacing;
  if (_boxKeys.contains(key)) return PropGroup.box;
  return PropGroup.specific;
}

const _labels = <String, String>{
  'fontFamily': 'Font',
  'fontSize': 'Size',
  'fontWeight': 'Weight',
  'fontStyle': 'Style',
  'lineHeight': 'Line height',
  'letterSpacing': 'Letter spacing',
  'color': 'Color',
  'caseTransform': 'Case',
  'fontFeatures': 'OpenType features',
  'spaceBefore': 'Space before',
  'spaceAfter': 'Space after',
  'padding': 'Padding',
  'background': 'Background',
  'border': 'Border',
  'borderRadius': 'Corner radius',
  'keepWithNext': 'Keep with next',
  'pageBreakBefore': 'Page break before',
  'align': 'Alignment',
  'firstLineIndent': 'First-line indent',
  'numbering': 'Heading numbering',
  'enabled': 'Enabled',
  'fromLevel': 'From level',
  'toLevel': 'To level',
  'style': 'Style',
  'suffix': 'Suffix',
  'borderBottom': 'Bottom border',
  'borderTop': 'Top border',
  'borderBottomGap': 'Gap above border',
  'lineColor': 'Line color',
  'lineThickness': 'Line thickness',
  'sizeRatio': 'Size ratio',
  'paddingX': 'Horizontal padding',
  'hoverColor': 'Hover color',
  'underline': 'Underline',
  'underlineStyle': 'Underline style',
  'underlineThickness': 'Underline thickness',
  'prefix': 'Prefix',
  'bar': 'Left bar',
  'italic': 'Italic',
  'wrap': 'Wrap lines',
  'showLanguageLabel': 'Language label',
  'tabSize': 'Tab size',
  'lineNumbers': 'Line numbers',
  'bullets': 'Bullets per level',
  'bulletColor': 'Bullet color',
  'bulletScale': 'Bullet size',
  'numberSuffix': 'Number suffix',
  'numberColor': 'Number color',
  'indentPerLevel': 'Indent per level',
  'markerGap': 'Marker gap',
  'itemSpacing': 'Item spacing',
  'checkbox': 'Checkbox',
  'shape': 'Shape',
  'size': 'Size',
  'borderColor': 'Border color',
  'checkedFill': 'Checked fill',
  'checkColor': 'Check mark',
  'checkedText': 'Checked items',
  'strike': 'Strike through',
  'opacity': 'Opacity',
  'thickness': 'Thickness',
  'width': 'Width',
  'ornament': 'Ornament',
  'maxWidth': 'Max width',
  'shadow': 'Shadow',
  'caption': 'Caption',
  'show': 'Show',
  'gap': 'Gap',
  'headerBackground': 'Header background',
  'headerColor': 'Header text',
  'headerFontWeight': 'Header weight',
  'borders': 'Borders',
  'borderWidth': 'Border width',
  'zebra': 'Zebra rows',
  'zebraColor': 'Zebra color',
  'cellPadding': 'Cell padding',
  'fontSizeRatio': 'Text size ratio',
  'paperColor': 'Paper',
  'canvasColor': 'Canvas',
  'pageShadow': 'Page shadow',
  'pagelessMaxWidth': 'Pageless width',
  'pagelessPadding': 'Pageless padding',
  'defaultMargins': 'Default margins',
  'selection': 'Selection',
  'caret': 'Caret',
  'commentHighlight': 'Comment highlight',
  'commentHighlightActive': 'Active comment',
  'suggestionInsert': 'Suggested insertion',
  'suggestionDelete': 'Suggested deletion',
  'findMatch': 'Find match',
  'findMatchActive': 'Current find match',
};

/// Display label of property [key].
String propLabel(String key) {
  final l = _labels[key];
  if (l != null) return l;
  final spaced = key.replaceAllMapped(
    RegExp('([A-Z])'),
    (m) => ' ${m[1]!.toLowerCase()}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Display labels of enum values.
String enumLabel(String value) => switch (value) {
  'none' => 'None',
  'smallCaps' => 'Small caps',
  'upperRoman-upperAlpha-decimal' => 'I. A. 1.',
  'decimal' => '1.',
  'outline' => '1.1.1',
  'legal' => '1.1.1.',
  'lowerAlpha' => 'a.',
  'upperAlpha' => 'A.',
  'lowerRoman' => 'i.',
  'upperRoman' => 'I.',
  'headerOnly' => 'Header only',
  '@' => '@ prefix',
  '' => 'No prefix',
  _ => value[0].toUpperCase() + value.substring(1),
};

/// Display name of a palette key.
String paletteLabel(PaletteKey k) => switch (k) {
  PaletteKey.text => 'Text',
  PaletteKey.heading => 'Headings',
  PaletteKey.muted => 'Muted text',
  PaletteKey.accent => 'Accent',
  PaletteKey.link => 'Link',
  PaletteKey.linkHover => 'Link hover',
  PaletteKey.page => 'Page',
  PaletteKey.canvas => 'Canvas',
  PaletteKey.border => 'Borders',
  PaletteKey.codeText => 'Code text',
  PaletteKey.codeBg => 'Code background',
  PaletteKey.quoteText => 'Quote text',
  PaletteKey.quoteBar => 'Quote bar',
  PaletteKey.quoteBg => 'Quote background',
  PaletteKey.tableHeaderBg => 'Table header',
  PaletteKey.tableStripe => 'Table stripe',
  PaletteKey.mentionBg => 'Mention background',
  PaletteKey.mentionText => 'Mention text',
  PaletteKey.highlight => 'Highlight',
  _ => 'Custom ${k.name.substring(6)}',
};

/// Display name of a syntax token.
String syntaxLabel(SyntaxToken t) => switch (t) {
  SyntaxToken.builtin => 'Built-in',
  SyntaxToken.regexp => 'Regular expression',
  _ => t.name[0].toUpperCase() + t.name.substring(1),
};

/// The node a contrast pair belongs to (tree ⚠ and inspector warnings).
ThemeNode nodeOfPair(String pairId) {
  if (pairId.startsWith('syntax.')) return ThemeNode.syntax;
  final level = RegExp(r'^h([1-6])$').firstMatch(pairId);
  if (level != null) {
    return ThemeNode.element(ThemeElement.heading(int.parse(level[1]!)));
  }
  return switch (pairId) {
    'body' => const ThemeNode.element(ThemeElement.body),
    'caption' => const ThemeNode.element(ThemeElement.image),
    'header' || 'footer' => ThemeNode.headerFooter,
    'link' => const ThemeNode.element(ThemeElement.link),
    'mention' => const ThemeNode.element(ThemeElement.mention),
    'inlineCode' => const ThemeNode.element(ThemeElement.inlineCode),
    'codeBlock' => const ThemeNode.element(ThemeElement.codeBlock),
    'blockquote' => const ThemeNode.element(ThemeElement.blockquote),
    'tableHeader' ||
    'tableCell' ||
    'tableZebra' => const ThemeNode.element(ThemeElement.table),
    'taskChecked' => const ThemeNode.element(ThemeElement.task),
    _ => ThemeNode.palette,
  };
}

/// Human name of a contrast pair ("Heading 2 on the page").
String pairLabel(String pairId) {
  if (pairId.startsWith('syntax.')) {
    final t = SyntaxToken.fromJsonName(pairId.substring(7));
    return '${t == null ? pairId : syntaxLabel(t)} tokens on code';
  }
  return switch (pairId) {
    'body' => 'Body text on the page',
    'caption' => 'Captions on the page',
    'header' => 'Page header text',
    'footer' => 'Page footer text',
    'link' => 'Links on the page',
    'mention' => 'Mentions on their chip',
    'inlineCode' => 'Inline code on its background',
    'codeBlock' => 'Code on the code background',
    'blockquote' => 'Quote text',
    'tableHeader' => 'Table header text',
    'tableCell' => 'Table cell text',
    'tableZebra' => 'Text on zebra rows',
    'taskChecked' => 'Checked task text',
    _ => switch (nodeOfPair(pairId).element) {
      final e? => '${elementLabel(e)} on the page',
      null => pairId,
    },
  };
}

/// Where a property's value comes from when the theme doesn't set it.
class InheritedValue {
  const InheritedValue(this.value, this.source);

  final Object? value;

  /// "Body", "All headings", "Wonky Default" …
  final String source;
}

/// Looks up inherited values for the inspector's placeholders and reset
/// tooltips ("Inherited from Body: 11pt", Write 06 §10.2): the variant's
/// layer, the cascade parents (text properties only) and finally the
/// built-in base.
abstract final class ThemeInheritance {
  static List<ThemeElement> _parents(ThemeElement e) => switch (e) {
    ThemeElement.h1 ||
    ThemeElement.h2 ||
    ThemeElement.h3 ||
    ThemeElement.h4 ||
    ThemeElement.h5 ||
    ThemeElement.h6 => const [ThemeElement.headings, ThemeElement.body],
    ThemeElement.headings ||
    ThemeElement.blockquote ||
    ThemeElement.list ||
    ThemeElement.task ||
    ThemeElement.table ||
    ThemeElement.header ||
    ThemeElement.footer => const [ThemeElement.body],
    ThemeElement.codeBlock ||
    ThemeElement.inlineCode => const [ThemeElement.body],
    _ => const [],
  };

  static const _inheritedFromParents = {
    'fontFamily',
    'fontSize',
    'fontWeight',
    'fontStyle',
    'lineHeight',
    'letterSpacing',
    'color',
    'caseTransform',
    'fontFeatures',
  };

  static const _codeInherits = {'color', 'lineHeight'};

  /// The value [path] inherits in [json] (it is not set at [path] itself).
  static InheritedValue? of(
    ThemeJson json,
    String path, {
    ThemeVariant variant = ThemeVariant.light,
  }) {
    final base = core.BaseTheme.instance.theme.toJson();
    Object? at(ThemeJson j, String p) {
      try {
        return ThemePropertyPath.get(j, p);
      } on core.ThemePathException {
        return null;
      }
    }

    final segs = path.split('.');
    // A dark override inherits the light value first.
    if (segs.first == 'dark') {
      final light = segs.sublist(1).join('.');
      final v = at(json, light);
      if (v != null) return InheritedValue(v, 'Light variant');
      return of(json, light);
    }
    if (segs.first == 'elements' && segs.length >= 3) {
      final e = ThemeElement.fromJsonName(segs[1]);
      final rest = segs.sublist(2).join('.');
      if (e != null) {
        final key = segs[2];
        final code =
            e == ThemeElement.codeBlock || e == ThemeElement.inlineCode;
        final inherits =
            segs.length == 3 &&
            (code ? _codeInherits : _inheritedFromParents).contains(key);
        if (inherits) {
          for (final p in _parents(e)) {
            final v = at(json, 'elements.${p.name}.$rest');
            if (v != null) return InheritedValue(v, elementLabel(p));
            if (p == ThemeElement.body &&
                (e == ThemeElement.header || e == ThemeElement.footer)) {
              final hf = at(json, 'page.headerFooter.$rest');
              if (hf != null) return InheritedValue(hf, 'Header and footer');
            }
          }
        }
        if (key == 'fontFamily' && segs.length == 3) {
          final role = core.ThemeCatalog.roleOf(e);
          return InheritedValue('@${role.name}', 'Theme fonts');
        }
        final b = at(base, path);
        if (b != null) return InheritedValue(b, 'Wonky Default');
        if (inherits) {
          for (final p in _parents(e)) {
            final v = at(base, 'elements.${p.name}.$rest');
            if (v != null) return InheritedValue(v, elementLabel(p));
          }
        }
        return null;
      }
    }
    final b = at(base, path);
    return b == null ? null : InheritedValue(b, 'Wonky Default');
  }

  /// The concrete font family [element] uses in [theme] (for weight
  /// options).
  static String familyOf(
    WriteThemeData theme,
    ThemeJson json,
    ThemeElement element,
  ) {
    Object? raw;
    try {
      raw = ThemePropertyPath.get(json, 'elements.${element.name}.fontFamily');
    } on core.ThemePathException {
      raw = null;
    }
    raw ??= of(json, 'elements.${element.name}.fontFamily')?.value;
    final ref = raw is String ? FontRef.tryParse(raw) : null;
    if (ref?.family != null) return ref!.family!;
    final role = ref?.role ?? core.ThemeCatalog.roleOf(element);
    return theme.fonts.of(role);
  }
}

/// The type of a property path (`fontSize` of `elements.h2` → the length
/// type), or null.
PropType? propTypeAt(ObjectProp object, List<String> rest) {
  PropType? t = object;
  for (final seg in rest) {
    if (t is! ObjectProp) return null;
    t = t.fields[seg];
  }
  return t;
}

/// Palette keys shown in the editor (all, custom last).
const editablePaletteKeys = PaletteKey.values;

/// A palette key as a color reference (`"@accent"`).
String paletteRef(PaletteKey k) => ColorRef.palette(k).toJson();

/// The theme fonts as `@role` references with their families.
List<(String, String)> roleFonts(WriteThemeData t) => [
  for (final r in FontRole.values) ('@${r.name}', t.fonts.of(r)),
];
