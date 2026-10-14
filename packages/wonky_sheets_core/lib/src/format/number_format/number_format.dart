/// Number formats (06 §5): parser, AST, formatter, presets, locale data,
/// automatic display, inference and decimals adjustment.
///
/// Entry points: [NumberFormatter] (value + pattern/preset + locale →
/// [FormattedValue] with segments and section color), [CellTextFormatter]
/// (a cell's computed value with its effective format), [NumberFormatPresets]
/// (preset ids, Format › Number menu, toolbar and shortcuts),
/// [DecimalsAdjuster] (increase/decrease decimals), [NumberFormatInfo]
/// (classification), [NumberFormatParser] (custom format dialog validation)
/// and [AutomaticFormatter] (Automatic display and column fitting).
library;

export 'ast.dart';
export 'automatic.dart';
export 'cache.dart';
export 'cell_text_formatter.dart';
export 'decimal_digits.dart';
export 'decimals.dart';
export 'font_size_steps.dart';
export 'format_info.dart';
export 'formatter.dart';
export 'inference.dart';
export 'locale_data.dart';
export 'number_formatter.dart';
export 'palette.dart';
export 'parser.dart';
export 'presets.dart';
export 'serial_calendar.dart';
