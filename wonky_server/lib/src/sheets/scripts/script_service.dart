import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    show OfflineSyncSpace, OfflineSyncDatabaseAccess;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    hide ActorKind, CellInput, TriggerKind;
import 'package:wonky_sheets_script/compiler.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';
import 'package:wonky_sync_models/ids.dart';

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/config/wonky_config.dart';
import '../../platform/files/file_service.dart';
import '../../platform/sharing/access_service.dart';
import '../headless/headless_workbook_provider.dart';
import '../mcp/sheets_bulk_writer.dart';
import '../sheets_service.dart';
import '../../platform/spaces/space_service.dart';
import '../sync/server_sheets_writer.dart';
import '../sync/sync_db.dart';
import '../sync/synced_tables.dart' show deleteSyncedRow, updateSyncedRow;
import 'script_limits.dart';
import 'script_runner_pool.dart';
import 'url_fetch_proxy.dart';

/// Server side of Sheets scripting (Sheets 09 §8.5, §9, §10, §11, §13):
/// compiling projects to `ScriptBuild` rows, running functions on the
/// server, the executions log, authorizations, quotas and the URL fetch
/// proxy.
abstract final class ScriptService {
  /// Executions kept per spreadsheet (09 §13.1).
  static const maxExecutionsPerSpreadsheet = 10000;

  /// Execution retention.
  static const executionRetention = Duration(days: 30);

  /// URL fetches per user per day.
  static const dailyFetchCalls = 20000;

  /// Fetched bytes per user per day.
  static const dailyFetchBytes = 500 * 1024 * 1024;

  /// The runner used for server executions (tests may replace it).
  static ScriptRunner? runnerOverride;

  /// The URL fetch proxy (tests may replace it).
  static UrlFetchProxy? proxyOverride;

  static ScriptRunner get _runner =>
      runnerOverride ??
      ScriptRunnerPool.instance(size: WonkyConfig.current.scriptPoolSize);

  static UrlFetchProxy get proxy =>
      proxyOverride ??
      UrlFetchProxy(allowHttp: WonkyConfig.current.scriptAllowHttp);

  static final _programs = <String, ScriptProgram>{};

  /// Throws unless scripting is enabled (`wonky.features.scripting`).
  static void requireEnabled() {
    if (!WonkyConfig.current.scriptingEnabled) {
      throw Errors.unavailable('Scripts are disabled on this server.');
    }
  }

  // -------------------------------------------------------------- project

  /// The script project of [space], if any.
  static Future<ScriptProject?> project(Session session, UuidValue space) =>
      ScriptProject.db.findFirstRow(
        syncSessionOf(session),
        where: (t) => t.spreadsheetId.equals(space),
        orderBy: (t) => t.id,
      );

  /// The files of [project] in order.
  static Future<List<ScriptFile>> files(Session session, UuidValue project) =>
      ScriptFile.db.find(
        syncSessionOf(session),
        where: (t) => t.projectId.equals(project),
        orderBy: (t) => t.sortKey,
      );

  /// The build row of [project].
  static Future<ScriptBuild?> build(Session session, UuidValue project) =>
      ScriptBuild.db.findById(
        syncSessionOf(session),
        UuidValue.fromString(SheetsIds.scriptBuildId(project.uuid)),
      );

  // -------------------------------------------------------------- compile

  /// Compiles the project of the spreadsheet [uuid] (item or space uuid)
  /// and writes its `ScriptBuild` row as [actor] (09 §9.1). Unchanged
  /// sources return the existing build.
  static Future<ScriptCompileResponse> compile(
    Session session,
    Actor actor,
    UuidValue uuid, {
    bool force = false,
  }) async {
    requireEnabled();
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.editor,
    );
    final space = item.contentRef!;
    final p = await project(session, space);
    if (p == null) throw Errors.notFound('Script');
    // "Latest wins" (09 §9.2): saves arriving during a compile share one
    // follow-up compile of the newest sources.
    return CompileCoalescer.instance.run(
      p.id.uuid,
      () => _compile(session, actor, item, p, force: force),
    );
  }

  static Future<ScriptCompileResponse> _compile(
    Session session,
    Actor actor,
    DriveItem item,
    ScriptProject p, {
    required bool force,
  }) async {
    final space = item.contentRef!;
    final sources = [
      for (final f in await files(session, p.id))
        ScriptSourceFile(f.name, f.source),
    ];
    final hash = ScriptCompiler.sourceHash(sources);
    final existing = await build(session, p.id);
    if (!force && existing != null && existing.sourceHash == hash) {
      return ScriptCompileResponse(
        ok: existing.status == ScriptBuildStatus.ok,
        compiled: false,
        sourceHash: hash,
        buildId: existing.id,
        diagnosticsJson: existing.diagnosticsJson,
        exportsJson: existing.exportsJson,
      );
    }
    if (!ScriptRateLimiter.compiles.tryAcquire(p.id.uuid)) {
      final wait = ScriptRateLimiter.compiles.retryAfter(p.id.uuid);
      throw Errors.limit(
        'This script was built 20 times in the last hour; try again in '
        '${(wait?.inMinutes ?? 0) + 1} min.',
        detailsJson: jsonEncode({'retryAfterSeconds': wait?.inSeconds ?? 60}),
      );
    }
    final result = await Isolate.run(
      () => const ScriptCompiler().compile(sources),
      debugName: 'wonky-script-compiler',
    ).timeout(const Duration(seconds: 60));
    final now = clock.now().toUtc();
    final buildId = UuidValue.fromString(SheetsIds.scriptBuildId(p.id.uuid));
    UuidValue? fileUuid;
    if (result.ok) {
      final stored = await FileService.storeServerFile(
        session,
        ownerId: actor.userId,
        itemId: item.id,
        kind: StoredFileKind.scriptBytecode,
        fileName: '${result.sourceHash}.evc',
        mimeType: 'application/octet-stream',
        bytes: result.bytecode!,
      );
      fileUuid = stored.fileUuid;
      _programs[result.sourceHash] = result.program!;
    }
    final diagnosticsJson = ScriptDiagnostic.encodeList(result.diagnostics);
    final exportsJson = result.exports.encode();
    final columns = <String, Object?>{
      'projectId': p.id,
      'status':
          (result.ok ? ScriptBuildStatus.ok : ScriptBuildStatus.errors).name,
      'sourceHash': hash,
      'bytecodeFileUuid': fileUuid,
      'diagnosticsJson': diagnosticsJson,
      'exportsJson': exportsJson,
      'apiVersion': wonkyApiVersion,
      'compilerVersion': ScriptCompiler.compilerVersion,
      'requestedBy': actor.authUserId,
      'builtAt': now,
      if (result.ok) ...{
        'lastGoodSourceHash': hash,
        'lastGoodBytecodeFileUuid': fileUuid,
        'lastGoodExportsJson': exportsJson,
        'lastGoodBuiltAt': now,
      },
    };
    await SpaceService.ensureWriter(
      session,
      actor,
      item,
      reason: SubscriptionReason.script,
    );
    await ServerSheetsWriter.apply(
      session,
      actor: actor.copyWith(kind: ActorKind.system),
      spaceUuid: space,
      changes: [
        if (existing == null)
          RowChange.insert(SheetsTables.scriptBuild, buildId.uuid, {
            ...columns,
            'createdAt': now,
          })
        else
          RowChange.update(
            SheetsTables.scriptBuild,
            buildId.uuid,
            {for (final k in columns.keys) k: null},
            columns,
          ),
      ],
      label: 'Build script',
      kinds: const {ChangeKinds.scripts},
    );
    return ScriptCompileResponse(
      ok: result.ok,
      compiled: true,
      sourceHash: hash,
      buildId: buildId,
      diagnosticsJson: diagnosticsJson,
      exportsJson: exportsJson,
    );
  }

  /// Writes the script file [name] as [actor] (MCP `update_script_file`):
  /// creates the project and the file when [createIfMissing]; fails with a
  /// conflict when [baseHash] does not match. Returns the content hash.
  static Future<String> writeFile(
    Session session,
    Actor actor,
    DriveItem item,
    String name,
    String source, {
    String? baseHash,
    bool createIfMissing = false,
  }) async {
    requireEnabled();
    final space = item.contentRef!;
    final now = clock.now().toUtc();
    final hash = ScriptCompiler.contentHash(source);
    final changes = <RowChange>[];
    var p = await project(session, space);
    UuidValue projectId;
    if (p == null) {
      if (!createIfMissing) throw Errors.notFound('Script');
      projectId = const Uuid().v7obj();
      changes.add(
        RowChange.insert(SheetsTables.scriptProject, projectId.uuid, {
          'spreadsheetId': space,
          'name': '${item.name} script',
          'settingsJson': '{}',
          'createdAt': now,
        }),
      );
    } else {
      projectId = p.id;
    }
    final existing = p == null ? <ScriptFile>[] : await files(session, p.id);
    final file = existing.where((f) => f.name == name).firstOrNull;
    if (file == null) {
      if (!createIfMissing) throw Errors.notFound('Script file $name');
      if (existing.length >= ScriptCompiler.maxFiles) {
        throw Errors.limit('A script can have at most 50 files.');
      }
      changes.add(
        RowChange.insert(SheetsTables.scriptFile, const Uuid().v7(), {
          'projectId': projectId,
          'name': name,
          'sortKey': FractionalIndex.after(
            existing.isEmpty ? null : existing.last.sortKey,
          ),
          'source': source,
          'contentHash': hash,
          'updatedBy': actor.authUserId,
          'updatedAt': now,
          'createdAt': now,
        }),
      );
    } else {
      if (baseHash != null && baseHash != file.contentHash) {
        throw Errors.conflict(
          '$name changed since you read it (content hash '
          '${file.contentHash}).',
        );
      }
      changes.add(
        RowChange.update(
          SheetsTables.scriptFile,
          file.id.uuid,
          {
            'source': file.source,
            'contentHash': file.contentHash,
            'updatedBy': file.updatedBy,
            'updatedAt': file.updatedAt,
          },
          {
            'source': source,
            'contentHash': hash,
            'updatedBy': actor.authUserId,
            'updatedAt': now,
          },
        ),
      );
    }
    await SpaceService.ensureWriter(
      session,
      actor,
      item,
      reason: SubscriptionReason.script,
    );
    await ServerSheetsWriter.apply(
      session,
      actor: actor,
      spaceUuid: space,
      changes: changes,
      label: 'Edit script',
      kinds: const {ChangeKinds.scripts},
    );
    return hash;
  }

  /// Deletes the script file [name] as [actor].
  static Future<void> deleteFile(
    Session session,
    Actor actor,
    DriveItem item,
    String name,
  ) async {
    requireEnabled();
    final p = await project(session, item.contentRef!);
    final file = p == null
        ? null
        : (await files(session, p.id)).where((f) => f.name == name).firstOrNull;
    if (file == null) throw Errors.notFound('Script file $name');
    await SpaceService.ensureWriter(
      session,
      actor,
      item,
      reason: SubscriptionReason.script,
    );
    await ServerSheetsWriter.apply(
      session,
      actor: actor,
      spaceUuid: item.contentRef!,
      changes: [
        RowChange.delete(SheetsTables.scriptFile, file.id.uuid, file.toJson()),
      ],
      label: 'Delete $name',
      kinds: const {ChangeKinds.scripts},
    );
  }

  /// Diagnostics for unsaved editor content (09 §9.5).
  static Future<String> analyze(
    Session session,
    Actor actor,
    UuidValue uuid,
    String fileName,
    String source,
  ) async {
    requireEnabled();
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.editor,
    );
    if (!ScriptRateLimiter.analyses.tryAcquire('${actor.userId}')) {
      throw Errors.limit(
        'Too many analysis requests; diagnostics update after the next save.',
      );
    }
    final p = await project(session, item.contentRef!);
    final names = p == null
        ? <String>{}
        : {for (final f in await files(session, p.id)) f.name};
    final diagnostics = await Isolate.run(
      () => const ScriptCompiler().analyze(
        fileName,
        source,
        projectFiles: names,
      ),
    );
    return ScriptDiagnostic.encodeList(diagnostics);
  }

  /// The last good program of [project], or null (09 §9.4).
  static Future<ScriptProgram?> lastGoodProgram(
    Session session,
    UuidValue project,
  ) async {
    final b = await build(session, project);
    final hash = b?.lastGoodSourceHash;
    final fileUuid = b?.lastGoodBytecodeFileUuid;
    final exportsJson = b?.lastGoodExportsJson;
    if (b == null || hash == null || fileUuid == null || exportsJson == null) {
      return null;
    }
    final cached = _programs[hash];
    if (cached != null) return cached;
    final file = await FileService.byUuid(session, fileUuid);
    if (file == null) return null;
    final data = await FileService.readBytes(session, file);
    final program = ScriptProgram(
      buildHash: hash,
      bytecode: Uint8List.sublistView(data),
      exports: ScriptExports.decode(exportsJson),
    );
    if (_programs.length > 64) _programs.remove(_programs.keys.first);
    return _programs[hash] = program;
  }

  /// The bytecode of the last good build of a spreadsheet (clients cache it
  /// in their local blob cache; 09 §8.8).
  static Future<ByteData> bytecode(
    Session session,
    Actor actor,
    UuidValue uuid,
  ) async {
    requireEnabled();
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final p = await project(session, item.contentRef!);
    if (p == null) throw Errors.notFound('Script');
    final program = await lastGoodProgram(session, p.id);
    if (program == null) throw Errors.notFound('Script build');
    return ByteData.sublistView(program.bytecode);
  }

  // -------------------------------------------------------- authorization

  static Future<ScriptAuthorization?> _authorizationOf(
    Session session,
    int userId,
    UuidValue space,
  ) => ScriptAuthorization.db.findFirstRow(
    session,
    where: (t) =>
        t.userId.equals(userId) &
        t.spreadsheetUuid.equals(space) &
        t.revokedAt.equals(null),
  );

  /// The scopes [actor] granted for the spreadsheet.
  static Future<ScriptAuthorizationView> authorization(
    Session session,
    Actor actor,
    UuidValue uuid,
  ) async {
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final a = await _authorizationOf(session, actor.userId, item.contentRef!);
    return ScriptAuthorizationView(
      scopes: a?.scopes ?? const [],
      grantedAt: a?.grantedAt,
    );
  }

  /// Grants [scopes] (the authorization dialog's *Allow*, 09 §11.2).
  static Future<ScriptAuthorizationView> authorize(
    Session session,
    Actor actor,
    UuidValue uuid,
    List<String> scopes,
  ) async {
    requireEnabled();
    if (actor.kind != ActorKind.user) {
      throw Errors.forbidden('Only people can authorize scripts.');
    }
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final unknown = scopes.where(
      (s) => !ScriptScopes.authorizable.contains(s),
    );
    if (unknown.isNotEmpty) {
      throw Errors.invalid('Unknown scope ${unknown.first}');
    }
    final space = item.contentRef!;
    final now = clock.now().toUtc();
    final existing = await ScriptAuthorization.db.findFirstRow(
      session,
      where: (t) =>
          t.userId.equals(actor.userId) & t.spreadsheetUuid.equals(space),
    );
    final merged = {
      if (existing != null && existing.revokedAt == null) ...existing.scopes,
      ...scopes,
    }.toList()..sort();
    if (existing == null) {
      await ScriptAuthorization.db.insertRow(
        session,
        ScriptAuthorization(
          userId: actor.userId,
          spreadsheetUuid: space,
          scopes: merged,
          grantedAt: now,
        ),
      );
    } else {
      await ScriptAuthorization.db.updateRow(
        session,
        existing.copyWith(scopes: merged, grantedAt: now, revokedAt: null),
      );
    }
    return ScriptAuthorizationView(scopes: merged, grantedAt: now);
  }

  /// *Revoke my authorization*: removes the grant and disables the user's
  /// installable triggers of the spreadsheet (09 §11.2).
  static Future<void> revokeAuthorization(
    Session session,
    Actor actor,
    UuidValue uuid,
  ) async {
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final space = item.contentRef!;
    final existing = await _authorizationOf(session, actor.userId, space);
    if (existing != null) {
      await ScriptAuthorization.db.updateRow(
        session,
        existing.copyWith(revokedAt: clock.now().toUtc()),
      );
    }
    final p = await project(session, space);
    if (p == null) return;
    final triggers = await ScriptTrigger.db.find(
      syncSessionOf(session),
      where: (t) =>
          t.projectId.equals(p.id) & t.runAsUserId.equals(actor.authUserId),
    );
    for (final t in triggers) {
      await _disableTrigger(session, t.id, space, 'Authorization revoked.');
    }
  }

  static Future<void> _disableTrigger(
    Session session,
    UuidValue triggerId,
    UuidValue space,
    String reason,
  ) async {
    final state = await ScriptTriggerState.db.findFirstRow(
      session,
      where: (t) => t.triggerId.equals(triggerId),
    );
    if (state == null) {
      await ScriptTriggerState.db.insertRow(
        session,
        ScriptTriggerState(
          triggerId: triggerId,
          spreadsheetUuid: space,
          disabledReason: reason,
        ),
      );
    } else {
      await ScriptTriggerState.db.updateRow(
        session,
        state.copyWith(disabledReason: reason, nextRunAt: null),
      );
    }
  }

  // ---------------------------------------------------------------- quotas

  static DateTime _today() {
    final n = clock.now().toUtc();
    return DateTime.utc(n.year, n.month, n.day);
  }

  /// Today's usage of [userId] (created on demand).
  static Future<ScriptQuotaUsage> usage(Session session, int userId) async {
    final day = _today();
    final found = await ScriptQuotaUsage.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId) & t.day.equals(day),
    );
    if (found != null) return found;
    try {
      return await ScriptQuotaUsage.db.insertRow(
        session,
        ScriptQuotaUsage(userId: userId, day: day),
      );
    } on DatabaseQueryException {
      return (await ScriptQuotaUsage.db.findFirstRow(
        session,
        where: (t) => t.userId.equals(userId) & t.day.equals(day),
      ))!;
    }
  }

  static Future<void> _addUsage(
    Session session,
    int userId, {
    int serverMs = 0,
    int clientMs = 0,
    int fetchCalls = 0,
    int fetchBytes = 0,
    int triggerRuns = 0,
  }) async {
    final u = await usage(session, userId);
    await session.db.unsafeExecute(
      'UPDATE "script_quota_usage" SET '
      '"serverRuntimeMs" = "serverRuntimeMs" + @server, '
      '"clientRuntimeMs" = "clientRuntimeMs" + @client, '
      '"urlFetchCalls" = "urlFetchCalls" + @calls, '
      '"urlFetchBytes" = "urlFetchBytes" + @bytes, '
      '"triggerRuns" = "triggerRuns" + @runs '
      'WHERE "id" = @id',
      parameters: QueryParameters.named({
        'server': serverMs,
        'client': clientMs,
        'calls': fetchCalls,
        'bytes': fetchBytes,
        'runs': triggerRuns,
        'id': u.id,
      }),
    );
  }

  // ------------------------------------------------------------ fetching

  static List<String> _allowlist(ScriptProject? p) {
    if (p == null) return const [];
    try {
      final s = jsonDecode(p.settingsJson);
      if (s is Map && s['urlAllowlist'] is List) {
        return [for (final h in s['urlAllowlist'] as List) '$h'];
      }
    } on FormatException {
      // Invalid settings: no allowlist.
    }
    return const [];
  }

  static Future<FetchResponseData> _fetch(
    Session session,
    int userId,
    ScriptProject? p,
    FetchRequestData request, {
    required bool customFunction,
  }) async {
    final u = await usage(session, userId);
    if (u.urlFetchCalls >= dailyFetchCalls) {
      throw const FetchFailure(
        'URL fetch quota exceeded (20,000 per day); it resets at midnight UTC.',
        code: 'quota_exceeded',
      );
    }
    if (u.urlFetchBytes >= dailyFetchBytes) {
      throw const FetchFailure(
        'URL fetch quota exceeded (500 MB per day); it resets at midnight UTC.',
        code: 'quota_exceeded',
      );
    }
    final allowlist = _allowlist(p);
    if (customFunction) {
      // 09 §8.3 step 8: cached for 1 h (the allowlist still applies).
      final hit = ScriptFetchCache.instance.get(request);
      if (hit != null && allowlist.isNotEmpty) return hit;
    }
    try {
      final r = await proxy.fetch(
        request,
        allowlist: allowlist,
        customFunction: customFunction,
      );
      if (customFunction) ScriptFetchCache.instance.put(request, r);
      await _addUsage(
        session,
        userId,
        fetchCalls: 1,
        fetchBytes: r.bytes.length,
      );
      return r;
    } on FetchFailure {
      await _addUsage(session, userId, fetchCalls: 1);
      rethrow;
    }
  }

  /// `ScriptEndpoint.urlFetch`: client executions fetch through the server
  /// (09 §8.3). Needs the `external_request` grant, except custom functions
  /// with an allowlist.
  static Future<ScriptFetchResponse> urlFetch(
    Session session,
    Actor actor,
    UuidValue uuid,
    String requestJson, {
    bool customFunction = false,
  }) async {
    requireEnabled();
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final space = item.contentRef!;
    if (!customFunction) {
      final a = await _authorizationOf(session, actor.userId, space);
      if (a == null || !a.scopes.contains(ScriptScopes.externalRequest)) {
        throw Errors.forbidden(
          'authorization_required: the script needs permission to connect '
          'to external services.',
        );
      }
    }
    final request = FetchRequestData.fromJson(
      (jsonDecode(requestJson) as Map).cast<String, Object?>(),
    );
    final FetchResponseData r;
    try {
      r = await _fetch(
        session,
        actor.userId,
        await project(session, space),
        request,
        customFunction: customFunction,
      );
    } on FetchFailure catch (e) {
      throw WonkyException(
        code: e.code == 'quota_exceeded'
            ? WonkyErrorCode.limitExceeded
            : WonkyErrorCode.invalidArgument,
        message: e.message,
        detailsJson: jsonEncode({'code': e.code, 'statusCode': e.statusCode}),
      );
    }
    return ScriptFetchResponse(
      statusCode: r.statusCode,
      headersJson: jsonEncode(r.headers),
      bodyBase64: base64Encode(r.bytes),
      contentText: r.contentText,
    );
  }

  // ------------------------------------------------------------- running

  /// Runs [functionName] on the server as [actor] (09 §8.5): Run on server,
  /// MCP `sheets.run_function`, installable triggers.
  ///
  /// The function runs against a private copy of the headless workbook;
  /// its writes are committed afterwards in one recorded change (revertible
  /// with `changes.revert`) and written through to the cache.
  static Future<ScriptRunResponse> run(
    Session session,
    Actor actor,
    UuidValue uuid,
    String functionName, {
    List<Object?> args = const [],
    ScriptExecutionKind kind = ScriptExecutionKind.editor,
    ScriptEvent? event,
    UuidValue? triggerId,
    Duration? timeout,
    bool requireAuthorization = true,
    void Function(LogEntry entry)? onLog,
  }) async {
    requireEnabled();
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final space = item.contentRef!;
    final role =
        await AccessService.effectiveRole(session, actor.userId, item) ??
        Role.viewer;
    final p = await project(session, space);
    final program = p == null ? null : await lastGoodProgram(session, p.id);
    if (p == null || program == null) {
      throw Errors.notFound('Script build');
    }
    if (program.exports.function(functionName) == null) {
      throw Errors.notFound('Script function "$functionName"');
    }
    final grant = await _authorizationOf(session, actor.userId, space);
    final granted = {...?grant?.scopes};
    final missing = [
      for (final s in program.exports.scopes)
        if (!ScriptScopes.implicit.contains(s) && !granted.contains(s)) s,
    ];
    if (requireAuthorization && missing.isNotEmpty) {
      throw Errors.forbidden(
        'authorization_required: the script needs ${missing.join(', ')}; '
        'run it once in the app to authorize it.',
      );
    }
    final profile = await UserProfile.db.findById(session, actor.userId);
    final user = ScriptUser(
      id: actor.authUserId.uuid,
      email: profile?.email ?? '',
      name: profile?.displayName ?? '',
    );

    final started = clock.now().toUtc();
    final quota = WonkyConfig.current.scriptDailyQuotaMs;
    final today = await usage(session, actor.userId);
    if (today.serverRuntimeMs >= quota) {
      final skipped = await _log(
        session,
        space: space,
        projectId: p.id,
        functionName: functionName,
        kind: kind,
        triggerId: triggerId,
        actor: actor,
        status: ScriptExecutionStatus.quotaExceeded,
        buildHash: program.buildHash,
        started: started,
        duration: Duration.zero,
        logs: '',
        error:
            'Daily server script runtime exceeded; it resets at '
            'midnight UTC.',
      );
      return ScriptRunResponse(
        executionId: skipped.uuid,
        status: ScriptExecutionStatus.quotaExceeded,
        logs: '',
        errorJson: jsonEncode({
          'type': 'QuotaExceededException',
          'message': skipped.errorMessage,
        }),
        cellsWritten: 0,
      );
    }

    final headless = await HeadlessWorkbookProvider.open(session, space);
    final model = WorkbookModel.fromRows(
      headless.model.spreadsheetId,
      headless.model.allRows(),
    );
    // The headless workbook holds the grid; the script tables the API
    // touches (project, triggers, document properties) come from the
    // database.
    final db = syncSessionOf(session);
    model.upsertRow(SheetsTables.scriptProject, p.id.uuid, p.toJson());
    for (final t in await ScriptTrigger.db.find(
      db,
      where: (t) => t.projectId.equals(p.id),
    )) {
      model.upsertRow(SheetsTables.scriptTrigger, t.id.uuid, {
        ...t.toJson(),
        'kind': t.kind.name,
      });
    }
    for (final prop in await ScriptProperty.db.find(
      db,
      where: (t) => t.projectId.equals(p.id),
    )) {
      model.upsertRow(SheetsTables.scriptProperty, prop.id.uuid, prop.toJson());
    }
    final access = ModelWorkbookAccess(
      model: model,
      userId: actor.authUserId.uuid,
    );
    final limitMs =
        timeout?.inMilliseconds ?? WonkyConfig.current.scriptServerTimeoutMs;
    final userProperties = await ServerUserProperties.load(
      session,
      user: actor.authUserId,
      spreadsheet: space,
    );
    final host = ScriptHost(
      workbook: access,
      context: ExecutionContext(
        kind: ExecutionKind.values.byName(kind.name),
        activeUser: user,
        role: role,
        grantedScopes: granted,
        isServer: true,
        spreadsheetUrl:
            '${WonkyConfig.current.publicWebUrl ?? WonkyConfig.productionWebUrl}'
            '/sheets/s/${item.uuid.uuid}',
      ),
      limits: ExecutionLimits.server.withTimeout(
        Duration(milliseconds: limitMs),
      ),
      fetcher: _ServerFetcher(session, actor.userId, p),
      userProperties: userProperties,
      knownFunctions: {for (final f in program.exports.functions) f.name},
      locks: MemoryScriptLocks.shared,
      onLog: onLog,
    );
    final ExecutionResult result;
    try {
      result = await runScript(
        runner: _runner,
        host: host,
        program: program,
        functionName: functionName,
        args: args,
        event: event,
      );
    } finally {
      access.dispose();
    }
    try {
      await userProperties.flush(session);
    } on Exception catch (e) {
      session.log(
        'Storing user properties of a script run failed: $e',
        level: LogLevel.warning,
      );
    }

    UuidValue? changeId;
    var status = result.status;
    var errorJson = result.error == null
        ? null
        : jsonEncode(result.error!.toJson());
    final changes = [for (final a in result.applied) ...a.plan.changes];
    if (changes.isNotEmpty) {
      try {
        final commitKind = switch (kind) {
          ScriptExecutionKind.mcp => ActorKind.mcp,
          ScriptExecutionKind.ai => ActorKind.ai,
          _ => ActorKind.script,
        };
        changeId = await HeadlessWorkbookProvider.withWriteLock(
          space,
          () async {
            final (id, applied) = await SheetsBulkWriter.applyRecorded(
              session,
              actor: actor.copyWith(kind: commitKind),
              item: item,
              changes: changes,
              label: 'Script: $functionName',
              plans: [for (final a in result.applied) a.plan],
            );
            HeadlessWorkbookProvider.writeThrough(space, applied.applied);
            return id;
          },
        );
      } on Exception catch (e) {
        status = ExecutionStatus.failed;
        errorJson = jsonEncode({
          'type': 'ScriptException',
          'message': 'The changes could not be saved: $e',
        });
      }
    }
    final duration = result.duration;
    await _addUsage(
      session,
      actor.userId,
      serverMs: duration.inMilliseconds - result.counters.uiWait.inMilliseconds,
      triggerRuns: triggerId == null ? 0 : 1,
    );
    final error = errorJson == null
        ? null
        : (jsonDecode(errorJson) as Map).cast<String, Object?>();
    final logged = await _log(
      session,
      space: space,
      projectId: p.id,
      functionName: functionName,
      kind: kind,
      triggerId: triggerId,
      actor: actor,
      status: _status(status),
      buildHash: program.buildHash,
      started: result.startedAt.toUtc(),
      duration: duration,
      logs: result.logsJsonLines,
      error: error?['message'] as String?,
      errorStackJson: error?['frames'] == null
          ? null
          : jsonEncode(error!['frames']),
      changeId: changeId,
      cellsRead: result.counters.cellsRead,
      cellsWritten: result.counters.cellsWritten,
      fetchCalls: result.counters.fetchCalls,
    );
    return ScriptRunResponse(
      executionId: logged.uuid,
      status: _status(status),
      resultJson: result.ok ? jsonEncode(_jsonable(result.result)) : null,
      logs: result.logsJsonLines,
      errorJson: errorJson,
      changeId: changeId,
      cellsWritten: result.counters.cellsWritten,
    );
  }

  static ScriptExecutionStatus _status(ExecutionStatus s) =>
      ScriptExecutionStatus.values.byName(s.name);

  static Object? _jsonable(Object? v) => switch (v) {
    DateTime d => d.toUtc().toIso8601String(),
    CellError e => e.code,
    Map<Object?, Object?> m => {
      for (final e in m.entries) '${e.key}': _jsonable(e.value),
    },
    List<Object?> l => [for (final e in l) _jsonable(e)],
    double d when !d.isFinite => null,
    _ => v,
  };

  static Future<ScriptExecution> _log(
    Session session, {
    required UuidValue space,
    required UuidValue? projectId,
    required String functionName,
    required ScriptExecutionKind kind,
    required UuidValue? triggerId,
    required Actor actor,
    required ScriptExecutionStatus status,
    required String buildHash,
    required DateTime started,
    required Duration duration,
    required String logs,
    String? error,
    String? errorStackJson,
    UuidValue? changeId,
    int cellsRead = 0,
    int cellsWritten = 0,
    int fetchCalls = 0,
    UuidValue? executionId,
  }) => ScriptExecution.db.insertRow(
    session,
    ScriptExecution(
      uuid: executionId ?? const Uuid().v7obj(),
      spreadsheetUuid: space,
      projectId: projectId,
      functionName: functionName,
      kind: kind,
      triggerId: triggerId,
      userId: actor.userId,
      runAsUserId: actor.userId,
      runtime: ScriptRuntimeKind.server,
      status: status,
      buildSourceHash: buildHash,
      startedAt: started,
      durationMs: duration.inMilliseconds,
      logs: _truncate(logs),
      errorMessage: error,
      errorStackJson: errorStackJson,
      changeId: changeId,
      cellsRead: cellsRead,
      cellsWritten: cellsWritten,
      fetchCalls: fetchCalls,
    ),
  );

  static String _truncate(String logs) {
    const max = 100 * 1024;
    if (logs.length <= max) return logs;
    return '${logs.substring(0, max)}\n'
        '${jsonEncode({'t': clock.now().toUtc().toIso8601String(), 'level': 'system', 'msg': 'Log truncated.'})}';
  }

  // ----------------------------------------------------------- executions

  /// The executions of a spreadsheet, newest first (09 §13.3): editors see
  /// all, others their own.
  static Future<List<ScriptExecution>> executions(
    Session session,
    Actor actor,
    UuidValue uuid, {
    String? functionName,
    ScriptExecutionStatus? status,
    DateTime? before,
    int limit = 50,
  }) async {
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final role = await AccessService.effectiveRole(
      session,
      actor.userId,
      item,
    );
    final space = item.contentRef!;
    final all = role != null && role >= Role.editor;
    return ScriptExecution.db.find(
      session,
      where: (t) {
        Expression e = t.spreadsheetUuid.equals(space);
        if (!all) e = e & t.userId.equals(actor.userId);
        if (functionName != null) e = e & t.functionName.equals(functionName);
        if (status != null) e = e & t.status.equals(status);
        if (before != null) e = e & (t.startedAt < before);
        return e;
      },
      orderBy: (t) => t.startedAt.desc(),
      limit: limit.clamp(1, 200),
    );
  }

  /// Client executions uploaded in batches (09 §13.1). The server owns the
  /// user and the runtime fields; client runtime counts toward the (soft)
  /// client quota.
  static Future<int> reportExecutions(
    Session session,
    Actor actor,
    UuidValue uuid,
    List<ScriptExecution> executions,
  ) async {
    requireEnabled();
    if (executions.length > 1000) {
      throw Errors.invalid('At most 1,000 executions per report.');
    }
    final item = await SheetsService.byItemOrSpace(
      session,
      actor,
      uuid,
      Role.viewer,
    );
    final space = item.contentRef!;
    var clientMs = 0;
    final rows = [
      for (final e in executions)
        e.copyWith(
          id: null,
          spreadsheetUuid: space,
          userId: actor.userId,
          runAsUserId: actor.userId,
          runtime: e.runtime == ScriptRuntimeKind.server
              ? ScriptRuntimeKind.clientDesktop
              : e.runtime,
          logs: _truncate(e.logs),
          changeId: null,
        ),
    ];
    for (final r in rows) {
      clientMs += r.durationMs.clamp(0, 6 * 3600 * 1000);
    }
    await ScriptExecution.db.insert(session, rows);
    await _addUsage(session, actor.userId, clientMs: clientMs);
    return rows.length;
  }

  /// Daily pruning: executions older than 30 days and beyond 10,000 per
  /// spreadsheet.
  static Future<int> pruneExecutions(Session session) async {
    final cutoff = clock.now().toUtc().subtract(executionRetention);
    final old = await ScriptExecution.db.deleteWhere(
      session,
      where: (t) => t.startedAt < cutoff,
    );
    final extra = await session.db.unsafeExecute(
      'DELETE FROM "script_execution" WHERE "id" IN ('
      'SELECT "id" FROM (SELECT "id", row_number() OVER '
      '(PARTITION BY "spreadsheetUuid" ORDER BY "startedAt" DESC) AS n '
      'FROM "script_execution") ranked WHERE n > $maxExecutionsPerSpreadsheet)',
    );
    return old.length + extra;
  }
}

/// `UrlFetchApp` of server executions: the SSRF-safe proxy with the run-as
/// user's quotas.
final class _ServerFetcher implements UrlFetcher {
  _ServerFetcher(this.session, this.userId, this.project);

  final Session session;
  final int userId;
  final ScriptProject? project;

  @override
  Future<FetchResponseData> fetch(
    FetchRequestData request, {
    required bool customFunction,
  }) => ScriptService._fetch(
    session,
    userId,
    project,
    request,
    customFunction: customFunction,
  );
}

/// `PropertiesService.userProperties` of server runs (09 §6.9, A-09-4): the
/// run-as user's `ScriptUserProperty` rows for one spreadsheet, stored in the
/// user's **personal space** (space UUID = auth user id, implicit in the
/// sync engine). The rows are loaded before the run (scripts read them
/// synchronously) and the changes are written by [flush] after it, in one
/// transaction of that user, so they sync to the user's clients.
final class ServerUserProperties implements PropertyStore {
  ServerUserProperties._(this.user, this.spreadsheet, this._rows)
    : _values = {for (final e in _rows.entries) e.key: e.value.value};

  /// Loads the properties of [user] for [spreadsheet] (space uuid).
  static Future<ServerUserProperties> load(
    Session session, {
    required UuidValue user,
    required UuidValue spreadsheet,
  }) async {
    final rows = <String, ScriptUserProperty>{};
    final space = await OfflineSyncSpace.db.findFirstRow(
      session,
      where: (t) => t.uuidSpaceId.equals(user),
    );
    if (space != null) {
      final found = await ScriptUserProperty.db.find(
        syncSessionOf(session),
        where: (t) =>
            t.spaceId.equals(space.id) & t.spreadsheetId.equals(spreadsheet),
        orderBy: (t) => t.createdAt,
      );
      for (final r in found) {
        rows[r.key] = r;
      }
    }
    return ServerUserProperties._(user, spreadsheet, rows);
  }

  /// The run-as user (auth user id = personal space uuid).
  final UuidValue user;

  /// The spreadsheet (space uuid).
  final UuidValue spreadsheet;

  final Map<String, ScriptUserProperty> _rows;
  final Map<String, String> _values;
  final Set<String> _changed = {};

  /// Whether the run changed properties.
  bool get isDirty => _changed.isNotEmpty;

  @override
  Map<String, String> all() => Map.of(_values);

  @override
  void set(String key, String value) {
    if (_values[key] == value) return;
    _values[key] = value;
    _changed.add(key);
  }

  @override
  void delete(String key) {
    if (_values.remove(key) != null) _changed.add(key);
  }

  /// Writes the changed properties into the personal space.
  Future<void> flush(Session session) async {
    if (_changed.isEmpty) return;
    final db = syncSessionOf(session);
    final keys = _changed.toList();
    _changed.clear();
    await db.offlineSyncDb.transactionForUser(user, (tx) async {
      for (final key in keys) {
        final row = _rows[key];
        final value = _values[key];
        if (value == null) {
          if (row != null) await deleteSyncedRow(db, row, transaction: tx);
          _rows.remove(key);
        } else if (row == null) {
          _rows[key] = await ScriptUserProperty.db.insertRow(
            db,
            ScriptUserProperty(
              spreadsheetId: spreadsheet,
              key: key,
              value: value,
              createdAt: clock.now().toUtc(),
            ),
            transaction: tx,
          );
        } else {
          final next = row.copyWith(value: value);
          await updateSyncedRow(
            db,
            next,
            columns: [ScriptUserProperty.t.value],
            transaction: tx,
          );
          _rows[key] = next;
        }
      }
    }, spaceId: user);
  }
}
