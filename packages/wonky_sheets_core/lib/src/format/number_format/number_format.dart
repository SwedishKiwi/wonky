/// Number formats (06 §5): the pattern engine of `wonky_numfmt` (parser, AST,
/// renderer, presets, locale data, automatic display, serial dates) plus the
/// cell adapters, inference and decimals adjustment.
///
/// Entry points: [NumberFormatter] (value + pattern/preset + locale →
/// [FormattedValue] with segments and section color), [CellTextFormatter]
/// (a cell's computed value with its effective format), [NumberFormatPresets]
/// (preset ids, Format › Number menu, toolbar and shortcuts),
/// [DecimalsAdjuster] (increase/decrease decimals), [NumberFormatInfo]
/// (classification), [NumberFormatParser] (custom format dialog validation)
/// and [AutomaticFormatter] (Automatic display and column fitting).
library;

export 'package:wonky_numfmt/wonky_numfmt.dart';

export 'cell_text_formatter.dart';
export 'decimals.dart';
export 'font_size_steps.dart';
export 'inference.dart';
export 'number_formatter.dart';
