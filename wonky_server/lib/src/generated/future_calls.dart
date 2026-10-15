/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: depend_on_referenced_packages

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:clock/clock.dart' as _io0w16m8;
import 'package:serverpod/serverpod.dart' as _is;
import '../platform/files/file_preview_future_call.dart' as _iw6v1fyh;
import '../platform/jobs/maintenance_future_call.dart' as _imgsvm9k;
import '../platform/notifications/notification_email_future_call.dart'
    as _i1dis1nt;
import '../platform/storage/storage_future_call.dart' as _iel4dsm1;
import '../sheets/scripts/script_scheduler_future_call.dart' as _iq0nfb3f;
import 'future_calls_generated_models/file_preview_future_call_generate_model.dart'
    as _ilpvgw0t;
import 'future_calls_generated_models/notification_email_future_call_send_model.dart'
    as _inb6x2l0;
import 'future_calls_generated_models/storage_future_call_refresh_item_size_model.dart'
    as _io4auc29;

/// Invokes a future call.
typedef _InvokeFutureCall =
    Future<void> Function(String name, _is.SerializableModel? object);

extension ServerpodFutureCallsGetter on _is.Serverpod {
  /// Generated future calls.
  FutureCalls get futureCalls => FutureCalls();
}

class FutureCalls extends _is.FutureCallDispatch<_FutureCallRef> {
  FutureCalls._();

  factory FutureCalls() {
    return _instance;
  }

  static final FutureCalls _instance = FutureCalls._();

  _is.FutureCallManager? _futureCallManager;

  String? _serverId;

  String get _effectiveServerId {
    if (_serverId == null) {
      throw StateError('FutureCalls is not initialized.');
    }
    return _serverId!;
  }

  _is.FutureCallManager get _effectiveFutureCallManager {
    if (_futureCallManager == null) {
      throw StateError('FutureCalls is not initialized.');
    }
    return _futureCallManager!;
  }

  @override
  void initialize(
    _is.FutureCallManager futureCallManager,
    String serverId,
  ) {
    var registeredFutureCalls = <String, _is.InvokableFutureCall>{
      'FilePreviewGenerateFutureCall': FilePreviewGenerateFutureCall(),
      'MaintenanceCaptureVersionsFutureCall':
          MaintenanceCaptureVersionsFutureCall(),
      'MaintenanceSendDigestsFutureCall': MaintenanceSendDigestsFutureCall(),
      'MaintenanceCleanupFilesFutureCall': MaintenanceCleanupFilesFutureCall(),
      'MaintenanceDailyFutureCall': MaintenanceDailyFutureCall(),
      'NotificationEmailSendFutureCall': NotificationEmailSendFutureCall(),
      'StorageBackfillFutureCall': StorageBackfillFutureCall(),
      'StorageReconcileFutureCall': StorageReconcileFutureCall(),
      'StorageRefreshItemSizeFutureCall': StorageRefreshItemSizeFutureCall(),
      'ScriptSchedulerTickFutureCall': ScriptSchedulerTickFutureCall(),
      'ScriptSchedulerPruneFutureCall': ScriptSchedulerPruneFutureCall(),
    };
    _futureCallManager = futureCallManager;
    _serverId = serverId;
    for (final entry in registeredFutureCalls.entries) {
      _futureCallManager?.registerFutureCall(entry.value, entry.key);
    }
  }

  @override
  _FutureCallRef callAtTime(
    DateTime time, {
    String? identifier,
  }) {
    return _FutureCallRef(
      (name, object) {
        return _effectiveFutureCallManager.scheduleFutureCall(
          name,
          object,
          time,
          _effectiveServerId,
          identifier,
        );
      },
    );
  }

  @override
  _FutureCallRef callWithDelay(
    Duration delay, {
    String? identifier,
  }) {
    return _FutureCallRef(
      (name, object) {
        return _effectiveFutureCallManager.scheduleFutureCall(
          name,
          object,
          DateTime.now().toUtc().add(delay),
          _effectiveServerId,
          identifier,
        );
      },
    );
  }

  @override
  _is.RecurringFutureCallDispatch<_FutureCallRef> callRecurring({
    String? identifier,
  }) {
    return _RecurringFutureCallDispatchImpl(
      _effectiveFutureCallManager,
      _effectiveServerId,
      identifier,
    );
  }

  @override
  Future<void> cancel(String identifier) async {
    await _effectiveFutureCallManager.cancelFutureCall(identifier);
  }
}

class _RecurringFutureCallDispatchImpl
    extends _is.RecurringFutureCallDispatch<_FutureCallRef> {
  _RecurringFutureCallDispatchImpl(
    this._futureCallManager,
    this._serverId,
    this._identifier,
  );

  final _is.FutureCallManager _futureCallManager;

  final String _serverId;

  final String? _identifier;

  @override
  _FutureCallRef cron(String cronExpression) {
    return _FutureCallRef(
      (name, object) {
        return _futureCallManager.scheduleFutureCall(
          name,
          object,
          _is.Cron.parse(cronExpression).nextTime(),
          _serverId,
          _identifier,
          scheduling: _is.CronFutureCallScheduling(cron: cronExpression),
        );
      },
    );
  }

  @override
  _FutureCallRef every(
    Duration interval, {
    DateTime? start,
  }) {
    final now = _io0w16m8.clock.now().toUtc();
    return _FutureCallRef(
      (name, object) {
        return _futureCallManager.scheduleFutureCall(
          name,
          object,
          start ?? now.add(interval),
          _serverId,
          _identifier,
          scheduling: _is.IntervalFutureCallScheduling(
            interval: interval,
            start: start,
          ),
        );
      },
    );
  }
}

class _FutureCallRef {
  _FutureCallRef(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  late final filePreview = _FilePreviewFutureCallDispatcher(_invokeFutureCall);

  late final maintenance = _MaintenanceFutureCallDispatcher(_invokeFutureCall);

  late final notificationEmail = _NotificationEmailFutureCallDispatcher(
    _invokeFutureCall,
  );

  late final storage = _StorageFutureCallDispatcher(_invokeFutureCall);

  late final scriptScheduler = _ScriptSchedulerFutureCallDispatcher(
    _invokeFutureCall,
  );
}

class _FilePreviewFutureCallDispatcher {
  _FilePreviewFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> generate(int itemId) {
    var object = _ilpvgw0t.FilePreviewFutureCallGenerateModel(itemId: itemId);
    return _invokeFutureCall(
      'FilePreviewGenerateFutureCall',
      object,
    );
  }
}

class _MaintenanceFutureCallDispatcher {
  _MaintenanceFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> captureVersions() {
    return _invokeFutureCall(
      'MaintenanceCaptureVersionsFutureCall',
      null,
    );
  }

  Future<void> sendDigests() {
    return _invokeFutureCall(
      'MaintenanceSendDigestsFutureCall',
      null,
    );
  }

  Future<void> cleanupFiles() {
    return _invokeFutureCall(
      'MaintenanceCleanupFilesFutureCall',
      null,
    );
  }

  Future<void> daily() {
    return _invokeFutureCall(
      'MaintenanceDailyFutureCall',
      null,
    );
  }
}

class _NotificationEmailFutureCallDispatcher {
  _NotificationEmailFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> send(int notificationId) {
    var object = _inb6x2l0.NotificationEmailFutureCallSendModel(
      notificationId: notificationId,
    );
    return _invokeFutureCall(
      'NotificationEmailSendFutureCall',
      object,
    );
  }
}

class _StorageFutureCallDispatcher {
  _StorageFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> backfill() {
    return _invokeFutureCall(
      'StorageBackfillFutureCall',
      null,
    );
  }

  Future<void> reconcile() {
    return _invokeFutureCall(
      'StorageReconcileFutureCall',
      null,
    );
  }

  Future<void> refreshItemSize(int itemId) {
    var object = _io4auc29.StorageFutureCallRefreshItemSizeModel(
      itemId: itemId,
    );
    return _invokeFutureCall(
      'StorageRefreshItemSizeFutureCall',
      object,
    );
  }
}

class _ScriptSchedulerFutureCallDispatcher {
  _ScriptSchedulerFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> tick() {
    return _invokeFutureCall(
      'ScriptSchedulerTickFutureCall',
      null,
    );
  }

  Future<void> prune() {
    return _invokeFutureCall(
      'ScriptSchedulerPruneFutureCall',
      null,
    );
  }
}

class FilePreviewGenerateFutureCall
    extends _is.FutureCall<_ilpvgw0t.FilePreviewFutureCallGenerateModel>
    implements
        _is.InvokableFutureCall<_ilpvgw0t.FilePreviewFutureCallGenerateModel> {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _ilpvgw0t.FilePreviewFutureCallGenerateModel? object,
  ) async {
    if (object != null) {
      await _iw6v1fyh.FilePreviewFutureCall().generate(
        session,
        object.itemId,
      );
    }
  }
}

/// Every minute: version capture policy.
class MaintenanceCaptureVersionsFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _imgsvm9k.MaintenanceFutureCall().captureVersions(session);
  }
}

/// Every 15 minutes: notification email digests.
class MaintenanceSendDigestsFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _imgsvm9k.MaintenanceFutureCall().sendDigests(session);
  }
}

/// Hourly: expired files (imports, exports) and abandoned uploads.
class MaintenanceCleanupFilesFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _imgsvm9k.MaintenanceFutureCall().cleanupFiles(session);
  }
}

/// Daily: trash purge, (v2) expired uploads and folder kind masks,
/// version thinning, op-log and change-log pruning,
/// active-set eviction, expired grants, server change records, deleted
/// themes and the diff cache.
class MaintenanceDailyFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _imgsvm9k.MaintenanceFutureCall().daily(session);
  }
}

class NotificationEmailSendFutureCall
    extends _is.FutureCall<_inb6x2l0.NotificationEmailFutureCallSendModel>
    implements
        _is.InvokableFutureCall<
          _inb6x2l0.NotificationEmailFutureCallSendModel
        > {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _inb6x2l0.NotificationEmailFutureCallSendModel? object,
  ) async {
    if (object != null) {
      await _i1dis1nt.NotificationEmailFutureCall().send(
        session,
        object.notificationId,
      );
    }
  }
}

/// Backfill of users without reconciled counters (idempotent,
/// resumable; serialized across instances).
class StorageBackfillFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _iel4dsm1.StorageFutureCall().backfill(session);
  }
}

/// Nightly: recomputes every user's counters from the sources.
class StorageReconcileFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _iel4dsm1.StorageFutureCall().reconcile(session);
  }
}

/// The trailing size estimate of a space item (Drive 03 §2 cadence).
class StorageRefreshItemSizeFutureCall
    extends _is.FutureCall<_io4auc29.StorageFutureCallRefreshItemSizeModel>
    implements
        _is.InvokableFutureCall<
          _io4auc29.StorageFutureCallRefreshItemSizeModel
        > {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _io4auc29.StorageFutureCallRefreshItemSizeModel? object,
  ) async {
    if (object != null) {
      await _iel4dsm1.StorageFutureCall().refreshItemSize(
        session,
        object.itemId,
      );
    }
  }
}

/// Every minute: runs due time-driven triggers.
class ScriptSchedulerTickFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _iq0nfb3f.ScriptSchedulerFutureCall().tick(session);
  }
}

/// Daily: executions older than 30 days or beyond 10,000 per spreadsheet.
class ScriptSchedulerPruneFutureCall extends _is.FutureCall
    implements _is.InvokableFutureCall {
  @override
  _ida.Future<void> invoke(
    _is.Session session,
    _is.SerializableModel? object,
  ) async {
    await _iq0nfb3f.ScriptSchedulerFutureCall().prune(session);
  }
}
