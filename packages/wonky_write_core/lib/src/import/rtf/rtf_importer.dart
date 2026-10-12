/// RTF import (07 §3.8).
library;

import 'dart:typed_data';

import '../../delta/embeds.dart';
import '../../delta/links.dart';
import '../../ir/doc_tree.dart';
import '../../markdown/inline_reader.dart' show mentionTitlePrefix;
import '../import_api.dart';
import '../import_limits.dart';
import '../import_support.dart';
import 'rtf_tokenizer.dart';

/// Imports Rich Text Format documents (`.rtf`; Word, WordPad, TextEdit,
/// LibreOffice and pandoc dialects), best effort.
///
/// Mapping (07 §3.8): stylesheet names `heading N` / `Title` / `Subtitle`
/// and `\outlinelevelN` → headings; styles named *quote* → quotes; styles
/// named *code* / *preformatted* and paragraphs whose runs are all in a
/// monospace font → code blocks; `\ls`/`\ilvl` with the list table
/// (`\levelnfc23`/`255` → bullets, other formats → numbers), `\pn`
/// paragraphs and `{\listtext}`/`{\pntext}` markers → lists; leading ☐/☑/☒
/// → tasks; `\b \i \strike \striked1` → bold, italic, strike (style
/// formatting of headings, quotes and table header rows is not repeated as
/// inline formatting); monospace fonts and *code* character styles →
/// inline code; `HYPERLINK` fields → links (other fields keep their result
/// text); `\pict` PNG/JPEG → images (alt text from `wzDescription`, a
/// following *caption* paragraph → title; metafiles and other formats →
/// placeholders); `\trowd … \cell … \row` → tables (the first row is the
/// header, cell alignment from `\qc`/`\qr`/`\ql`, nested tables flattened);
/// empty paragraphs with a bottom border or the *Horizontal Line* style →
/// rules; `\line` → soft break; footnotes → a final "Notes" section;
/// annotations, headers and footers dropped (warnings); underline, colors,
/// highlight, sizes and alignment → one aggregated warning; `\paperw`,
/// `\paperh`, `\margl`… → [ImportResult.pageSetup]; `{\info{\title}}` →
/// title.
///
/// Throws [ImportFormatException] when the bytes do not start with
/// `{\rtf`; damaged content never throws.
final class RtfImporter implements DocumentImporter {
  /// Creates the importer.
  const RtfImporter();

  @override
  ImportFormat get format => ImportFormat.rtf;

  @override
  Future<ImportResult> import(Uint8List bytes, ImportOptions options) async =>
      importSync(bytes, options);

  /// Synchronous variant of [import].
  ImportResult importSync(Uint8List bytes, ImportOptions options) {
    if (!looksLikeRtf(bytes)) {
      throw const ImportFormatException(
        'The file is not a Rich Text Format document (no "{\\rtf" header).',
      );
    }
    final tokenizer = RtfTokenizer(bytes);
    final tokens = tokenizer.tokenize();
    final reader = _RtfReader(options);
    try {
      return reader.read(tokens, tokenizer.unsupportedCodePages);
    } on Object {
      return _RtfReader.salvage(tokens, options);
    }
  }

  /// Whether [bytes] start with `{\rtf` (after an optional UTF-8 byte order
  /// mark and whitespace).
  static bool looksLikeRtf(Uint8List bytes) {
    var i = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      i = 3;
    }
    while (i < bytes.length &&
        (bytes[i] == 0x20 ||
            bytes[i] == 0x09 ||
            bytes[i] == 0x0A ||
            bytes[i] == 0x0D)) {
      i++;
    }
    const sig = [0x7B, 0x5C, 0x72, 0x74, 0x66]; // {\rtf
    if (bytes.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (bytes[i + k] != sig[k]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Reader state

enum _Dest {
  normal,
  skip,
  headerFooter,
  comment,
  fontTable,
  styleSheet,
  styleEntry,
  info,
  title,
  listTable,
  list,
  listLevel,
  levelText,
  overrideTable,
  override,
  pict,
  picProp,
  shapeProp,
  shapePropName,
  shapePropValue,
  fieldInst,
  listText,
  pn,
  note,
  codeLang,
  upr,
}

final class _FontDef {
  final name = StringBuffer();
  late final bool mono = MonospaceFonts.isMonospace(
    name.toString().split(';').first.trim(),
  );
}

enum _StyleKind { paragraph, character, other }

final class _StyleDef {
  _StyleKind kind = _StyleKind.paragraph;
  int id = 0;
  int? basedOn;
  final name = StringBuffer();
  bool bold = false;
  bool italic = false;
  int fontSize = 24;
  int color = 0;
  String? align;
  int? outline;
  int? font;

  late final String lowerName = name
      .toString()
      .split(';')
      .first
      .trim()
      .toLowerCase();
}

final class _LevelDef {
  int nfc = 0;
  int start = 1;
  final text = StringBuffer();

  bool get isBullet => nfc == 23 || nfc == 255;

  /// The marker glyph of a bullet level (the level text without its length
  /// prefix and placeholders).
  String get glyph {
    final t = text.toString().replaceAll(';', '');
    final runes = t.runes.where((r) => r >= 0x20).toList();
    return runes.isEmpty ? '' : String.fromCharCode(runes.first);
  }
}

final class _ListDef {
  int id = 0;
  final levels = <_LevelDef>[];
}

final class _OverrideDef {
  int listId = 0;
  int ls = 0;
}

final class _PictDef {
  String? mime;
  bool unsupported = false;
  final hex = StringBuffer();
  final binary = BytesBuilder(copy: false);
  String alt = '';
}

final class _ShapeProp {
  final name = StringBuffer();
  final value = StringBuffer();
}

final class _Field {
  final instr = StringBuffer();
}

final class _Props {
  _Props();

  _Props.copy(_Props o)
    : style = o.style,
      ls = o.ls,
      ilvl = o.ilvl,
      outline = o.outline,
      inTable = o.inTable,
      itap = o.itap,
      align = o.align,
      borderBottom = o.borderBottom,
      borderTop = o.borderTop,
      fi = o.fi,
      li = o.li,
      pristine = o.pristine;

  int? style;
  int? ls;
  int? ilvl;
  int? outline;
  bool inTable = false;
  int itap = 0;
  String? align;
  bool borderBottom = false;
  bool borderTop = false;
  int fi = 0;
  int li = 0;
  bool pristine = true;
}

final class _State {
  _State();

  _State.child(_State p)
    : dest = p.dest,
      bold = p.bold,
      italic = p.italic,
      strike = p.strike,
      underline = p.underline,
      hidden = p.hidden,
      deleted = p.deleted,
      script = p.script,
      highlight = p.highlight,
      font = p.font,
      fontSize = p.fontSize,
      color = p.color,
      charStyle = p.charStyle,
      link = p.link,
      mention = p.mention,
      field = p.field,
      para = _Props.copy(p.para),
      target = p.target;

  _Dest dest = _Dest.normal;
  bool owner = false;
  bool star = false;
  bool sawText = false;

  bool bold = false;
  bool italic = false;
  bool strike = false;
  bool underline = false;
  bool hidden = false;
  bool deleted = false;
  bool script = false;
  bool highlight = false;
  int font = -1;
  int fontSize = 24;
  int color = 0;
  int charStyle = -1;
  String? link;
  String? mention;
  _Field? field;
  _Props para = _Props();

  /// Destination object (font, style, list, level, pict, …).
  Object? target;

  /// Destination to resume for `\ud` inside `\upr`.
  _Dest? resume;

  void plain(int defaultFont) {
    bold = false;
    italic = false;
    strike = false;
    underline = false;
    hidden = false;
    deleted = false;
    script = false;
    highlight = false;
    font = defaultFont;
    fontSize = 24;
    color = 0;
    charStyle = -1;
  }
}

sealed class _Seg {}

final class _RunSeg extends _Seg {
  _RunSeg(this.run);
  final InlineRun run;
}

final class _BlockSeg extends _Seg {
  _BlockSeg(this.block, this.alt);
  final DocBlock block;
  final String alt;
}

enum _PnKind { bullet, ordered }

/// The paragraph being read.
final class _Acc {
  final segs = <_Seg>[];
  _Props? props;
  StringBuffer? marker;
  _PnKind? pnKind;
  bool pnNumbered = false;
  int? pnLevel;
  String? codeLang;
  bool monoMark = false;

  bool get isEmpty => segs.isEmpty;

  void add(InlineRun r) {
    if (r.text.isEmpty) return;
    final last = segs.isEmpty ? null : segs.last;
    if (last is _RunSeg && last.run.sameFormat(r)) {
      segs[segs.length - 1] = _RunSeg(
        last.run.copyWith(text: last.run.text + r.text),
      );
    } else {
      segs.add(_RunSeg(r));
    }
  }

  List<InlineRun> get runs => [
    for (final s in segs)
      if (s is _RunSeg) s.run,
  ];

  /// Runs with images replaced by their alt text (single-line contexts).
  List<InlineRun> get flatRuns => InlineRun.merge([
    for (final s in segs)
      switch (s) {
        _RunSeg(:final run) => run,
        _BlockSeg(:final alt) => InlineRun(alt.isEmpty ? '' : ' $alt '),
      },
  ]);
}

final class _Cell {
  _Cell(this.runs, this.align, this.style);
  final List<InlineRun> runs;
  final CellAlign? align;
  final _StyleDef? style;
}

final class _Row {
  _Row(this.cells);
  final List<_Cell> cells;
}

// ---------------------------------------------------------------------------

final class _RtfReader {
  _RtfReader(this.options);

  final ImportOptions options;
  final _warnings = WarningCollector();
  final _images = ImageCollector();
  final _notes = NotesCollector();
  final _blocks = <DocBlock>[];

  final _stack = <_State>[];
  _State get _s => _stack.last;

  final _fonts = <int, _FontDef>{};
  final _styles = <_StyleDef>[];
  final _paraStyles = <int, _StyleDef>{};
  final _charStyles = <int, _StyleDef>{};
  final _lists = <int, _ListDef>{};
  final _overrides = <int, int>{};
  var _defaultFont = -1;
  final _title = StringBuffer();
  var _hasTitle = false;

  var _acc = _Acc();

  // Notes.
  _Acc? _outerAcc;
  final _noteParas = <List<InlineRun>>[];

  // Tables.
  final _rows = <_Row>[];
  final _cells = <_Cell>[];
  final _cellParts = <List<InlineRun>>[];
  CellAlign? _cellAlign;
  var _cellAlignSet = false;
  _StyleDef? _cellStyle;
  var _tableFlattened = false;

  // Breaks: reported once content follows.
  var _pendingBreak = false;

  // Lists.
  final _startWarned = <String>{};

  // Page setup.
  int? _paperW, _paperH, _margL, _margR, _margT, _margB;
  var _landscape = false;

  // Code.
  String _codeLang = '';

  ImportResult read(List<RtfToken> tokens, Set<int> unsupportedCodePages) {
    final root = _State()..dest = _Dest.normal;
    _stack.add(root);
    for (final t in tokens) {
      switch (t) {
        case RtfGroupStart():
          _groupStart();
        case RtfGroupEnd():
          if (_stack.length > 1) _groupEnd();
        case RtfControl():
          _control(t);
        case RtfText(:final text):
          _text(text);
        case RtfBinary(:final bytes):
          if (_s.dest == _Dest.pict) {
            (_s.target as _PictDef?)?.binary.add(bytes);
          }
      }
    }
    while (_stack.length > 1) {
      _groupEnd();
    }
    if (_outerAcc != null) _closeNote();
    if (!_acc.isEmpty) _endParagraph();
    _flushTable();
    _mergeCodeGaps();
    while (_blocks.isNotEmpty &&
        _blocks.last is ParagraphBlock &&
        (_blocks.last as ParagraphBlock).runs.isEmpty) {
      _blocks.removeLast();
    }
    if (!_notes.isEmpty) {
      _warnings.add(
        ImportWarningKind.footnotesAppended,
        'Footnotes and endnotes were moved to a "Notes" section at the end.',
      );
      _blocks.addAll(_notes.blocks());
    }
    if (unsupportedCodePages.isNotEmpty) {
      _warnings.add(
        ImportWarningKind.encodingGuessed,
        'The document uses a code page that is not supported '
        '(${(unsupportedCodePages.toList()..sort()).join(', ')}); some '
        'characters may be wrong.',
      );
    }
    if (_blocks.isEmpty) _blocks.add(const ParagraphBlock([]));
    final title = ImportText.inline(_title.toString()).trim();
    return buildImportResult(
      _blocks,
      options: options,
      warnings: _warnings,
      images: _images,
      title: _hasTitle && title.isNotEmpty ? title : null,
      pageSetup: _pageSetup(),
    );
  }

  /// Text-only fallback for documents the reader cannot process.
  static ImportResult salvage(List<RtfToken> tokens, ImportOptions options) {
    final warnings = WarningCollector()
      ..add(
        ImportWarningKind.contentDropped,
        'The document is damaged; only its text could be imported.',
      );
    final blocks = <DocBlock>[];
    final line = StringBuffer();
    var depth = 0;
    int? skipBelow;
    var pendingStar = false;
    void flush() {
      final t = ImportText.inline(line.toString()).trim();
      if (t.isNotEmpty) blocks.add(ParagraphBlock([InlineRun(t)]));
      line.clear();
    }

    for (final t in tokens) {
      switch (t) {
        case RtfGroupStart():
          depth++;
        case RtfGroupEnd():
          if (skipBelow != null && depth <= skipBelow) skipBelow = null;
          depth--;
        case RtfControl(:final word, :final symbol):
          if (symbol && word == '*') {
            pendingStar = true;
            continue;
          }
          if (pendingStar ||
              const {
                'fonttbl',
                'colortbl',
                'stylesheet',
                'info',
                'pict',
                'fldinst',
                'listtable',
                'listoverridetable',
              }.contains(word)) {
            skipBelow ??= depth;
          }
          pendingStar = false;
          if (skipBelow == null && (word == 'par' || word == 'row')) flush();
        case RtfText(:final text):
          pendingStar = false;
          if (skipBelow == null) line.write(text);
        case RtfBinary():
          break;
      }
    }
    flush();
    if (blocks.isEmpty) blocks.add(const ParagraphBlock([]));
    return buildImportResult(blocks, options: options, warnings: warnings);
  }

  // -------------------------------------------------------------------------
  // Groups

  void _groupStart() {
    final parent = _s;
    final child = _State.child(parent);
    if (parent.dest == _Dest.styleSheet) {
      final def = _StyleDef();
      _styles.add(def);
      child
        ..dest = _Dest.styleEntry
        ..owner = true
        ..target = def;
    } else if (parent.dest == _Dest.upr) {
      child
        ..dest = _Dest.skip
        ..resume = parent.resume;
    }
    _stack.add(child);
  }

  void _groupEnd() {
    if (_stack.length == 2 &&
        _s.dest == _Dest.normal &&
        _outerAcc == null &&
        !_acc.isEmpty) {
      // The last paragraph of the document has no \par.
      _endParagraph();
    }
    final s = _stack.removeLast();
    if (s.owner) _closeDest(s);
  }

  void _enter(_Dest dest, {Object? target}) {
    final s = _s;
    s
      ..dest = dest
      ..owner = true;
    if (target != null) s.target = target;
  }

  void _closeDest(_State s) {
    switch (s.dest) {
      case _Dest.styleEntry:
        final def = s.target as _StyleDef;
        def
          ..bold = s.bold
          ..italic = s.italic
          ..fontSize = s.fontSize
          ..color = s.color
          ..align = s.para.align
          ..outline = s.para.outline
          ..font = s.font < 0 ? null : s.font;
        switch (def.kind) {
          case _StyleKind.paragraph:
            _paraStyles[def.id] = def;
          case _StyleKind.character:
            _charStyles[def.id] = def;
          case _StyleKind.other:
            break;
        }
      case _Dest.override:
        final o = s.target as _OverrideDef;
        _overrides[o.ls] = o.listId;
      case _Dest.list:
        final l = s.target as _ListDef;
        _lists[l.id] = l;
      case _Dest.pict:
        _closePict(s.target as _PictDef);
      case _Dest.shapeProp:
        final sp = s.target as _ShapeProp;
        final pict = _pictOf();
        if (pict != null &&
            sp.name.toString().trim().toLowerCase() == 'wzdescription') {
          pict.alt = ImportText.inline(sp.value.toString()).trim();
        }
      case _Dest.note:
        if (_outerAcc != null && _s.dest != _Dest.note) _closeNote();
      case _Dest.headerFooter:
        if (s.sawText) {
          _warnings.add(
            ImportWarningKind.headersFootersDropped,
            'Headers and footers were not imported.',
          );
        }
      default:
        break;
    }
  }

  _PictDef? _pictOf() {
    for (var i = _stack.length - 1; i >= 0; i--) {
      final t = _stack[i].target;
      if (t is _PictDef) return t;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Control words

  static const _skipDestinations = {
    'colortbl',
    'filetbl',
    'revtbl',
    'rsidtbl',
    'ftnsep',
    'ftnsepc',
    'ftncn',
    'aftnsep',
    'aftnsepc',
    'aftncn',
    'xe',
    'tc',
    'tcn',
    'txe',
    'rxe',
    'bkmkstart',
    'bkmkend',
    'template',
    'userprops',
    'docvar',
    'private',
    'colorschememapping',
    'themedata',
    'latentstyles',
    'datastore',
    'xmlnstbl',
    'pgdsctbl',
    'generator',
    'mmathPr',
    'fchars',
    'lchars',
    'pgptbl',
    'protusertbl',
    'wgrffmtfilter',
    'do',
    'background',
    'nesttableprops',
    'nonesttables',
    'falt',
    'panose',
    'fname',
    'listpicture',
    'nonshppict',
    'shpinst',
    'shptxt',
    'objdata',
    'objclass',
    'objname',
    'objalias',
    'objsect',
    'objtime',
    'datafield',
    'formfield',
    'blipuid',
    'pntxta',
    'pntxtb',
    'listname',
    'levelnumbers',
    'lfolevel',
    'keycode',
    'author',
    'operator',
    'keywords',
    'subject',
    'doccomm',
    'comment',
    'company',
    'manager',
    'category',
    'hlinkbase',
    'creatim',
    'revtim',
    'printim',
    'buptim',
    'expandedcolortbl',
    'passwordhash',
    'mmath',
    'oldcprops',
    'oldpprops',
    'oldsprops',
    'oldtprops',
  };

  static const _headerFooter = {
    'header',
    'headerl',
    'headerr',
    'headerf',
    'footer',
    'footerl',
    'footerr',
    'footerf',
  };

  static const _comments = {
    'annotation',
    'atnid',
    'atnauthor',
    'atndate',
    'atnref',
    'atrfstart',
    'atrfend',
    'atnparent',
    'atnicn',
    'atntime',
  };

  /// Starred destinations this reader understands.
  static const _knownStarred = {
    'fldinst',
    'shppict',
    'picprop',
    'pn',
    'listtable',
    'listoverridetable',
    'wonkycodelang',
    'ud',
    'footnote',
    'shprslt',
  };

  void _control(RtfControl c) {
    final s = _s;
    final word = c.word;
    if (c.symbol) {
      if (word == '*') s.star = true;
      return;
    }
    if (s.dest == _Dest.skip) {
      if (word == 'ud' && s.resume != null) _enter(s.resume!);
      return;
    }
    if (s.dest == _Dest.headerFooter || s.dest == _Dest.comment) return;
    if (s.star) {
      s.star = false;
      final keep =
          _knownStarred.contains(word) ||
          (s.dest == _Dest.styleEntry && (word == 'cs' || word == 'ts')) ||
          _comments.contains(word);
      if (!keep) {
        _enter(_Dest.skip);
        return;
      }
    }
    if (_destination(c)) return;
    switch (s.dest) {
      case _Dest.fontTable:
        if (word == 'f' && c.param != null) {
          final def = _FontDef();
          _fonts[c.param!] = def;
          s.target = def;
        }
      case _Dest.list:
        if (word == 'listid' && c.param != null) {
          (s.target as _ListDef).id = c.param!;
        }
      case _Dest.listLevel:
        final lvl = s.target as _LevelDef;
        if ((word == 'levelnfc' || word == 'levelnfcn') && c.param != null) {
          lvl.nfc = c.param!;
        } else if (word == 'levelstartat' && c.param != null) {
          lvl.start = c.param!;
        }
      case _Dest.override:
        final o = s.target as _OverrideDef;
        if (word == 'listid' && c.param != null) o.listId = c.param!;
        if (word == 'ls' && c.param != null) o.ls = c.param!;
      case _Dest.pict:
        _pictControl(s.target as _PictDef, word);
      case _Dest.pn:
        _pnControl(word, c.param);
      case _Dest.styleEntry:
        final def = s.target as _StyleDef;
        switch (word) {
          case 's':
            def
              ..kind = _StyleKind.paragraph
              ..id = c.param ?? 0;
          case 'cs':
            def
              ..kind = _StyleKind.character
              ..id = c.param ?? 0;
          case 'ts' || 'ds':
            def
              ..kind = _StyleKind.other
              ..id = c.param ?? 0;
          case 'sbasedon':
            def.basedOn = c.param;
          default:
            _formatting(c);
        }
      case _Dest.normal || _Dest.note:
        if (!_formatting(c)) _content(c);
      default:
        break;
    }
  }

  /// Handles destination control words; returns whether [c] was one.
  bool _destination(RtfControl c) {
    final s = _s;
    final word = c.word;
    final d = s.dest;
    if (_skipDestinations.contains(word)) {
      _enter(_Dest.skip);
      return true;
    }
    if (_headerFooter.contains(word)) {
      _enter(_Dest.headerFooter);
      return true;
    }
    if (_comments.contains(word)) {
      _warnings.add(
        ImportWarningKind.commentsDropped,
        'Comments in the document were not imported.',
      );
      _enter(_Dest.comment);
      return true;
    }
    switch (word) {
      case 'fonttbl':
        _enter(_Dest.fontTable);
      case 'stylesheet':
        _enter(_Dest.styleSheet);
      case 'info':
        _enter(_Dest.info);
      case 'title' when d == _Dest.info:
        _hasTitle = true;
        _title.clear();
        _enter(_Dest.title);
      case 'listtable':
        _enter(_Dest.listTable);
      case 'list' when d == _Dest.listTable:
        _enter(_Dest.list, target: _ListDef());
      case 'listlevel' when d == _Dest.list:
        final lvl = _LevelDef();
        (s.target as _ListDef).levels.add(lvl);
        _enter(_Dest.listLevel, target: lvl);
      case 'leveltext' when d == _Dest.listLevel:
        _enter(_Dest.levelText);
      case 'listoverridetable':
        _enter(_Dest.overrideTable);
      case 'listoverride' when d == _Dest.overrideTable:
        _enter(_Dest.override, target: _OverrideDef());
      case 'pict':
        if (d == _Dest.normal || d == _Dest.note) {
          _enter(_Dest.pict, target: _PictDef());
        } else {
          _enter(_Dest.skip);
        }
      case 'picprop' when d == _Dest.pict:
        _enter(_Dest.picProp);
      case 'sp' when d == _Dest.picProp:
        _enter(_Dest.shapeProp, target: _ShapeProp());
      case 'sn' when d == _Dest.shapeProp:
        _enter(_Dest.shapePropName);
      case 'sv' when d == _Dest.shapeProp:
        _enter(_Dest.shapePropValue);
      case 'shppict' || 'shprslt' || 'result':
        break;
      case 'shp':
        _warnings.add(
          ImportWarningKind.placeholderInserted,
          'Shapes and text boxes were not imported.',
          blockIndex: _blocks.length,
        );
      case 'field' when d == _Dest.normal || d == _Dest.note:
        s.field = _Field();
        s.owner = true;
      case 'fldinst':
        _enter(_Dest.fieldInst);
      case 'fldrslt':
        _fieldResult();
      case 'listtext' || 'pntext':
        _acc.marker ??= StringBuffer();
        _enter(_Dest.listText);
      case 'pn':
        _enter(_Dest.pn);
      case 'footnote':
        if (d == _Dest.normal && _outerAcc == null) {
          _outerAcc = _acc;
          _acc = _Acc();
          _noteParas.clear();
          _enter(_Dest.note);
        } else {
          _enter(_Dest.skip);
        }
      case 'wonkycodelang':
        _enter(_Dest.codeLang);
        _acc.codeLang = '';
      case 'upr':
        s.resume = d;
        _enter(_Dest.upr);
      case 'ud' when d == _Dest.upr:
        _enter(s.resume ?? _Dest.normal);
      default:
        return false;
    }
    return true;
  }

  void _pictControl(_PictDef p, String word) {
    switch (word) {
      case 'pngblip':
        p.mime = 'image/png';
      case 'jpegblip':
        p.mime = 'image/jpeg';
      case 'emfblip' ||
          'wmetafile' ||
          'macpict' ||
          'pmmetafile' ||
          'dibitmap' ||
          'wbitmap':
        p.unsupported = true;
    }
  }

  void _pnControl(String word, int? param) {
    switch (word) {
      case 'pnlvlblt':
        _acc
          ..pnKind = _PnKind.bullet
          ..pnLevel = 0;
      case 'pnlvlbody':
        _acc
          ..pnKind = _PnKind.ordered
          ..pnLevel = 0;
      case 'pnlvl':
        _acc
          ..pnLevel = ((param ?? 1) - 1).clamp(0, 8)
          ..pnKind = _acc.pnNumbered ? _PnKind.ordered : _PnKind.bullet;
      case 'pndec' ||
          'pnucrm' ||
          'pnlcrm' ||
          'pnucltr' ||
          'pnlcltr' ||
          'pnord' ||
          'pncard':
        _acc.pnNumbered = true;
        if (_acc.pnLevel != null && _acc.pnKind == _PnKind.bullet) {
          _acc.pnKind = _PnKind.ordered;
        }
    }
  }

  /// Character and paragraph formatting; returns whether [c] was one.
  bool _formatting(RtfControl c) {
    final s = _s;
    final p = c.param;
    switch (c.word) {
      case 'plain':
        s.plain(_defaultFont);
      case 'b':
        s.bold = c.isOn;
      case 'i':
        s.italic = c.isOn;
      case 'strike':
        s.strike = c.isOn;
      case 'striked':
        s.strike = c.isOn;
      case 'ul' ||
          'uld' ||
          'uldash' ||
          'uldashd' ||
          'uldashdd' ||
          'uldb' ||
          'ulhwave' ||
          'ulldash' ||
          'ulth' ||
          'ulthd' ||
          'ulthdash' ||
          'ulthdashd' ||
          'ulthdashdd' ||
          'ulthldash' ||
          'ululdbwave' ||
          'ulw' ||
          'ulwave':
        s.underline = c.isOn;
      case 'ulnone':
        s.underline = false;
      case 'v':
        s.hidden = c.isOn;
      case 'deleted':
        s.deleted = c.isOn;
        if (c.isOn) _trackedChanges();
      case 'revised':
        if (c.isOn) _trackedChanges();
      case 'super' || 'sub':
        s.script = true;
      case 'nosupersub':
        s.script = false;
      case 'up' || 'dn':
        s.script = p != 0;
      case 'highlight':
        s.highlight = p != null && p != 0;
      case 'f' when p != null:
        s.font = p;
      case 'fs' when p != null:
        s.fontSize = p;
      case 'cf' when p != null:
        s.color = p;
      case 'cs' when p != null:
        s.charStyle = p;
      case 'pard':
        s.para = _Props();
      case 's' when p != null:
        s.para
          ..style = p
          ..pristine = false;
      case 'ls' when p != null:
        s.para
          ..ls = p
          ..pristine = false;
      case 'ilvl' when p != null:
        s.para
          ..ilvl = p
          ..pristine = false;
      case 'outlinelevel' when p != null:
        s.para
          ..outline = p
          ..pristine = false;
      case 'intbl':
        s.para
          ..inTable = true
          ..pristine = false;
      case 'itap' when p != null:
        s.para
          ..itap = p
          ..inTable = p > 0
          ..pristine = false;
      case 'ql':
        s.para
          ..align = 'left'
          ..pristine = false;
      case 'qc':
        s.para
          ..align = 'center'
          ..pristine = false;
      case 'qr':
        s.para
          ..align = 'right'
          ..pristine = false;
      case 'qj' || 'qd':
        s.para
          ..align = 'justify'
          ..pristine = false;
      case 'brdrb':
        s.para
          ..borderBottom = true
          ..pristine = false;
      case 'brdrt':
        s.para
          ..borderTop = true
          ..pristine = false;
      case 'fi' when p != null:
        s.para.fi = p;
      case 'li' when p != null:
        s.para.li = p;
      default:
        return false;
    }
    return true;
  }

  void _content(RtfControl c) {
    final p = c.param;
    switch (c.word) {
      case 'par':
        _endParagraph();
      case 'sect':
        _endParagraph();
        _pendingBreak = true;
      case 'page' || 'column' || 'pagebb':
        _pendingBreak = true;
      case 'line' || 'lbr' || 'softline':
        _text(importSoftBreak);
      case 'tab':
        _text('\t');
      case 'cell':
        _endCell();
      case 'nestcell':
        _nestCell();
      case 'row':
        _endRow();
      case 'deff' when p != null:
        _defaultFont = p;
      case 'emdash':
        _text('—');
      case 'endash':
        _text('–');
      case 'emspace' || 'enspace' || 'qmspace':
        _text(' ');
      case 'bullet':
        _text('•');
      case 'lquote':
        _text('‘');
      case 'rquote':
        _text('’');
      case 'ldblquote':
        _text('“');
      case 'rdblquote':
        _text('”');
      case 'paperw':
        _paperW = p;
      case 'paperh':
        _paperH = p;
      case 'pgwsxn':
        _paperW = p ?? _paperW;
      case 'pghsxn':
        _paperH = p ?? _paperH;
      case 'margl' || 'marglsxn':
        _margL = p ?? _margL;
      case 'margr' || 'margrsxn':
        _margR = p ?? _margR;
      case 'margt' || 'margtsxn':
        _margT = p ?? _margT;
      case 'margb' || 'margbsxn':
        _margB = p ?? _margB;
      case 'landscape' || 'lndscpsxn':
        _landscape = true;
    }
  }

  void _trackedChanges() => _warnings.add(
    ImportWarningKind.trackedChangesAccepted,
    'Tracked changes were accepted.',
    blockIndex: _blocks.length,
  );

  // -------------------------------------------------------------------------
  // Text

  void _text(String t) {
    final s = _s..star = false;
    switch (s.dest) {
      case _Dest.normal || _Dest.note:
        if (s.hidden || s.deleted) return;
        _contentText(t);
      case _Dest.fontTable:
        (s.target as _FontDef?)?.name.write(t);
      case _Dest.styleEntry:
        (s.target as _StyleDef).name.write(t);
      case _Dest.title:
        _title.write(t);
      case _Dest.levelText:
        _levelOf()?.text.write(t);
      case _Dest.pict:
        (s.target as _PictDef).hex.write(t);
      case _Dest.shapePropName:
        (_shapePropOf())?.name.write(t);
      case _Dest.shapePropValue:
        (_shapePropOf())?.value.write(t);
      case _Dest.fieldInst:
        s.field?.instr.write(t);
      case _Dest.listText:
        _acc.marker?.write(t);
      case _Dest.codeLang:
        _acc.codeLang = (_acc.codeLang ?? '') + t;
      case _Dest.headerFooter:
        if (t.trim().isNotEmpty) {
          for (final st in _stack) {
            if (st.dest == _Dest.headerFooter && st.owner) st.sawText = true;
          }
        }
      default:
        break;
    }
  }

  _LevelDef? _levelOf() {
    for (var i = _stack.length - 1; i >= 0; i--) {
      final t = _stack[i].target;
      if (t is _LevelDef) return t;
    }
    return null;
  }

  _ShapeProp? _shapePropOf() {
    for (var i = _stack.length - 1; i >= 0; i--) {
      final t = _stack[i].target;
      if (t is _ShapeProp) return t;
    }
    return null;
  }

  bool _isMonoFont(int font) =>
      _fonts[font < 0 ? _defaultFont : font]?.mono ?? false;

  /// Whether [font] marks code in a paragraph with [props]: a monospace
  /// font that is not the paragraph style's own font (documents whose body
  /// font is monospace).
  bool _isCodeFont(int font, _Props props) {
    if (!_isMonoFont(font)) return false;
    final style = _resolvedStyle(props.style ?? 0);
    final styleFont = _inherit(style, (d) => d.font);
    final f = font < 0 ? _defaultFont : font;
    return styleFont == null || styleFont != f;
  }

  bool _isCodeStyle(int cs) {
    final name = _charStyles[cs]?.lowerName ?? '';
    return name.contains('code') || name.contains('verbatim');
  }

  /// A table ends where content outside of it starts.
  void _beforeContent(_State s) {
    if (s.dest == _Dest.normal &&
        !s.para.inTable &&
        (_rows.isNotEmpty || _cells.isNotEmpty || _cellParts.isNotEmpty)) {
      _flushTable();
    }
  }

  void _contentText(String t) {
    final s = _s;
    _beforeContent(s);
    if (_acc.isEmpty && _acc.props == null) {
      _acc.props = _Props.copy(s.para);
    }
    final code = _isCodeFont(s.font, s.para) || _isCodeStyle(s.charStyle);
    if (s.dest == _Dest.normal && s.link == null && t.trim().isNotEmpty) {
      _formattingWarnings(s, code);
    }
    _acc.add(
      InlineRun(
        t,
        bold: s.bold,
        italic: s.italic,
        strike: s.strike,
        code: code,
        link: s.link,
        mentionUserUuid: s.link == null ? null : s.mention,
      ),
    );
  }

  void _formattingWarnings(_State s, bool code) {
    void removed(String what) =>
        _warnings.formattingRemoved(what, blockIndex: _blocks.length);
    if (s.underline) removed('underline');
    if (s.script) removed('superscript and subscript');
    if (s.highlight) removed('highlight');
    if (code) return;
    final style = _resolvedStyle(s.para.style ?? 0);
    final heading = _headingLevel(s.para, style) != null;
    if (s.color != 0 && s.color != (style?.color ?? 0)) removed('colors');
    if (!heading && s.fontSize != (style?.fontSize ?? 24)) {
      removed('font sizes');
    }
  }

  // -------------------------------------------------------------------------
  // Fields

  void _fieldResult() {
    final s = _s;
    final field = s.field;
    if (field == null) return;
    final (url, tooltip) = _hyperlink(field.instr.toString());
    if (url == null) return;
    final link = _normalizedLink(url);
    if (link == null) return;
    s.link = link;
    s.mention =
        tooltip != null &&
            tooltip.startsWith(mentionTitlePrefix) &&
            tooltip.length > mentionTitlePrefix.length &&
            LinkPolicy.isMailto(link)
        ? tooltip.substring(mentionTitlePrefix.length)
        : null;
  }

  /// The target and tooltip of a `HYPERLINK` field instruction.
  static (String?, String?) _hyperlink(String instr) {
    final tokens = <String>[];
    final re = RegExp(r'"([^"]*)"|(\S+)');
    for (final m in re.allMatches(instr)) {
      tokens.add(m.group(1) ?? m.group(2)!);
    }
    if (tokens.isEmpty || tokens.first.toUpperCase() != 'HYPERLINK') {
      return (null, null);
    }
    String? url;
    String? anchor;
    String? tooltip;
    for (var i = 1; i < tokens.length; i++) {
      final t = tokens[i];
      if (t == r'\l') {
        anchor = i + 1 < tokens.length ? tokens[++i] : null;
      } else if (t == r'\o') {
        tooltip = i + 1 < tokens.length ? tokens[++i] : null;
      } else if (t == r'\t' || t == r'\m') {
        i++;
      } else if (t.startsWith(r'\')) {
        continue;
      } else {
        url ??= t;
      }
    }
    if (url == null) return (null, tooltip);
    return (anchor == null ? url : '$url#$anchor', tooltip);
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

  // -------------------------------------------------------------------------
  // Pictures

  void _closePict(_PictDef p) {
    final s = _s; // the parent of the pict group
    if (s.dest != _Dest.normal && s.dest != _Dest.note) return;
    _beforeContent(s);
    if (_acc.isEmpty && _acc.props == null) _acc.props = _Props.copy(s.para);
    final alt = p.alt;
    if (s.dest == _Dest.note || s.para.inTable) {
      _warnings.add(
        ImportWarningKind.imageFlattened,
        'Images inside tables and notes were replaced by their description.',
        blockIndex: _blocks.length,
      );
      _acc.segs.add(_BlockSeg(const ParagraphBlock([]), alt));
      return;
    }
    Uint8List? bytes;
    if (!p.unsupported && p.mime != null) {
      bytes = p.binary.length > 0 ? p.binary.takeBytes() : _hexBytes(p.hex);
    }
    final sniffed = bytes == null ? null : ImageMime.sniff(bytes);
    final emb = (bytes == null || sniffed == null)
        ? null
        : embeddableImage(bytes, sniffed);
    if (emb == null) {
      _warnings.add(
        ImportWarningKind.unresolvedImage,
        p.unsupported
            ? 'Metafile and bitmap pictures are not supported; they were '
                  'replaced by placeholders.'
            : 'Some images could not be imported; they were replaced by '
                  'placeholders.',
        blockIndex: _blocks.length,
      );
      _acc.segs.add(_BlockSeg(imagePlaceholder(alt), alt));
      return;
    }
    final image = _images.add(emb.$1, emb.$2, alt: alt);
    _acc.segs.add(
      _BlockSeg(ImageBlock(options.idGenerator(), image.src, alt), alt),
    );
  }

  static Uint8List _hexBytes(StringBuffer hex) {
    final s = hex.toString();
    final out = Uint8List(s.length ~/ 2);
    var n = 0;
    var hi = -1;
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      final v = c >= 0x30 && c <= 0x39
          ? c - 0x30
          : c >= 0x61 && c <= 0x66
          ? c - 0x57
          : c >= 0x41 && c <= 0x46
          ? c - 0x37
          : -1;
      if (v < 0) continue;
      if (hi < 0) {
        hi = v;
      } else {
        out[n++] = hi * 16 + v;
        hi = -1;
      }
    }
    return Uint8List.sublistView(out, 0, n);
  }

  // -------------------------------------------------------------------------
  // Notes

  void _closeNote() {
    if (!_acc.isEmpty) _noteParas.add(_acc.flatRuns);
    final paragraphs = [
      for (final p in _noteParas) _clean(RunTools.trim(p)),
    ].where((p) => !RunTools.isBlank(p));
    final n = _notes.add(RunTools.join(paragraphs, importSoftBreak));
    _acc = _outerAcc!;
    _outerAcc = null;
    _noteParas.clear();
    _acc.add(InlineRun('[$n]', link: _s.link));
  }

  // -------------------------------------------------------------------------
  // Paragraphs

  _StyleDef? _resolvedStyle(int id) => _paraStyles[id];

  /// Inherited style attribute through `\sbasedon`.
  T? _inherit<T>(_StyleDef? def, T? Function(_StyleDef) get) {
    var d = def;
    final seen = <int>{};
    while (d != null && seen.add(d.id)) {
      final v = get(d);
      if (v != null) return v;
      d = d.basedOn == null ? null : _paraStyles[d.basedOn!];
    }
    return null;
  }

  static final _headingName = RegExp(r'^heading\s*([1-9])$');

  int? _headingLevel(_Props props, _StyleDef? style) {
    final name = style?.lowerName ?? '';
    final m = _headingName.firstMatch(name);
    if (m != null) return int.parse(m.group(1)!).clamp(1, 6);
    if (name == 'title') return 1;
    if (name == 'subtitle') return 2;
    final outline = props.outline ?? _inherit(style, (d) => d.outline);
    if (outline != null && outline >= 0 && outline <= 8) {
      return (outline + 1).clamp(1, 6);
    }
    return null;
  }

  static bool _isCodeName(String name) =>
      name.startsWith('code') ||
      name.contains('preformatted') ||
      name.startsWith('source code') ||
      name == 'macro text';

  void _endParagraph() {
    final s = _s;
    final acc = _acc;
    _acc = _Acc();
    acc.monoMark = _isCodeFont(s.font, s.para);
    final props = s.para.pristine && acc.props != null ? acc.props! : s.para;
    if (s.dest == _Dest.note) {
      _noteParas.add(acc.flatRuns);
      return;
    }
    if (props.inTable) {
      _cellParagraph(acc, props);
      return;
    }
    _flushTable();
    _emitParagraph(acc, props);
  }

  void _addBlock(DocBlock b) {
    if (_pendingBreak && _blocks.isNotEmpty) {
      _warnings.add(
        ImportWarningKind.breaksDropped,
        'Page breaks, section breaks and columns were removed.',
        blockIndex: _blocks.length,
      );
    }
    _pendingBreak = false;
    if (b is! CodeBlock) _codeLang = '';
    _blocks.add(b);
  }

  void _emitParagraph(_Acc acc, _Props props) {
    final style = _resolvedStyle(props.style ?? 0);
    final name = style?.lowerName ?? '';
    final groups = <List<InlineRun>>[[]];
    final images = <DocBlock?>[null];
    for (final seg in acc.segs) {
      switch (seg) {
        case _RunSeg(:final run):
          groups.last.add(run);
        case _BlockSeg(:final block):
          images.add(block);
          groups.add([]);
      }
    }
    final hasImages = images.length > 1;
    final onlyImages = hasImages && groups.every(RunTools.isBlank);
    if (!hasImages &&
        (name == 'horizontal line' || RunTools.isBlank(groups.first))) {
      if (name == 'horizontal line' ||
          ((props.borderBottom || props.borderTop) &&
              name != 'caption' &&
              _headingLevel(props, style) == null)) {
        _addBlock(RuleBlock(options.idGenerator()));
        return;
      }
    }
    for (var i = 0; i < groups.length; i++) {
      final image = images[i];
      if (image != null) _addBlock(image);
      if (onlyImages) continue;
      final runs = InlineRun.merge(groups[i]);
      if (i > 0 && RunTools.isBlank(runs)) continue;
      _emitRuns(acc, props, style, runs, first: i == 0);
    }
  }

  void _emitRuns(
    _Acc acc,
    _Props props,
    _StyleDef? style,
    List<InlineRun> raw, {
    required bool first,
  }) {
    final name = style?.lowerName ?? '';
    final heading = _headingLevel(props, style);
    if (heading != null) {
      final runs = _clean(_stripStyle(raw, style, allRuns: style == null));
      _addBlock(
        runs.isEmpty ? const ParagraphBlock([]) : HeadingBlock(heading, runs),
      );
      return;
    }
    if (name == 'caption' && first) {
      final last = _blocks.isEmpty ? null : _blocks.last;
      final text = ImportText.inline(InlineRun.plainText(raw)).trim();
      if (last is ImageBlock && last.title == null && text.isNotEmpty) {
        _blocks[_blocks.length - 1] = ImageBlock(
          last.id,
          last.src,
          last.alt,
          title: text,
        );
        return;
      }
    }
    if (name.contains('quote') || name == 'block text') {
      _addBlock(QuoteBlock([_clean(_stripStyle(raw, style))]));
      return;
    }
    final allCode =
        raw.any((r) => r.code && r.text.trim().isNotEmpty) &&
        raw.every((r) => r.code || r.text.trim().isEmpty);
    final listLike =
        props.ls != null && props.ls != 0 ||
        acc.pnKind != null ||
        acc.marker != null;
    if (_isCodeName(name) ||
        (allCode && !listLike) ||
        (raw.isEmpty && acc.monoMark && !listLike && first)) {
      _addBlock(_codeBlock(raw, acc.codeLang));
      return;
    }
    var runs = raw;
    bool? checked;
    if (first) {
      final task = _taskGlyph(runs);
      if (task != null) {
        checked = task.$1;
        runs = task.$2;
      }
    }
    if (first && listLike) {
      final (ordered, glyphTask, level) = _listInfo(acc, props);
      checked ??= glyphTask;
      final indent = level.clamp(0, 8);
      final cleaned = _clean(runs);
      if (checked != null) {
        _addBlock(_task(checked, indent, cleaned));
      } else {
        _addBlock(
          ListItemBlock(
            ordered ? ListKindIr.ordered : ListKindIr.bullet,
            indent,
            cleaned,
          ),
        );
      }
      return;
    }
    if (first && props.fi < 0) {
      final manual = _manualList(runs, props);
      if (manual != null) {
        _addBlock(manual);
        return;
      }
    }
    final cleaned = _clean(runs);
    if (checked != null) {
      _addBlock(_task(checked, 0, cleaned));
      return;
    }
    if (cleaned.isNotEmpty &&
        props.align != null &&
        props.align != 'left' &&
        props.align != _inherit(style, (d) => d.align)) {
      _warnings.formattingRemoved('alignment', blockIndex: _blocks.length);
    }
    _addBlock(ParagraphBlock(cleaned));
  }

  /// Ordered?, task state from a checkbox bullet glyph, and level.
  (bool, bool?, int) _listInfo(_Acc acc, _Props props) {
    final level = props.ilvl ?? acc.pnLevel ?? 0;
    final ls = props.ls;
    if (ls != null && ls != 0) {
      final list = _lists[_overrides[ls] ?? -1];
      if (list != null && list.levels.isNotEmpty) {
        final lvl = list.levels[level.clamp(0, list.levels.length - 1)];
        if (!lvl.isBullet && lvl.start != 1 && _startWarned.add('$ls:$level')) {
          _warnings.add(
            ImportWarningKind.orderedListStart,
            'Numbered lists that did not start at 1 now start at 1.',
            blockIndex: _blocks.length,
          );
        }
        bool? task;
        if (lvl.isBullet) {
          final g = lvl.glyph;
          if (TaskGlyphs.unchecked.contains(g) || g == '\uF0A8') task = false;
          if (TaskGlyphs.checked.contains(g) || g == '\uF0FE') task = true;
        }
        return (!lvl.isBullet, task, level);
      }
    }
    if (acc.pnKind != null) {
      return (acc.pnKind == _PnKind.ordered, null, level);
    }
    final marker = acc.marker?.toString() ?? '';
    return (_isNumberMarker(marker), null, level);
  }

  static final _numberMarker = RegExp(
    r'^\(?(\d{1,4}|[A-Za-z]{1,6})[.)]$|^\d{1,4}$',
  );

  static bool _isNumberMarker(String marker) {
    final m = marker.replaceAll(RegExp(r'[\s\u00A0]'), '');
    return _numberMarker.hasMatch(m);
  }

  /// A paragraph like `•<tab>text` or `1.<tab>text` with a hanging indent
  /// (pandoc, plain writers) as a list item.
  DocBlock? _manualList(List<InlineRun> runs, _Props props) {
    final merged = InlineRun.merge(runs);
    final text = InlineRun.plainText(merged);
    final tab = text.indexOf('\t');
    if (tab <= 0 || tab > 8) return null;
    final marker = text.substring(0, tab).trim();
    final bullet = const {
      '•',
      '·',
      '◦',
      '▪',
      '‣',
      '-',
      '–',
      '*',
      'o',
      '§',
    }.contains(marker);
    final ordered = !bullet && _isNumberMarker(marker);
    if (!bullet && !ordered) return null;
    final indent = ((props.li / 360).round() - 1).clamp(0, 8);
    final rest = _clean(RunTools.trim(TaskGlyphs.dropPrefix(merged, tab + 1)));
    final task = _taskGlyph(rest);
    if (task != null) return _task(task.$1, indent, _clean(task.$2));
    return ListItemBlock(
      ordered ? ListKindIr.ordered : ListKindIr.bullet,
      indent,
      rest,
    );
  }

  /// A task item; the strikethrough of a fully struck checked item is the
  /// checked-item presentation, not formatting.
  static TaskBlock _task(bool checked, int indent, List<InlineRun> runs) {
    final visible = runs.where((r) => r.text.trim().isNotEmpty);
    if (checked && visible.isNotEmpty && visible.every((r) => r.strike)) {
      return TaskBlock(checked, indent, [
        for (final r in runs) r.copyWith(strike: false),
      ]);
    }
    return TaskBlock(checked, indent, runs);
  }

  /// A leading task glyph (followed by spaces or a tab).
  static (bool, List<InlineRun>)? _taskGlyph(List<InlineRun> runs) {
    final merged = InlineRun.merge(runs);
    final text = InlineRun.plainText(merged);
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return null;
    final glyph = String.fromCharCode(trimmed.runes.first);
    final bool checked;
    if (TaskGlyphs.unchecked.contains(glyph)) {
      checked = false;
    } else if (TaskGlyphs.checked.contains(glyph)) {
      checked = true;
    } else {
      return null;
    }
    var cut = text.length - trimmed.length + glyph.length;
    while (cut < text.length &&
        (text[cut] == ' ' || text[cut] == '\t' || text[cut] == '\u00A0')) {
      cut++;
    }
    return (checked, TaskGlyphs.dropPrefix(merged, cut));
  }

  /// Removes bold/italic that the paragraph style (or, with [allRuns],
  /// uniformly applied direct formatting) already implies.
  List<InlineRun> _stripStyle(
    List<InlineRun> runs,
    _StyleDef? style, {
    bool allRuns = false,
  }) {
    final visible = runs.where((r) => r.text.trim().isNotEmpty).toList();
    final dropBold =
        (style != null &&
            (_inherit(style, (d) => d.bold ? true : null) ?? false)) ||
        (allRuns && visible.isNotEmpty && visible.every((r) => r.bold));
    final dropItalic =
        (style != null &&
            (_inherit(style, (d) => d.italic ? true : null) ?? false)) ||
        (allRuns && visible.isNotEmpty && visible.every((r) => r.italic));
    if (!dropBold && !dropItalic) return runs;
    return [
      for (final r in runs)
        r.copyWith(
          bold: dropBold ? false : r.bold,
          italic: dropItalic ? false : r.italic,
        ),
    ];
  }

  static List<InlineRun> _clean(List<InlineRun> runs) => InlineRun.merge([
    for (final r in runs) r.copyWith(text: ImportText.inline(r.text)),
  ]);

  CodeBlock _codeBlock(List<InlineRun> runs, String? lang) {
    if (lang != null) _codeLang = ImportText.language(lang.trim());
    final text = InlineRun.plainText(runs).replaceAll(importSoftBreak, '\n');
    return CodeBlock(
      _codeLang,
      text.split('\n').map(ImportText.codeLine).join('\n'),
    );
  }

  void _mergeCodeGaps() {
    for (var i = 1; i + 1 < _blocks.length; i++) {
      final b = _blocks[i];
      final prev = _blocks[i - 1];
      final next = _blocks[i + 1];
      if (b is ParagraphBlock &&
          b.runs.isEmpty &&
          prev is CodeBlock &&
          next is CodeBlock) {
        _blocks[i] = CodeBlock(prev.language, '');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Tables

  void _cellParagraph(_Acc acc, _Props props) {
    if (acc.segs.any((s) => s is _BlockSeg)) {
      _warnings.add(
        ImportWarningKind.imageFlattened,
        'Images inside tables and notes were replaced by their description.',
        blockIndex: _blocks.length,
      );
    }
    if (props.itap > 1 && !_tableFlattened) {
      _tableFlattened = true;
      _warnings.add(
        ImportWarningKind.tableFlattened,
        'Nested tables were converted to text.',
        blockIndex: _blocks.length,
      );
    }
    if (!_cellAlignSet) {
      _cellAlignSet = true;
      _cellAlign = switch (props.align) {
        'center' => CellAlign.center,
        'right' => CellAlign.right,
        'left' => CellAlign.left,
        _ => null,
      };
      _cellStyle = _resolvedStyle(props.style ?? 0);
    }
    _cellParts.add(acc.flatRuns);
  }

  void _endCell() {
    final s = _s;
    final acc = _acc;
    _acc = _Acc();
    final props = s.para.pristine && acc.props != null ? acc.props! : s.para;
    if (!acc.isEmpty || _cellParts.isEmpty) _cellParagraph(acc, props);
    final parts = [
      for (final p in _cellParts) _clean(RunTools.trim(p)),
    ].where((p) => !RunTools.isBlank(p)).toList();
    if (parts.length > 1) {
      _warnings.add(
        ImportWarningKind.tableFlattened,
        'Table cells with several paragraphs were joined into one line.',
        blockIndex: _blocks.length,
      );
    }
    _cells.add(_Cell(RunTools.join(parts, ' '), _cellAlign, _cellStyle));
    _cellParts.clear();
    _cellAlign = null;
    _cellAlignSet = false;
    _cellStyle = null;
  }

  void _nestCell() {
    if (!_tableFlattened) {
      _tableFlattened = true;
      _warnings.add(
        ImportWarningKind.tableFlattened,
        'Nested tables were converted to text.',
        blockIndex: _blocks.length,
      );
    }
    final acc = _acc;
    _acc = _Acc();
    if (!acc.isEmpty) _cellParts.add(acc.flatRuns);
  }

  void _endRow() {
    if (!_acc.isEmpty || _cellParts.isNotEmpty) _endCell();
    if (_cells.isNotEmpty) {
      _rows.add(_Row(List.of(_cells)));
    }
    _cells.clear();
  }

  void _flushTable() {
    if (_cells.isNotEmpty || _cellParts.isNotEmpty) _endRow();
    if (_rows.isEmpty) return;
    final align = <CellAlign?>[];
    final grid = <List<List<InlineRun>>>[];
    for (var r = 0; r < _rows.length; r++) {
      final row = _rows[r];
      final cells = <List<InlineRun>>[];
      final header = r == 0;
      final visible = [
        for (final c in row.cells)
          ...c.runs.where((x) => x.text.trim().isNotEmpty),
      ];
      final allBold = visible.isNotEmpty && visible.every((x) => x.bold);
      for (var c = 0; c < row.cells.length; c++) {
        final cell = row.cells[c];
        var runs = cell.runs;
        if (header) {
          final styleBold = cell.style?.bold ?? false;
          if (styleBold || allBold) {
            runs = InlineRun.merge([
              for (final x in runs) x.copyWith(bold: false),
            ]);
          }
        }
        cells.add(runs);
        while (align.length <= c) {
          align.add(null);
        }
        if (header) align[c] = cell.align;
      }
      grid.add(cells);
    }
    _rows.clear();
    _addBlock(buildTable(options.idGenerator(), grid, align));
  }

  // -------------------------------------------------------------------------
  // Page setup

  ImportedPageSetup? _pageSetup() {
    if (_paperW == null &&
        _paperH == null &&
        _margL == null &&
        _margR == null &&
        _margT == null &&
        _margB == null) {
      return null;
    }
    var w = (_paperW ?? 12240).abs();
    var h = (_paperH ?? 15840).abs();
    if (w == 0 || h == 0) return null;
    if (_landscape && w < h) {
      final t = w;
      w = h;
      h = t;
    }
    double? m(int? v) => v == null ? null : v.abs() / 20;
    return ImportedPageSetup(
      widthPt: w / 20,
      heightPt: h / 20,
      marginTopPt: m(_margT),
      marginRightPt: m(_margR),
      marginBottomPt: m(_margB),
      marginLeftPt: m(_margL),
    );
  }
}
