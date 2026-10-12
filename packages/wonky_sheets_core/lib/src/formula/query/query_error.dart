/// A query parse or execution error; QUERY reports it as `#VALUE!` with
/// [QueryException.fullMessage] (05 §16.2).
final class QueryException implements Exception {
  /// Detail, e.g. `NO_COLUMN: F` or `PARSE_ERROR: Encountered "x" at line 1, column 12.`.
  final String message;

  const QueryException(this.message);

  /// `PARSE_ERROR` for [token] at the 1-based [line] and [column].
  factory QueryException.parse(String token, int line, int column) =>
      QueryException('PARSE_ERROR: Encountered "$token" at line $line, column $column.');

  /// Unknown column identifier.
  factory QueryException.noColumn(String id) => QueryException('NO_COLUMN: $id');

  /// A non-aggregated column outside the `group by` list.
  factory QueryException.addColToGroupBy(String id) =>
      QueryException('ADD_COL_TO_GROUP_BY_OR_AGG: $id');

  /// Message as shown in the cell's error tooltip (Sheets wording).
  String get fullMessage =>
      'Unable to parse query string for Function QUERY parameter 2: $message';

  @override
  String toString() => 'QueryException($message)';
}
