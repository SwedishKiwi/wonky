/// The code element's `dataJson` (Slides 07 §3.1, 02 §6.7): whole-value
/// LWW; missing keys take the defaults below (theme defaults where 07 says
/// "null = from palette/theme").
library;

import 'package:wonky_code/wonky_code.dart';

import '../theme/json/json_util.dart';

/// Line-highlight style (07 §4.2).
enum CodeHighlightStyleKind {
  dim,
  blur,
  dimBlur,
  bar,
  box,
  none;

  static CodeHighlightStyleKind? fromName(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// How a step keeps its lines in view when the code overflows (07 §4.3).
enum CodeFocusMode {
  scroll,
  zoom,
  none;

  static CodeFocusMode? fromName(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// `dataJson.highlightStyle` (07 §4.2, §4.3).
final class CodeHighlightStyle {
  const CodeHighlightStyle({
    this.style = CodeHighlightStyleKind.dim,
    this.dimOpacity = 0.3,
    this.blurSigma = 2.5,
    this.barColor,
    this.gutterMarker = true,
    this.focus = CodeFocusMode.scroll,
    this.startWithFirstStep = false,
  });

  final CodeHighlightStyleKind style;
  final double dimOpacity;

  /// su.
  final double blurSigma;

  /// Color string (hex or `theme:` ref); null = palette `highlightBar`.
  final String? barColor;
  final bool gutterMarker;
  final CodeFocusMode focus;

  /// P1: step 1 is active before the first build.
  final bool startWithFirstStep;

  JsonMap toJson() => {
    'style': style.name,
    'dimOpacity': _n(dimOpacity),
    'blurSigma': _n(blurSigma),
    'barColor': barColor,
    'gutterMarker': gutterMarker,
    'focus': focus.name,
    'startWithFirstStep': startWithFirstStep,
  };

  static CodeHighlightStyle fromJson(Object? json) {
    if (json is! Map) return const CodeHighlightStyle();
    const d = CodeHighlightStyle();
    return CodeHighlightStyle(
      style: CodeHighlightStyleKind.fromName(json['style']) ?? d.style,
      dimOpacity: _d(json['dimOpacity'], 0, 1) ?? d.dimOpacity,
      blurSigma: _d(json['blurSigma'], 0, 50) ?? d.blurSigma,
      barColor: json['barColor'] is String ? json['barColor'] as String : null,
      gutterMarker: _b(json['gutterMarker']) ?? d.gutterMarker,
      focus: CodeFocusMode.fromName(json['focus']) ?? d.focus,
      startWithFirstStep:
          _b(json['startWithFirstStep']) ?? d.startWithFirstStep,
    );
  }
}

/// `dataJson.box` (07 §3.1, §3.4). Null values come from the palette or the
/// deck theme's code style.
final class CodeBoxStyle {
  const CodeBoxStyle({
    this.background,
    this.borderColor,
    this.borderWidth = 1,
    this.cornerRadius,
    this.shadow,
  });

  /// Color string; null = palette background.
  final String? background;

  /// Color string; null = no border.
  final String? borderColor;

  /// su.
  final double borderWidth;

  /// su; null = the theme's code corner radius.
  final double? cornerRadius;

  /// `none`, `soft`, `strong`; null = the theme's.
  final String? shadow;

  JsonMap toJson() => {
    'background': background,
    'border': borderColor == null
        ? null
        : {'color': borderColor, 'width': _n(borderWidth)},
    'cornerRadius': cornerRadius == null ? null : _n(cornerRadius!),
    'shadow': shadow,
  };

  /// Parses `box`; `border` is a color string or `{color, width}`.
  static CodeBoxStyle fromJson(Object? json) {
    if (json is! Map) return const CodeBoxStyle();
    final border = json['border'];
    String? borderColor;
    var borderWidth = 1.0;
    if (border is String) {
      borderColor = border;
    } else if (border is Map && border['color'] is String) {
      borderColor = border['color'] as String;
      borderWidth = _d(border['width'], 0, 50) ?? 1;
    }
    final shadow = json['shadow'];
    return CodeBoxStyle(
      background: json['background'] is String
          ? json['background'] as String
          : null,
      borderColor: borderColor,
      borderWidth: borderWidth,
      cornerRadius: _d(json['cornerRadius'], 0, 1000),
      shadow: shadow == 'none' || shadow == 'soft' || shadow == 'strong'
          ? shadow as String
          : null,
    );
  }
}

/// `dataJson.callouts` defaults (07 §4.4).
final class CodeCalloutDefaults {
  const CodeCalloutDefaults({this.style = 'bubble', this.maxWidth = 520});

  /// `bubble`, `label` or `pill`.
  final String style;

  /// su.
  final double maxWidth;

  JsonMap toJson() => {'style': style, 'maxWidth': _n(maxWidth)};

  static CodeCalloutDefaults fromJson(Object? json) {
    if (json is! Map) return const CodeCalloutDefaults();
    final style = json['style'];
    return CodeCalloutDefaults(
      style: calloutStyles.contains(style) ? style as String : 'bubble',
      maxWidth: _d(json['maxWidth'], 40, 4000) ?? 520,
    );
  }
}

/// Callout styles.
const calloutStyles = {'bubble', 'label', 'pill'};

/// The code element's `dataJson` (07 §3.1).
final class CodeElementData {
  const CodeElementData({
    this.language = '',
    this.lineNumbers = true,
    this.startLine = 1,
    this.wrap = false,
    this.fontSize,
    this.title,
    this.chrome,
    this.showLanguage = false,
    this.palette = 'auto',
    this.fontFamily,
    this.fontSizeMin = 14,
    this.fontSizeMax = 40,
    this.lineHeight = 1.5,
    this.ligatures = false,
    this.fitAcrossStates = true,
    this.tabSize = 2,
    this.padding = 32,
    this.box = const CodeBoxStyle(),
    this.highlightStyle = const CodeHighlightStyle(),
    this.copyButton = 'present',
    this.typing = TypingSettings.defaults,
    this.callouts = const CodeCalloutDefaults(),
  });

  /// Normalized language id; "" = plain text.
  final String language;
  final bool lineNumbers;

  /// Number shown for the first line.
  final int startLine;
  final bool wrap;

  /// su; null = auto size.
  final double? fontSize;

  /// Title text (tab, window title or caption); null = none.
  final String? title;

  /// `none`, `tab`, `window`, `caption`; null = the theme's default.
  final String? chrome;

  /// Language badge in the tab/window title.
  final bool showLanguage;

  /// `auto`, `light`, `dark` or a palette id (07 §2.5).
  final String palette;

  /// Font family; null = `@mono` (the deck theme's mono font).
  final String? fontFamily;

  /// Auto-size bounds (su).
  final double fontSizeMin;
  final double fontSizeMax;

  /// × font size.
  final double lineHeight;
  final bool ligatures;

  /// Auto size fits the largest state.
  final bool fitAcrossStates;

  /// 2, 4 or 8.
  final int tabSize;

  /// Inner padding (su).
  final double padding;
  final CodeBoxStyle box;
  final CodeHighlightStyle highlightStyle;

  /// `never`, `present`, `always` (07 §3.7).
  final String copyButton;

  /// Element defaults of state transitions (07 §5.3) incl. `crossSlideMode`.
  final TypingSettings typing;
  final CodeCalloutDefaults callouts;

  /// The chrome to draw ([chrome] or the theme default).
  CodeChrome chromeOr(String themeDefault) =>
      CodeChrome.fromName(chrome) ??
      CodeChrome.fromName(themeDefault) ??
      CodeChrome.window;

  JsonMap toJson() => {
    'v': 1,
    'language': language,
    'lineNumbers': lineNumbers,
    'startLine': startLine,
    'wrap': wrap,
    'fontSize': fontSize == null ? null : _n(fontSize!),
    'title': title,
    'chrome': chrome,
    'showLanguage': showLanguage,
    'palette': palette,
    'fontFamily': fontFamily,
    'fontSizeMin': _n(fontSizeMin),
    'fontSizeMax': _n(fontSizeMax),
    'lineHeight': _n(lineHeight),
    'ligatures': ligatures,
    'fitAcrossStates': fitAcrossStates,
    'tabSize': tabSize,
    'padding': _n(padding),
    'box': box.toJson(),
    'highlightStyle': highlightStyle.toJson(),
    'copyButton': copyButton,
    'typing': typing.toJson(),
    'callouts': callouts.toJson(),
  };

  /// Parses `dataJson` (a map or null); invalid values fall back to the
  /// defaults, unknown keys are ignored.
  static CodeElementData fromJson(Object? json) {
    if (json is! Map) return const CodeElementData();
    const d = CodeElementData();
    final tab = json['tabSize'];
    final copy = json['copyButton'];
    final chrome = json['chrome'];
    final min = _d(json['fontSizeMin'], 4, 400) ?? d.fontSizeMin;
    final max = _d(json['fontSizeMax'], 4, 400) ?? d.fontSizeMax;
    return CodeElementData(
      language: CodeLanguages.normalize(
        json['language'] is String ? json['language'] as String : '',
      ),
      lineNumbers: _b(json['lineNumbers']) ?? d.lineNumbers,
      startLine: _i(json['startLine'], 0, 1 << 30) ?? d.startLine,
      wrap: _b(json['wrap']) ?? d.wrap,
      fontSize: _d(json['fontSize'], 4, 400),
      title: json['title'] is String && (json['title'] as String).isNotEmpty
          ? json['title'] as String
          : null,
      chrome: CodeChrome.fromName(chrome is String ? chrome : null)?.name,
      showLanguage: _b(json['showLanguage']) ?? d.showLanguage,
      palette:
          json['palette'] is String && (json['palette'] as String).isNotEmpty
          ? json['palette'] as String
          : d.palette,
      fontFamily:
          json['fontFamily'] is String &&
              (json['fontFamily'] as String).isNotEmpty
          ? json['fontFamily'] as String
          : null,
      fontSizeMin: min < max ? min : max,
      fontSizeMax: min < max ? max : min,
      lineHeight: _d(json['lineHeight'], 0.8, 4) ?? d.lineHeight,
      ligatures: _b(json['ligatures']) ?? d.ligatures,
      fitAcrossStates: _b(json['fitAcrossStates']) ?? d.fitAcrossStates,
      tabSize: tab == 2 || tab == 4 || tab == 8 ? tab as int : d.tabSize,
      padding: _d(json['padding'], 0, 400) ?? d.padding,
      box: CodeBoxStyle.fromJson(json['box']),
      highlightStyle: CodeHighlightStyle.fromJson(json['highlightStyle']),
      copyButton: copy == 'never' || copy == 'present' || copy == 'always'
          ? copy as String
          : d.copyButton,
      typing: TypingSettings.fromJson(json['typing']),
      callouts: CodeCalloutDefaults.fromJson(json['callouts']),
    );
  }
}

Object _n(double v) => v == v.roundToDouble() ? v.toInt() : v;

double? _d(Object? v, double min, double max) =>
    v is num && v.isFinite ? v.toDouble().clamp(min, max) : null;

int? _i(Object? v, int min, int max) =>
    v is num && v.isFinite ? v.round().clamp(min, max) : null;

bool? _b(Object? v) => v is bool ? v : null;
