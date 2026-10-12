/// DOCX import (07 §3.6).
library;

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

import '../../delta/embeds.dart';
import '../../delta/links.dart';
import '../../ir/doc_tree.dart';
import '../../markdown/inline_reader.dart' show mentionTitlePrefix;
import '../import_api.dart';
import '../import_limits.dart';
import '../import_support.dart';
import '../xml_support.dart';
import 'ooxml_reader.dart';

/// Imports Word documents (`.docx`, OOXML Transitional and Strict).
///
/// Mapping (07 §3.6): heading styles / `Title` (H1) / `Subtitle` (H2) /
/// `w:outlineLvl` → headings; `Quote` styles → quotes; monospace paragraphs
/// and `HTML Preformatted`/`Code*` styles → code blocks; `w:numPr` → lists
/// (`bullet` levels → bullets, others ordered, `ilvl` → indent); ☐/☑/☒ glyphs
/// and `w14:checkbox` controls → tasks; `w:b`/`w:i`/`w:strike`/`w:dstrike`
/// (direct or via character styles) and monospace fonts → inline attributes;
/// hyperlinks (relationships and `HYPERLINK` fields) → links; drawings →
/// images (alt from `wp:docPr/@descr`, EMF/WMF → placeholder); tables →
/// table embeds (merged cells flattened); `w:br` → soft break; footnotes and
/// endnotes → a final "Notes" section; tracked changes accepted; comments,
/// headers/footers and breaks dropped (with warnings); page size and margins
/// → [ImportResult.pageSetup]; `docProps/core.xml` → title and language.
///
/// Throws [ImportFormatException] when the bytes are not an OOXML package;
/// damaged content never throws (best effort plus warnings).
final class DocxImporter implements DocumentImporter {
  /// Creates the importer.
  const DocxImporter();

  @override
  ImportFormat get format => ImportFormat.docx;

  @override
  Future<ImportResult> import(Uint8List bytes, ImportOptions options) async =>
      importSync(bytes, options);

  /// Synchronous variant of [import].
  ImportResult importSync(Uint8List bytes, ImportOptions options) {
    final pkg = OoxmlPackage.open(bytes);
    if (pkg == null) {
      throw const ImportFormatException(
        'The file is not a Word document (no OOXML package).',
      );
    }
    return _DocxReader(pkg, options).read();
  }
}

const _w = OoxmlNs.w;

sealed class _Seg {}

final class _RunSeg extends _Seg {
  _RunSeg(this.run);
  final InlineRun run;
}

final class _BlockSeg extends _Seg {
  _BlockSeg(this.block);
  final DocBlock block;
}

final class _ParaCtx {
  _ParaCtx({this.styleToggles, this.style, this.inCell = false});

  /// Paragraph style whose bold/italic/strike apply to runs (plain
  /// paragraphs and list items only).
  final OoxmlStyle? styleToggles;

  /// Paragraph style (fonts for code detection).
  final OoxmlStyle? style;
  final bool inCell;
  final segs = <_Seg>[];
  final after = <DocBlock>[];
  bool? checkbox;
  String? link;
  String? mention;

  bool get hasText => segs.any(
    (s) => s is _BlockSeg || (s is _RunSeg && s.run.text.trim().isNotEmpty),
  );

  void add(InlineRun r) {
    if (r.text.isNotEmpty) segs.add(_RunSeg(r));
  }
}

final class _Field {
  final instr = StringBuffer();
  var separated = false;
  String? link;
}

enum _Kind { paragraph, heading, quote, code, list, rule }

final class _DocxReader {
  _DocxReader(this.pkg, this.options);

  final OoxmlPackage pkg;
  final ImportOptions options;
  final _warnings = WarningCollector();
  final _images = ImageCollector();
  final _notes = NotesCollector();
  var _blocks = <DocBlock>[];
  final _fields = <_Field>[];
  final _listStarts = <String>{};
  late String _docPart;
  late String _part;
  late OoxmlStyles _styles;
  late OoxmlNumbering _numbering;
  final _footnotes = <String, XmlElement>{};
  final _endnotes = <String, XmlElement>{};
  String? _footnotesPart;
  String? _endnotesPart;
  var _inNote = false;
  ImportedPageSetup? _pageSetup;

  /// Written by Wonky Write's own exporter: its theme-derived formatting
  /// (colors, alignment, borders) is presentation only, so no "formatting
  /// removed" warnings, and its helper paragraphs (TOC) are skipped.
  var _own = false;

  ZipPackage get _zip => pkg.zip;

  ImportResult read() {
    _docPart = pkg.mainDocumentPart;
    _part = _docPart;
    _own = _isOwnDocument();
    _styles = OoxmlStyles.parse(_partXml('styles'));
    _numbering = OoxmlNumbering.parse(_partXml('numbering'));
    _footnotesPart = pkg.relationshipOfKind(_docPart, 'footnotes')?.target;
    _endnotesPart = pkg.relationshipOfKind(_docPart, 'endnotes')?.target;
    _readNotes(_footnotesPart, 'footnote', _footnotes);
    _readNotes(_endnotesPart, 'endnote', _endnotes);
    final comments = _partXml('comments');
    if (comments != null &&
        comments.rootElement.kids(_w, 'comment').isNotEmpty) {
      _commentsDropped();
    }

    final doc = _zip.xml(_docPart);
    final body = doc?.rootElement.kid(_w, 'body');
    if (body == null) {
      _salvage();
    } else {
      for (final e in body.childElements) {
        _block(e);
      }
    }
    _mergeCodeGaps();
    if (!_notes.isEmpty) {
      _warnings.add(
        ImportWarningKind.footnotesAppended,
        'Footnotes and endnotes were moved to a "Notes" section at the end.',
      );
      _blocks.addAll(_notes.blocks());
    }
    if (_blocks.isEmpty) _blocks.add(const ParagraphBlock([]));
    final core = _coreProperties();
    return buildImportResult(
      _blocks,
      options: options,
      warnings: _warnings,
      images: _images,
      title: core.$1,
      language: normalizeLanguageTag(core.$2 ?? _styles.defaultLanguage),
      pageSetup: _pageSetup,
    );
  }

  bool _isOwnDocument() {
    final rel = pkg.relationshipOfKind('', 'extended-properties');
    final doc = _zip.xml(rel?.target ?? 'docProps/app.xml');
    final app = doc?.rootElement.childElements
        .where((e) => e.name.local == 'Application')
        .firstOrNull
        ?.innerText
        .trim();
    return app == 'Wonky Write';
  }

  /// Styles whose formatting is presentation only (written by our exporter:
  /// table headings, checked tasks, mentions…): their run toggles are not
  /// content.
  static bool _presentationStyle(OoxmlStyle? s) =>
      s != null && s.lowerName.startsWith('wonky ');

  XmlDocument? _partXml(String kind) {
    final r = pkg.relationshipOfKind(_docPart, kind);
    if (r == null) return null;
    return _zip.xml(r.target);
  }

  void _readNotes(String? part, String tag, Map<String, XmlElement> into) {
    if (part == null) return;
    final doc = _zip.xml(part);
    if (doc == null) return;
    for (final n in doc.rootElement.kids(_w, tag)) {
      final type = n.attr(_w, 'type');
      if (type == 'separator' ||
          type == 'continuationSeparator' ||
          type == 'continuationNotice') {
        continue;
      }
      final id = n.attr(_w, 'id');
      if (id != null) into[id] = n;
    }
  }

  (String?, String?) _coreProperties() {
    final rel = pkg.relationshipOfKind('', 'core-properties');
    final doc = _zip.xml(rel?.target ?? 'docProps/core.xml');
    if (doc == null) return (null, null);
    String? text(String local) {
      final e = doc.rootElement.deep(OoxmlNs.dc, local).firstOrNull;
      final t = e?.innerText.trim();
      return (t == null || t.isEmpty) ? null : ImportText.inline(t);
    }

    return (text('title'), text('language'));
  }

  // -------------------------------------------------------------------------
  // Warnings

  void _commentsDropped() => _warnings.add(
    ImportWarningKind.commentsDropped,
    'Comments in the document were not imported.',
  );

  void _trackedChanges() => _warnings.add(
    ImportWarningKind.trackedChangesAccepted,
    'Tracked changes were accepted.',
    blockIndex: _blocks.length,
  );

  void _breaksDropped() => _warnings.add(
    ImportWarningKind.breaksDropped,
    'Page breaks, section breaks and columns were removed.',
    blockIndex: _blocks.length,
  );

  void _placeholder(String what) => _warnings.add(
    ImportWarningKind.placeholderInserted,
    'Text boxes, shapes, charts and equations were converted to text or '
    'placeholders ($what).',
    blockIndex: _blocks.length,
  );

  void _removed(String feature) {
    if (_own) return;
    _warnings.formattingRemoved(feature, blockIndex: _blocks.length);
  }

  // -------------------------------------------------------------------------
  // Block level

  void _block(XmlElement e) {
    if (!e.isA(_w, e.name.local)) {
      if (e.isA(OoxmlNs.mc, 'AlternateContent')) {
        final choice =
            e.kid(OoxmlNs.mc, 'Choice') ?? e.kid(OoxmlNs.mc, 'Fallback');
        choice?.childElements.forEach(_block);
      }
      return;
    }
    switch (e.name.local) {
      case 'p':
        _paragraph(e);
      case 'tbl':
        _table(e);
      case 'sdt':
        e.kid(_w, 'sdtContent')?.childElements.forEach(_block);
      case 'customXml' || 'ins' || 'moveTo':
        if (e.name.local != 'customXml') _trackedChanges();
        e.childElements.forEach(_block);
      case 'del' || 'moveFrom':
        _trackedChanges();
      case 'sectPr':
        _section(e, last: true);
      case 'altChunk':
        _warnings.add(
          ImportWarningKind.contentDropped,
          'Embedded documents (alternative format chunks) were not imported.',
          blockIndex: _blocks.length,
        );
    }
  }

  void _section(XmlElement sectPr, {required bool last}) {
    if (!last) _breaksDropped();
    final cols = int.tryParse(sectPr.kid(_w, 'cols')?.attr(_w, 'num') ?? '');
    if (cols != null && cols > 1) _breaksDropped();
    for (final ref in [
      ...sectPr.kids(_w, 'headerReference'),
      ...sectPr.kids(_w, 'footerReference'),
    ]) {
      final id = ref.attr(OoxmlNs.r, 'id');
      final rel = id == null ? null : pkg.relationships(_docPart)[id];
      final x = rel == null ? null : _zip.xml(rel.target);
      if (x != null &&
          x.rootElement
              .deep(_w, 't')
              .any((t) => t.innerText.trim().isNotEmpty)) {
        _warnings.add(
          ImportWarningKind.headersFootersDropped,
          'Headers and footers were not imported.',
        );
        break;
      }
    }
    if (!last) return;
    final pgSz = sectPr.kid(_w, 'pgSz');
    var w = double.tryParse(pgSz?.attr(_w, 'w') ?? '');
    var h = double.tryParse(pgSz?.attr(_w, 'h') ?? '');
    if (w == null || h == null || w <= 0 || h <= 0) return;
    if (pgSz?.attr(_w, 'orient') == 'landscape' && w < h) {
      final t = w;
      w = h;
      h = t;
    }
    final mar = sectPr.kid(_w, 'pgMar');
    double? m(String side) {
      final v = double.tryParse(mar?.attr(_w, side) ?? '');
      return v == null ? null : v.abs() / 20;
    }

    _pageSetup = ImportedPageSetup(
      widthPt: w / 20,
      heightPt: h / 20,
      marginTopPt: m('top'),
      marginRightPt: m('right'),
      marginBottomPt: m('bottom'),
      marginLeftPt: m('left'),
    );
  }

  // -------------------------------------------------------------------------
  // Paragraphs

  static final _headingName = RegExp(r'^heading\s*([1-9])$');

  (_Kind, int, int?, int) _kindOf(XmlElement? pPr, OoxmlStyle? style) {
    final name = style?.lowerName ?? '';
    final id = style?.id.toLowerCase() ?? '';
    final hm = _headingName.firstMatch(name) ?? _headingName.firstMatch(id);
    if (hm != null) {
      return (_Kind.heading, int.parse(hm.group(1)!).clamp(1, 6), null, 0);
    }
    if (name == 'title' || id == 'title') return (_Kind.heading, 1, null, 0);
    if (name == 'wonky horizontal rule' ||
        name == 'horizontal rule' ||
        id == 'horizontalrule') {
      return (_Kind.rule, 0, null, 0);
    }
    if (name == 'subtitle' || id == 'subtitle') {
      return (_Kind.heading, 2, null, 0);
    }
    final outline =
        int.tryParse(pPr?.kid(_w, 'outlineLvl')?.attr(_w, 'val') ?? '') ??
        style?.outlineLevel;
    if (outline != null && outline >= 0 && outline <= 8) {
      return (_Kind.heading, (outline + 1).clamp(1, 6), null, 0);
    }
    if (name.contains('quote') || name == 'block text') {
      return (_Kind.quote, 0, null, 0);
    }
    if (name == 'html preformatted' ||
        name.startsWith('code') ||
        name.startsWith('source code') ||
        name == 'macro text' ||
        id == 'htmlpreformatted' ||
        id.startsWith('code') ||
        id.startsWith('sourcecode')) {
      return (_Kind.code, 0, null, 0);
    }
    final numPr = pPr?.kid(_w, 'numPr');
    var numId = int.tryParse(numPr?.kid(_w, 'numId')?.attr(_w, 'val') ?? '');
    var ilvl = int.tryParse(numPr?.kid(_w, 'ilvl')?.attr(_w, 'val') ?? '');
    numId ??= style?.numId;
    ilvl ??= style?.ilvl ?? 0;
    if (numId != null && numId != 0 && _numbering.has(numId)) {
      return (_Kind.list, 0, numId, ilvl.clamp(0, 8));
    }
    return (_Kind.paragraph, 0, null, 0);
  }

  void _paragraph(XmlElement p) {
    final pPr = p.kid(_w, 'pPr');
    final styleId = pPr?.kid(_w, 'pStyle')?.attr(_w, 'val');
    final style = _styles[styleId] ?? _styles.defaultParagraph;
    final sect = pPr?.kid(_w, 'sectPr');
    final styleName = style?.lowerName ?? '';
    if (styleName == 'wonky spacer' ||
        (_own &&
            (styleName.startsWith('toc ') || styleName == 'toc heading'))) {
      if (sect != null) _section(sect, last: false);
      return;
    }
    if (pPr?.kid(_w, 'pageBreakBefore') != null &&
        OoxmlRunProps.toggle(pPr!.kid(_w, 'pageBreakBefore')!)) {
      _breaksDropped();
    }
    final (kind, level, numId, ilvl) = _kindOf(pPr, style);
    if (kind == _Kind.rule) {
      _blocks.add(RuleBlock(options.idGenerator()));
      if (sect != null) _section(sect, last: false);
      return;
    }
    final jc = pPr?.kid(_w, 'jc')?.attr(_w, 'val');
    if (jc == 'center' || jc == 'right' || jc == 'end' || jc == 'both') {
      _removed('alignment');
    }
    final ctx = _ParaCtx(
      styleToggles:
          (kind == _Kind.paragraph || kind == _Kind.list) &&
              !_presentationStyle(style)
          ? style
          : null,
      style: style,
    );
    _inline(p, ctx);
    if (_isCaptionOfPreviousImage(styleName, ctx)) {
      if (sect != null) _section(sect, last: false);
      return;
    }
    _emitParagraph(p, pPr, ctx, kind, level, numId, ilvl);
    _blocks.addAll(ctx.after);
    if (sect != null) _section(sect, last: false);
  }

  /// A `Caption` paragraph repeating the title of the image just before it
  /// (the title is already imported from `wp:docPr/@title`).
  bool _isCaptionOfPreviousImage(String styleName, _ParaCtx ctx) {
    if (styleName != 'caption' || _blocks.isEmpty) return false;
    final last = _blocks.last;
    if (last is! ImageBlock || last.title == null) return false;
    if (ctx.segs.any((s) => s is _BlockSeg)) return false;
    final text = ctx.segs
        .whereType<_RunSeg>()
        .map((s) => s.run.text)
        .join()
        .trim();
    return text == last.title!.trim();
  }

  void _emitParagraph(
    XmlElement p,
    XmlElement? pPr,
    _ParaCtx ctx,
    _Kind kind,
    int level,
    int? numId,
    int ilvl,
  ) {
    // Split at block segments (images, rules).
    final groups = <List<InlineRun>>[[]];
    final blocks = <DocBlock?>[null];
    for (final s in ctx.segs) {
      switch (s) {
        case _RunSeg(:final run):
          groups.last.add(run);
        case _BlockSeg(:final block):
          blocks.add(block);
          groups.add([]);
      }
    }
    final onlyBlocks = groups.every(RunTools.isBlank) && blocks.length > 1;
    for (var i = 0; i < groups.length; i++) {
      final b = blocks[i];
      if (b != null) _blocks.add(b);
      final runs = InlineRun.merge(groups[i]);
      if (onlyBlocks) continue;
      if (i > 0 && RunTools.isBlank(runs)) continue;
      final k = i == 0 || kind != _Kind.list ? kind : _Kind.paragraph;
      _emitRuns(pPr, ctx, k, level, numId, ilvl, runs, first: i == 0);
    }
  }

  void _emitRuns(
    XmlElement? pPr,
    _ParaCtx ctx,
    _Kind kind,
    int level,
    int? numId,
    int ilvl,
    List<InlineRun> raw, {
    required bool first,
  }) {
    final allCode =
        raw.isNotEmpty &&
        raw.any((r) => r.code && r.text.trim().isNotEmpty) &&
        raw.every((r) => r.code || r.text.trim().isEmpty);
    if (kind == _Kind.code ||
        (allCode && (kind == _Kind.paragraph || kind == _Kind.code))) {
      _blocks.add(_codeBlock(raw));
      return;
    }
    if (raw.isEmpty && kind == _Kind.paragraph) {
      if (_isRuleParagraph(pPr)) {
        _blocks.add(RuleBlock(options.idGenerator()));
        return;
      }
      final markFont = OoxmlRunProps.parse(pPr?.kid(_w, 'rPr')).font;
      if (MonospaceFonts.isMonospace(markFont)) {
        _blocks.add(const CodeBlock('', ''));
        return;
      }
    }
    var runs = _clean(raw);
    switch (kind) {
      case _Kind.heading:
        _blocks.add(
          runs.isEmpty ? const ParagraphBlock([]) : HeadingBlock(level, runs),
        );
        return;
      case _Kind.quote:
        _blocks.add(QuoteBlock([runs]));
        return;
      case _Kind.code:
        return; // handled above
      case _Kind.rule:
        _blocks.add(RuleBlock(options.idGenerator()));
        return;
      case _Kind.list || _Kind.paragraph:
        break;
    }
    bool? checked = first ? ctx.checkbox : null;
    if (checked == null && first) {
      final s = TaskGlyphs.strip(runs);
      if (s != null) {
        checked = s.$1;
        runs = s.$2;
      }
    }
    if (kind == _Kind.list && numId != null) {
      final lvl = _numbering.level(numId, ilvl);
      final glyphTask = lvl == null ? null : _glyphTask(lvl);
      checked ??= glyphTask;
      if (checked != null) {
        _blocks.add(TaskBlock(checked, ilvl, runs));
        return;
      }
      final ordered = lvl != null && !lvl.isBullet;
      if (ordered && _listStarts.add('$numId:$ilvl') && lvl.start != 1) {
        _warnings.add(
          ImportWarningKind.orderedListStart,
          'Numbered lists that did not start at 1 now start at 1.',
          blockIndex: _blocks.length,
        );
      }
      _blocks.add(
        ListItemBlock(
          ordered ? ListKindIr.ordered : ListKindIr.bullet,
          ilvl,
          runs,
        ),
      );
      return;
    }
    if (checked != null) {
      _blocks.add(TaskBlock(checked, 0, runs));
      return;
    }
    _blocks.add(ParagraphBlock(runs));
  }

  static bool? _glyphTask(OoxmlLevel lvl) {
    if (!lvl.isBullet || lvl.text.isEmpty) return null;
    final t = String.fromCharCode(lvl.text.runes.first);
    if (TaskGlyphs.unchecked.contains(t) || t == '\uF0A8' || t == '\uF06F') {
      return false;
    }
    if (TaskGlyphs.checked.contains(t) || t == '\uF0FE' || t == '\uF0FD') {
      return true;
    }
    return null;
  }

  bool _isRuleParagraph(XmlElement? pPr) {
    final bdr = pPr?.kid(_w, 'pBdr');
    if (bdr == null) return false;
    final edge = bdr.kid(_w, 'bottom') ?? bdr.kid(_w, 'top');
    final v = edge?.attr(_w, 'val');
    return v != null && v != 'nil' && v != 'none';
  }

  static List<InlineRun> _clean(List<InlineRun> runs) => InlineRun.merge([
    for (final r in runs) r.copyWith(text: ImportText.inline(r.text)),
  ]);

  static CodeBlock _codeBlock(List<InlineRun> runs) {
    final text = InlineRun.plainText(runs).replaceAll(importSoftBreak, '\n');
    return CodeBlock('', text.split('\n').map(ImportText.codeLine).join('\n'));
  }

  void _mergeCodeGaps() {
    for (var i = 1; i + 1 < _blocks.length; i++) {
      final b = _blocks[i];
      if (b is ParagraphBlock &&
          b.runs.isEmpty &&
          _blocks[i - 1] is CodeBlock &&
          _blocks[i + 1] is CodeBlock) {
        _blocks[i] = const CodeBlock('', '');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Inline content

  void _inline(XmlElement container, _ParaCtx ctx) {
    for (final e in container.childElements) {
      if (!e.isA(_w, e.name.local)) {
        if (e.isA(OoxmlNs.mc, 'AlternateContent')) {
          final choice =
              e.kid(OoxmlNs.mc, 'Choice') ?? e.kid(OoxmlNs.mc, 'Fallback');
          if (choice != null) _inline(choice, ctx);
        } else if (e.isA(OoxmlNs.m, 'oMath') || e.isA(OoxmlNs.m, 'oMathPara')) {
          _math(e, ctx);
        }
        continue;
      }
      switch (e.name.local) {
        case 'r':
          _run(e, ctx);
        case 'hyperlink':
          final prev = ctx.link;
          final prevMention = ctx.mention;
          ctx.link = _hyperlink(e);
          final tooltip = e.attr(_w, 'tooltip') ?? '';
          ctx.mention =
              ctx.link != null &&
                  LinkPolicy.isMailto(ctx.link!) &&
                  tooltip.startsWith(mentionTitlePrefix) &&
                  tooltip.length > mentionTitlePrefix.length
              ? tooltip.substring(mentionTitlePrefix.length)
              : null;
          _inline(e, ctx);
          ctx.link = prev;
          ctx.mention = prevMention;
        case 'fldSimple':
          final prev = ctx.link;
          ctx.link = _fieldLink(e.attr(_w, 'instr') ?? '') ?? prev;
          _inline(e, ctx);
          ctx.link = prev;
        case 'ins' || 'moveTo':
          _trackedChanges();
          _inline(e, ctx);
        case 'del' || 'moveFrom':
          _trackedChanges();
        case 'smartTag' || 'customXml' || 'dir' || 'bdo':
          _inline(e, ctx);
        case 'sdt':
          _inlineSdt(e, ctx);
        case 'commentRangeStart' || 'commentReference':
          _commentsDropped();
      }
    }
  }

  void _inlineSdt(XmlElement sdt, _ParaCtx ctx) {
    final cb = sdt.kid(_w, 'sdtPr')?.kid(OoxmlNs.w14, 'checkbox');
    if (cb != null) {
      final v = cb.kid(OoxmlNs.w14, 'checked')?.attr(OoxmlNs.w14, 'val');
      final checked = v == '1' || v == 'true';
      if (!ctx.hasText && ctx.checkbox == null) {
        ctx.checkbox = checked;
      } else {
        ctx.add(InlineRun(checked ? '☒' : '☐'));
      }
      return;
    }
    final content = sdt.kid(_w, 'sdtContent');
    if (content != null) _inline(content, ctx);
  }

  bool get _inInstruction => _fields.any((f) => !f.separated);

  String? get _fieldLinkActive {
    for (var i = _fields.length - 1; i >= 0; i--) {
      final f = _fields[i];
      if (f.separated && f.link != null) return f.link;
    }
    return null;
  }

  void _run(XmlElement r, _ParaCtx ctx) {
    final props = OoxmlRunProps.parse(r.kid(_w, 'rPr'));
    final charStyle = _styles[props.style];
    final cs = _presentationStyle(charStyle) ? null : charStyle;
    final toggles = ctx.styleToggles;
    final bold = props.bold ?? cs?.bold ?? toggles?.bold ?? false;
    final italic = props.italic ?? cs?.italic ?? toggles?.italic ?? false;
    final strike = props.strike ?? cs?.strike ?? toggles?.strike ?? false;
    // Our own exports mark inline code with the `CodeChar` style; their
    // paragraph fonts are theme typography (monospace themes exist).
    final font = props.font ?? cs?.font ?? (_own ? null : ctx.style?.font);
    final hidden = props.hidden || (cs?.hidden ?? false);
    final link = ctx.link ?? _fieldLinkActive;
    if (!hidden && link == null) {
      if (props.underline || (cs?.underline ?? false)) _removed('underline');
      if (props.color || (cs?.color ?? false)) _removed('colors');
      if (props.highlight || (cs?.highlight ?? false)) _removed('highlight');
      if (props.script) _removed('superscript and subscript');
    }
    InlineRun make(String text) => InlineRun(
      text,
      bold: bold,
      italic: italic,
      strike: strike,
      code: MonospaceFonts.isMonospace(font),
      link: ctx.link ?? _fieldLinkActive,
      mentionUserUuid: ctx.link != null ? ctx.mention : null,
    );
    _runContent(r, ctx, make, hidden: hidden, font: font);
  }

  void _runContent(
    XmlElement r,
    _ParaCtx ctx,
    InlineRun Function(String) make, {
    required bool hidden,
    required String? font,
  }) {
    void text(String t) {
      if (hidden || _inInstruction || t.isEmpty) return;
      ctx.add(make(t));
    }

    for (final c in r.childElements) {
      if (!c.isA(_w, c.name.local)) {
        if (c.isA(OoxmlNs.mc, 'AlternateContent')) {
          final choice =
              c.kid(OoxmlNs.mc, 'Choice') ?? c.kid(OoxmlNs.mc, 'Fallback');
          if (choice != null) {
            _runContent(choice, ctx, make, hidden: hidden, font: font);
          }
        }
        continue;
      }
      switch (c.name.local) {
        case 't':
          text(c.innerText);
        case 'instrText':
          if (_fields.isNotEmpty && !_fields.last.separated) {
            _fields.last.instr.write(c.innerText);
          }
        case 'fldChar':
          _fieldChar(c, ctx);
        case 'tab' || 'ptab':
          text('\t');
        case 'br':
          final type = c.attr(_w, 'type');
          if (type == 'page' || type == 'column') {
            _breaksDropped();
          } else {
            text(importSoftBreak);
          }
        case 'cr':
          text(importSoftBreak);
        case 'noBreakHyphen':
          text('-');
        case 'sym':
          text(_symbol(c));
        case 'drawing':
          if (!hidden && !_inInstruction) _drawing(c, ctx);
        case 'pict' || 'object':
          if (!hidden && !_inInstruction) _vml(c, ctx);
        case 'footnoteReference':
          if (!hidden) _noteReference(c, ctx, footnote: true);
        case 'endnoteReference':
          if (!hidden) _noteReference(c, ctx, footnote: false);
        case 'commentReference':
          _commentsDropped();
        case 'ruby':
          final base = c.kid(_w, 'rubyBase');
          if (base != null) _inline(base, ctx);
      }
    }
  }

  static String _symbol(XmlElement sym) {
    final code = int.tryParse(sym.attr(_w, 'char') ?? '', radix: 16);
    if (code == null) return '';
    final font = (sym.attr(_w, 'font') ?? '').toLowerCase();
    var c = code;
    if (c < 0x100 && font.contains('wingdings')) c += 0xF000;
    if (c >= 0xF000 && c <= 0xF0FF) {
      return switch (c) {
        0xF0A8 || 0xF06F || 0xF071 => '☐',
        0xF0FE => '☑',
        0xF0FD || 0xF078 => '☒',
        0xF0B7 || 0xF09F => '•',
        _ => '',
      };
    }
    return String.fromCharCode(c);
  }

  void _fieldChar(XmlElement c, _ParaCtx ctx) {
    switch (c.attr(_w, 'fldCharType')) {
      case 'begin':
        final f = _Field();
        _fields.add(f);
        final cb = c.kid(_w, 'ffData')?.kid(_w, 'checkBox');
        if (cb != null && !ctx.hasText && ctx.checkbox == null) {
          final checkedEl = cb.kid(_w, 'checked') ?? cb.kid(_w, 'default');
          ctx.checkbox = checkedEl != null && OoxmlRunProps.toggle(checkedEl);
        }
      case 'separate':
        if (_fields.isNotEmpty) {
          final f = _fields.last;
          f.separated = true;
          f.link = _fieldLink(f.instr.toString());
        }
      case 'end':
        if (_fields.isNotEmpty) _fields.removeLast();
    }
  }

  /// The link of a `HYPERLINK` field instruction (external targets only).
  String? _fieldLink(String instr) {
    final tokens = <String>[];
    final re = RegExp(r'"([^"]*)"|(\S+)');
    for (final m in re.allMatches(instr)) {
      tokens.add(m.group(1) ?? m.group(2)!);
    }
    if (tokens.isEmpty || tokens.first.toUpperCase() != 'HYPERLINK') {
      return null;
    }
    String? url;
    String? anchor;
    for (var i = 1; i < tokens.length; i++) {
      final t = tokens[i];
      if (t == r'\l') {
        anchor = i + 1 < tokens.length ? tokens[++i] : null;
      } else if (t == r'\o' || t == r'\t') {
        i++;
      } else if (t.startsWith(r'\')) {
        continue;
      } else {
        url ??= t;
      }
    }
    if (url == null) return null;
    return _normalizedLink(anchor == null ? url : '$url#$anchor');
  }

  String? _hyperlink(XmlElement h) {
    final id = h.attr(OoxmlNs.r, 'id');
    final anchor = h.attr(_w, 'anchor');
    if (id == null) return null; // internal bookmark: text only
    final rel = pkg.relationships(_part)[id];
    if (rel == null) return null;
    var url = rel.target;
    if (anchor != null && anchor.isNotEmpty && !url.contains('#')) {
      url = '$url#$anchor';
    }
    return _normalizedLink(url);
  }

  String? _normalizedLink(String url) {
    final n = LinkPolicy.normalizeLink(url.trim());
    if (n == null) {
      _warnings.add(
        ImportWarningKind.unsupportedLink,
        'Links with relative or unsupported targets were removed (the text '
        'was kept).',
        blockIndex: _blocks.length,
      );
    }
    return n;
  }

  void _math(XmlElement e, _ParaCtx ctx) {
    final t = e.deep(OoxmlNs.m, 't').map((x) => x.innerText).join();
    _placeholder('equations');
    ctx.add(InlineRun(t.trim().isEmpty ? '[equation]' : t));
  }

  void _noteReference(XmlElement c, _ParaCtx ctx, {required bool footnote}) {
    final id = c.attr(_w, 'id');
    final note = id == null ? null : (footnote ? _footnotes : _endnotes)[id];
    if (note == null || _inNote) return;
    final prevPart = _part;
    _inNote = true;
    _part = (footnote ? _footnotesPart : _endnotesPart) ?? _part;
    final paragraphs = <List<InlineRun>>[];
    for (final p in note.deep(_w, 'p')) {
      paragraphs.add(_clean(RunTools.trim(_paragraphRuns(p))));
    }
    _part = prevPart;
    _inNote = false;
    final n = _notes.add(RunTools.join(paragraphs, importSoftBreak));
    ctx.add(InlineRun('[$n]', link: ctx.link));
  }

  /// Inline runs of [p] for single-line contexts (cells, notes): images
  /// become their alt text.
  List<InlineRun> _paragraphRuns(XmlElement p, {bool inCell = false}) {
    final pPr = p.kid(_w, 'pPr');
    final style = _styles[pPr?.kid(_w, 'pStyle')?.attr(_w, 'val')];
    final heading = _kindOf(pPr, style).$1 == _Kind.heading;
    final ctx = _ParaCtx(
      styleToggles: heading || _presentationStyle(style) ? null : style,
      style: style,
      inCell: true,
    );
    _inline(p, ctx);
    final runs = <InlineRun>[
      if (ctx.checkbox != null) InlineRun(ctx.checkbox! ? '☒ ' : '☐ '),
    ];
    for (final s in ctx.segs) {
      switch (s) {
        case _RunSeg(:final run):
          runs.add(run);
        case _BlockSeg(:final block):
          final alt = block is ImageBlock ? block.alt : '';
          if (alt.isNotEmpty) runs.add(InlineRun(' $alt '));
      }
    }
    for (final b in ctx.after) {
      final t = switch (b) {
        ParagraphBlock(:final runs) => runs,
        _ => const <InlineRun>[],
      };
      if (t.isNotEmpty) runs.addAll([const InlineRun(' '), ...t]);
    }
    return InlineRun.merge(runs);
  }

  // -------------------------------------------------------------------------
  // Drawings

  void _drawing(XmlElement d, _ParaCtx ctx) {
    final container = d.childElements.firstOrNull;
    final docPr = container?.kid(OoxmlNs.wp, 'docPr');
    if (docPr?.attr(null, 'hidden') == '1') return;
    final alt = ImportText.inline(docPr?.attr(null, 'descr') ?? '').trim();
    final title = docPr?.attr(null, 'title');
    final pics = d.deep(OoxmlNs.pic, 'pic').toList();
    if (pics.isNotEmpty) {
      for (final pic in pics) {
        final blip = pic.deep(OoxmlNs.a, 'blip').firstOrNull;
        final id =
            blip?.attr(OoxmlNs.r, 'embed') ?? blip?.attr(OoxmlNs.r, 'link');
        _image(id, alt, title, ctx);
      }
      return;
    }
    final txbx = d.deep(_w, 'txbxContent').firstOrNull;
    if (txbx != null) {
      _textBox(txbx, ctx);
      return;
    }
    final uri =
        d.deep(OoxmlNs.a, 'graphicData').firstOrNull?.attr(null, 'uri') ?? '';
    final what = uri.contains('chart')
        ? 'chart'
        : uri.contains('diagram')
        ? 'diagram'
        : 'shape';
    _placeholder('${what}s');
    ctx.add(InlineRun(alt.isEmpty ? '[$what]' : '[$what: $alt]'));
  }

  void _vml(XmlElement e, _ParaCtx ctx) {
    final imageData = e.deep(OoxmlNs.v, 'imagedata').firstOrNull;
    if (imageData != null) {
      final shape = imageData.parentElement;
      final alt = ImportText.inline(
        shape?.attr(null, 'alt') ?? imageData.attr(OoxmlNs.o, 'title') ?? '',
      ).trim();
      _image(imageData.attr(OoxmlNs.r, 'id'), alt, null, ctx);
      return;
    }
    final txbx = e.deep(_w, 'txbxContent').firstOrNull;
    if (txbx != null) {
      _textBox(txbx, ctx);
      return;
    }
    final isRule = e.descendantElements.any(
      (x) =>
          x.attr(OoxmlNs.o, 'hr') == 't' || x.attr(OoxmlNs.o, 'hr') == 'true',
    );
    if (isRule && !ctx.inCell) {
      ctx.segs.add(_BlockSeg(RuleBlock(options.idGenerator())));
    }
  }

  void _textBox(XmlElement txbx, _ParaCtx ctx) {
    _placeholder('text boxes');
    final saved = _blocks;
    _blocks = <DocBlock>[];
    for (final e in txbx.childElements) {
      _block(e);
    }
    final produced = _blocks;
    _blocks = saved;
    if (ctx.inCell) {
      ctx.after.addAll(produced.whereType<ParagraphBlock>());
    } else {
      ctx.after.addAll(produced);
    }
  }

  void _image(String? relId, String alt, String? title, _ParaCtx ctx) {
    if (ctx.inCell) {
      ctx.segs.add(_BlockSeg(ImageBlock('', '', alt)));
      _warnings.add(
        ImportWarningKind.imageFlattened,
        'Images inside tables were replaced by their description.',
        blockIndex: _blocks.length,
      );
      return;
    }
    final t = title == null ? null : ImportText.inline(title).trim();
    DocBlock block;
    final rel = relId == null ? null : pkg.relationships(_part)[relId];
    if (rel == null) {
      _unresolvedImage();
      block = imagePlaceholder(alt);
    } else if (rel.external) {
      final src = LinkPolicy.normalizeImageSource(rel.target);
      if (src == null || !src.startsWith('http')) {
        _unresolvedImage();
        block = imagePlaceholder(alt);
      } else {
        block = ImageBlock(
          options.idGenerator(),
          src,
          alt,
          title: (t == null || t.isEmpty) ? null : t,
        );
      }
    } else {
      final bytes = _zip.bytes(rel.target);
      final mime = bytes == null
          ? null
          : ImageMime.detect(bytes, fileName: rel.target);
      final emb = (bytes == null || mime == null)
          ? null
          : embeddableImage(bytes, mime);
      if (emb == null) {
        _unresolvedImage(vector: mime == 'image/emf' || mime == 'image/wmf');
        block = imagePlaceholder(alt);
      } else {
        final image = _images.add(emb.$1, emb.$2, alt: alt, key: rel.target);
        block = ImageBlock(
          options.idGenerator(),
          image.src,
          alt,
          title: (t == null || t.isEmpty) ? null : t,
        );
      }
    }
    ctx.segs.add(_BlockSeg(block));
  }

  void _unresolvedImage({bool vector = false}) => _warnings.add(
    ImportWarningKind.unresolvedImage,
    vector
        ? 'EMF/WMF images are not supported; they were replaced by '
              'placeholders.'
        : 'Some images could not be imported; they were replaced by '
              'placeholders.',
    blockIndex: _blocks.length,
  );

  // -------------------------------------------------------------------------
  // Tables

  Iterable<XmlElement> _rows(XmlElement tbl) sync* {
    for (final e in tbl.childElements) {
      if (e.isA(_w, 'tr')) {
        final trPr = e.kid(_w, 'trPr');
        if (trPr?.kid(_w, 'del') != null) {
          _trackedChanges();
          continue;
        }
        yield e;
      } else if (e.isA(_w, 'sdt')) {
        final c = e.kid(_w, 'sdtContent');
        if (c != null) yield* _rows(c);
      } else if (e.isA(_w, 'customXml')) {
        yield* _rows(e);
      }
    }
  }

  Iterable<XmlElement> _cells(XmlElement tr) sync* {
    for (final e in tr.childElements) {
      if (e.isA(_w, 'tc')) {
        yield e;
      } else if (e.isA(_w, 'sdt')) {
        final c = e.kid(_w, 'sdtContent');
        if (c != null) yield* _cells(c);
      } else if (e.isA(_w, 'customXml')) {
        yield* _cells(e);
      }
    }
  }

  void _table(XmlElement tbl) {
    final grid = <List<List<InlineRun>>>[];
    final align = <CellAlign?>[];
    var spanned = false;
    for (final tr in _rows(tbl)) {
      final row = <List<InlineRun>>[];
      final trPr = tr.kid(_w, 'trPr');
      final before =
          int.tryParse(trPr?.kid(_w, 'gridBefore')?.attr(_w, 'val') ?? '') ?? 0;
      for (var k = 0; k < before.clamp(0, 64); k++) {
        row.add(const []);
      }
      for (final tc in _cells(tr)) {
        final tcPr = tc.kid(_w, 'tcPr');
        final span =
            (int.tryParse(tcPr?.kid(_w, 'gridSpan')?.attr(_w, 'val') ?? '') ??
                    1)
                .clamp(1, 64);
        final vMerge = tcPr?.kid(_w, 'vMerge');
        final continuation =
            vMerge != null &&
            (vMerge.attr(_w, 'val') ?? 'continue') != 'restart';
        final col = row.length;
        if (continuation) {
          spanned = true;
          row.add(const []);
        } else {
          row.add(_cellRuns(tc));
          if (vMerge != null) spanned = true;
        }
        while (align.length <= col) {
          align.add(null);
        }
        align[col] ??= _cellAlign(tc);
        if (span > 1) spanned = true;
        for (var k = 1; k < span; k++) {
          row.add(const []);
        }
      }
      if (row.isNotEmpty) grid.add(row);
    }
    if (grid.isEmpty) return;
    if (spanned) {
      _warnings.add(
        ImportWarningKind.tableFlattened,
        'Merged table cells were split; their content is in the first cell.',
        blockIndex: _blocks.length,
      );
    }
    _blocks.add(buildTable(options.idGenerator(), grid, align));
  }

  CellAlign? _cellAlign(XmlElement tc) {
    final p = tc.kid(_w, 'p');
    final jc = p?.kid(_w, 'pPr')?.kid(_w, 'jc')?.attr(_w, 'val');
    return switch (jc) {
      'center' => CellAlign.center,
      'right' || 'end' => CellAlign.right,
      'left' || 'start' => CellAlign.left,
      _ => null,
    };
  }

  List<InlineRun> _cellRuns(XmlElement tc) {
    final parts = <List<InlineRun>>[];
    void visit(XmlElement container) {
      for (final e in container.childElements) {
        if (e.isA(_w, 'p')) {
          parts.add(_clean(RunTools.trim(_paragraphRuns(e, inCell: true))));
        } else if (e.isA(_w, 'tbl')) {
          _warnings.add(
            ImportWarningKind.tableFlattened,
            'Nested tables were converted to text.',
            blockIndex: _blocks.length,
          );
          for (final tr in _rows(e)) {
            for (final c in _cells(tr)) {
              parts.add(_cellRuns(c));
            }
          }
        } else if (e.isA(_w, 'sdt')) {
          final c = e.kid(_w, 'sdtContent');
          if (c != null) visit(c);
        } else if (e.isA(_w, 'customXml')) {
          visit(e);
        }
      }
    }

    visit(tc);
    final nonEmpty = parts.where((p) => !RunTools.isBlank(p)).toList();
    if (nonEmpty.length > 1) {
      _warnings.add(
        ImportWarningKind.tableFlattened,
        'Table cells with several paragraphs were joined into one line.',
        blockIndex: _blocks.length,
      );
    }
    return RunTools.join(nonEmpty, ' ');
  }

  // -------------------------------------------------------------------------
  // Damaged packages

  void _salvage() {
    final raw = _zip.text(_docPart);
    if (raw != null) {
      final para = RegExp(r'<w:p[\s>][\s\S]*?</w:p>');
      final text = RegExp(r'<w:t(?:\s[^>]*)?>([^<]*)</w:t>');
      for (final m in para.allMatches(raw)) {
        final t = text
            .allMatches(m.group(0)!)
            .map((x) => _unescapeXml(x.group(1)!))
            .join();
        final clean = ImportText.inline(t);
        _blocks.add(
          ParagraphBlock(clean.isEmpty ? const [] : [InlineRun(clean)]),
        );
      }
    }
    _warnings.add(
      ImportWarningKind.contentDropped,
      'The document is damaged; only its text could be imported.',
    );
  }

  static String _unescapeXml(String s) => s.replaceAllMapped(
    RegExp(r'&(#x[0-9A-Fa-f]+|#[0-9]+|lt|gt|amp|quot|apos);'),
    (m) {
      final e = m.group(1)!;
      switch (e) {
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'amp':
          return '&';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final code = e.startsWith('#x')
          ? int.tryParse(e.substring(2), radix: 16)
          : int.tryParse(e.substring(1));
      return code == null || code > 0x10FFFF ? '' : String.fromCharCode(code);
    },
  );
}
