/// Page setup model (`Document.pageSetupJson`, 07 §6).
library;

/// Pages (paginated frames) or Pageless (continuous column).
enum PageLayoutMode {
  /// Paginated.
  pages,

  /// Continuous.
  pageless,
}

/// Paper sizes.
enum PaperSize {
  /// 8.5 × 11 in.
  letter(612, 792),

  /// 210 × 297 mm.
  a4(595.2756, 841.8898),

  /// 297 × 420 mm.
  a3(841.8898, 1190.5512),

  /// 148 × 210 mm.
  a5(419.5276, 595.2756),

  /// 8.5 × 14 in.
  legal(612, 1008),

  /// 11 × 17 in.
  tabloid(792, 1224),

  /// Custom (see [PageSetup.customWidthPt]).
  custom(0, 0);

  const PaperSize(this.widthPt, this.heightPt);

  /// Portrait width in pt.
  final double widthPt;

  /// Portrait height in pt.
  final double heightPt;
}

/// Page orientation.
enum PageOrientation {
  /// Portrait.
  portrait,

  /// Landscape.
  landscape,
}

/// Page number formats.
enum PageNumberFormat {
  /// 1, 2, 3.
  decimal,

  /// i, ii, iii.
  lowerRoman,

  /// I, II, III.
  upperRoman;

  /// Formats [n] (≥ 1; values < 1 are rendered in decimal).
  String format(int n) {
    if (this == decimal || n < 1 || n >= 4000) return '$n';
    const values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    const symbols = [
      'M',
      'CM',
      'D',
      'CD',
      'C',
      'XC',
      'L',
      'XL',
      'X',
      'IX',
      'V',
      'IV',
      'I',
    ];
    var rest = n;
    final b = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      while (rest >= values[i]) {
        b.write(symbols[i]);
        rest -= values[i];
      }
    }
    return this == upperRoman ? b.toString() : b.toString().toLowerCase();
  }
}

/// Lengths in page setup JSON: `"<number><unit>"` with `pt`, `px`, `mm`,
/// `cm`, `in`.
abstract final class PageLength {
  static final _re = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*(pt|px|mm|cm|in)\s*$');

  /// Parses to points; throws [FormatException].
  static double parse(String s) {
    final m = _re.firstMatch(s);
    if (m == null) throw FormatException('Invalid length "$s"');
    final v = double.parse(m.group(1)!);
    return switch (m.group(2)) {
      'pt' => v,
      'px' => v * 0.75,
      'mm' => v * 72 / 25.4,
      'cm' => v * 72 / 2.54,
      _ => v * 72,
    };
  }

  /// Formats points as the shortest exact unit string (`in` when a multiple
  /// of 1/8 in, otherwise `pt`).
  static String format(double pt) {
    final inches = pt / 72;
    if (((inches * 8) - (inches * 8).round()).abs() < 1e-6) {
      return '${_trim(inches)}in';
    }
    return '${_trim(pt)}pt';
  }

  static String _trim(double v) {
    final s = v.toStringAsFixed(4);
    return s.contains('.')
        ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : s;
  }
}

/// Margins in points.
final class PageMargins {
  /// Creates margins.
  const PageMargins({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  /// All four equal.
  const PageMargins.all(double v) : this(top: v, right: v, bottom: v, left: v);

  /// Top.
  final double top;

  /// Right.
  final double right;

  /// Bottom.
  final double bottom;

  /// Left.
  final double left;

  /// JSON (`Edges<Length>`).
  Map<String, dynamic> toJson() => {
    'top': PageLength.format(top),
    'right': PageLength.format(right),
    'bottom': PageLength.format(bottom),
    'left': PageLength.format(left),
  };

  /// Parses `"1in"` or `{top,right,bottom,left}` (missing edges = 1in).
  static PageMargins fromJson(Object? json) {
    if (json is String) return PageMargins.all(PageLength.parse(json));
    if (json is Map) {
      double e(String k) =>
          json[k] is String ? PageLength.parse(json[k] as String) : 72;
      return PageMargins(
        top: e('top'),
        right: e('right'),
        bottom: e('bottom'),
        left: e('left'),
      );
    }
    throw const FormatException('Invalid margins');
  }

  @override
  bool operator ==(Object other) =>
      other is PageMargins &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom &&
      other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

/// A header or footer: three plain-text slots with tokens (§6.3).
final class HeaderFooterSpec {
  /// Creates a spec.
  const HeaderFooterSpec({
    this.enabled = true,
    this.left = '',
    this.center = '',
    this.right = '',
    this.distancePt = 36,
  });

  /// Shown.
  final bool enabled;

  /// Left slot.
  final String left;

  /// Center slot.
  final String center;

  /// Right slot.
  final String right;

  /// Distance from the page edge (pt).
  final double distancePt;

  /// Whether every slot is empty.
  bool get isEmpty => left.isEmpty && center.isEmpty && right.isEmpty;

  /// JSON.
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'left': left,
    'center': center,
    'right': right,
    'distance': PageLength.format(distancePt),
  };

  /// Parses JSON over [fallback].
  static HeaderFooterSpec fromJson(Object? json, HeaderFooterSpec fallback) {
    if (json is! Map) return fallback;
    return HeaderFooterSpec(
      enabled: json['enabled'] is bool
          ? json['enabled'] as bool
          : fallback.enabled,
      left: json['left'] is String ? json['left'] as String : fallback.left,
      center: json['center'] is String
          ? json['center'] as String
          : fallback.center,
      right: json['right'] is String ? json['right'] as String : fallback.right,
      distancePt: json['distance'] is String
          ? PageLength.parse(json['distance'] as String)
          : fallback.distancePt,
    );
  }
}

/// Page setup of a document (07 §6.1).
final class PageSetup {
  /// Creates a page setup.
  const PageSetup({
    this.layout = PageLayoutMode.pages,
    this.paper = PaperSize.letter,
    this.customWidthPt = 612,
    this.customHeightPt = 792,
    this.orientation = PageOrientation.portrait,
    this.margins,
    this.header = const HeaderFooterSpec(enabled: true, right: '{title}'),
    this.footer = const HeaderFooterSpec(enabled: true, center: '{page}'),
    this.differentFirstPage = false,
    this.firstPageHeader = const HeaderFooterSpec(enabled: false),
    this.firstPageFooter = const HeaderFooterSpec(enabled: false),
    this.pageNumberStart = 1,
    this.pageNumberFormat = PageNumberFormat.decimal,
  });

  /// Schema version.
  static const version = 1;

  /// Locales defaulting to Letter (others: A4).
  static const letterLocales = {
    'en-US',
    'en-CA',
    'es-MX',
    'fil-PH',
    'es-CL',
    'es-CO',
  };

  /// Defaults for new documents in [locale] (07 §6.1).
  factory PageSetup.defaultsFor(String locale) => PageSetup(
    paper: letterLocales.contains(locale.replaceAll('_', '-'))
        ? PaperSize.letter
        : PaperSize.a4,
    header: const HeaderFooterSpec(enabled: true),
  );

  /// Pages or Pageless.
  final PageLayoutMode layout;

  /// Paper.
  final PaperSize paper;

  /// Custom width (pt, portrait).
  final double customWidthPt;

  /// Custom height (pt, portrait).
  final double customHeightPt;

  /// Orientation.
  final PageOrientation orientation;

  /// Margins; `null` = the theme's `page.defaultMargins`.
  final PageMargins? margins;

  /// Header.
  final HeaderFooterSpec header;

  /// Footer.
  final HeaderFooterSpec footer;

  /// Use [firstPageHeader]/[firstPageFooter] on page 1.
  final bool differentFirstPage;

  /// First page header.
  final HeaderFooterSpec firstPageHeader;

  /// First page footer.
  final HeaderFooterSpec firstPageFooter;

  /// Logical number of the first page.
  final int pageNumberStart;

  /// Page number format.
  final PageNumberFormat pageNumberFormat;

  /// Page width in pt (orientation applied).
  double get pageWidthPt {
    final (w, h) = _portrait;
    return orientation == PageOrientation.portrait ? w : h;
  }

  /// Page height in pt (orientation applied).
  double get pageHeightPt {
    final (w, h) = _portrait;
    return orientation == PageOrientation.portrait ? h : w;
  }

  (double, double) get _portrait => paper == PaperSize.custom
      ? (customWidthPt, customHeightPt)
      : (paper.widthPt, paper.heightPt);

  /// Margins, resolving `theme` with [themeMargins].
  PageMargins marginsOr(PageMargins themeMargins) => margins ?? themeMargins;

  /// Header for physical page [index] (0-based).
  HeaderFooterSpec headerFor(int index) =>
      differentFirstPage && index == 0 ? firstPageHeader : header;

  /// Footer for physical page [index] (0-based).
  HeaderFooterSpec footerFor(int index) =>
      differentFirstPage && index == 0 ? firstPageFooter : footer;

  /// Logical page label of physical page [index].
  String pageLabel(int index) =>
      pageNumberFormat.format(pageNumberStart + index);

  /// JSON (`pageSetupJson`).
  Map<String, dynamic> toJson() => {
    'v': version,
    'layout': layout.name,
    'paper': paper.name,
    if (paper == PaperSize.custom)
      'customSize': {
        'width': PageLength.format(customWidthPt),
        'height': PageLength.format(customHeightPt),
      },
    'orientation': orientation.name,
    'margins': margins?.toJson() ?? 'theme',
    'header': header.toJson(),
    'footer': footer.toJson(),
    'differentFirstPage': differentFirstPage,
    'firstPage': {
      'header': firstPageHeader.toJson(),
      'footer': firstPageFooter.toJson(),
    },
    'pageNumberStart': pageNumberStart,
    'pageNumberFormat': pageNumberFormat.name,
  };

  /// Parses JSON leniently (unknown/invalid fields fall back to defaults);
  /// use [validate] for strict checks.
  static PageSetup fromJson(Map<String, dynamic> json) {
    const d = PageSetup();
    T e<T extends Enum>(List<T> values, Object? v, T fallback) =>
        values.where((x) => x.name == v).firstOrNull ?? fallback;
    var cw = d.customWidthPt;
    var ch = d.customHeightPt;
    final custom = json['customSize'];
    if (custom is Map) {
      try {
        if (custom['width'] is String) {
          cw = PageLength.parse(custom['width'] as String);
        }
        if (custom['height'] is String) {
          ch = PageLength.parse(custom['height'] as String);
        }
      } on FormatException {
        // keep defaults
      }
    }
    PageMargins? margins;
    final m = json['margins'];
    if (m != null && m != 'theme') {
      try {
        margins = PageMargins.fromJson(m);
      } on FormatException {
        margins = null;
      }
    }
    HeaderFooterSpec hf(Object? j, HeaderFooterSpec fb) {
      try {
        return HeaderFooterSpec.fromJson(j, fb);
      } on FormatException {
        return fb;
      }
    }

    final first = json['firstPage'] is Map
        ? json['firstPage'] as Map
        : const <String, dynamic>{};
    return PageSetup(
      layout: e(PageLayoutMode.values, json['layout'], d.layout),
      paper: e(PaperSize.values, json['paper'], d.paper),
      customWidthPt: cw,
      customHeightPt: ch,
      orientation: e(
        PageOrientation.values,
        json['orientation'],
        d.orientation,
      ),
      margins: margins,
      header: hf(json['header'], d.header),
      footer: hf(json['footer'], d.footer),
      differentFirstPage: json['differentFirstPage'] == true,
      firstPageHeader: hf(first['header'], d.firstPageHeader),
      firstPageFooter: hf(first['footer'], d.firstPageFooter),
      pageNumberStart: json['pageNumberStart'] is int
          ? json['pageNumberStart'] as int
          : 1,
      pageNumberFormat: e(
        PageNumberFormat.values,
        json['pageNumberFormat'],
        d.pageNumberFormat,
      ),
    );
  }

  /// Applies an RFC 7396 merge [patch] to the JSON form (MCP
  /// `write.update_page_setup`, dialog *Apply*) and returns the result after
  /// [validate] (throws [FormatException] listing the errors).
  PageSetup applyPatch(
    Map<String, dynamic> patch, {
    PageMargins themeMargins = const PageMargins.all(72),
  }) {
    final merged = _merge(toJson(), patch) as Map<String, dynamic>;
    final errors = validateJson(merged, themeMargins: themeMargins);
    if (errors.isNotEmpty) throw FormatException(errors.join('; '));
    return fromJson(merged);
  }

  static Object? _merge(Object? target, Object? patch) {
    if (patch is! Map) return patch;
    final result = target is Map
        ? Map<String, dynamic>.from(target)
        : <String, dynamic>{};
    for (final e in patch.entries) {
      if (e.value == null) {
        result.remove(e.key);
      } else {
        result['${e.key}'] = _merge(result[e.key], e.value);
      }
    }
    return result;
  }

  /// Validation errors of this setup (`PageSetupValidator`, 07 §6.1):
  /// margins ≥ 0, content box ≥ 2 × 2 in, header/footer distance < the
  /// corresponding margin, custom size 2–48 in.
  List<String> validate({
    PageMargins themeMargins = const PageMargins.all(72),
  }) {
    final errors = <String>[];
    if (paper == PaperSize.custom) {
      for (final v in [customWidthPt, customHeightPt]) {
        if (v < 144 || v > 3456) {
          errors.add('Custom size must be between 2in and 48in');
        }
      }
    }
    final mg = marginsOr(themeMargins);
    if ([mg.top, mg.right, mg.bottom, mg.left].any((v) => v < 0)) {
      errors.add('Margins must not be negative');
    }
    if (pageWidthPt - mg.left - mg.right < 144 ||
        pageHeightPt - mg.top - mg.bottom < 144) {
      errors.add('The content area must be at least 2in × 2in');
    }
    for (final (spec, margin, name) in [
      (header, mg.top, 'Header'),
      (footer, mg.bottom, 'Footer'),
      if (differentFirstPage) (firstPageHeader, mg.top, 'First page header'),
      if (differentFirstPage) (firstPageFooter, mg.bottom, 'First page footer'),
    ]) {
      if (spec.enabled && spec.distancePt >= margin) {
        errors.add('$name distance must be smaller than the margin');
      }
      if (spec.distancePt < 0) {
        errors.add('$name distance must not be negative');
      }
    }
    if (pageNumberStart < 0 || pageNumberStart > 100000) {
      errors.add('Page numbers must start between 0 and 100000');
    }
    return errors;
  }

  /// Strict validation of a JSON object (types and values).
  static List<String> validateJson(
    Map<String, dynamic> json, {
    PageMargins themeMargins = const PageMargins.all(72),
  }) {
    final errors = <String>[];
    void enumCheck(String key, List<Enum> values) {
      final v = json[key];
      if (v != null && !values.any((e) => e.name == v)) {
        errors.add('Invalid $key "$v"');
      }
    }

    enumCheck('layout', PageLayoutMode.values);
    enumCheck('paper', PaperSize.values);
    enumCheck('orientation', PageOrientation.values);
    enumCheck('pageNumberFormat', PageNumberFormat.values);
    void lengthCheck(Object? v, String what) {
      if (v == null) return;
      if (v is! String) {
        errors.add('$what must be a length string');
        return;
      }
      try {
        PageLength.parse(v);
      } on FormatException {
        errors.add('Invalid $what "$v"');
      }
    }

    final m = json['margins'];
    if (m is Map) {
      for (final k in ['top', 'right', 'bottom', 'left']) {
        lengthCheck(m[k], 'margin $k');
      }
    } else if (m != null && m != 'theme') {
      lengthCheck(m, 'margins');
    }
    final cs = json['customSize'];
    if (cs is Map) {
      lengthCheck(cs['width'], 'width');
      lengthCheck(cs['height'], 'height');
    }
    for (final key in ['header', 'footer']) {
      final hf = json[key];
      if (hf is Map) lengthCheck(hf['distance'], '$key distance');
    }
    final start = json['pageNumberStart'];
    if (start != null && start is! int) {
      errors.add('pageNumberStart must be an integer');
    }
    if (errors.isNotEmpty) return errors;
    return fromJson(json).validate(themeMargins: themeMargins);
  }

  @override
  bool operator ==(Object other) =>
      other is PageSetup && _eq(toJson(), other.toJson());

  @override
  int get hashCode => toJson().toString().hashCode;

  static bool _eq(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((k) => b.containsKey(k) && _eq(a[k], b[k]));
    }
    return a == b;
  }
}
