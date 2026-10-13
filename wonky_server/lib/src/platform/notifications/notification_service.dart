import 'dart:async';
import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../common/actor.dart';
import '../config/wonky_config.dart';
import '../common/errors.dart';
import '../common/models.dart';
import '../common/json.dart';
import '../common/time.dart';
import '../users/user_service.dart';
import '../../generated/future_calls.dart';
import 'email/email_sender.dart';
import 'email/notification_emails.dart';
import '../cluster/cluster_bus.dart';

/// In-app notifications (specs/07 §4).
abstract final class NotificationService {
  static EmailSender? _emailSender;

  /// Delivers notification emails; [EmailSenders.fromServer] by default
  /// (logs in development). Tests install a fake.
  static EmailSender get emailSender =>
      _emailSender ??= EmailSenders.fromServer();
  static set emailSender(EmailSender? sender) => _emailSender = sender;

  /// Schedules the immediate email of a notification. By default a future
  /// call without delay ([NotificationEmailFutureCall]); tests replace it to
  /// run [sendImmediate] inline.
  static Future<void> Function(Session session, int notificationId)
  scheduleImmediateEmail = _scheduleViaFutureCall;

  static Future<void> _scheduleViaFutureCall(
    Session session,
    int notificationId,
  ) => session.serverpod.futureCalls
      .callWithDelay(Duration.zero)
      .notificationEmail
      .send(notificationId);

  /// The public web origin used for links in emails.
  static Uri webOrigin() {
    try {
      return WonkyConfig.current.webOrigin(Serverpod.instance.config);
    } on Object {
      return Uri.parse('http://localhost:8082');
    }
  }

  static NotificationEmails get _emails =>
      NotificationEmails(webOrigin: webOrigin());

  /// Kinds that are emailed right away instead of in the digest.
  static const immediateKinds = {
    NotificationKind.mention,
    NotificationKind.assigned,
  };

  static String channel(int userId) => 'notifications:$userId';

  /// The preference key (notificationSettings) of a [kind].
  static String settingKey(NotificationKind kind) => switch (kind) {
    NotificationKind.mention => 'mentions',
    NotificationKind.assigned => 'mentions',
    NotificationKind.reply => 'replies',
    NotificationKind.shared => 'shares',
    NotificationKind.ownershipTransfer => 'shares',
    NotificationKind.accessRequest => 'accessRequests',
    NotificationKind.suggestion => 'suggestions',
    NotificationKind.suggestionDecided => 'suggestions',
    NotificationKind.scriptFailure => 'scripts',
  };

  /// Older settings stored access requests under `shares`.
  static const _fallbackKeys = {'accessRequests': 'shares'};

  /// The channel (`inApp`, `email` or `off`) for [kind] in the decoded
  /// notificationSettings [settings].
  static String channelOf(
    Map<String, Object?> settings,
    NotificationKind kind,
  ) {
    final key = settingKey(kind);
    final value = settings[key] ?? settings[_fallbackKeys[key]];
    return value == 'email' || value == 'off' ? value as String : 'inApp';
  }

  /// Whether non-mention emails are batched in the digest (`digest`,
  /// default true) or sent one by one.
  static bool digestOf(Map<String, Object?> settings) =>
      settings['digest'] != false;

  static Future<Map<String, Object?>> _settings(
    Session session,
    int userId,
  ) async {
    final prefs = await UserPreferences.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );
    return decodeObject(prefs?.notificationSettings);
  }

  /// Creates a notification for [userId] unless they turned this kind off.
  /// Notifications about one's own actions are never created.
  static Future<UserNotification?> notify(
    Session session, {
    required int userId,
    required NotificationKind kind,
    DriveItem? item,
    Actor? actor,
    Map<String, Object?> payload = const {},
  }) async {
    if (actor != null && actor.userId == userId) return null;
    final settings = await _settings(session, userId);
    final channelSetting = channelOf(settings, kind);
    if (channelSetting == 'off') return null;
    final row = await UserNotification.db.insertRow(
      session,
      UserNotification(
        userId: userId,
        kind: kind,
        itemId: item?.id,
        actorId: actor?.userId,
        payload: jsonEncode({
          ...payload,
          if (item != null) 'itemName': item.name,
          if (actor != null) 'actorKind': actor.kind.name,
        }),
        createdAt: nowUtc(),
      ),
    );
    await ClusterBus.post(
      session,
      channel(userId),
      NotificationSignal(notificationId: row.id),
    );
    if (channelSetting == 'email' &&
        (immediateKinds.contains(kind) || !digestOf(settings))) {
      try {
        await scheduleImmediateEmail(session, row.id!);
      } on Object catch (e) {
        // The digest job picks it up.
        session.log(
          'Could not schedule the email of notification ${row.id}: $e',
          level: LogLevel.warning,
        );
      }
    }
    return row;
  }

  static Future<List<NotificationView>> _views(
    Session session,
    List<UserNotification> rows,
  ) async {
    final itemIds = {for (final r in rows) ?r.itemId};
    final items = itemIds.isEmpty
        ? <DriveItem>[]
        : await DriveItem.db.find(session, where: (t) => t.id.inSet(itemIds));
    final itemById = {for (final i in items) i.id!: i};
    final users = await UserService.summaries(session, [
      for (final r in rows) r.actorId,
    ]);
    return [
      for (final r in rows)
        NotificationView(
          id: r.id!,
          kind: r.kind,
          itemUuid: itemById[r.itemId]?.uuid,
          itemName: itemById[r.itemId]?.name,
          itemKind: itemById[r.itemId]?.kind,
          actor: r.actorId == null ? null : users[r.actorId],
          payload: r.payload,
          createdAt: r.createdAt,
          readAt: r.readAt,
        ),
    ];
  }

  static Future<int> unreadCount(Session session, int userId) =>
      UserNotification.db.count(
        session,
        where: (t) => t.userId.equals(userId) & t.readAt.equals(null),
      );

  static Future<NotificationPage> list(
    Session session,
    Actor actor, {
    String? cursor,
    int limit = 30,
    bool unreadOnly = false,
  }) async {
    final beforeId = int.tryParse(cursor ?? '');
    final rows = await UserNotification.db.find(
      session,
      where: (t) =>
          t.userId.equals(actor.userId) &
          (unreadOnly ? t.readAt.equals(null) : Constant.bool(true)) &
          (beforeId == null ? Constant.bool(true) : t.id < beforeId),
      orderBy: (t) => t.id.desc(),
      limit: limit.clamp(1, 100),
    );
    return NotificationPage(
      items: await _views(session, rows),
      nextCursor: rows.length == limit.clamp(1, 100) ? '${rows.last.id}' : null,
      unreadCount: await unreadCount(session, actor.userId),
    );
  }

  static Future<int> markRead(
    Session session,
    Actor actor,
    List<int> ids,
  ) async {
    if (ids.isNotEmpty) {
      await UserNotification.db.updateWhere(
        session,
        columnValues: (t) => [t.readAt(nowUtc())],
        where: (t) =>
            t.userId.equals(actor.userId) &
            t.id.inSet(ids.toSet()) &
            t.readAt.equals(null),
      );
    }
    await ClusterBus.post(
      session,
      channel(actor.userId),
      NotificationSignal(),
    );
    return unreadCount(session, actor.userId);
  }

  static Future<int> markAllRead(Session session, Actor actor) async {
    await UserNotification.db.updateWhere(
      session,
      columnValues: (t) => [t.readAt(nowUtc())],
      where: (t) => t.userId.equals(actor.userId) & t.readAt.equals(null),
    );
    await ClusterBus.post(
      session,
      channel(actor.userId),
      NotificationSignal(),
    );
    return 0;
  }

  static Stream<NotificationEvent> watch(Session session, Actor actor) async* {
    final signals = session.messages.createStream<NotificationSignal>(
      channel(actor.userId),
    );
    await for (final signal in signals) {
      NotificationView? view;
      if (signal.notificationId != null) {
        final row = await UserNotification.db.findById(
          session,
          signal.notificationId!,
        );
        if (row != null && row.userId == actor.userId) {
          view = (await _views(session, [row])).single;
        }
      }
      yield NotificationEvent(
        notification: view,
        unreadCount: await unreadCount(session, actor.userId),
      );
    }
  }

  /// Sends the email of one notification (mentions and assignments, or
  /// every kind when the user turned the digest off). Idempotent: skips
  /// notifications that were read, already emailed, or whose kind is no
  /// longer set to email. Returns whether an email was sent.
  static Future<bool> sendImmediate(
    Session session,
    int notificationId, {
    DateTime? now,
  }) async {
    final row = await UserNotification.db.findById(session, notificationId);
    if (row == null || row.readAt != null || row.emailedAt != null) {
      return false;
    }
    final settings = await _settings(session, row.userId);
    if (channelOf(settings, row.kind) != 'email') return false;
    final profile = await UserProfile.db.findById(session, row.userId);
    if (profile == null) return false;
    final view = (await _views(session, [row])).single;
    try {
      await emailSender.send(
        session,
        _emails.single(
          to: profile.email,
          displayName: profile.displayName,
          notification: view,
        ),
      );
    } on Exception catch (e) {
      // Left unmarked: the next digest retries it.
      session.log(
        'Email of notification $notificationId failed: $e',
        level: LogLevel.warning,
      );
      return false;
    }
    await UserNotification.db.updateWhere(
      session,
      columnValues: (t) => [t.emailedAt(now ?? nowUtc())],
      where: (t) => t.id.equals(notificationId) & t.emailedAt.equals(null),
    );
    return true;
  }

  /// Email digest job (every 15 min, specs/07 §4): per user, one email with
  /// the unread notifications of the last two days whose kind is set to
  /// email and that were not emailed yet (including immediate emails that
  /// failed). Returns the number of digests sent.
  static Future<int> sendDigests(Session session, {DateTime? now}) async {
    final at = now ?? nowUtc();
    final pending = await UserNotification.db.find(
      session,
      where: (t) =>
          t.readAt.equals(null) &
          t.emailedAt.equals(null) &
          (t.createdAt > at.subtract(const Duration(days: 2))),
      orderBy: (t) => t.userId,
      limit: 5000,
    );
    final byUser = <int, List<UserNotification>>{};
    for (final n in pending) {
      byUser.putIfAbsent(n.userId, () => []).add(n);
    }
    var sent = 0;
    for (final entry in byUser.entries) {
      final settings = await _settings(session, entry.key);
      final wanted = [
        for (final n in entry.value)
          if (channelOf(settings, n.kind) == 'email') n,
      ];
      if (wanted.isEmpty) continue;
      final profile = await UserProfile.db.findById(session, entry.key);
      if (profile == null) continue;
      try {
        await emailSender.send(
          session,
          _emails.digest(
            to: profile.email,
            displayName: profile.displayName,
            notifications: await _views(session, wanted),
          ),
        );
      } on Exception catch (e) {
        session.log(
          'Digest for ${entry.key} failed: $e',
          level: LogLevel.warning,
        );
        continue;
      }
      await UserNotification.db.updateWhere(
        session,
        columnValues: (t) => [t.emailedAt(at)],
        where: (t) =>
            t.id.inSet(<int>{for (final n in wanted) n.id!}) &
            t.emailedAt.equals(null),
      );
      sent++;
    }
    return sent;
  }

  static Never notFound() => throw Errors.notFound('Notification');
}
