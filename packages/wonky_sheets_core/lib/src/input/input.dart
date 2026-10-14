/// Typed-input parsing (03 §8.4, §8.6): numbers, currency, percent,
/// fractions, dates, times, booleans, errors, formulas and auto-links per
/// locale.
///
/// Entry point: [InputParser.parse] (typed text → [ParsedInput] with the
/// literal content or formula and the auto-detected number format).
library;

export 'date_input.dart';
export 'input_parser.dart';
export 'number_input.dart';
