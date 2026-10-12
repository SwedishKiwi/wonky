part of 'odt_exporter.dart';

/// `styles.xml`: font faces, common styles from the theme, outline and list
/// styles, the page layout and the `Standard` master page (07 §5.6, 06 §7.1).
extension on _OdtWriter {
  String stylesXml() {
    final b = StringBuffer(_xmlDecl)
      ..write('<office:document-styles $_nsDecl office:version="1.3">')
      ..write(fontFaceDecls())
      ..write('<office:styles>')
      ..write(_defaultStyle())
      ..write(_paragraphStyles())
      ..write(_textStyles())
      ..write(_graphicStyles())
      ..write(_outlineStyle())
      ..write(_listStyles())
      ..write('</office:styles>')
      ..write('<office:automatic-styles>')
      ..write(_pageLayout())
      ..write('</office:automatic-styles>')
      ..write('<office:master-styles>')
      ..write(_masterPage())
      ..write('</office:master-styles>')
      ..write('</office:document-styles>');
    return b.toString();
  }

  /// `office:font-face-decls` for every family the theme uses.
  String fontFaceDecls() {
    final b = StringBuffer('<office:font-face-decls>');
    for (final family in fonts) {
      final info = FontRegistry.lookup(family);
      final generic = switch (info?.category) {
        FontCategory.sans => 'swiss',
        FontCategory.serif => 'roman',
        FontCategory.mono => 'modern',
        null => null,
      };
      final quoted = family.contains(RegExp(r'[\s,]')) ? "'$family'" : family;
      b.write(
        '<style:font-face${_attrs({'style:name': family, 'svg:font-family': quoted, 'style:font-family-generic': generic, 'style:font-pitch': info == null ? null : (info.category == FontCategory.mono ? 'fixed' : 'variable')})}/>',
      );
    }
    b.write('</office:font-face-decls>');
    return b.toString();
  }

  String _defaultStyle() {
    final lang = _languageAttrs(input.meta.language);
    return '<style:default-style style:family="paragraph">'
        '<style:paragraph-properties${_attrs({'fo:hyphenation-ladder-count': 'no-limit', 'style:tab-stop-distance': _pt(36), 'style:writing-mode': 'page'})}/>'
        '<style:text-properties${_attrs({'style:font-name': t.body.style.fontFamily, 'fo:font-size': _pt(t.body.style.fontSize), ...lang, 'fo:hyphenate': 'false', 'fo:hyphenation-remain-char-count': '2', 'fo:hyphenation-push-char-count': '2'})}/>'
        '</style:default-style>'
        '<style:default-style style:family="graphic">'
        '<style:graphic-properties${_attrs({'style:wrap': 'none', 'style:flow-with-text': 'false'})}/>'
        '</style:default-style>';
  }

  static Map<String, String> _languageAttrs(String? tag) {
    if (tag == null) return const {};
    final parts = tag.trim().split(RegExp('[-_]'));
    if (parts.isEmpty || !RegExp(r'^[A-Za-z]{2,3}$').hasMatch(parts.first)) {
      return const {};
    }
    final region = parts
        .skip(1)
        .where((p) => RegExp(r'^[A-Za-z]{2}$').hasMatch(p));
    return {
      'fo:language': parts.first.toLowerCase(),
      if (region.isNotEmpty) 'fo:country': region.first.toUpperCase(),
    };
  }

  String _paragraphStyles() {
    final b = StringBuffer();
    final body = t.body;
    b.write(
      _style(
        'Standard',
        'paragraph',
        cls: 'text',
        para: {
          ..._box(body.box, lineHeight: body.style),
          if (body.firstLineIndent != 0)
            'fo:text-indent': _pt(body.firstLineIndent),
        },
        text: _text(body.style),
      ),
    );

    // Headings.
    final h1 = t.headings.first;
    b.write(
      _style(
        'Heading',
        'paragraph',
        parent: 'Standard',
        next: 'Standard',
        cls: 'text',
        para: {'fo:keep-with-next': 'always', 'fo:text-indent': _pt(0)},
        text: {'style:font-name': h1.style.fontFamily},
      ),
    );
    for (var level = 1; level <= 6; level++) {
      final h = t.headings[level - 1];
      final border = h.borderBottom;
      b.write(
        _style(
          'Heading_20_$level',
          'paragraph',
          display: 'Heading $level',
          parent: 'Heading',
          next: 'Standard',
          cls: 'text',
          extra: {'style:default-outline-level': '$level'},
          para: {
            ..._box(h.box, lineHeight: h.style),
            'fo:keep-with-next': 'always',
            if (border != null && border.isVisible) ...{
              'fo:border-bottom': _border(border),
              'fo:padding-bottom': _pt(h.borderBottomGap),
            },
          },
          text: _text(h.style),
        ),
      );
    }

    // Quotations.
    final q = t.blockquote;
    b.write(
      _style(
        'Quotations',
        'paragraph',
        parent: 'Standard',
        cls: 'html',
        para: {
          ..._box(q.box, lineHeight: q.style),
          'fo:margin-top': _pt(0),
          'fo:margin-bottom': _pt(0),
          if (q.bar.isVisible) 'fo:border-left': _border(q.bar),
          if (q.box.padding.left == 0 && q.bar.isVisible)
            'fo:padding-left': _pt(9),
        },
        text: _text(q.style),
      ),
    );

    // Code blocks.
    final c = t.codeBlock;
    b.write(
      _style(
        'Preformatted_20_Text',
        'paragraph',
        display: 'Preformatted Text',
        parent: 'Standard',
        cls: 'html',
        para: {
          ..._box(c.box, lineHeight: c.style),
          'fo:margin-top': _pt(0),
          'fo:margin-bottom': _pt(0),
          'fo:text-align': 'start',
          'style:tab-stop-distance': _pt(
            math.max(1, c.tabSize) * c.style.fontSize * 0.6,
          ),
        },
        text: {..._text(c.style), 'fo:hyphenate': 'false'},
      ),
    );

    // Lists and tasks.
    final l = t.list;
    b.write(
      _style(
        'List_20_Paragraph',
        'paragraph',
        display: 'List Paragraph',
        parent: 'Standard',
        cls: 'list',
        para: {
          'fo:margin-top': _pt(0),
          'fo:margin-bottom': _pt(l.itemSpacing),
          'fo:text-indent': _pt(0),
          'style:line-height-at-least': _pt(l.style.lineHeightPt),
        },
        text: _text(l.style),
      ),
    );
    final task = t.task;
    final paper = t.page.paperColor;
    final checkedColor = task.checkedOpacity < 1
        ? _blend(task.checkedColor, paper, task.checkedOpacity)
        : task.checkedColor;
    b.write(
      _style(
        _taskChecked,
        'paragraph',
        display: 'Task Checked',
        parent: 'List_20_Paragraph',
        cls: 'list',
        text: {
          'fo:color': _color(checkedColor),
          if (task.checkedStrike) ...{
            'style:text-line-through-style': 'solid',
            'style:text-line-through-type': 'single',
          },
        },
      ),
    );

    // Images and captions.
    final im = t.image;
    b.write(
      _style(
        _imageStyle,
        'paragraph',
        display: 'Image',
        parent: 'Standard',
        cls: 'extra',
        para: {
          'fo:margin-top': _pt(im.box.spaceBefore),
          'fo:margin-bottom': _pt(im.box.spaceAfter),
          'fo:text-align': im.align == ImageAlign.center ? 'center' : 'start',
          'fo:line-height': '100%',
          'fo:text-indent': _pt(0),
          'fo:keep-with-next': im.caption.show ? 'always' : 'auto',
        },
      ),
    );
    final cap = im.caption;
    b.write(
      _style(
        'Caption',
        'paragraph',
        parent: 'Standard',
        cls: 'extra',
        para: {
          'fo:margin-top': _pt(cap.gap),
          'fo:margin-bottom': _pt(im.box.spaceAfter),
          'fo:text-align': _align(cap.align),
          'fo:text-indent': _pt(0),
        },
        text: _text(cap.style),
      ),
    );

    // Rules.
    final r = t.rule;
    final ruleWidth = r.width.resolve(contentWidth).clamp(0.0, contentWidth);
    final side = (contentWidth - ruleWidth) / 2;
    if (r.style == RuleStyle.ornament) {
      b.write(
        _style(
          _ruleStyle,
          'paragraph',
          display: 'Horizontal Line',
          parent: 'Standard',
          next: 'Standard',
          cls: 'html',
          para: {
            'fo:margin-top': _pt(r.box.spaceBefore),
            'fo:margin-bottom': _pt(r.box.spaceAfter),
            'fo:text-align': 'center',
            'fo:text-indent': _pt(0),
          },
          text: {..._text(r.ornamentStyle), 'fo:color': _color(r.color)},
        ),
      );
    } else {
      b.write(
        _style(
          _ruleStyle,
          'paragraph',
          display: 'Horizontal Line',
          parent: 'Standard',
          next: 'Standard',
          cls: 'html',
          para: {
            'fo:margin-top': _pt(r.box.spaceBefore),
            'fo:margin-bottom': _pt(r.box.spaceAfter),
            'fo:margin-left': _pt(side),
            'fo:margin-right': _pt(side),
            'fo:text-indent': _pt(0),
            'fo:line-height': '100%',
            'fo:border-bottom':
                '${_pt(r.thickness)} ${_ruleLine(r.style)} ${_color(r.color)}',
            'fo:padding': _pt(0),
          },
          text: {'fo:font-size': _pt(2)},
        ),
      );
    }

    // Tables.
    final tb = t.table;
    b.write(
      _style(
        'Table_20_Contents',
        'paragraph',
        display: 'Table Contents',
        parent: 'Standard',
        cls: 'extra',
        para: {
          'fo:margin-top': _pt(0),
          'fo:margin-bottom': _pt(0),
          'fo:text-indent': _pt(0),
          'fo:text-align': 'start',
          'style:line-height-at-least': _pt(tb.style.lineHeightPt),
        },
        text: _text(tb.style),
      ),
    );
    b.write(
      _style(
        'Table_20_Heading',
        'paragraph',
        display: 'Table Heading',
        parent: 'Table_20_Contents',
        cls: 'extra',
        para: {'fo:keep-with-next': 'always'},
        text: _text(tb.headerStyle),
      ),
    );

    // Header and footer.
    for (final (name, hf, top) in [
      ('Header', t.header, false),
      ('Footer', t.footer, true),
    ]) {
      final edge = top ? hf.borderTop : hf.borderBottom;
      b.write(
        _style(
          name,
          'paragraph',
          parent: 'Standard',
          cls: 'extra',
          para: {
            'fo:margin-top': _pt(0),
            'fo:margin-bottom': _pt(0),
            'fo:text-indent': _pt(0),
            'fo:text-align': 'start',
            if (edge != null && edge.isVisible) ...{
              top ? 'fo:border-top' : 'fo:border-bottom': _border(edge),
              top ? 'fo:padding-top' : 'fo:padding-bottom': _pt(3),
            },
          },
          paraChildren:
              '<style:tab-stops>'
              '<style:tab-stop style:position="${_pt(contentWidth / 2)}" style:type="center"/>'
              '<style:tab-stop style:position="${_pt(contentWidth)}" style:type="right"/>'
              '</style:tab-stops>',
          text: _text(hf.style),
        ),
      );
    }

    // Table of contents.
    if (options.includeToc) {
      b.write(
        _style(
          'Contents_20_Heading',
          'paragraph',
          display: 'Contents Heading',
          parent: 'Heading',
          cls: 'index',
          para: _box(t.headings[1].box, lineHeight: t.headings[1].style),
          text: _text(t.headings[1].style),
        ),
      );
      for (var level = 1; level <= _tocDepth; level++) {
        b.write(
          _style(
            'Contents_20_$level',
            'paragraph',
            display: 'Contents $level',
            parent: 'Standard',
            cls: 'index',
            para: {
              'fo:margin-left': _pt(t.list.indentPerLevel * (level - 1)),
              'fo:margin-top': _pt(0),
              'fo:margin-bottom': _pt(t.list.itemSpacing),
              'fo:text-indent': _pt(0),
            },
            paraChildren:
                '<style:tab-stops><style:tab-stop style:position="${_pt(math.max(0, contentWidth - t.list.indentPerLevel * (level - 1)))}" style:type="right" style:leader-style="dotted" style:leader-text="."/></style:tab-stops>',
          ),
        );
      }
    }
    return b.toString();
  }

  String _textStyles() {
    final b = StringBuffer();
    final ic = t.inlineCode;
    b.write(
      _style(
        'Source_20_Text',
        'text',
        display: 'Source Text',
        text: {
          'style:font-name': ic.fontFamily,
          'fo:font-size': '${(ic.sizeRatio * 100).round()}%',
          'fo:font-weight': _weight(ic.fontWeight),
          'fo:font-style': ic.italic ? 'italic' : 'normal',
          'fo:color': _color(ic.color),
          if (ic.background != null)
            'fo:background-color': _color(ic.background!),
          if (ic.letterSpacingEm != 0)
            'fo:letter-spacing': _pt(
              ic.letterSpacingEm * t.body.style.fontSize * ic.sizeRatio,
            ),
        },
      ),
    );
    final link = t.link;
    final underline = link.underline == LinkUnderline.always;
    final linkProps = {
      'fo:color': _color(link.color),
      'style:text-underline-style': underline
          ? _underlineStyle(link.underlineStyle)
          : 'none',
      if (underline) ...{
        'style:text-underline-width': 'auto',
        'style:text-underline-color': 'font-color',
      },
    };
    b.write(
      _style(
        'Internet_20_link',
        'text',
        display: 'Internet link',
        text: linkProps,
      ),
    );
    b.write(
      _style(
        'Visited_20_Internet_20_Link',
        'text',
        display: 'Visited Internet Link',
        text: linkProps,
      ),
    );
    final m = t.mention;
    b.write(
      _style(
        _mentionStyle,
        'text',
        display: 'Mention',
        text: {
          'fo:color': _color(m.color),
          'fo:font-weight': _weight(m.fontWeight),
          'style:text-underline-style': 'none',
          if (m.background != null)
            'fo:background-color': _color(m.background!),
        },
      ),
    );
    return b.toString();
  }

  String _graphicStyles() {
    final border = t.image.border;
    return '<style:style style:name="Graphics" style:family="graphic">'
        '<style:graphic-properties${_attrs({'text:anchor-type': 'as-char', 'svg:y': _pt(0), 'style:wrap': 'none', 'style:vertical-pos': 'top', 'style:vertical-rel': 'baseline', if (border != null && border.isVisible) 'fo:border': _border(border)})}/>'
        '</style:style>';
  }

  /// `text:outline-style` (heading numbering, 06 §7.1).
  String _outlineStyle() {
    final n = t.headingNumbering;
    final b = StringBuffer('<text:outline-style style:name="Outline">');
    const roman = ['I', 'A', '1', 'a', 'i', '1'];
    final trimmed = n.suffix.startsWith('.') ? n.suffix.substring(1) : n.suffix;
    for (var level = 1; level <= 10; level++) {
      String format = '';
      String suffix = '';
      var display = 1;
      if (level <= 6 && n.numbers(level)) {
        final depth = (level - n.fromLevel).clamp(0, 5);
        switch (n.style) {
          case HeadingNumberingStyle.decimal:
            format = '1';
            suffix = '.$trimmed';
          case HeadingNumberingStyle.outline:
            format = '1';
            suffix = n.suffix;
            display = depth + 1;
          case HeadingNumberingStyle.legal:
            format = '1';
            suffix = '.$trimmed';
            display = depth + 1;
          case HeadingNumberingStyle.upperRomanUpperAlphaDecimal:
            format = roman[depth];
            suffix = '.$trimmed';
        }
      }
      b.write(
        '<text:outline-level-style${_attrs({'text:level': '$level', 'style:num-format': format, if (suffix.isNotEmpty) 'style:num-suffix': suffix, if (display > 1) 'text:display-levels': '$display'})}>'
        '<style:list-level-properties text:list-level-position-and-space-mode="label-alignment">'
        '<style:list-level-label-alignment text:label-followed-by="nothing" fo:text-indent="${_pt(0)}" fo:margin-left="${_pt(0)}"/>'
        '</style:list-level-properties>'
        '</text:outline-level-style>',
      );
    }
    b.write('</text:outline-style>');
    return b.toString();
  }

  /// `WonkyBullets`, `WonkyNumbers` and `WonkyTasks` (9 theme levels plus
  /// the tenth ODF level).
  String _listStyles() {
    final l = t.list;
    final labelWidth = math.min(
      l.indentPerLevel,
      l.markerGap + l.style.fontSize,
    );
    String alignment(int level, {bool task = false}) {
      final indent = l.indentFor(level);
      final margin = task ? math.max(0.0, indent - labelWidth) : indent;
      return '<style:list-level-properties text:list-level-position-and-space-mode="label-alignment">'
          '<style:list-level-label-alignment${_attrs({'text:label-followed-by': task ? 'nothing' : 'listtab', if (!task) 'text:list-tab-stop-position': _pt(indent), 'fo:text-indent': _pt(task ? 0 : -labelWidth), 'fo:margin-left': _pt(margin)})}/>'
          '</style:list-level-properties>';
    }

    final b = StringBuffer();
    b.write(
      '<text:list-style style:name="$_bullets" style:display-name="Wonky Bullets">',
    );
    for (var level = 0; level < 10; level++) {
      final glyph = l.bulletFor(level);
      final char = glyph.isEmpty ? '•' : String.fromCharCode(glyph.runes.first);
      b.write(
        '<text:list-level-style-bullet${_attrs({'text:level': '${level + 1}', 'text:bullet-char': char, 'text:bullet-relative-size': '${(l.bulletScale * 100).round()}%'})}>'
        '${alignment(level)}'
        '<style:text-properties${_attrs({'fo:color': _color(l.bulletColor)})}/>'
        '</text:list-level-style-bullet>',
      );
    }
    b.write('</text:list-style>');
    b.write(
      '<text:list-style style:name="$_numbers" style:display-name="Wonky Numbers">',
    );
    for (var level = 0; level < 10; level++) {
      b.write(
        '<text:list-level-style-number${_attrs({'text:level': '${level + 1}', 'style:num-suffix': l.numberSuffix, 'style:num-format': _numFormat(l.numberStyleFor(level)), 'text:display-levels': '1'})}>'
        '${alignment(level)}'
        '<style:text-properties${_attrs({'fo:color': _color(l.numberColor)})}/>'
        '</text:list-level-style-number>',
      );
    }
    b.write('</text:list-style>');
    b.write(
      '<text:list-style style:name="$_tasks" style:display-name="Wonky Tasks">',
    );
    for (var level = 0; level < 10; level++) {
      b.write(
        '<text:list-level-style-number text:level="${level + 1}" style:num-format="">'
        '${alignment(level, task: true)}'
        '</text:list-level-style-number>',
      );
    }
    b.write('</text:list-style>');
    return b.toString();
  }

  static String _numFormat(ListNumberStyle s) => switch (s) {
    ListNumberStyle.decimal => '1',
    ListNumberStyle.lowerAlpha => 'a',
    ListNumberStyle.upperAlpha => 'A',
    ListNumberStyle.lowerRoman => 'i',
    ListNumberStyle.upperRoman => 'I',
  };

  // -------------------------------------------------------------------------
  // Page layout and master page

  HeaderFooterSpec? get _header =>
      _shown(input.pageSetup.header) ? input.pageSetup.header : null;
  HeaderFooterSpec? get _footer =>
      _shown(input.pageSetup.footer) ? input.pageSetup.footer : null;
  HeaderFooterSpec? get _firstHeader =>
      input.pageSetup.differentFirstPage &&
          _shown(input.pageSetup.firstPageHeader)
      ? input.pageSetup.firstPageHeader
      : null;
  HeaderFooterSpec? get _firstFooter =>
      input.pageSetup.differentFirstPage &&
          _shown(input.pageSetup.firstPageFooter)
      ? input.pageSetup.firstPageFooter
      : null;

  static bool _shown(HeaderFooterSpec s) => s.enabled && !s.isEmpty;

  String _pageLayout() {
    final ps = input.pageSetup;
    final m = pageMarginsPt(input, t);
    final hasHeader = _header != null || _firstHeader != null;
    final hasFooter = _footer != null || _firstFooter != null;
    final headerDistance = (_header ?? _firstHeader)?.distancePt ?? 0;
    final footerDistance = (_footer ?? _firstFooter)?.distancePt ?? 0;
    // ODF measures the page margin to the header; the header area plus its
    // spacing fills the rest of the theme/page-setup body margin.
    (double, double, double) area(double margin, double distance) {
      var d = distance;
      if (d <= 0 || d >= margin) d = margin / 2;
      final avail = margin - d;
      final spacing = math.min(avail * 0.25, 14.4);
      return (d, math.max(0, avail - spacing), spacing);
    }

    final (top, headerHeight, headerSpacing) = hasHeader
        ? area(m.top, headerDistance)
        : (m.top, 0.0, 0.0);
    final (bottom, footerHeight, footerSpacing) = hasFooter
        ? area(m.bottom, footerDistance)
        : (m.bottom, 0.0, 0.0);
    final paper = t.page.paperColor;
    final background =
        input.variant == ThemeVariant.dark || (paper & 0xFFFFFF) != 0xFFFFFF;
    final b = StringBuffer('<style:page-layout style:name="pm1">');
    b.write(
      '<style:page-layout-properties${_attrs({'fo:page-width': _pt(ps.pageWidthPt), 'fo:page-height': _pt(ps.pageHeightPt), 'style:num-format': _pageNumFormat(ps.pageNumberFormat), 'style:print-orientation': ps.orientation == PageOrientation.landscape ? 'landscape' : 'portrait', 'fo:margin-top': _pt(top), 'fo:margin-bottom': _pt(bottom), 'fo:margin-left': _pt(m.left), 'fo:margin-right': _pt(m.right), if (background) 'fo:background-color': _color(paper), 'style:writing-mode': 'lr-tb'})}/>',
    );
    if (hasHeader) {
      b.write(
        '<style:header-style><style:header-footer-properties${_attrs({'fo:min-height': _pt(headerHeight), 'fo:margin-left': _pt(0), 'fo:margin-right': _pt(0), 'fo:margin-bottom': _pt(headerSpacing), 'style:dynamic-spacing': 'false'})}/></style:header-style>',
      );
    }
    if (hasFooter) {
      b.write(
        '<style:footer-style><style:header-footer-properties${_attrs({'fo:min-height': _pt(footerHeight), 'fo:margin-left': _pt(0), 'fo:margin-right': _pt(0), 'fo:margin-top': _pt(footerSpacing), 'style:dynamic-spacing': 'false'})}/></style:footer-style>',
      );
    }
    b.write('</style:page-layout>');
    return b.toString();
  }

  static String _pageNumFormat(PageNumberFormat f) => switch (f) {
    PageNumberFormat.decimal => '1',
    PageNumberFormat.lowerRoman => 'i',
    PageNumberFormat.upperRoman => 'I',
  };

  String _masterPage() {
    final ps = input.pageSetup;
    final b = StringBuffer(
      '<style:master-page style:name="Standard" style:page-layout-name="pm1">',
    );
    final header = _header;
    final firstHeader = _firstHeader;
    final footer = _footer;
    final firstFooter = _firstFooter;
    final different = ps.differentFirstPage;
    if (header != null || firstHeader != null) {
      b.write(
        header == null
            ? '<style:header style:display="false"/>'
            : '<style:header>${_slots(header, 'Header')}</style:header>',
      );
      if (different) {
        b.write(
          firstHeader == null
              ? '<style:header-first style:display="false"/>'
              : '<style:header-first>${_slots(firstHeader, 'Header')}</style:header-first>',
        );
      }
    }
    if (footer != null || firstFooter != null) {
      b.write(
        footer == null
            ? '<style:footer style:display="false"/>'
            : '<style:footer>${_slots(footer, 'Footer')}</style:footer>',
      );
      if (different) {
        b.write(
          firstFooter == null
              ? '<style:footer-first style:display="false"/>'
              : '<style:footer-first>${_slots(firstFooter, 'Footer')}</style:footer-first>',
        );
      }
    }
    b.write('</style:master-page>');
    return b.toString();
  }

  /// One header/footer paragraph: left, center and right slots separated by
  /// the center and right tab stops of the `Header`/`Footer` style.
  String _slots(HeaderFooterSpec spec, String style) {
    final ctx = HeaderFooterSlots.context(input);
    final ps = input.pageSetup;
    final b = StringBuffer('<text:p text:style-name="$style">');
    final o = _TextOut(b);
    final slots = [spec.left, spec.center, spec.right];
    var last = 2;
    while (last > 0 && slots[last].isEmpty) {
      last--;
    }
    for (var i = 0; i <= last; i++) {
      if (i > 0) o.raw('<text:tab/>');
      for (final part in HeaderFooterSlots.parts(slots[i], ctx)) {
        switch (part) {
          case SlotText(:final text):
            o.text(text.replaceAll('\n', ' '));
          case SlotField(pageCount: false):
            o.raw(
              '<text:page-number text:select-page="current" style:num-format="${_pageNumFormat(ps.pageNumberFormat)}">'
              '${xmlText(ps.pageNumberFormat.format(math.max(1, ps.pageNumberStart)))}'
              '</text:page-number>',
            );
          case SlotField(pageCount: true):
            o.raw('<text:page-count style:num-format="1">1</text:page-count>');
        }
      }
    }
    b.write('</text:p>');
    return b.toString();
  }

  // -------------------------------------------------------------------------
  // Property helpers

  /// A common style element.
  String _style(
    String name,
    String family, {
    String? display,
    String? parent,
    String? next,
    String? cls,
    Map<String, String> extra = const {},
    Map<String, String> para = const {},
    String paraChildren = '',
    Map<String, String> text = const {},
  }) {
    final b = StringBuffer(
      '<style:style${_attrs({'style:name': name, 'style:display-name': display ?? (name.contains('_20_') ? name.replaceAll('_20_', ' ') : null), 'style:family': family, 'style:parent-style-name': parent, 'style:next-style-name': next, 'style:class': cls, ...extra})}>',
    );
    if (para.isNotEmpty || paraChildren.isNotEmpty) {
      b.write(
        paraChildren.isEmpty
            ? '<style:paragraph-properties${_attrs(para)}/>'
            : '<style:paragraph-properties${_attrs(para)}>$paraChildren</style:paragraph-properties>',
      );
    }
    if (text.isNotEmpty) b.write('<style:text-properties${_attrs(text)}/>');
    b.write('</style:style>');
    return b.toString();
  }

  /// `style:text-properties` attributes of a theme text style.
  Map<String, String> _text(ResolvedTextStyle s) => {
    'style:font-name': s.fontFamily,
    'fo:font-size': _pt(s.fontSize),
    'fo:font-weight': _weight(s.fontWeight),
    'fo:font-style': s.italic ? 'italic' : 'normal',
    'fo:color': _color(s.color),
    'fo:letter-spacing': s.letterSpacing == 0 ? 'normal' : _pt(s.letterSpacing),
    ...switch (s.caseTransform) {
      CaseTransform.uppercase => {'fo:text-transform': 'uppercase'},
      CaseTransform.lowercase => {'fo:text-transform': 'lowercase'},
      CaseTransform.capitalize => {'fo:text-transform': 'capitalize'},
      CaseTransform.smallCaps => {'fo:font-variant': 'small-caps'},
      CaseTransform.none => const <String, String>{},
    },
  };

  /// `style:paragraph-properties` attributes of a theme box.
  Map<String, String> _box(
    ResolvedBox box, {
    required ResolvedTextStyle lineHeight,
  }) {
    final p = box.padding;
    final bd = box.border;
    return {
      'fo:margin-top': _pt(box.spaceBefore),
      'fo:margin-bottom': _pt(box.spaceAfter),
      'fo:text-align': _align(box.align),
      if (box.align == ThemeAlign.justify) 'style:justify-single-word': 'false',
      'style:line-height-at-least': _pt(lineHeight.lineHeightPt),
      if (p.top != 0) 'fo:padding-top': _pt(p.top),
      if (p.right != 0) 'fo:padding-right': _pt(p.right),
      if (p.bottom != 0) 'fo:padding-bottom': _pt(p.bottom),
      if (p.left != 0) 'fo:padding-left': _pt(p.left),
      if (bd.top.isVisible) 'fo:border-top': _border(bd.top),
      if (bd.right.isVisible) 'fo:border-right': _border(bd.right),
      if (bd.bottom.isVisible) 'fo:border-bottom': _border(bd.bottom),
      if (bd.left.isVisible) 'fo:border-left': _border(bd.left),
      if (box.background != null)
        'fo:background-color': _color(box.background!),
      if (box.keepWithNext) 'fo:keep-with-next': 'always',
      if (box.pageBreakBefore) 'fo:break-before': 'page',
    };
  }

  static String _align(ThemeAlign a) => switch (a) {
    ThemeAlign.left => 'start',
    ThemeAlign.center => 'center',
    ThemeAlign.right => 'end',
    ThemeAlign.justify => 'justify',
  };

  static String _underlineStyle(LineStyle s) => switch (s) {
    LineStyle.dashed => 'dash',
    LineStyle.dotted => 'dotted',
    LineStyle.none => 'none',
    LineStyle.solid || LineStyle.doubleLine => 'solid',
  };

  static String _ruleLine(RuleStyle s) => switch (s) {
    RuleStyle.dashed => 'dashed',
    RuleStyle.dotted => 'dotted',
    RuleStyle.doubleLine => 'double',
    RuleStyle.solid || RuleStyle.ornament => 'solid',
  };

  /// An `fo:border` value.
  String _border(BorderPt b) {
    final style = switch (b.style) {
      LineStyle.dashed => 'dashed',
      LineStyle.dotted => 'dotted',
      LineStyle.doubleLine => 'double',
      LineStyle.solid || LineStyle.none => 'solid',
    };
    return '${_pt(b.width)} $style ${_color(b.color)}';
  }

  static int _blend(int color, int background, double opacity) {
    final a = (opacity.clamp(0.0, 1.0) * 255).round();
    return flattenAlpha(
      (color & 0xFFFFFF) | (a << 24),
      background: background | 0xFF000000,
    );
  }
}
