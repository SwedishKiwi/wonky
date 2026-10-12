/// OpenDocument Text import (07 §3.7).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

import '../../delta/embeds.dart';
import '../../delta/links.dart';
import '../../ir/doc_tree.dart';
import '../import_api.dart';
import '../import_limits.dart';
import '../import_support.dart';
import '../xml_support.dart';

part 'odt_styles.dart';

/// Imports OpenDocument Text packages (`.odt`, best effort).
///
/// Mapping (07 §3.7): `text:h` (`text:outline-level`) and heading styles →
/// headings 1–6; paragraph styles resolved through
/// `style:parent-style-name` (`Quotations` → quote, `Preformatted_20_Text`
/// and code styles → code lines merged into code blocks, paragraphs whose
/// spans are all monospace → code, `Horizontal_20_Line` or empty paragraphs
/// with a bottom border → rule, `Caption` after an image → image title);
/// `text:list` nesting → lists (bullet vs. number from the list style's level
/// at that depth); leading ☐/☑/☒ → tasks; span styles (bold or weight ≥ 600,
/// italic/oblique, line-through, monospace fonts and the `Source Text` style)
/// → inline attributes; `text:a` → links; `draw:frame`/`draw:image` →
/// images (alt from `svg:title`/`svg:desc`); `table:table` → tables (spans
/// flattened, cell alignment → column alignment); `text:line-break` → soft
/// break; `text:s`/`text:tab` → spaces/tab; footnotes → a final "Notes"
/// section; tracked changes accepted; annotations, headers/footers, indexes
/// and other unsupported formatting dropped with warnings; the master page
/// layout → [ImportResult.pageSetup]; `meta.xml` → title and language.
///
/// Throws [ImportFormatException] when the bytes are not an OpenDocument
/// text package; damaged content never throws.
final class OdtImporter implements DocumentImporter {
  /// Creates the importer.
  const OdtImporter();

  @override
  ImportFormat get format => ImportFormat.odt;

  @override
  Future<ImportResult> import(Uint8List bytes, ImportOptions options) async =>
      importSync(bytes, options);

  /// Synchronous variant of [import].
  ImportResult importSync(Uint8List bytes, ImportOptions options) {
    final zip = ZipPackage.open(bytes);
    if (zip == null) {
      throw const ImportFormatException(
        'The file is not an OpenDocument text (no ZIP package).',
      );
    }
    final mimetype = zip.text('mimetype')?.trim() ?? '';
    final isText = mimetype.startsWith(
      'application/vnd.oasis.opendocument.text',
    );
    if (mimetype.isNotEmpty && !isText) {
      throw ImportFormatException(
        'The file is not an OpenDocument text ($mimetype).',
      );
    }
    if (mimetype.isEmpty && !zip.has('content.xml')) {
      throw const ImportFormatException(
        'The file is not an OpenDocument text (no content.xml).',
      );
    }
    return _OdtReader(zip, options).read();
  }
}

const _text = _Ns.text;

sealed class _Seg {}

final class _RunSeg extends _Seg {
  _RunSeg(this.run, {required this.directMono});
  final InlineRun run;

  /// Monospace by an explicit font (not by the `Source Text` style).
  final bool directMono;
}

final class _BlockSeg extends _Seg {
  _BlockSeg(this.block);
  final DocBlock block;
}

/// Inline formatting while walking spans.
final class _Fmt {
  const _Fmt({
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.code = false,
    this.directMono = false,
    this.link,
  });

  final bool bold;
  final bool italic;
  final bool strike;
  final bool code;
  final bool directMono;
  final String? link;

  _Fmt copyWith({
    bool? bold,
    bool? italic,
    bool? strike,
    bool? code,
    bool? directMono,
    String? link,
    bool clearLink = false,
  }) => _Fmt(
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    strike: strike ?? this.strike,
    code: code ?? this.code,
    directMono: directMono ?? this.directMono,
    link: clearLink ? null : (link ?? this.link),
  );
}

/// Inline content of one paragraph.
final class _PCtx {
  _PCtx({required this.inCell});

  final bool inCell;
  final segs = <_Seg>[];
  final after = <DocBlock>[];

  /// ODF white-space collapsing: a space was just emitted (or the paragraph
  /// starts), so further character-data spaces are dropped.
  var lastSpace = true;

  bool get hasText => segs.any(
    (s) => s is _BlockSeg || (s is _RunSeg && s.run.text.trim().isNotEmpty),
  );

  void add(InlineRun r, {bool directMono = false}) {
    if (r.text.isNotEmpty) segs.add(_RunSeg(r, directMono: directMono));
  }

  /// Character data (collapsed white space).
  void chars(String raw, _Fmt f) {
    var s = raw.replaceAll(RegExp('[\t\n\r]'), ' ');
    s = s.replaceAll(RegExp(' {2,}'), ' ');
    if (lastSpace && s.startsWith(' ')) s = s.substring(1);
    if (s.isEmpty) return;
    lastSpace = s.endsWith(' ');
    add(_run(s, f), directMono: f.directMono);
  }

  /// Literal content (`text:s`, `text:tab`, `text:line-break`).
  void literal(String s, _Fmt f, {required bool collapseAfter}) {
    add(_run(s, f), directMono: f.directMono);
    lastSpace = collapseAfter;
  }

  static InlineRun _run(String s, _Fmt f) => InlineRun(
    s,
    bold: f.bold,
    italic: f.italic,
    strike: f.strike,
    code: f.code,
    link: f.link,
  );
}

enum _Kind { paragraph, heading, quote, code, rule, caption }

final class _ListCtx {
  const _ListCtx(this.depth, {required this.ordered});
  final int depth;
  final bool ordered;
}

final class _OdtReader {
  _OdtReader(this.zip, this.options);

  final ZipPackage zip;
  final ImportOptions options;
  final _warnings = WarningCollector();
  final _images = ImageCollector();
  final _notes = NotesCollector();
  final _sheet = _StyleSheet();
  var _blocks = <DocBlock>[];
  var _inNote = false;
  var _imageParaEnd = -1;
  String? _firstMasterPage;
  _Font? _defaultFont;

  ImportResult read() {
    final content = zip.xml('content.xml');
    _sheet.load(styles: zip.xml('styles.xml'), content: content);
    _defaultFont = _sheet.fontAlong(_sheet.chain('paragraph', 'Standard'));
    final body = content?.rootElement
        .kid(_Ns.office, 'body')
        ?.kid(_Ns.office, 'text');
    if (body == null) {
      _salvage();
    } else {
      _blockChildren(body);
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
    final pageSetup = _pageSetup();
    final meta = _meta();
    return buildImportResult(
      _blocks,
      options: options,
      warnings: _warnings,
      images: _images,
      title: meta.$1,
      language: normalizeLanguageTag(meta.$2 ?? _sheet.defaultLanguage),
      pageSetup: pageSetup,
    );
  }

  (String?, String?) _meta() {
    final root = zip.xml('meta.xml')?.rootElement;
    final meta = root?.kid(_Ns.office, 'meta');
    String? text(String local) {
      final t = meta?.kid(_Ns.dc, local)?.innerText.trim();
      return (t == null || t.isEmpty) ? null : ImportText.inline(t);
    }

    return (text('title'), text('language'));
  }

  // -------------------------------------------------------------------------
  // Warnings

  void _removed(String feature) =>
      _warnings.formattingRemoved(feature, blockIndex: _blocks.length);

  void _placeholder(String what) => _warnings.add(
    ImportWarningKind.placeholderInserted,
    'Text boxes, shapes, charts and equations were converted to text or '
    'placeholders ($what).',
    blockIndex: _blocks.length,
  );

  void _unresolvedImage({bool vector = false}) => _warnings.add(
    ImportWarningKind.unresolvedImage,
    vector
        ? 'Vector images (SVG, EMF, WMF) are not supported; they were '
              'replaced by placeholders.'
        : 'Some images could not be imported; they were replaced by '
              'placeholders.',
    blockIndex: _blocks.length,
  );

  // -------------------------------------------------------------------------
  // Block level

  void _blockChildren(XmlElement container) {
    for (final e in container.childElements) {
      _block(e);
    }
  }

  void _block(XmlElement e) {
    final ns = e.name.namespaceUri;
    final local = e.name.local;
    if (ns == _text) {
      switch (local) {
        case 'p':
          _paragraph(e);
        case 'h':
          _paragraph(e, heading: true);
        case 'list':
          _list(e, 0, null);
        case 'numbered-paragraph':
          _numberedParagraph(e);
        case 'section':
          _blockChildren(e);
        case 'tracked-changes':
          if (e.kids(_text, 'changed-region').isNotEmpty) {
            _warnings.add(
              ImportWarningKind.trackedChangesAccepted,
              'Tracked changes were accepted.',
              blockIndex: _blocks.length,
            );
          }
        case 'table-of-content' ||
            'illustration-index' ||
            'table-index' ||
            'object-index' ||
            'user-index' ||
            'alphabetical-index' ||
            'bibliography':
          _warnings.add(
            ImportWarningKind.contentDropped,
            'Tables of contents and indexes were removed.',
            blockIndex: _blocks.length,
          );
      }
    } else if (ns == _Ns.table && local == 'table') {
      _table(e);
    } else if (ns == _Ns.draw) {
      // Page-anchored frames and shapes.
      final ctx = _PCtx(inCell: false);
      _inlineElement(e, ctx, const _Fmt());
      _emit(ctx, _Kind.paragraph, 0, null, const []);
      _blocks.addAll(ctx.after);
    }
  }

  // -------------------------------------------------------------------------
  // Paragraphs

  static final _headingName = RegExp(r'^heading\s*([1-9]|10)$');

  (_Kind, int) _classify(List<_OdfStyle> chain) {
    for (final s in chain) {
      for (final n in s.names) {
        final hm = _headingName.firstMatch(n);
        if (hm != null) return (_Kind.heading, int.parse(hm.group(1)!));
        if (n == 'title') return (_Kind.heading, 1);
        if (n == 'subtitle') return (_Kind.heading, 2);
        if (n == 'horizontal line') return (_Kind.rule, 0);
        if (n == 'quotations' || n.contains('quote')) return (_Kind.quote, 0);
        if (n == 'preformatted text' ||
            n == 'html preformatted' ||
            n.startsWith('code') ||
            n.startsWith('source code')) {
          return (_Kind.code, 0);
        }
        if (n == 'caption') return (_Kind.caption, 0);
      }
      final ol = s.outlineLevel;
      if (ol != null && ol > 0) return (_Kind.heading, ol);
    }
    return (_Kind.paragraph, 0);
  }

  int? _outlineOf(List<_OdfStyle> chain) {
    for (final s in chain) {
      if (s.outlineLevel != null) return s.outlineLevel;
    }
    return null;
  }

  /// Base formatting of plain paragraphs and list items: the paragraph
  /// style's bold/italic/strike and a monospace font other than the
  /// document default.
  _Fmt _paragraphFmt(
    List<_OdfStyle> chain,
    _Kind kind, {
    required bool inCell,
  }) {
    if (kind != _Kind.paragraph || inCell) return const _Fmt();
    if (chain.any((s) => s.named((n) => n == 'task checked'))) {
      return const _Fmt();
    }
    final font = _sheet.fontAlong(chain);
    final mono =
        _isMono(font) &&
        font!.family.toLowerCase() != _defaultFont?.family.toLowerCase();
    return _Fmt(
      bold: _bold(_StyleSheet.textProp(chain, 'font-weight')) ?? false,
      italic: _italic(_StyleSheet.textProp(chain, 'font-style')) ?? false,
      strike:
          _strike(_StyleSheet.textProp(chain, 'text-line-through-style')) ??
          false,
      code: mono,
      directMono: mono,
    );
  }

  static bool? _bold(String? v) {
    if (v == null) return null;
    if (v == 'bold' || v == 'bolder') return true;
    final n = int.tryParse(v);
    if (n != null) return n >= 600;
    return false;
  }

  static bool? _italic(String? v) =>
      v == null ? null : (v == 'italic' || v == 'oblique');

  static bool? _strike(String? v) => v == null ? null : v != 'none';

  void _paragraph(XmlElement p, {bool heading = false, _ListCtx? list}) {
    final chain = _sheet.chain('paragraph', p.attr(_text, 'style-name'));
    _firstMasterPage ??= chain.firstOrNull?.masterPage;
    var (kind, level) = _classify(chain);
    if (heading) {
      level =
          int.tryParse(p.attr(_text, 'outline-level') ?? '') ??
          _outlineOf(chain) ??
          1;
      kind = level >= 1 ? _Kind.heading : _Kind.paragraph;
    }
    level = level.clamp(1, 6);
    final ctx = _PCtx(inCell: false);
    _inline(p, ctx, _paragraphFmt(chain, kind, inCell: false));
    _directParagraphFormatting(chain, ctx);
    if (kind == _Kind.caption && _captionTarget(ctx)) return;
    _emit(ctx, kind, level, list, chain);
    _blocks.addAll(ctx.after);
  }

  void _directParagraphFormatting(List<_OdfStyle> chain, _PCtx ctx) {
    final own = chain.firstOrNull;
    if (own == null || !own.automatic) return;
    final align = own.para['text-align'];
    final textOnly = ctx.segs.every((s) => s is _RunSeg);
    if (textOnly &&
        ctx.hasText &&
        (align == 'center' ||
            align == 'end' ||
            align == 'right' ||
            align == 'justify')) {
      _removed('alignment');
    }
    if (own.para['break-before'] == 'page' ||
        own.para['break-after'] == 'page') {
      _warnings.add(
        ImportWarningKind.breaksDropped,
        'Page breaks, section breaks and columns were removed.',
        blockIndex: _blocks.length,
      );
    }
  }

  /// A `Caption` paragraph right after an image paragraph becomes the
  /// image's title.
  bool _captionTarget(_PCtx ctx) {
    if (_imageParaEnd != _blocks.length || _blocks.isEmpty) return false;
    final last = _blocks.last;
    if (last is! ImageBlock || last.title != null) return false;
    if (ctx.segs.any((s) => s is _BlockSeg) || ctx.after.isNotEmpty) {
      return false;
    }
    final text = ImportText.inline(
      InlineRun.plainText([
        for (final s in ctx.segs)
          if (s is _RunSeg) s.run,
      ]).replaceAll(importSoftBreak, ' '),
    ).trim();
    if (text.isEmpty) return false;
    _blocks[_blocks.length - 1] = ImageBlock(
      last.id,
      last.src,
      last.alt,
      title: text,
    );
    _imageParaEnd = -1;
    return true;
  }

  void _emit(
    _PCtx ctx,
    _Kind kind,
    int level,
    _ListCtx? list,
    List<_OdfStyle> chain,
  ) {
    final groups = <List<_RunSeg>>[[]];
    final blocks = <DocBlock?>[null];
    for (final s in ctx.segs) {
      switch (s) {
        case _RunSeg():
          groups.last.add(s);
        case _BlockSeg(:final block):
          blocks.add(block);
          groups.add([]);
      }
    }
    bool blank(List<_RunSeg> g) => RunTools.isBlank([for (final s in g) s.run]);
    final onlyBlocks = groups.every(blank) && blocks.length > 1;
    for (var i = 0; i < groups.length; i++) {
      final b = blocks[i];
      if (b != null) _blocks.add(b);
      if (onlyBlocks) continue;
      if (i > 0 && blank(groups[i])) continue;
      _emitRuns(
        i == 0 || list == null ? kind : _Kind.paragraph,
        level,
        i == 0 ? list : null,
        groups[i],
        chain,
        first: i == 0,
      );
    }
    _imageParaEnd = onlyBlocks && _blocks.lastOrNull is ImageBlock
        ? _blocks.length
        : -1;
  }

  void _emitRuns(
    _Kind kind,
    int level,
    _ListCtx? list,
    List<_RunSeg> segs,
    List<_OdfStyle> chain, {
    required bool first,
  }) {
    final raw = InlineRun.merge([for (final s in segs) s.run]);
    final visible = segs.where((s) => s.run.text.trim().isNotEmpty);
    final allCode =
        visible.isNotEmpty &&
        visible.every((s) => s.run.code) &&
        visible.any((s) => s.directMono);
    if (kind == _Kind.code ||
        (allCode && kind == _Kind.paragraph && list == null)) {
      _blocks.add(_codeBlock(raw));
      return;
    }
    if (kind == _Kind.rule) {
      _blocks.add(RuleBlock(options.idGenerator()));
      return;
    }
    if (raw.isEmpty &&
        kind == _Kind.paragraph &&
        list == null &&
        _bottomBorder(chain)) {
      _blocks.add(RuleBlock(options.idGenerator()));
      return;
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
      case _Kind.code || _Kind.rule:
        return; // handled above
      case _Kind.paragraph || _Kind.caption:
        break;
    }
    bool? checked;
    if (first) {
      final s = TaskGlyphs.strip(runs);
      if (s != null) {
        checked = s.$1;
        runs = s.$2;
      }
    }
    if (list != null) {
      _blocks.add(
        checked != null
            ? TaskBlock(checked, list.depth, runs)
            : ListItemBlock(
                list.ordered ? ListKindIr.ordered : ListKindIr.bullet,
                list.depth,
                runs,
              ),
      );
      return;
    }
    _blocks.add(
      checked != null ? TaskBlock(checked, 0, runs) : ParagraphBlock(runs),
    );
  }

  static bool _bottomBorder(List<_OdfStyle> chain) {
    for (final s in chain) {
      final v = s.para['border-bottom'];
      if (v == null) continue;
      final t = v.trim();
      return t.isNotEmpty && t != 'none' && !t.startsWith('0pt') && t != '0';
    }
    return false;
  }

  static String _plain(List<InlineRun> runs) =>
      InlineRun.plainText(runs).replaceAll(importSoftBreak, ' ').trim();

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
  // Lists

  void _list(XmlElement list, int depth, String? inherited) {
    final styleName = list.attr(_text, 'style-name') ?? inherited;
    var d = depth;
    if (d > 8) {
      d = 8;
      _warnings.add(
        ImportWarningKind.indentTooDeep,
        'Lists nested deeper than 9 levels were flattened.',
        blockIndex: _blocks.length,
      );
    }
    for (final item in list.childElements) {
      if (item.isA(_text, 'list-header')) {
        for (final c in item.childElements) {
          if (c.isA(_text, 'list')) {
            _list(c, depth + 1, styleName);
          } else {
            _block(c);
          }
        }
        continue;
      }
      if (!item.isA(_text, 'list-item')) continue;
      final itemStyle = item.attr(_text, 'style-override') ?? styleName;
      var firstDone = false;
      int? itemIndex;
      for (final c in item.childElements) {
        if (c.isA(_text, 'p') || c.isA(_text, 'h')) {
          if (!firstDone) {
            firstDone = true;
            final pChain = _sheet.chain(
              'paragraph',
              c.attr(_text, 'style-name'),
            );
            final ordered = _ordered(itemStyle, d, pChain, item);
            final before = _blocks.length;
            _paragraph(
              c,
              heading: c.isA(_text, 'h'),
              list: _ListCtx(d, ordered: ordered),
            );
            for (var k = before; k < _blocks.length; k++) {
              final b = _blocks[k];
              if (b is ListItemBlock || b is TaskBlock) itemIndex = k;
            }
          } else {
            _continuation(c, itemIndex);
          }
        } else if (c.isA(_text, 'list')) {
          firstDone = true;
          _list(c, depth + 1, itemStyle);
          itemIndex = null;
        } else {
          if (c.isA(_Ns.table, 'table') || c.isA(_text, 'section')) {
            _warnings.add(
              ImportWarningKind.blockFlattened,
              'Tables and sections inside list items were moved out of the '
              'list.',
              blockIndex: _blocks.length,
            );
          }
          firstDone = true;
          _block(c);
          itemIndex = null;
        }
      }
    }
  }

  /// A further paragraph of a list item: joined to the item with a soft
  /// break.
  void _continuation(XmlElement p, int? itemIndex) {
    final hasFrames = p.descendantElements.any((e) => e.isA(_Ns.draw, 'frame'));
    if (itemIndex == null || itemIndex != _blocks.length - 1 || hasFrames) {
      _paragraph(p, heading: p.isA(_text, 'h'));
      return;
    }
    final runs = _clean(RunTools.trim(_paragraphRuns(p)));
    if (RunTools.isBlank(runs)) return;
    _warnings.add(
      ImportWarningKind.multiParagraphItem,
      'List items with several paragraphs were joined with line breaks.',
      blockIndex: itemIndex,
    );
    final b = _blocks[itemIndex];
    List<InlineRun> joined(List<InlineRun> a) =>
        InlineRun.merge([...a, const InlineRun(importSoftBreak), ...runs]);
    _blocks[itemIndex] = switch (b) {
      ListItemBlock(:final kind, :final indent, runs: final a) => ListItemBlock(
        kind,
        indent,
        joined(a),
      ),
      TaskBlock(:final checked, :final indent, runs: final a) => TaskBlock(
        checked,
        indent,
        joined(a),
      ),
      _ => b,
    };
  }

  void _numberedParagraph(XmlElement e) {
    final level = (int.tryParse(e.attr(_text, 'level') ?? '') ?? 1).clamp(
      1,
      10,
    );
    for (final c in e.childElements) {
      if (c.isA(_text, 'p') || c.isA(_text, 'h')) {
        final chain = _sheet.chain('paragraph', c.attr(_text, 'style-name'));
        final d = (level - 1).clamp(0, 8);
        _paragraph(
          c,
          heading: c.isA(_text, 'h'),
          list: _ListCtx(d, ordered: _ordered(null, d, chain, e)),
        );
      }
    }
  }

  /// Whether level [depth] of the list style is numbered.
  bool _ordered(
    String? listStyle,
    int depth,
    List<_OdfStyle> paragraphChain,
    XmlElement item,
  ) {
    var style = _sheet.listStyle(listStyle);
    if (style == null) {
      for (final s in paragraphChain) {
        final n = s.listStyle;
        if (n != null && n.isNotEmpty) {
          style = _sheet.listStyle(n);
          if (style != null) break;
        }
      }
    }
    if (style == null) return false;
    XmlElement? levelStyle;
    XmlElement? lower;
    for (final l in style.childElements) {
      final n = int.tryParse(l.attr(_text, 'level') ?? '');
      if (n == null) continue;
      if (n == depth + 1) {
        levelStyle = l;
        break;
      }
      if (n <= depth + 1) lower = l;
    }
    levelStyle ??= lower;
    if (levelStyle == null ||
        !levelStyle.isA(_text, 'list-level-style-number')) {
      return false;
    }
    final format = levelStyle.attr(_Ns.style, 'num-format') ?? '';
    if (format.isEmpty) return false;
    final start =
        int.tryParse(item.attr(_text, 'start-value') ?? '') ??
        int.tryParse(levelStyle.attr(_text, 'start-value') ?? '') ??
        1;
    if (start != 1) {
      _warnings.add(
        ImportWarningKind.orderedListStart,
        'Numbered lists that did not start at 1 now start at 1.',
        blockIndex: _blocks.length,
      );
    }
    return true;
  }

  // -------------------------------------------------------------------------
  // Inline content

  void _inline(XmlElement el, _PCtx ctx, _Fmt fmt) {
    for (final node in el.children) {
      if (node is XmlText) {
        ctx.chars(node.value, fmt);
      } else if (node is XmlCDATA) {
        ctx.chars(node.value, fmt);
      } else if (node is XmlElement) {
        _inlineElement(node, ctx, fmt);
      }
    }
  }

  void _inlineElement(XmlElement e, _PCtx ctx, _Fmt fmt) {
    final ns = e.name.namespaceUri;
    final local = e.name.local;
    if (ns == _text) {
      switch (local) {
        case 's':
          final n = (int.tryParse(e.attr(_text, 'c') ?? '') ?? 1).clamp(
            1,
            1024,
          );
          ctx.literal(' ' * n, fmt, collapseAfter: true);
        case 'tab':
          ctx.literal('\t', fmt, collapseAfter: false);
        case 'line-break':
          ctx.literal(importSoftBreak, fmt, collapseAfter: true);
        case 'span':
          _inline(e, ctx, _span(fmt, e.attr(_text, 'style-name')));
        case 'a':
          final link = _link(e.attr(_Ns.xlink, 'href'));
          _inline(
            e,
            ctx,
            _span(
              link == null
                  ? fmt.copyWith(clearLink: true)
                  : fmt.copyWith(link: link),
              e.attr(_text, 'style-name'),
            ),
          );
        case 'note':
          _note(e, ctx, fmt);
        case 'ruby':
          final base = e.kid(_text, 'ruby-base');
          if (base != null) _inline(base, ctx, fmt);
        default:
          // Fields (page numbers, dates, titles …), meta and unknown
          // elements contribute their text content; marks do not.
          if (!_ignoredText.contains(local)) _inline(e, ctx, fmt);
      }
    } else if (ns == _Ns.office) {
      if (local == 'annotation') {
        _warnings.add(
          ImportWarningKind.commentsDropped,
          'Comments in the document were not imported.',
        );
      }
    } else if (ns == _Ns.draw) {
      switch (local) {
        case 'frame':
          _frame(e, ctx);
        case 'a':
          _inline(e, ctx, fmt);
        default:
          _shape(e, ctx);
      }
    } else if (ns != _Ns.table && ns != _Ns.style) {
      _inline(e, ctx, fmt);
    }
  }

  /// Text elements without visible content (marks, hidden text, change
  /// markers).
  static const _ignoredText = {
    'bookmark',
    'bookmark-start',
    'bookmark-end',
    'reference-mark',
    'reference-mark-start',
    'reference-mark-end',
    'soft-page-break',
    'change',
    'change-start',
    'change-end',
    'toc-mark',
    'toc-mark-start',
    'toc-mark-end',
    'alphabetical-index-mark',
    'alphabetical-index-mark-start',
    'alphabetical-index-mark-end',
    'user-index-mark',
    'user-index-mark-start',
    'user-index-mark-end',
    'hidden-text',
    'hidden-paragraph',
    'note-citation',
    'tracked-changes',
  };

  static const _neutralCharStyles = {
    'internet link',
    'visited internet link',
    'index link',
    'mention',
    'wonky mention',
  };

  static bool _codeStyleName(String n) =>
      n == 'source text' ||
      n == 'teletype' ||
      n == 'example' ||
      n.startsWith('source code') ||
      n == 'code' ||
      n == 'inline code' ||
      n == 'html code';

  /// [fmt] with the text style [styleName] applied.
  _Fmt _span(_Fmt fmt, String? styleName) {
    if (styleName == null) return fmt;
    final chain = _sheet.chain('text', styleName, withDefault: false);
    if (chain.isEmpty) return fmt;
    bool? bold;
    bool? italic;
    bool? strike;
    _Font? font;
    var codeStyle = false;
    var underline = false;
    var color = false;
    var highlight = false;
    var script = false;
    for (final s in chain) {
      if (s.named(_codeStyleName)) {
        // The code style's own typography (weight, color) is not semantic.
        codeStyle = true;
        continue;
      }
      if (s.named(_neutralCharStyles.contains)) continue;
      final t = s.text;
      bold ??= _bold(t['font-weight']);
      italic ??= _italic(t['font-style']);
      strike ??= _strike(t['text-line-through-style']);
      font ??= _sheet.fontOf(t);
      final u = t['text-underline-style'];
      if (u != null && u != 'none') underline = true;
      if (t['color'] != null) color = true;
      final bg = t['background-color'];
      if (bg != null && bg != 'transparent') highlight = true;
      final pos = t['text-position'];
      if (pos != null && !pos.startsWith('0') && pos != 'normal') {
        script = true;
      }
    }
    final mono = _isMono(font);
    final code = codeStyle || (font != null ? mono : fmt.code);
    if (fmt.link == null && !code) {
      if (underline) _removed('underline');
      if (color) _removed('colors');
      if (highlight) _removed('highlight');
    }
    if (script) _removed('superscript and subscript');
    return fmt.copyWith(
      bold: bold,
      italic: italic,
      strike: strike,
      code: code,
      directMono: codeStyle ? false : (font != null ? mono : fmt.directMono),
    );
  }

  String? _link(String? href) {
    if (href == null) return null;
    final h = href.trim();
    if (h.isEmpty || h.startsWith('#')) return null; // internal: text only
    final n = LinkPolicy.normalizeLink(h);
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

  void _note(XmlElement note, _PCtx ctx, _Fmt fmt) {
    if (_inNote) return;
    final body = note.kid(_text, 'note-body');
    if (body == null) return;
    _inNote = true;
    final paragraphs = <List<InlineRun>>[];
    for (final p in body.descendantElements) {
      if (p.isA(_text, 'p') || p.isA(_text, 'h')) {
        paragraphs.add(_clean(RunTools.trim(_paragraphRuns(p))));
      }
    }
    _inNote = false;
    final n = _notes.add(RunTools.join(paragraphs, importSoftBreak));
    ctx.add(InlineRun('[$n]', link: fmt.link));
    ctx.lastSpace = false;
  }

  /// Inline runs of [p] for single-line contexts (cells, notes, list
  /// continuations): images become their alt text.
  List<InlineRun> _paragraphRuns(XmlElement p) {
    final ctx = _PCtx(inCell: true);
    _inline(p, ctx, const _Fmt());
    final runs = <InlineRun>[];
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
      if (b is ParagraphBlock && b.runs.isNotEmpty) {
        runs.addAll([const InlineRun(' '), ...b.runs]);
      }
    }
    return InlineRun.merge(runs);
  }

  // -------------------------------------------------------------------------
  // Frames, images, shapes

  void _frame(XmlElement f, _PCtx ctx) {
    String? kidText(String local) {
      final t = f.kid(_Ns.svg, local)?.innerText.trim();
      return (t == null || t.isEmpty) ? null : t;
    }

    final alt = ImportText.inline(
      kidText('title') ?? kidText('desc') ?? '',
    ).trim();
    final object = f.kid(_Ns.draw, 'object') ?? f.kid(_Ns.draw, 'object-ole');
    if (object != null) {
      final what = _objectKind(object);
      _placeholder('${what}s');
      ctx.add(InlineRun(alt.isEmpty ? '[$what]' : '[$what: $alt]'));
      ctx.lastSpace = false;
      return;
    }
    final images = f.kids(_Ns.draw, 'image').toList();
    if (images.isNotEmpty) {
      _image(images, alt, ctx);
      return;
    }
    final box = f.kid(_Ns.draw, 'text-box');
    if (box != null) {
      _textBox(box, ctx);
      return;
    }
    if (f.childElements.any(
      (e) => e.isA(_Ns.draw, 'plugin') || e.isA(_Ns.draw, 'applet'),
    )) {
      _placeholder('objects');
      ctx.add(InlineRun(alt.isEmpty ? '[object]' : '[object: $alt]'));
    }
  }

  String _objectKind(XmlElement object) {
    final href = object.attr(_Ns.xlink, 'href');
    if (href != null) {
      final root = zip
          .xml('${ZipPackage.normalizePath(href)}/content.xml')
          ?.rootElement;
      if (root != null) {
        if (root.name.namespaceUri == _Ns.math ||
            root.descendantElements.any(
              (e) => e.name.namespaceUri == _Ns.math,
            )) {
          return 'equation';
        }
        if (root.deep(_Ns.office, 'chart').isNotEmpty) return 'chart';
      }
    }
    if (object.childElements.any((e) => e.name.namespaceUri == _Ns.math)) {
      return 'equation';
    }
    return 'object';
  }

  void _image(List<XmlElement> images, String alt, _PCtx ctx) {
    if (ctx.inCell) {
      ctx.segs.add(_BlockSeg(ImageBlock('', '', alt)));
      _warnings.add(
        ImportWarningKind.imageFlattened,
        'Images inside tables were replaced by their description.',
        blockIndex: _blocks.length,
      );
      return;
    }
    DocBlock? block;
    var vector = false;
    for (final im in images) {
      final href = im.attr(_Ns.xlink, 'href')?.trim();
      if (href != null && RegExp('^https?://').hasMatch(href)) {
        final src = LinkPolicy.normalizeImageSource(href);
        if (src != null) {
          block = ImageBlock(options.idGenerator(), src, alt);
          break;
        }
        continue;
      }
      Uint8List? bytes;
      String? path;
      if (href != null && href.isNotEmpty && !href.contains(':')) {
        path = ZipPackage.resolve('content.xml', href);
        bytes = zip.bytes(path);
      } else {
        final data = im.kid(_Ns.office, 'binary-data')?.innerText;
        if (data != null) {
          try {
            bytes = base64.decode(data.replaceAll(RegExp(r'\s'), ''));
          } on FormatException {
            bytes = null;
          }
        }
      }
      if (bytes == null) continue;
      final mime = ImageMime.detect(bytes, fileName: path);
      final emb = mime == null ? null : embeddableImage(bytes, mime);
      if (emb == null) {
        if (mime == 'image/svg+xml' ||
            mime == 'image/emf' ||
            mime == 'image/wmf' ||
            (path != null && path.toLowerCase().endsWith('.svm'))) {
          vector = true;
        }
        continue;
      }
      final image = _images.add(emb.$1, emb.$2, alt: alt, key: path);
      block = ImageBlock(options.idGenerator(), image.src, alt);
      break;
    }
    if (block == null) {
      _unresolvedImage(vector: vector);
      block = imagePlaceholder(alt);
    }
    ctx.segs.add(_BlockSeg(block));
    ctx.lastSpace = true;
  }

  void _textBox(XmlElement box, _PCtx ctx) {
    final saved = _blocks;
    final savedEnd = _imageParaEnd;
    _blocks = <DocBlock>[];
    _blockChildren(box);
    var produced = _blocks;
    _blocks = saved;
    _imageParaEnd = savedEnd;
    // A captioned image (frame > text box > image + caption text).
    if (produced.length == 2 &&
        produced[0] is ImageBlock &&
        produced[1] is ParagraphBlock) {
      final img = produced[0] as ImageBlock;
      final caption = _plain((produced[1] as ParagraphBlock).runs);
      if (img.title == null && caption.isNotEmpty) {
        produced = [ImageBlock(img.id, img.src, img.alt, title: caption)];
      }
    }
    if (!produced.any((b) => b is ImageBlock)) _placeholder('text boxes');
    if (ctx.inCell) {
      ctx.after.addAll(produced.whereType<ParagraphBlock>());
    } else if (produced.length == 1 && produced.single is ImageBlock) {
      ctx.segs.add(_BlockSeg(produced.single));
    } else {
      ctx.after.addAll(produced);
    }
  }

  void _shape(XmlElement shape, _PCtx ctx) {
    final parts = <String>[
      for (final p in shape.descendantElements)
        if (p.isA(_text, 'p') || p.isA(_text, 'h'))
          InlineRun.plainText(_paragraphRuns(p)).trim(),
    ].where((t) => t.isNotEmpty).toList();
    if (parts.isEmpty) return;
    _placeholder('shapes');
    ctx.add(InlineRun(parts.join(' ')));
    ctx.lastSpace = false;
  }

  // -------------------------------------------------------------------------
  // Tables

  Iterable<XmlElement> _rows(XmlElement container) sync* {
    for (final e in container.childElements) {
      if (e.isA(_Ns.table, 'table-row')) {
        final repeat =
            (int.tryParse(e.attr(_Ns.table, 'number-rows-repeated') ?? '') ?? 1)
                .clamp(1, 100);
        for (var i = 0; i < repeat; i++) {
          yield e;
        }
      } else if (e.isA(_Ns.table, 'table-header-rows') ||
          e.isA(_Ns.table, 'table-rows') ||
          e.isA(_Ns.table, 'table-row-group')) {
        yield* _rows(e);
      }
    }
  }

  void _table(XmlElement tbl) {
    final grid = <List<List<InlineRun>>>[];
    final aligns = <List<CellAlign?>>[];
    var spanned = false;
    for (final tr in _rows(tbl)) {
      final row = <List<InlineRun>>[];
      final rowAlign = <CellAlign?>[];
      for (final cell in tr.childElements) {
        final covered = cell.isA(_Ns.table, 'covered-table-cell');
        if (!covered && !cell.isA(_Ns.table, 'table-cell')) continue;
        final repeat =
            (int.tryParse(
                      cell.attr(_Ns.table, 'number-columns-repeated') ?? '',
                    ) ??
                    1)
                .clamp(1, 64);
        final colSpan =
            int.tryParse(
              cell.attr(_Ns.table, 'number-columns-spanned') ?? '',
            ) ??
            1;
        final rowSpan =
            int.tryParse(cell.attr(_Ns.table, 'number-rows-spanned') ?? '') ??
            1;
        if (covered || colSpan > 1 || rowSpan > 1) spanned = true;
        final runs = covered ? const <InlineRun>[] : _cellRuns(cell);
        final align = covered ? null : _cellAlign(cell);
        for (var k = 0; k < repeat && row.length < 64; k++) {
          row.add(runs);
          rowAlign.add(align);
        }
      }
      if (row.isNotEmpty) {
        grid.add(row);
        aligns.add(rowAlign);
      }
    }
    if (grid.isEmpty) return;
    // Trailing empty columns (repeated spreadsheet cells) are dropped.
    var columns = grid.map((r) => r.length).max;
    while (columns > 1 &&
        grid.every(
          (r) => r.length < columns || RunTools.isBlank(r[columns - 1]),
        )) {
      columns--;
    }
    for (var r = 0; r < grid.length; r++) {
      if (grid[r].length > columns) {
        grid[r] = grid[r].sublist(0, columns);
        aligns[r] = aligns[r].sublist(0, columns);
      }
    }
    if (spanned) {
      _warnings.add(
        ImportWarningKind.tableFlattened,
        'Merged table cells were split; their content is in the first cell.',
        blockIndex: _blocks.length,
      );
    }
    final align = <CellAlign?>[
      for (var c = 0; c < columns; c++) _columnAlign(aligns, c),
    ];
    _blocks.add(buildTable(options.idGenerator(), grid, align));
  }

  static CellAlign? _columnAlign(List<List<CellAlign?>> aligns, int c) {
    for (var r = 1; r < aligns.length; r++) {
      if (c < aligns[r].length) return aligns[r][c];
    }
    return aligns.isNotEmpty && c < aligns[0].length ? aligns[0][c] : null;
  }

  /// Alignment of the first paragraph of [cell] from its direct
  /// (automatic) paragraph style.
  CellAlign? _cellAlign(XmlElement cell) {
    final p = cell.childElements.firstWhereOrNull(
      (e) => e.isA(_text, 'p') || e.isA(_text, 'h'),
    );
    final own = _sheet.lookup('paragraph', p?.attr(_text, 'style-name'));
    if (own == null || !own.automatic) return null;
    return switch (own.para['text-align']) {
      'center' => CellAlign.center,
      'end' || 'right' => CellAlign.right,
      'start' || 'left' => CellAlign.left,
      _ => null,
    };
  }

  List<InlineRun> _cellRuns(XmlElement cell) {
    final parts = <List<InlineRun>>[];
    void visit(XmlElement container) {
      for (final e in container.childElements) {
        if (e.isA(_text, 'p') || e.isA(_text, 'h')) {
          parts.add(_clean(RunTools.trim(_paragraphRuns(e))));
        } else if (e.isA(_text, 'list') ||
            e.isA(_text, 'list-item') ||
            e.isA(_text, 'list-header') ||
            e.isA(_text, 'section')) {
          visit(e);
        } else if (e.isA(_Ns.table, 'table')) {
          _warnings.add(
            ImportWarningKind.tableFlattened,
            'Nested tables were converted to text.',
            blockIndex: _blocks.length,
          );
          for (final tr in _rows(e)) {
            for (final c in tr.childElements) {
              if (c.isA(_Ns.table, 'table-cell')) parts.add(_cellRuns(c));
            }
          }
        }
      }
    }

    visit(cell);
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
  // Page setup

  ImportedPageSetup? _pageSetup() {
    final pages = _sheet.masterPages;
    if (pages.isEmpty) return null;
    final master =
        pages.firstWhereOrNull(
          (m) => m.attr(_Ns.style, 'name') == _firstMasterPage,
        ) ??
        pages.firstWhereOrNull(
          (m) => m.attr(_Ns.style, 'name') == 'Standard',
        ) ??
        pages.first;
    _headersFooters(master);
    final layout = _sheet.pageLayout(
      master.attr(_Ns.style, 'page-layout-name'),
    );
    final props = layout?.kid(_Ns.style, 'page-layout-properties');
    if (props == null) return null;
    final w = _length(props.attr(_Ns.fo, 'page-width'));
    final h = _length(props.attr(_Ns.fo, 'page-height'));
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    final all = _length(props.attr(_Ns.fo, 'margin'));
    double? margin(String side) =>
        _length(props.attr(_Ns.fo, 'margin-$side')) ?? all;
    double area(String kind, String gapSide) {
      final shown = master.kid(_Ns.style, kind);
      if (shown == null || shown.attr(_Ns.style, 'display') == 'false') {
        return 0;
      }
      final p = layout
          ?.kid(_Ns.style, '$kind-style')
          ?.kid(_Ns.style, 'header-footer-properties');
      if (p == null) return 0;
      final height =
          _length(p.attr(_Ns.fo, 'min-height')) ??
          _length(p.attr(_Ns.svg, 'height')) ??
          0;
      final gap = _length(p.attr(_Ns.fo, 'margin-$gapSide')) ?? 0;
      return height + gap;
    }

    final top = margin('top');
    final bottom = margin('bottom');
    return ImportedPageSetup(
      widthPt: w,
      heightPt: h,
      marginTopPt: top == null ? null : top + area('header', 'bottom'),
      marginRightPt: margin('right'),
      marginBottomPt: bottom == null ? null : bottom + area('footer', 'top'),
      marginLeftPt: margin('left'),
    );
  }

  void _headersFootersDropped() => _warnings.add(
    ImportWarningKind.headersFootersDropped,
    'Headers and footers were not imported.',
  );

  void _headersFooters(XmlElement master) {
    for (final e in master.childElements) {
      if (e.name.namespaceUri != _Ns.style ||
          !(e.name.local.startsWith('header') ||
              e.name.local.startsWith('footer'))) {
        continue;
      }
      if (e.attr(_Ns.style, 'display') == 'false') continue;
      if (e.innerText.trim().isNotEmpty ||
          e.descendantElements.any(
            (x) => x.isA(_text, 'page-number') || x.isA(_text, 'page-count'),
          )) {
        _headersFootersDropped();
        return;
      }
    }
  }

  // -------------------------------------------------------------------------
  // Damaged packages

  void _salvage() {
    final raw = zip.text('content.xml');
    if (raw != null) {
      final para = RegExp(r'<text:(p|h)[\s>/][\s\S]*?</text:\1>');
      for (final m in para.allMatches(raw)) {
        final inner = m
            .group(0)!
            .replaceAll(RegExp(r'<text:s(\s[^>]*)?/>'), ' ')
            .replaceAll(RegExp(r'<text:(tab|line-break)\s*/>'), ' ')
            .replaceAll(RegExp(r'<[^>]*>'), '');
        final clean = ImportText.inline(
          _unescapeXml(inner),
        ).replaceAll(RegExp(' {2,}'), ' ').trim();
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
