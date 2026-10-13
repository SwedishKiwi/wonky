import 'dart:async';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../format/attributes.dart';
import '../../input/input_parser.dart';
import '../formula/formula_tokens.dart';
import '../formula/function_map.dart';
import '../ir/workbook_document.dart';
import 'csv_parser.dart';
import 'encoding.dart';

/// Options of a CSV/TSV import (11 §2.2, §4).
final class CsvImportOptions {
  /// Creates options.
  const CsvImportOptions({
    this.delimiter,
    this.encoding,
    this.locale = 'en_US',
    this.convert = true,
    this.fileName,
    this.sheetName,
    this.today,
    this.chunkRecords = 5000,
    this.maxFieldLength = 50000,
    this.columnFormatThreshold = 0.95,
  });

  /// Field delimiter; null = detect.
  final String? delimiter;

  /// Encoding; null = detect.
  final TextEncoding? encoding;

  /// Locale for numbers, dates and booleans.
  final String locale;

  /// Convert text to numbers, dates and formulas.
  final bool convert;

  /// Source file name (sheet name, `.tsv` tie-break).
  final String? fileName;

  /// Sheet name (default: file name without extension, or `Sheet1`).
  final String? sheetName;

  /// Date used for partial dates (`1/2`); inject for determinism.
  final DateTime? today;

  /// Records per emitted chunk.
  final int chunkRecords;

  /// Maximum field length.
  final int maxFieldLength;

  /// Share of a column's non-empty cells that must have the same detected
  /// number format for it to become the column default.
  final double columnFormatThreshold;
}

/// A chunk of imported rows (≤ [CsvImportOptions.chunkRecords] records).
final class CsvChunk {
  /// Creates a chunk.
  const CsvChunk(this.startRow, this.rowCount, this.cells);

  /// First row index of the chunk.
  final int startRow;

  /// Number of records in the chunk.
  final int rowCount;

  /// Non-empty cells `(row, col, cell)` (formats index into
  /// [CsvStreamImporter.document]'s table).
  final List<(int row, int col, IrCell cell)> cells;
}

/// Result of [CsvImporter.import].
final class CsvImportResult {
  /// Creates a result.
  const CsvImportResult(
    this.document,
    this.encoding,
    this.encodingReason,
    this.delimiter,
  );

  final WorkbookDocument document;
  final TextEncoding encoding;

  /// `bom`, `nulBytes`, `validUtf8`, `fallback` or `option`.
  final String encodingReason;
  final String delimiter;
}

/// CSV/TSV → IR (11 §4).
abstract final class CsvImporter {
  /// Imports complete [bytes] into a one-sheet document.
  static CsvImportResult import(
    List<int> bytes, [
    CsvImportOptions options = const CsvImportOptions(),
  ]) {
    final s = CsvStreamImporter(options, accumulate: true);
    s.add(bytes);
    s.close();
    return CsvImportResult(
      s.document,
      s.encoding!,
      s.encodingReason!,
      s.delimiter!,
    );
  }

  /// Imports text (already decoded).
  static WorkbookDocument importText(
    String text, [
    CsvImportOptions options = const CsvImportOptions(),
  ]) {
    final s = CsvStreamImporter(options, accumulate: true);
    s.addText(text);
    s.close();
    return s.document;
  }

  /// Streams chunks of IR rows from a byte stream. The importer's document
  /// (formats, warnings, column formats) is complete after the stream ends.
  static Stream<CsvChunk> stream(
    Stream<List<int>> bytes,
    CsvStreamImporter importer,
  ) async* {
    await for (final b in bytes) {
      for (final c in importer.add(b)) {
        yield c;
      }
    }
    for (final c in importer.close()) {
      yield c;
    }
  }

  /// The first [rows] records of [bytes] as raw fields (dialog preview).
  static List<List<String>> preview(
    List<int> bytes,
    CsvImportOptions options, {
    int rows = 20,
  }) {
    final head = bytes.length > 65536 ? bytes.sublist(0, 65536) : bytes;
    final enc = options.encoding ?? EncodingSniffer.sniff(head).encoding;
    final text = enc.decode(head);
    final d =
        options.delimiter ??
        CsvDelimiterDetector.detect(
          text,
          fileName: options.fileName,
          decimalCommaLocale: FormulaDialect.usesDecimalComma(options.locale),
        ).delimiter;
    final sep = CsvDelimiterDetector.detect(text).sepLineLength;
    final p = CsvParser(delimiter: d, maxFieldLength: options.maxFieldLength);
    final out = [
      ...p.feed(text.substring(options.delimiter == null ? sep : 0)),
      if (head.length == bytes.length) ...p.close(),
    ];
    return [for (final r in out.take(rows)) r.fields];
  }
}

/// Incremental CSV importer: bytes in, IR chunks out (11 §4.5). Memory stays
/// O(chunk) unless [accumulate] keeps the cells in [document].
final class CsvStreamImporter {
  /// Creates an importer.
  CsvStreamImporter(this.options, {this.accumulate = false}) {
    final name = options.sheetName ?? _sheetNameOf(options.fileName);
    sheet = IrSheet(name);
    document = WorkbookDocument(
      title: _titleOf(options.fileName),
      locale: options.locale,
    )..sheets.add(sheet);
    _dialect = FormulaDialect.forLocale(options.locale);
  }

  final CsvImportOptions options;
  final bool accumulate;

  /// The document (one sheet).
  late final WorkbookDocument document;
  late final IrSheet sheet;
  late final FormulaDialect _dialect;

  TextEncoding? encoding;
  String? encodingReason;
  String? delimiter;

  final List<int> _head = [];
  String _textHead = '';
  bool _headDone = false;
  ChunkedTextDecoder? _decoder;
  CsvParser? _parser;
  int _row = 0;
  int _chunkStart = 0;
  List<(int, int, IrCell)> _pending = [];
  int _pendingRecords = 0;
  final Map<int, Map<String, int>> _colFormats = {};
  final Map<int, int> _colNonEmpty = {};
  final Map<String, int> _formatIndex = {};
  bool _textMode = false;

  /// Column defaults detected after [close] (column → number format).
  final Map<int, String> columnFormats = {};

  /// Adds raw bytes.
  List<CsvChunk> add(List<int> bytes) {
    if (_headDone) return _addText(_decoder!.convert(bytes));
    _head.addAll(bytes);
    if (_head.length < 65536) return const [];
    return _startFromHead(atEnd: false);
  }

  /// Adds decoded text (no encoding detection).
  List<CsvChunk> addText(String text) {
    _textMode = true;
    if (!_headDone) {
      encoding ??= TextEncoding.utf8;
      encodingReason ??= 'text';
      _textHead += text;
      if (_textHead.length < 65536) return const [];
      return _startText(_textHead);
    }
    return _addText(text);
  }

  /// Ends the input.
  List<CsvChunk> close() {
    final out = <CsvChunk>[];
    if (!_headDone) {
      out.addAll(
        _textMode ? _startText(_textHead) : _startFromHead(atEnd: true),
      );
    } else if (!_textMode) {
      out.addAll(_addText(_decoder!.close()));
    }
    for (final r in _parser!.close()) {
      _record(r);
    }
    final p = _parser!;
    if (p.unterminatedQuoteLine != null) {
      document.warnings.add(
        'unterminatedQuote',
        'Unterminated quote at line ${p.unterminatedQuoteLine}',
        sheet: sheet.name,
      );
    }
    if (p.truncatedFields > 0) {
      document.warnings.add(
        'fieldTruncated',
        'Fields longer than ${options.maxFieldLength} characters were truncated (first at line ${p.firstTruncatedLine})',
        sheet: sheet.name,
        count: p.truncatedFields,
      );
    }
    final last = _flush();
    if (last != null) out.add(last);
    _finishColumnFormats();
    return out;
  }

  List<CsvChunk> _startFromHead({required bool atEnd}) {
    final sniff = EncodingSniffer.sniff(_head);
    encoding = options.encoding ?? sniff.encoding;
    encodingReason = options.encoding != null ? 'option' : sniff.reason;
    _decoder = encoding!.decoder();
    final text = _decoder!.convert(_head) + (atEnd ? _decoder!.close() : '');
    _head.clear();
    return _startText(text);
  }

  List<CsvChunk> _startText(String text) {
    _headDone = true;
    var t = text;
    if (t.isNotEmpty && t.codeUnitAt(0) == 0xfeff) t = t.substring(1);
    final detected = CsvDelimiterDetector.detect(
      t,
      fileName: options.fileName,
      decimalCommaLocale: FormulaDialect.usesDecimalComma(options.locale),
    );
    if (options.delimiter != null && options.delimiter!.isNotEmpty) {
      delimiter = options.delimiter;
      if (detected.fromSepLine) t = t.substring(detected.sepLineLength);
    } else {
      delimiter = detected.delimiter;
      if (detected.fromSepLine) t = t.substring(detected.sepLineLength);
    }
    _parser = CsvParser(
      delimiter: delimiter!,
      maxFieldLength: options.maxFieldLength,
    );
    return _addText(t);
  }

  List<CsvChunk> _addText(String text) {
    final out = <CsvChunk>[];
    for (final r in _parser!.feed(text)) {
      _record(r);
      if (_pendingRecords >= options.chunkRecords) out.add(_flush()!);
    }
    return out;
  }

  CsvChunk? _flush() {
    if (_pendingRecords == 0 && _pending.isEmpty) return null;
    final c = CsvChunk(_chunkStart, _pendingRecords, _pending);
    _pending = [];
    _chunkStart = _row;
    _pendingRecords = 0;
    return c;
  }

  void _record(CsvRecord r) {
    final row = _row++;
    _pendingRecords++;
    for (var col = 0; col < r.fields.length; col++) {
      final f = r.fields[col];
      if (f.isEmpty) continue;
      final cell = _convert(f, row, col);
      if (cell == null) continue;
      _pending.add((row, col, cell));
      if (accumulate) sheet.cells.set(row, col, cell);
    }
  }

  IrCell? _convert(String field, int row, int col) {
    if (!options.convert) return IrCell(value: IrText(field));
    final parsed = InputParser.instance.parse(
      field,
      locale: options.locale,
      today: options.today,
    );
    if (parsed.isClear) return null;
    _colNonEmpty[col] = (_colNonEmpty[col] ?? 0) + 1;
    if (parsed.formulaA1 != null) {
      var f = parsed.formulaA1!;
      if (f.startsWith('=')) f = f.substring(1);
      f = FormulaRewriter.toCanonical(f, _dialect);
      if (_isExternal(f)) {
        document.warnings.add(
          'blockedFormula',
          'Formulas using external data were disabled until allowed',
          sheet: sheet.name,
          range: CellPos(row, col).a1,
        );
        return IrCell(
          value: const IrError(CellErrorKind.blocked),
          note: 'Blocked formula (external data): =$f',
          blockedFormulaA1: f,
        );
      }
      return IrCell(formulaA1: f);
    }
    final value = IrValue.fromContent(parsed.content);
    var format = 0;
    final nf = parsed.autoNumberFormat;
    if (nf != null) {
      final m = _colFormats.putIfAbsent(col, () => {});
      m[nf] = (m[nf] ?? 0) + 1;
      format = _formatIndex[nf] ??= document.formats.internAttrs(
        CellFormat({FormatAttr.numberFormat: nf}),
      );
    }
    return IrCell(value: value, format: format, link: parsed.autoLinkUrl);
  }

  static bool _isExternal(String formula) {
    final tokens = FormulaTokenizer.tokenize(formula);
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.kind != FTok.func) continue;
      final u = t.text.toUpperCase();
      if (FunctionMap.externalData.contains(u)) return true;
      if (u == 'IMAGE') {
        for (var j = i + 1; j < tokens.length && j < i + 4; j++) {
          final a = tokens[j];
          if (a.kind == FTok.string &&
              RegExp(
                r'^"\s*(https?|ftp):',
                caseSensitive: false,
              ).hasMatch(a.text)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _finishColumnFormats() {
    _colFormats.forEach((col, counts) {
      final total = _colNonEmpty[col] ?? 0;
      if (total == 0) return;
      for (final e in counts.entries) {
        if (e.value / total >= options.columnFormatThreshold) {
          columnFormats[col] = e.key;
          break;
        }
      }
    });
    if (columnFormats.isEmpty) return;
    for (final e in columnFormats.entries) {
      final idx = _formatIndex[e.value]!;
      sheet.columns[e.key] = (sheet.columns[e.key] ?? const IrDim()).copyWith(
        format: idx,
      );
    }
    if (!accumulate) return;
    for (final (r, c, cell) in sheet.cells.entries.toList()) {
      final nf = columnFormats[c];
      if (nf != null && cell.format == _formatIndex[nf]) {
        sheet.cells.set(r, c, cell.copyWith(format: 0));
      }
    }
  }

  static String _titleOf(String? fileName) {
    if (fileName == null || fileName.isEmpty) return 'Imported data';
    final base = fileName.split(RegExp(r'[/\\]')).last;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }

  static String _sheetNameOf(String? fileName) {
    if (fileName == null || fileName.isEmpty) return 'Sheet1';
    final t = _titleOf(
      fileName,
    ).replaceAll(RegExp(r"[\[\]\*\?/\\:]"), ' ').trim();
    if (t.isEmpty) return 'Sheet1';
    return t.length > 100 ? t.substring(0, 100) : t;
  }
}
