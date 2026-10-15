/// `word/styles.xml`, `word/numbering.xml`, `word/settings.xml` and
/// `word/fontTable.xml` generated from the resolved theme (07 §5.4, 06 §7.1).
library;

import '../../theme/model/style_enums.dart';
import '../../theme/model/values.dart';
import '../../theme/resolve/resolved_theme.dart';
import 'package:wonky_fonts/wonky_fonts.dart';
import '../office/office_support.dart';
import 'docx_xml.dart';

/// Style ids used by the DOCX exporter (and recognized by the importer).
abstract final class DocxStyleIds {
  /// Body text.
  static const normal = 'Normal';

  /// `Heading1` … `Heading6`.
  static String heading(int level) => 'Heading${level.clamp(1, 6)}';

  /// Blockquote lines.
  static const quote = 'Quote';

  /// Code block lines.
  static const codeBlock = 'CodeBlock';

  /// Inline code (character style).
  static const codeChar = 'CodeChar';

  /// Hyperlinks (character style).
  static const hyperlink = 'Hyperlink';

  /// List items and tasks.
  static const listParagraph = 'ListParagraph';

  /// Image captions.
  static const caption = 'Caption';

  /// Paragraph holding an image.
  static const figure = 'WonkyFigure';

  /// Horizontal rule paragraph.
  static const rule = 'WonkyRule';

  /// Spacer paragraphs around tables (skipped by the importer).
  static const spacer = 'WonkySpacer';

  /// Table header cell paragraphs.
  static const tableHeading = 'WonkyTableHeading';

  /// Table body cell paragraphs.
  static const tableText = 'WonkyTableText';

  /// Text of checked tasks (character style).
  static const taskDone = 'WonkyTaskDone';

  /// Mentions (character style).
  static const mention = 'WonkyMention';

  /// Page header.
  static const header = 'Header';

  /// Page footer.
  static const footer = 'Footer';

  /// TOC title.
  static const tocHeading = 'TOCHeading';

  /// `TOC1` … `TOC6`.
  static String toc(int level) => 'TOC${level.clamp(1, 6)}';

  /// The table style.
  static const table = 'WonkyTable';
}

/// Numbering instance ids (`w:numId`).
abstract final class DocxNumIds {
  /// Bullets (shared by all bullet lists).
  static const bullets = 1;

  /// Tasks (no marker; the checkbox glyph is text).
  static const tasks = 2;

  /// Heading numbering (only when the theme numbers headings).
  static const headings = 3;

  /// First ordered-list instance; each ordered run gets its own id. Ids
  /// are contiguous (some readers index `w:num` by position).
  static int firstOrdered({required bool headingNumbering}) =>
      headingNumbering ? 4 : 3;
}

/// Writes the style-related package parts.
final class DocxStyleWriter {
  /// Creates a writer for [theme].
  DocxStyleWriter(this.theme, {this.language});

  /// The resolved theme.
  final ResolvedWriteTheme theme;

  /// Document language (`w:lang`).
  final String? language;

  static const _header =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

  String _style(
    String type,
    String id,
    String name, {
    String? basedOn,
    String? next,
    String? link,
    bool isDefault = false,
    bool qFormat = true,
    int? uiPriority,
    ParaProps? pPr,
    RunProps? rPr,
    String extra = '',
  }) {
    final b = StringBuffer(
      '<w:style w:type="$type"${isDefault ? ' w:default="1"' : ''} '
      'w:styleId="${xmlAttr(id)}"><w:name w:val="${xmlAttr(name)}"/>',
    );
    if (basedOn != null) b.write('<w:basedOn w:val="$basedOn"/>');
    if (next != null) b.write('<w:next w:val="$next"/>');
    if (link != null) b.write('<w:link w:val="$link"/>');
    if (uiPriority != null) b.write('<w:uiPriority w:val="$uiPriority"/>');
    if (qFormat) b.write('<w:qFormat/>');
    b.write(pPr?.xml() ?? '');
    b.write(rPr?.xml() ?? '');
    b.write(extra);
    b.write('</w:style>');
    return b.toString();
  }

  RunProps _r(ResolvedTextStyle s) => RunProps().applyStyle(s);

  ParaProps _box(ResolvedBox box, {double? lineHeight}) => ParaProps()
    ..spaceBefore = box.spaceBefore
    ..spaceAfter = box.spaceAfter
    ..lineHeight = lineHeight
    ..align = box.align == ThemeAlign.left ? null : box.align
    ..keepNext = box.keepWithNext
    ..pageBreakBefore = box.pageBreakBefore;

  /// `word/styles.xml`.
  String stylesXml({required double contentWidth}) {
    final t = theme;
    final b = StringBuffer(_header)..write('<w:styles xmlns:w="${DocxNs.w}">');
    // Document defaults.
    final defaults = RunProps().applyStyle(t.body.style)
      ..bold = null
      ..italic = null
      ..lang = language;
    b.write(
      '<w:docDefaults><w:rPrDefault>${defaults.xml()}</w:rPrDefault>'
      '<w:pPrDefault><w:pPr><w:spacing w:after="0" '
      'w:line="${(t.body.style.lineHeight * 240).round()}" w:lineRule="auto"/>'
      '</w:pPr></w:pPrDefault></w:docDefaults>',
    );
    // Normal.
    final normal = _box(t.body.box, lineHeight: t.body.style.lineHeight)
      ..widowControl = true
      ..keepNext = false;
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.normal,
        'Normal',
        isDefault: true,
        pPr: normal,
        rPr: _r(t.body.style),
      ),
    );
    b.write(
      _style(
        'character',
        'DefaultParagraphFont',
        'Default Paragraph Font',
        isDefault: true,
        qFormat: false,
        uiPriority: 1,
      ),
    );
    // Headings.
    for (final h in t.headings) {
      final p = _box(h.box, lineHeight: h.style.lineHeight)
        ..keepNext = true
        ..keepLines = true
        ..outlineLevel = h.level - 1
        ..firstLine = null;
      if (t.headingNumbering.numbers(h.level)) {
        p.numbering = (DocxNumIds.headings, h.level - 1);
      }
      final border = h.borderBottom;
      if (border != null && border.isVisible) {
        p.bottom = docxBorder(
          'bottom',
          border,
          space: h.borderBottomGap.clamp(0, 31),
        );
      }
      b.write(
        _style(
          'paragraph',
          DocxStyleIds.heading(h.level),
          'heading ${h.level}',
          basedOn: DocxStyleIds.normal,
          next: DocxStyleIds.normal,
          uiPriority: 9,
          pPr: p,
          rPr: _r(h.style),
        ),
      );
    }
    // Quote.
    final q = t.blockquote;
    final quote = _box(q.box, lineHeight: q.style.lineHeight)
      ..indentLeft = q.box.padding.left + (q.bar.isVisible ? q.bar.width : 0)
      ..indentRight = q.box.padding.right == 0 ? null : q.box.padding.right
      ..spaceBefore = 0
      ..spaceAfter = 0;
    if (q.bar.isVisible) {
      quote.left = docxBorder(
        'left',
        q.bar,
        space: q.box.padding.left.clamp(0, 31),
      );
    }
    if (q.box.background != null) quote.shading = q.box.background;
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.quote,
        'Quote',
        basedOn: DocxStyleIds.normal,
        next: DocxStyleIds.normal,
        uiPriority: 29,
        pPr: quote,
        rPr: _r(q.style),
      ),
    );
    // Code block.
    final c = t.codeBlock;
    final code = ParaProps()
      ..spaceBefore = 0
      ..spaceAfter = 0
      ..lineHeight = c.style.lineHeight
      ..indentLeft = c.box.padding.left
      ..indentRight = c.box.padding.right
      ..keepLines = true;
    if (c.box.background != null) code.shading = c.box.background;
    if (c.box.border.hasAny) {
      code
        ..top = docxBorder('top', c.box.border.top)
        ..left = docxBorder('left', c.box.border.left)
        ..bottom = docxBorder('bottom', c.box.border.bottom)
        ..right = docxBorder('right', c.box.border.right);
    }
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.codeBlock,
        'Code Block',
        basedOn: DocxStyleIds.normal,
        uiPriority: 39,
        pPr: code,
        rPr: _r(c.style),
      ),
    );
    // Inline code.
    final ic = t.inlineCode;
    final codeChar = RunProps()
      ..font = ic.fontFamily
      ..size = t.body.style.fontSize * ic.sizeRatio
      ..color = ic.color
      ..shading = ic.background;
    b.write(
      _style(
        'character',
        DocxStyleIds.codeChar,
        'Code Char',
        basedOn: 'DefaultParagraphFont',
        uiPriority: 39,
        rPr: codeChar,
      ),
    );
    // Hyperlink.
    final link = RunProps()
      ..color = t.link.color
      ..underline = t.link.underline == LinkUnderline.always;
    b.write(
      _style(
        'character',
        DocxStyleIds.hyperlink,
        'Hyperlink',
        basedOn: 'DefaultParagraphFont',
        uiPriority: 99,
        qFormat: false,
        rPr: link,
      ),
    );
    // Mention.
    b.write(
      _style(
        'character',
        DocxStyleIds.mention,
        'Wonky Mention',
        basedOn: 'DefaultParagraphFont',
        qFormat: false,
        rPr: RunProps()
          ..bold = t.mention.fontWeight >= 600 ? true : null
          ..color = t.mention.color
          ..shading = t.mention.background,
      ),
    );
    // Checked task text.
    b.write(
      _style(
        'character',
        DocxStyleIds.taskDone,
        'Wonky Task Done',
        basedOn: 'DefaultParagraphFont',
        qFormat: false,
        rPr: RunProps()
          ..strike = t.task.checkedStrike
          ..color = flattenAlpha(
            (t.task.checkedColor & 0xFFFFFF) |
                ((t.task.checkedOpacity.clamp(0, 1) * 255).round() << 24),
            background: t.page.paperColor,
          ),
      ),
    );
    // List paragraph.
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.listParagraph,
        'List Paragraph',
        basedOn: DocxStyleIds.normal,
        uiPriority: 34,
        pPr: ParaProps()
          ..spaceBefore = 0
          ..spaceAfter = t.list.itemSpacing,
      ),
    );
    // Caption.
    final cap = t.image.caption;
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.caption,
        'caption',
        basedOn: DocxStyleIds.normal,
        next: DocxStyleIds.normal,
        uiPriority: 35,
        pPr: ParaProps()
          ..spaceBefore = 0
          ..spaceAfter = t.image.box.spaceAfter
          ..lineHeight = cap.style.lineHeight
          ..align = cap.align == ThemeAlign.left ? null : cap.align,
        rPr: _r(cap.style),
      ),
    );
    // Figure.
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.figure,
        'Wonky Figure',
        basedOn: DocxStyleIds.normal,
        next: DocxStyleIds.normal,
        pPr: ParaProps()
          ..spaceBefore = t.image.box.spaceBefore
          ..spaceAfter = t.image.box.spaceAfter
          ..lineHeight = 1
          ..keepNext = t.image.caption.show
          ..align = t.image.align == ImageAlign.center
              ? ThemeAlign.center
              : null,
      ),
    );
    // Rule.
    final rule = ParaProps()
      ..spaceBefore = t.rule.box.spaceBefore
      ..spaceAfter = t.rule.box.spaceAfter;
    final RunProps? ruleRun;
    if (t.rule.style == RuleStyle.ornament) {
      rule.align = ThemeAlign.center;
      ruleRun = _r(t.rule.ornamentStyle)..color = t.rule.color;
    } else {
      final width = t.rule.width.resolve(contentWidth);
      final inset = ((contentWidth - width) / 2).clamp(0, contentWidth / 2);
      if (inset > 0.5) {
        rule
          ..indentLeft = inset.toDouble()
          ..indentRight = inset.toDouble();
      }
      rule
        ..lineHeight = 0.5
        ..bottom = docxBorder(
          'bottom',
          BorderPt(
            width: t.rule.thickness,
            style: switch (t.rule.style) {
              RuleStyle.dashed => LineStyle.dashed,
              RuleStyle.dotted => LineStyle.dotted,
              RuleStyle.doubleLine => LineStyle.doubleLine,
              _ => LineStyle.solid,
            },
            color: t.rule.color,
          ),
        );
      ruleRun = RunProps()..size = 4;
    }
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.rule,
        'Wonky Horizontal Rule',
        basedOn: DocxStyleIds.normal,
        next: DocxStyleIds.normal,
        pPr: rule,
        rPr: ruleRun,
      ),
    );
    // Spacer.
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.spacer,
        'Wonky Spacer',
        basedOn: DocxStyleIds.normal,
        qFormat: false,
        pPr: ParaProps()
          ..spaceBefore = 0
          ..spaceAfter = 0,
        rPr: RunProps()..size = 1,
      ),
    );
    // Table cell paragraphs.
    final tb = t.table;
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.tableText,
        'Wonky Table Text',
        basedOn: DocxStyleIds.normal,
        pPr: ParaProps()
          ..spaceBefore = 0
          ..spaceAfter = 0
          ..lineHeight = tb.style.lineHeight
          ..firstLine = 0,
        rPr: _r(tb.style),
      ),
    );
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.tableHeading,
        'Wonky Table Heading',
        basedOn: DocxStyleIds.tableText,
        pPr: ParaProps()..keepNext = true,
        rPr: _r(tb.headerStyle),
      ),
    );
    // Header / footer.
    for (final (id, name, hf) in [
      (DocxStyleIds.header, 'header', t.header),
      (DocxStyleIds.footer, 'footer', t.footer),
    ]) {
      final p = ParaProps()
        ..spaceBefore = 0
        ..spaceAfter = 0
        ..lineHeight = hf.style.lineHeight
        ..firstLine = 0
        ..tabs = [
          (kind: 'center', positionPt: contentWidth / 2),
          (kind: 'right', positionPt: contentWidth),
        ];
      if (hf.borderBottom?.isVisible ?? false) {
        p.bottom = docxBorder('bottom', hf.borderBottom, space: 4);
      }
      if (hf.borderTop?.isVisible ?? false) {
        p.top = docxBorder('top', hf.borderTop, space: 4);
      }
      b.write(
        _style(
          'paragraph',
          id,
          name,
          basedOn: DocxStyleIds.normal,
          uiPriority: 99,
          qFormat: false,
          pPr: p,
          rPr: _r(hf.style),
        ),
      );
    }
    // TOC.
    b.write(
      _style(
        'paragraph',
        DocxStyleIds.tocHeading,
        'TOC Heading',
        basedOn: DocxStyleIds.normal,
        next: DocxStyleIds.normal,
        uiPriority: 39,
        pPr:
            _box(
                t.headings.first.box,
                lineHeight: t.headings.first.style.lineHeight,
              )
              ..keepNext = true
              ..pageBreakBefore = false,
        rPr: _r(t.headings[1].style),
      ),
    );
    for (var level = 1; level <= 6; level++) {
      b.write(
        _style(
          'paragraph',
          DocxStyleIds.toc(level),
          'toc $level',
          basedOn: DocxStyleIds.normal,
          next: DocxStyleIds.normal,
          uiPriority: 39,
          qFormat: false,
          pPr: ParaProps()
            ..spaceBefore = 0
            ..spaceAfter = 4
            ..indentLeft = (level - 1) * 12.0
            ..firstLine = 0
            ..tabs = [(kind: 'right', positionPt: contentWidth)],
        ),
      );
    }
    // Table style.
    b.write(_tableStyle());
    b.write('</w:styles>');
    return b.toString();
  }

  String _tableStyle() {
    final tb = theme.table;
    final line = BorderPt(
      width: tb.borderWidth,
      style: LineStyle.solid,
      color: tb.borderColor,
    );
    String border(String side, bool on) =>
        on ? docxBorder(side, line) : '<w:$side w:val="nil"/>';
    final all = tb.borders == TableBorders.all;
    final outer = all || tb.borders == TableBorders.outer;
    final horizontal = all || tb.borders == TableBorders.horizontal;
    final pad = tb.cellPadding;
    final b = StringBuffer(
      '<w:style w:type="table" w:styleId="${DocxStyleIds.table}">'
      '<w:name w:val="Wonky Table"/><w:basedOn w:val="TableNormal"/>'
      '<w:uiPriority w:val="59"/><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>'
      '<w:tblPr><w:tblStyleRowBandSize w:val="1"/><w:tblBorders>'
      '${border('top', outer || tb.borders == TableBorders.horizontal)}'
      '${border('left', outer)}'
      '${border('bottom', outer || tb.borders == TableBorders.horizontal)}'
      '${border('right', outer)}'
      '${border('insideH', horizontal)}'
      '${border('insideV', all)}'
      '</w:tblBorders><w:tblCellMar>'
      '<w:top w:w="${OfficeUnits.twips(pad.top)}" w:type="dxa"/>'
      '<w:left w:w="${OfficeUnits.twips(pad.left)}" w:type="dxa"/>'
      '<w:bottom w:w="${OfficeUnits.twips(pad.bottom)}" w:type="dxa"/>'
      '<w:right w:w="${OfficeUnits.twips(pad.right)}" w:type="dxa"/>'
      '</w:tblCellMar></w:tblPr>',
    );
    final headerFill = tb.headerBackground;
    final headerBottom =
        tb.borders == TableBorders.headerOnly ||
        tb.borders == TableBorders.horizontal;
    if (headerFill != null || headerBottom) {
      b.write('<w:tblStylePr w:type="firstRow"><w:tcPr>');
      if (headerBottom) {
        b.write('<w:tcBorders>${docxBorder('bottom', line)}</w:tcBorders>');
      }
      if (headerFill != null) b.write(docxShading(headerFill));
      b.write('</w:tcPr></w:tblStylePr>');
    }
    if (tb.zebra && tb.zebraColor != null) {
      b.write(
        '<w:tblStylePr w:type="band2Horz"><w:tcPr>'
        '${docxShading(tb.zebraColor!)}</w:tcPr></w:tblStylePr>',
      );
    }
    b.write('</w:style>');
    return '<w:style w:type="table" w:default="1" w:styleId="TableNormal">'
        '<w:name w:val="Normal Table"/><w:uiPriority w:val="99"/><w:semiHidden/>'
        '<w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar>'
        '<w:top w:w="0" w:type="dxa"/><w:left w:w="108" w:type="dxa"/>'
        '<w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/>'
        '</w:tblCellMar></w:tblPr></w:style>$b';
  }

  /// The `w:numFmt` of a list number style.
  static String numFmt(ListNumberStyle s) => switch (s) {
    ListNumberStyle.decimal => 'decimal',
    ListNumberStyle.lowerAlpha => 'lowerLetter',
    ListNumberStyle.upperAlpha => 'upperLetter',
    ListNumberStyle.lowerRoman => 'lowerRoman',
    ListNumberStyle.upperRoman => 'upperRoman',
  };

  /// `word/numbering.xml` with [orderedNums] ordered-list instances
  /// (ids from [DocxNumIds.firstOrdered]).
  String numberingXml(int orderedNums) {
    final l = theme.list;
    final b = StringBuffer(_header)
      ..write('<w:numbering xmlns:w="${DocxNs.w}">');
    String ind(int level) =>
        '<w:pPr><w:ind w:left="${OfficeUnits.twips(l.indentFor(level))}" '
        'w:hanging="${OfficeUnits.twips(l.indentPerLevel)}"/></w:pPr>';
    // 1: bullets.
    b.write(
      '<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="hybridMultilevel"/>',
    );
    for (var level = 0; level < 9; level++) {
      final size = theme.body.style.fontSize * l.bulletScale;
      b.write(
        '<w:lvl w:ilvl="$level"><w:start w:val="1"/><w:numFmt w:val="bullet"/>'
        '<w:lvlText w:val="${xmlAttr(l.bulletFor(level))}"/><w:lvlJc w:val="left"/>'
        '${ind(level)}<w:rPr><w:color w:val="${rgbHex(flattenAlpha(l.bulletColor))}"/>'
        '<w:sz w:val="${OfficeUnits.halfPoints(size)}"/></w:rPr></w:lvl>',
      );
    }
    b.write('</w:abstractNum>');
    // 2: ordered.
    b.write(
      '<w:abstractNum w:abstractNumId="2"><w:multiLevelType w:val="hybridMultilevel"/>',
    );
    for (var level = 0; level < 9; level++) {
      b.write(
        '<w:lvl w:ilvl="$level"><w:start w:val="1"/>'
        '<w:numFmt w:val="${numFmt(l.numberStyleFor(level))}"/>'
        '<w:lvlText w:val="%${level + 1}${xmlAttr(l.numberSuffix)}"/>'
        '<w:lvlJc w:val="left"/>${ind(level)}'
        '<w:rPr><w:color w:val="${rgbHex(flattenAlpha(l.numberColor))}"/></w:rPr></w:lvl>',
      );
    }
    b.write('</w:abstractNum>');
    // 3: tasks (no marker).
    b.write(
      '<w:abstractNum w:abstractNumId="3"><w:multiLevelType w:val="hybridMultilevel"/>',
    );
    for (var level = 0; level < 9; level++) {
      b.write(
        '<w:lvl w:ilvl="$level"><w:start w:val="1"/><w:numFmt w:val="none"/>'
        '<w:suff w:val="nothing"/><w:lvlText w:val=""/><w:lvlJc w:val="left"/>'
        '${ind(level)}</w:lvl>',
      );
    }
    b.write('</w:abstractNum>');
    // 4: heading numbering.
    final hn = theme.headingNumbering;
    if (hn.enabled) {
      b.write(
        '<w:abstractNum w:abstractNumId="4"><w:multiLevelType w:val="multilevel"/>',
      );
      for (var level = 1; level <= 6; level++) {
        final ilvl = level - 1;
        if (!hn.numbers(level)) {
          b.write(
            '<w:lvl w:ilvl="$ilvl"><w:start w:val="1"/><w:numFmt w:val="none"/>'
            '<w:pStyle w:val="${DocxStyleIds.heading(level)}"/>'
            '<w:suff w:val="nothing"/><w:lvlText w:val=""/><w:lvlJc w:val="left"/>'
            '<w:pPr><w:ind w:left="0" w:firstLine="0"/></w:pPr></w:lvl>',
          );
          continue;
        }
        final (fmt, text) = _headingLevel(level);
        var suffix = hn.suffix;
        if (text.endsWith('.') && suffix.startsWith('.')) {
          suffix = suffix.substring(1);
        }
        final trailingSpace = suffix.endsWith(' ');
        final lvlText = text + suffix.trimRight();
        b.write(
          '<w:lvl w:ilvl="$ilvl"><w:start w:val="1"/><w:numFmt w:val="$fmt"/>'
          '<w:pStyle w:val="${DocxStyleIds.heading(level)}"/>'
          '<w:suff w:val="${trailingSpace ? 'space' : 'nothing'}"/>'
          '<w:lvlText w:val="${xmlAttr(lvlText)}"/><w:lvlJc w:val="left"/>'
          '<w:pPr><w:ind w:left="0" w:firstLine="0"/></w:pPr></w:lvl>',
        );
      }
      b.write('</w:abstractNum>');
    }
    b.write(
      '<w:num w:numId="${DocxNumIds.bullets}"><w:abstractNumId w:val="1"/></w:num>'
      '<w:num w:numId="${DocxNumIds.tasks}"><w:abstractNumId w:val="3"/></w:num>',
    );
    if (hn.enabled) {
      b.write(
        '<w:num w:numId="${DocxNumIds.headings}"><w:abstractNumId w:val="4"/></w:num>',
      );
    }
    for (var i = 0; i < orderedNums; i++) {
      b.write(
        '<w:num w:numId="${DocxNumIds.firstOrdered(headingNumbering: hn.enabled) + i}">'
        '<w:abstractNumId w:val="2"/>',
      );
      for (var level = 0; level < 9; level++) {
        b.write(
          '<w:lvlOverride w:ilvl="$level"><w:startOverride w:val="1"/></w:lvlOverride>',
        );
      }
      b.write('</w:num>');
    }
    b.write('</w:numbering>');
    return b.toString();
  }

  /// `w:numFmt` and `w:lvlText` core of a numbered heading [level].
  (String, String) _headingLevel(int level) {
    final hn = theme.headingNumbering;
    String path({required bool trailingDot}) {
      final parts = [for (var l = hn.fromLevel; l <= level; l++) '%$l'];
      return parts.join('.') + (trailingDot ? '.' : '');
    }

    switch (hn.style) {
      case HeadingNumberingStyle.decimal:
        return ('decimal', '%$level.');
      case HeadingNumberingStyle.outline:
        return ('decimal', path(trailingDot: false));
      case HeadingNumberingStyle.legal:
        return ('decimal', path(trailingDot: true));
      case HeadingNumberingStyle.upperRomanUpperAlphaDecimal:
        const cycle = [
          'upperRoman',
          'upperLetter',
          'decimal',
          'lowerLetter',
          'lowerRoman',
          'decimal',
        ];
        final depth = (level - hn.fromLevel).clamp(0, 5);
        return (cycle[depth], '%$level.');
    }
  }

  /// `word/settings.xml`.
  String settingsXml({required bool background, required bool updateFields}) =>
      '$_header<w:settings xmlns:w="${DocxNs.w}">'
      '<w:zoom w:percent="100"/>'
      '${background ? '<w:displayBackgroundShape/>' : ''}'
      '<w:defaultTabStop w:val="720"/>'
      '<w:characterSpacingControl w:val="doNotCompress"/>'
      '${updateFields ? '<w:updateFields w:val="true"/>' : ''}'
      '<w:compat><w:compatSetting w:name="compatibilityMode" '
      'w:uri="http://schemas.microsoft.com/office/word" w:val="15"/></w:compat>'
      '</w:settings>';

  /// `word/fontTable.xml` for [families].
  String fontTableXml(Iterable<String> families) {
    final b = StringBuffer(_header)..write('<w:fonts xmlns:w="${DocxNs.w}">');
    for (final f in families.toSet().toList()..sort()) {
      final info = FontRegistry.families.where((e) => e.family == f);
      final category = info.isEmpty ? null : info.first.category;
      final (family, pitch) = switch (category) {
        FontCategory.serif => ('roman', 'variable'),
        FontCategory.mono => ('modern', 'fixed'),
        _ => ('swiss', 'variable'),
      };
      b.write(
        '<w:font w:name="${xmlAttr(f)}"><w:family w:val="$family"/>'
        '<w:pitch w:val="$pitch"/></w:font>',
      );
    }
    b.write('</w:fonts>');
    return b.toString();
  }
}
