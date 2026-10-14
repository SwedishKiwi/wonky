/// Limits of one execution (09 §10).
final class ExecutionLimits {
  /// Creates limits.
  const ExecutionLimits({
    required this.timeout,
    this.maxCellsRead = 10000000,
    this.maxCellsWritten = 2000000,
    this.maxLogBytes = 100 * 1024,
    this.maxBridgedValues = 5000000,
    this.maxListLength = 10000000,
    this.maxUiWait = const Duration(minutes: 5),
    this.maxPropertyValueBytes = 9 * 1024,
    this.maxPropertyStoreBytes = 500 * 1024,
    this.maxSleepMs = 5000,
    this.maxFetchAll = 20,
    this.writeBatchCells = 10000,
  });

  /// Client run / menu / macro / simple trigger: 30 s.
  static const client = ExecutionLimits(timeout: Duration(seconds: 30));

  /// `onSelectionChange`: 5 s.
  static const selectionChange = ExecutionLimits(timeout: Duration(seconds: 5));

  /// One custom function call: 3 s.
  static const customFunction = ExecutionLimits(timeout: Duration(seconds: 3));

  /// Server executions (triggers, MCP, run on server): 6 min.
  static const server = ExecutionLimits(timeout: Duration(minutes: 6));

  /// Maximum execution time (UI waits excluded).
  final Duration timeout;

  /// Cells read through the bridge.
  final int maxCellsRead;

  /// Cells written through the bridge.
  final int maxCellsWritten;

  /// Log size; later lines are dropped with a notice.
  final int maxLogBytes;

  /// Values boxed into the guest (approximates memory).
  final int maxBridgedValues;

  /// Largest list a script may allocate in one call (`List.filled`, …).
  final int maxListLength;

  /// Longest wait for an alert/prompt answer.
  final Duration maxUiWait;

  /// Property value size.
  final int maxPropertyValueBytes;

  /// Property store size.
  final int maxPropertyStoreBytes;

  /// `Utilities.sleep` per call.
  final int maxSleepMs;

  /// `UrlFetchApp.fetchAll` requests.
  final int maxFetchAll;

  /// Buffered cells before the guest flushes its write batch (09 §8.2.4).
  final int writeBatchCells;

  /// Copy with a different [timeout].
  ExecutionLimits withTimeout(Duration timeout) => ExecutionLimits(
    timeout: timeout,
    maxCellsRead: maxCellsRead,
    maxCellsWritten: maxCellsWritten,
    maxLogBytes: maxLogBytes,
    maxBridgedValues: maxBridgedValues,
    maxListLength: maxListLength,
    maxUiWait: maxUiWait,
    maxPropertyValueBytes: maxPropertyValueBytes,
    maxPropertyStoreBytes: maxPropertyStoreBytes,
    maxSleepMs: maxSleepMs,
    maxFetchAll: maxFetchAll,
    writeBatchCells: writeBatchCells,
  );

  /// Wire form (sent to the guest).
  Map<String, Object?> toWire() => {
    'timeoutMs': timeout.inMilliseconds,
    'maxBridgedValues': maxBridgedValues,
    'maxListLength': maxListLength,
    'maxSleepMs': maxSleepMs,
    'writeBatchCells': writeBatchCells,
  };
}

/// Counters of one execution (`ScriptExecution` stats).
final class ExecutionCounters {
  /// Host calls handled.
  int calls = 0;

  /// Cells read.
  int cellsRead = 0;

  /// Cells written.
  int cellsWritten = 0;

  /// URL fetches.
  int fetchCalls = 0;

  /// Bytes fetched.
  int fetchBytes = 0;

  /// Time spent waiting for the user (alerts, prompts).
  Duration uiWait = Duration.zero;

  /// JSON form.
  Map<String, Object?> toJson() => {
    'calls': calls,
    'cellsRead': cellsRead,
    'cellsWritten': cellsWritten,
    'fetchCalls': fetchCalls,
    'fetchBytes': fetchBytes,
    'uiWaitMs': uiWait.inMilliseconds,
  };
}
