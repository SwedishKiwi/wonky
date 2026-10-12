/// Pure Dart core for Wonky Sheets: addressing, formula engine, number formats,
/// workbook model, import/export.
///
/// Sub-libraries (each owned by one workstream, see specs/wonky_sheets/13):
/// - `formula.dart`: addressing, formula parser/codec/evaluator/functions, recalculation.
/// - `model.dart`: workbook model, number formats, input parsing, mutation planner,
///   import/export, charts engine.
library;

export 'formula.dart';
export 'model.dart';
