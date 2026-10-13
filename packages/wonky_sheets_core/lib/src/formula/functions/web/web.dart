import 'dart:math' as math;

import '../../eval/args.dart';
import '../../eval/eval_context.dart';
import '../../eval/runtime_services.dart';
import '../../external/external_data.dart';
import '../../values/errors.dart';
import '../../values/fvalue.dart';
import '../../values/numeric.dart';
import '../registry.dart';
import 'rich_values.dart';

/// Web, Google and special functions (05 §13, §15.17, §17).
void registerWeb(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.web;
  b.fn(
    'HYPERLINK',
    'Creates a hyperlink inside a cell.',
    [
      P.text(
        'url',
        'The full URL of the link location enclosed in quotation marks, or a reference to a cell containing such a URL.',
      ),
      P.scalar(
        'link_label',
        'The text to display in the cell as the link, enclosed in quotation marks, or a reference to a cell containing such a label.',
        true,
      ),
    ],
    (a) {
      final url = a.text(0).trim();
      var label = a.has(1) ? a.scalar(1) : FText(url);
      if (label is FEmpty) label = FText(url);
      final ok =
          RegExp(
            r'^(https?://|mailto:|#)',
            caseSensitive: false,
          ).hasMatch(url) ||
          RegExp(
            r'^[\w.-]+\.[a-z]{2,}(/.*)?$',
            caseSensitive: false,
          ).hasMatch(url);
      if (!ok) return label;
      final full =
          RegExp(r'^(https?://|mailto:|#)', caseSensitive: false).hasMatch(url)
          ? url
          : 'http://$url';
      final labelText = switch (label) {
        FText(:final v) => v,
        FNumber(:final v) => Numeric.toText(v, decimal: a.locale.decimal),
        FBool(:final v) => v ? 'TRUE' : 'FALSE',
        _ => url,
      };
      return FRich(RichKind.hyperlink, label, LinkValue(full, labelText));
    },
    returns: ReturnKind.rich,
    liftable: true,
    priority: Priority.p0,
    examples: ['HYPERLINK("https://www.example.com", "Example")'],
  );
  b.fn(
    'ENCODEURL',
    'Encodes a string of text for the purpose of using in a URL query.',
    [P.text('text', 'The text to encode.')],
    (a) => FText(
      Uri.encodeComponent(a.text(0))
          .replaceAll('!', '%21')
          .replaceAll("'", '%27')
          .replaceAll('(', '%28')
          .replaceAll(')', '%29')
          .replaceAll('*', '%2A'),
    ),
    examples: ['ENCODEURL("Hello World")'],
  );
  b.fn(
    'IMAGE',
    'Inserts an image into a cell.',
    [
      P.text(
        'url',
        'The URL of the image, including protocol (https:// or wonky-file://).',
      ),
      P.num(
        'mode',
        'The sizing mode: 1 resize to fit (default), 2 stretch, 3 original size, 4 custom size.',
        true,
        1,
      ),
      P.num('height', 'The height of the image in pixels (mode 4).', true),
      P.num('width', 'The width of the image in pixels (mode 4).', true),
      P.text(
        'alt_text',
        'Alternative text for accessibility (Wonky extension).',
        true,
      ),
    ],
    (a) {
      final url = a.text(0).trim();
      final mode = a.intOr(1, 1);
      if (mode < 1 || mode > 4) {
        fail(
          ErrorKind.value,
          'Function IMAGE parameter 2 value $mode is out of range.',
        );
      }
      final h = a.has(2) ? a.number(2) : null;
      final w = a.has(3) ? a.number(3) : null;
      if (mode == 4 && (h == null || w == null)) {
        fail(ErrorKind.na, 'IMAGE mode 4 requires height and width.');
      }
      if ((h != null && h <= 0) || (w != null && w <= 0)) fail(ErrorKind.value);
      if (!_imageUrlAllowed(url)) fail(ErrorKind.ref, 'Image URL not allowed');
      return FRich(
        RichKind.image,
        FEmpty.instance,
        ImageValue(
          url,
          mode: mode,
          height: h,
          width: w,
          altText: a.has(4) ? a.text(4) : null,
        ),
      );
    },
    returns: ReturnKind.rich,
    liftable: true,
    priority: Priority.p0,
    examples: [
      'IMAGE("https://www.example.com/logo.png")',
      'IMAGE("wonky-file://3f1c…", 4, 50, 100)',
    ],
  );

  b.category = FunctionCategory.google;
  b.fn(
    'SPARKLINE',
    'Creates a miniature chart contained within a single cell.',
    [
      P.array('data', 'The range or array containing the data to plot.'),
      P.array(
        'options',
        'A range or array of optional settings: pairs of {option, value}, e.g. {"charttype","bar";"max",100}.',
        true,
      ),
    ],
    _sparkline,
    returns: ReturnKind.rich,
    priority: Priority.p0,
    examples: [
      'SPARKLINE(A1:A10)',
      'SPARKLINE(A1:B1, {"charttype","bar";"max",100})',
    ],
  );

  // ---- async external data (05 §13)
  void external(
    String name,
    String summary,
    List<ArgSpec> params,
    List<String> examples,
    Priority p,
  ) {
    b.fn(
      name,
      summary,
      params,
      (a) => _external(a, name),
      async: true,
      returns: ReturnKind.array,
      liftable: false,
      priority: p,
      cost: FunctionCost.heavy,
      examples: examples,
      category: FunctionCategory.web,
    );
  }

  external(
    'IMPORTRANGE',
    'Imports a range of cells from a specified spreadsheet.',
    [
      P.text(
        'spreadsheet_url',
        'The URL (or id) of the Wonky spreadsheet from which data will be imported.',
      ),
      P.text(
        'range_string',
        'A string of the format "[sheet_name!]range" (e.g. "Sheet1!A2:B6" or "A2:B6") or a named range.',
      ),
    ],
    ['IMPORTRANGE("https://example.com/sheets/d/3f1c…", "Sheet1!A1:C10")'],
    Priority.p1,
  );
  external(
    'IMPORTDATA',
    'Imports data at a given URL in .csv (comma-separated value) or .tsv (tab-separated value) format.',
    [
      P.text(
        'url',
        'The URL from which to fetch the .csv or .tsv-formatted data.',
      ),
      P.text('delimiter', 'The delimiter to use to parse the data.', true),
      P.text(
        'locale',
        'A language and region locale code to use when parsing the data.',
        true,
      ),
    ],
    ['IMPORTDATA("https://example.com/data.csv")'],
    Priority.p2,
  );
  external(
    'IMPORTHTML',
    'Imports data from a table or list within an HTML page.',
    [
      P.text('url', 'The URL of the page to examine.'),
      P.text(
        'query',
        '"list" or "table" depending on what type of structure contains the desired data.',
      ),
      P.num(
        'index',
        'The index, starting at 1, which identifies which table or list should be returned.',
      ),
      P.text('locale', 'Locale code for parsing.', true),
    ],
    [
      'IMPORTHTML("https://en.wikipedia.org/wiki/Demographics_of_India", "table", 4)',
    ],
    Priority.p2,
  );
  external(
    'IMPORTXML',
    'Imports data from any of various structured data types including XML, HTML, CSV, TSV, and RSS and ATOM XML feeds.',
    [
      P.text('url', 'The URL of the page to examine.'),
      P.text('xpath_query', 'The XPath query to run on the structured data.'),
      P.text('locale', 'Locale code for parsing.', true),
    ],
    ['IMPORTXML("https://example.com", "//a/@href")'],
    Priority.p2,
  );
  external(
    'IMPORTFEED',
    'Imports a RSS or ATOM feed.',
    [
      P.text('url', 'The URL of the RSS or ATOM feed.'),
      P.text('query', 'What data to fetch, e.g. "items title".', true),
      P.bool_('headers', 'Whether to include headers.', true, false),
      P.num('num_items', 'The number of items to return.', true),
    ],
    ['IMPORTFEED("https://example.com/feed.xml")'],
    Priority.p2,
  );
  b.fn(
    'AI',
    'Generates text with an AI model from a prompt and optional context range.',
    [
      P.text('prompt', 'The instruction for the AI.'),
      P.array('range', 'Optional cells to use as context.', true),
    ],
    (a) => _external(a, 'AI', perCell: true),
    async: true,
    liftable: false,
    priority: Priority.p2,
    examples: ['AI("Summarize this review in 3 words", A2)'],
    category: FunctionCategory.google,
  );
  b.fn(
    'GOOGLETRANSLATE',
    'Translates text from one language into another (AI-backed).',
    [
      P.text('text', 'The text to translate.'),
      P.text(
        'source_language',
        'Two-letter language code of the source language, or "auto".',
        true,
        'auto',
      ),
      P.text(
        'target_language',
        'Two-letter language code of the target language.',
        true,
      ),
    ],
    (a) => _external(a, 'GOOGLETRANSLATE', notYet: true),
    async: true,
    priority: Priority.p2,
    examples: ['GOOGLETRANSLATE("Hello world", "en", "es")'],
  );
  b.fn(
    'DETECTLANGUAGE',
    'Identifies the language used in text within the specified range (AI-backed).',
    [
      P.array(
        'text_or_range',
        'The text or range whose language will be detected.',
      ),
    ],
    (a) => _external(a, 'DETECTLANGUAGE', notYet: true),
    async: true,
    liftable: false,
    priority: Priority.p2,
    examples: ['DETECTLANGUAGE("Bonjour")'],
  );
  b.stub(
    'GOOGLEFINANCE',
    'Fetches current or historical securities information (not available in Wonky Sheets).',
    message: ErrorMessages.notAvailable('GOOGLEFINANCE'),
  );

  // ---- Excel-only / unsupported (keep formulas round-tripping with a clear message)
  b.category = FunctionCategory.web;
  for (final name in [
    'WEBSERVICE',
    'FILTERXML',
    'RTD',
    'CALL',
    'REGISTER.ID',
    'EUROCONVERT',
    'STOCKHISTORY',
  ]) {
    b.stub(
      name,
      'Excel function that is not supported in Wonky Sheets.',
      message: ErrorMessages.notAvailable(name),
    );
  }
  for (final name in [
    'CUBEKPIMEMBER',
    'CUBEMEMBER',
    'CUBEMEMBERPROPERTY',
    'CUBERANKEDMEMBER',
    'CUBESET',
    'CUBESETCOUNT',
    'CUBEVALUE',
  ]) {
    b.stub(
      name,
      'Excel OLAP cube function (not supported in Wonky Sheets).',
      message: ErrorMessages.notAvailable(name),
      category: FunctionCategory.web,
    );
  }
}

bool _imageUrlAllowed(String url) {
  if (url.startsWith('wonky-file://')) {
    return url.length > 'wonky-file://'.length;
  }
  final u = Uri.tryParse(url);
  if (u == null ||
      !(u.scheme == 'https' || u.scheme == 'http') ||
      u.host.isEmpty) {
    return false;
  }
  final h = u.host.toLowerCase();
  if (h == 'localhost' || h.endsWith('.local') || h.endsWith('.internal')) {
    return false;
  }
  final ip = RegExp(r'^(\d+)\.(\d+)\.(\d+)\.(\d+)$').firstMatch(h);
  if (ip != null) {
    final o = [for (var i = 1; i <= 4; i++) int.parse(ip.group(i)!)];
    if (o[0] == 10 || o[0] == 127 || o[0] == 0) return false;
    if (o[0] == 169 && o[1] == 254) return false;
    if (o[0] == 172 && o[1] >= 16 && o[1] <= 31) return false;
    if (o[0] == 192 && o[1] == 168) return false;
    if (o[0] == 100 && o[1] >= 64 && o[1] <= 127) return false;
    if (o[0] >= 224) return false;
  }
  if (h.startsWith('[') || h.contains(':')) {
    // IPv6 literals: block loopback, link-local, ULA
    if (h.contains('::1') ||
        h.startsWith('[fe80') ||
        h.startsWith('[fd') ||
        h.startsWith('[fc')) {
      return false;
    }
  }
  return true;
}

String _argText(FValue v) => switch (v) {
  FText(:final v) => 's$v',
  FNumber(:final v) => 'n$v',
  FBool(:final v) => 'b$v',
  FArray() => 'a${v.rows}x${v.cols}:${v.elements.map(_argText).join('|')}',
  FEmpty() => 'e',
  _ => '?',
};

FValue _external(
  Args a,
  String fn, {
  bool perCell = false,
  bool notYet = false,
}) {
  final provider = a.ctx.host.external;
  if (provider == null) {
    if (notYet) {
      return FError(ErrorKind.name, ErrorMessages.notAvailableYet(fn));
    }
    return const FError(ErrorKind.na, ErrorMessages.offline);
  }
  final args = <FValue>[];
  for (var i = 0; i < a.length; i++) {
    final v = a[i];
    if (v is FError) return v;
    args.add(v is FRef || v is FArray ? a.array(i) : a.scalarOrError(i));
  }
  for (final v in args) {
    if (v is FError) return v;
  }
  final material = [
    if (perCell) a.ctx.cellId,
    ...args.map(_argText),
  ].join('\u0001');
  final hash =
      DeterministicRandom.hashString(
        material,
      ).toRadixString(16).padLeft(8, '0') +
      DeterministicRandom.hashString(
        material,
        0x2545f491,
      ).toRadixString(16).padLeft(8, '0');
  final key = ExternalKey(fn, hash);
  a.ctx.deps.external.add(key);
  final cached = provider.lookup(key);
  if (cached != null) return cached.value;
  provider.request(
    key,
    ExternalRequest(
      fn,
      args,
      callerSheetId: a.ctx.sheet.id,
      callerRowId: a.ctx.rowId,
      callerColId: a.ctx.colId,
    ),
  );
  return const FError.pending();
}

FValue _sparkline(Args a) {
  final data = a.array(0);
  final opts = <String, Object>{};
  if (a.has(1)) {
    final o = a.array(1);
    if (o.cols < 2) {
      fail(
        ErrorKind.value,
        'Invalid option for SPARKLINE: options must be pairs.',
      );
    }
    for (var r = 0; r < o.rows; r++) {
      final k = o.at(r, 0), v = o.at(r, 1);
      if (k is FEmpty) continue;
      if (k is! FText) {
        fail(ErrorKind.value, 'Invalid option for SPARKLINE: ${k.debugText}');
      }
      opts[k.v.toLowerCase()] = switch (v) {
        FText(:final v) => v,
        FNumber(:final v) => v,
        FBool(:final v) => v,
        _ => '',
      };
    }
  }
  final type = (opts['charttype'] ?? 'line').toString().toLowerCase();
  const allowed = {
    'line': {
      'charttype',
      'xmin',
      'xmax',
      'ymin',
      'ymax',
      'color',
      'empty',
      'nan',
      'rtl',
      'linewidth',
    },
    'column': {
      'charttype',
      'color',
      'lowcolor',
      'highcolor',
      'firstcolor',
      'lastcolor',
      'negcolor',
      'empty',
      'nan',
      'axis',
      'axiscolor',
      'ymin',
      'ymax',
      'rtl',
    },
    'winloss': {
      'charttype',
      'color',
      'lowcolor',
      'highcolor',
      'firstcolor',
      'lastcolor',
      'negcolor',
      'empty',
      'nan',
      'axis',
      'axiscolor',
      'ymin',
      'ymax',
      'rtl',
    },
    'bar': {'charttype', 'max', 'color1', 'color2', 'empty', 'nan', 'rtl'},
  };
  final keys = allowed[type];
  if (keys == null) {
    fail(ErrorKind.value, 'Invalid option for SPARKLINE: $type');
  }
  for (final k in opts.keys) {
    if (!keys.contains(k)) {
      fail(ErrorKind.value, 'Invalid option for SPARKLINE: $k');
    }
  }
  for (final k in opts.keys.where((k) => k.contains('color'))) {
    final c = opts[k].toString();
    if (!RegExp(
      r'^(#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?|[a-zA-Z]+)$',
    ).hasMatch(c)) {
      fail(ErrorKind.value, 'Invalid option for SPARKLINE: $k');
    }
  }
  final emptyZero =
      (opts['empty'] ?? 'ignore').toString().toLowerCase() == 'zero';
  final nanConvert =
      (opts['nan'] ?? 'convert').toString().toLowerCase() == 'convert';
  var values = <double>[];
  for (final v in data.elements) {
    switch (v) {
      case FNumber(:final v):
        values.add(v);
      case FEmpty():
        values.add(emptyZero ? 0 : double.nan);
      case FBool(:final v):
        values.add(v ? 1 : 0);
      case FError():
        throw FormulaError(v);
      default:
        values.add(nanConvert ? 0 : double.nan);
    }
  }
  if (values.length > 10000) values = _downsample(values, 5000);
  return FRich(
    RichKind.sparkline,
    FEmpty.instance,
    SparklineValue(type, values, opts),
  );
}

/// Min/max per bucket (keeps the visual envelope).
List<double> _downsample(List<double> v, int buckets) {
  final out = <double>[];
  final size = v.length / buckets;
  for (var i = 0; i < buckets; i++) {
    final s = (i * size).floor(),
        e = math.min(v.length, ((i + 1) * size).floor());
    var lo = double.infinity, hi = double.negativeInfinity;
    for (var k = s; k < e; k++) {
      if (v[k].isNaN) continue;
      if (v[k] < lo) lo = v[k];
      if (v[k] > hi) hi = v[k];
    }
    if (lo.isInfinite) {
      out.add(double.nan);
    } else {
      out
        ..add(lo)
        ..add(hi);
    }
  }
  return out;
}
