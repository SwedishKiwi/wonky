import 'dart:convert';
import 'dart:typed_data';

import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

/// The result of `ScriptEndpoint.compile` (09 §9.1).
class ScriptCompileResult {
  const ScriptCompileResult({
    required this.ok,
    required this.sourceHash,
    this.diagnostics = const [],
    this.exportsJson,
  });

  final bool ok;
  final String sourceHash;
  final List<ScriptDiagnostic> diagnostics;
  final String? exportsJson;
}

/// The result of *Run on server* (09 §14.5).
class ServerRunResult {
  const ServerRunResult({
    required this.status,
    this.logs = const [],
    this.error,
    this.cellsWritten = 0,
    this.changeId,
  });

  final ExecutionStatus status;

  /// The server change of the run's writes (undo reverts it).
  final String? changeId;
  final List<LogEntry> logs;
  final ScriptFailure? error;
  final int cellsWritten;
}

/// The server side of scripting as the app sees it (`ScriptEndpoint`, 09
/// §8.4, §9, §11, §13). Tests supply a fake; offline calls throw.
abstract class ScriptBackend {
  /// EVC bytecode of the last good build, or null when there is none.
  Future<Uint8List?> bytecode(UuidValue item);

  /// Builds the project's synced sources.
  Future<ScriptCompileResult> compile(UuidValue item);

  /// Diagnostics of unsaved editor content.
  Future<List<ScriptDiagnostic>> analyze(
    UuidValue item,
    String fileName,
    String source,
  );

  /// *Run on server*.
  /// *Run on server*; [onLog] receives log lines while the function runs
  /// (09 §14.5; backends without streaming report them with the result).
  Future<ServerRunResult> runOnServer(
    UuidValue item,
    String functionName, {
    void Function(LogEntry entry)? onLog,
  });

  /// The executions log, newest first.
  Future<List<ScriptExecution>> executions(
    UuidValue item, {
    String? functionName,
    ScriptExecutionStatus? status,
    int limit = 50,
  });

  /// Uploads client executions.
  Future<void> reportExecutions(UuidValue item, List<ScriptExecution> rows);

  /// `UrlFetchApp` through the server proxy.
  Future<FetchResponseData> urlFetch(
    UuidValue item,
    FetchRequestData request, {
    required bool customFunction,
  });

  /// The caller's granted scopes.
  Future<Set<String>> authorization(UuidValue item);

  /// Grants [scopes]; returns the granted set.
  Future<Set<String>> authorize(UuidValue item, List<String> scopes);

  /// Revokes the caller's grant.
  Future<void> revokeAuthorization(UuidValue item);

  /// Installable onOpen triggers (09 §8.7.3).
  Future<void> notifyOpen(UuidValue item);

  /// Reverts a server change (*Revert changes* of a server execution);
  /// returns the id of the revert.
  Future<String> revertChange(String changeId);
}

/// [ScriptBackend] over the generated client.
class ServerScriptBackend implements ScriptBackend {
  ServerScriptBackend(this.client);

  final Client client;

  EndpointScript get _ep => client.script;

  @override
  Future<Uint8List?> bytecode(UuidValue item) async {
    final data = await _ep.bytecode(item);
    if (data.lengthInBytes == 0) return null;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  Future<ScriptCompileResult> compile(UuidValue item) async {
    final r = await _ep.compile(item);
    return ScriptCompileResult(
      ok: r.ok,
      sourceHash: r.sourceHash,
      diagnostics: ScriptDiagnostic.decodeList(r.diagnosticsJson),
      exportsJson: r.exportsJson,
    );
  }

  @override
  Future<List<ScriptDiagnostic>> analyze(
    UuidValue item,
    String fileName,
    String source,
  ) async =>
      ScriptDiagnostic.decodeList(await _ep.analyze(item, fileName, source));

  @override
  Future<ServerRunResult> runOnServer(
    UuidValue item,
    String functionName, {
    void Function(LogEntry entry)? onLog,
  }) async {
    ScriptRunResponse? r;
    var events = 0;
    try {
      await for (final e in _ep.runLive(item, functionName, null)) {
        events++;
        final m = (jsonDecode(e) as Map).cast<String, Object?>();
        final log = m['log'];
        if (log is Map) onLog?.call(LogEntry.fromJson(log.cast()));
        final result = m['result'];
        if (result is Map) {
          r = ScriptRunResponse.fromJson(result.cast<String, dynamic>());
        }
      }
    } on Object {
      // Streaming unavailable (old server, proxy): run without live logs.
      if (events > 0) rethrow;
    }
    r ??= await _ep.run(item, functionName, null);
    final err = r.errorJson;
    return ServerRunResult(
      status: ExecutionStatus.values.byName(
        r.status == ScriptExecutionStatus.queued ||
                r.status == ScriptExecutionStatus.running
            ? 'completed'
            : r.status.name,
      ),
      logs: parseLogLines(r.logs),
      error: err == null
          ? null
          : ScriptFailure.fromJson((jsonDecode(err) as Map).cast()),
      cellsWritten: r.cellsWritten,
      changeId: r.changeId?.uuid,
    );
  }

  @override
  Future<List<ScriptExecution>> executions(
    UuidValue item, {
    String? functionName,
    ScriptExecutionStatus? status,
    int limit = 50,
  }) => _ep.executions(
    item,
    functionName: functionName,
    status: status,
    limit: limit,
  );

  @override
  Future<void> reportExecutions(
    UuidValue item,
    List<ScriptExecution> rows,
  ) async {
    await _ep.reportExecutions(item, rows);
  }

  @override
  Future<FetchResponseData> urlFetch(
    UuidValue item,
    FetchRequestData request, {
    required bool customFunction,
  }) async {
    final r = await _ep.urlFetch(
      item,
      jsonEncode(request.toJson()),
      customFunction: customFunction,
    );
    return FetchResponseData(
      statusCode: r.statusCode,
      headers: (jsonDecode(r.headersJson) as Map).map(
        (k, v) => MapEntry('$k', '$v'),
      ),
      bytes: base64Decode(r.bodyBase64),
      contentText: r.contentText,
    );
  }

  @override
  Future<Set<String>> authorization(UuidValue item) async => {
    ...(await _ep.authorization(item)).scopes,
  };

  @override
  Future<Set<String>> authorize(UuidValue item, List<String> scopes) async => {
    ...(await _ep.authorize(item, scopes)).scopes,
  };

  @override
  Future<void> revokeAuthorization(UuidValue item) =>
      _ep.revokeAuthorization(item);

  @override
  Future<void> notifyOpen(UuidValue item) async {
    await _ep.notifyOpen(item);
  }

  @override
  Future<String> revertChange(String changeId) async =>
      (await client.sheets.revertChange(
        UuidValue.fromString(changeId),
      )).changeId.uuid;
}

/// Parses `ScriptExecution.logs` (JSON lines `{t, level, msg}`).
List<LogEntry> parseLogLines(String lines) {
  final out = <LogEntry>[];
  for (final line in const LineSplitter().convert(lines)) {
    if (line.trim().isEmpty) continue;
    try {
      final j = (jsonDecode(line) as Map).cast<String, Object?>();
      out.add(LogEntry.fromJson(j));
    } on Object {
      out.add(LogEntry(DateTime.now(), ScriptLogLevel.info, line));
    }
  }
  return out;
}
