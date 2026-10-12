import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/common/roles.dart';
import '../../platform/common/time.dart';
import '../../platform/drive/drive_service.dart';
import '../../platform/sharing/access_service.dart';
import '../../platform/users/user_service.dart';
import '../themes/theme_service.dart';
import 'document_bus.dart';
import 'document_cache.dart';
import 'document_store.dart';
import 'ot_service.dart';

/// One editing/viewing session of `document.connect` (Write 03 §1–2).
class DocumentConnection {
  DocumentConnection._(this.session, this.actor, this.documentUuid);

  /// Clients more than this many revisions behind get a snapshot.
  static const maxOpsInInit = 1000;

  /// Beyond this many editors, new joiners become viewers (Write 03 §7).
  static const maxEditors = 100;

  final Session session;
  final Actor actor;
  final UuidValue documentUuid;
  final String sessionId = const Uuid().v4();

  late Document _document;
  late DriveItem _item;
  late Role _role;
  late DocumentState _state;
  late StreamController<DocServerMessage> _out;
  StreamSubscription<DocClientMessage>? _input;
  final Map<String, Participant> _participants = {};
  Participant? _me;
  String? _themeChannel;
  bool _closed = false;
  Future<void> _queue = Future.value();

  static Stream<DocServerMessage> open(
    Session session,
    Actor actor,
    UuidValue documentUuid,
    int knownRevision,
    Stream<DocClientMessage> input,
  ) {
    final c = DocumentConnection._(session, actor, documentUuid);
    c._out = StreamController<DocServerMessage>(
      onListen: () {
        c._start(knownRevision, input).catchError((Object e, StackTrace st) {
          if (!c._out.isClosed) {
            c._out.addError(e, st);
            unawaited(c._close());
          }
        });
      },
      onCancel: c._close,
    );
    return c._out.stream;
  }

  void _send(DocServerMessage m) {
    if (!_out.isClosed) _out.add(m);
  }

  Future<void> _start(int knownRevision, Stream<DocClientMessage> input) async {
    final doc = await DocumentStore.byUuid(session, documentUuid);
    if (doc == null) throw Errors.notFound('Document');
    final item = await DriveItem.db.findById(session, doc.itemId);
    if (item == null) throw Errors.notFound('Document');
    _item = item;
    _role = await AccessService.requireRole(session, actor, item, Role.viewer);
    await DriveService.recordOpen(session, actor, item, _role);
    _document = doc;
    _state = await DocumentCache.of(session, doc);
    DocumentCache.retain(_state);
    await _state.lock(() async {
      final fresh = await Document.db.findById(session, doc.id!);
      await _state.catchUp(session, fresh!.headRevision);
    });

    final profile = await UserService.requireProfile(session, actor.userId);
    final summary = await UserService.summaryOf(session, profile);
    _me = Participant(
      sessionId: sessionId,
      userId: actor.userId,
      userUuid: actor.authUserId,
      displayName: summary.displayName,
      avatarUrl: summary.avatarUrl,
      colorIndex: summary.colorIndex,
      role: _role.access,
      actorKind: actor.kind,
      state: PresenceState.active,
      joinedAt: nowUtc(),
    );

    session.messages.addListener(DocumentBus.channel(documentUuid), _onBus);
    await DocumentBus.post(
      session,
      documentUuid,
      DocBusMessage(
        type: 'hello',
        originSessionId: sessionId,
        participant: _me,
      ),
    );
    // Over the editor limit: join as a viewer.
    final editors = _participants.values
        .where((p) => p.role.index >= AccessRole.editor.index)
        .length;
    if (_role >= Role.editor && editors >= maxEditors) {
      _role = Role.viewer;
      _me = _me!.copyWith(role: AccessRole.viewer);
    }
    _subscribeTheme(doc.themeId);

    final head = _state.revision;
    List<DocumentOpView>? ops;
    String? snapshot;
    if (knownRevision > 0 &&
        knownRevision <= head &&
        head - knownRevision <= maxOpsInInit) {
      ops = await _opViews(knownRevision + 1, head);
      if (ops.length != head - knownRevision) ops = null;
    }
    if (ops == null) {
      snapshot = DocumentStore.encodeContent(_state.content, compress: false);
    }
    _send(
      DocInit(
        revision: head,
        snapshotJson: snapshot,
        ops: ops,
        meta: _metaOf(_document),
        role: _role.access,
        sessionId: sessionId,
        participants: [_me!, ..._participants.values],
      ),
    );
    _input = input.listen(
      (m) => _queue = _queue.then((_) => _handle(m)),
      onDone: _close,
      onError: (Object _) => _close(),
    );
    session.addWillCloseListener((_) => _close());
  }

  static DocumentMetaView _metaOf(Document d) => DocumentMetaView(
    themeId: d.themeId,
    pageSetupJson: d.pageSetupJson,
    language: d.language,
    frontMatter: d.frontMatter,
  );

  Future<List<DocumentOpView>> _opViews(int from, int to) async {
    final ops = await DocumentOp.db.find(
      session,
      where: (t) =>
          t.documentId.equals(_document.id!) &
          (t.revision >= from) &
          (t.revision <= to),
      orderBy: (t) => t.revision,
      limit: maxOpsInInit,
    );
    final users = await UserService.summaries(session, [
      for (final o in ops) o.authorId,
    ]);
    return [
      for (final o in ops)
        DocumentOpView(
          revision: o.revision,
          deltaJson: o.deltaJson,
          clientOpId: o.clientOpId,
          authorId: o.authorId,
          authorUuid: o.authorId == null ? null : users[o.authorId]?.uuid,
          actorKind: o.actorKind,
          kind: o.kind,
          sessionId: o.sessionId,
          createdAt: o.createdAt,
        ),
    ];
  }

  void _subscribeTheme(UuidValue? themeId) {
    final channel = themeId == null ? null : ThemeService.channel(themeId);
    if (channel == _themeChannel) return;
    if (_themeChannel != null) {
      session.messages.removeListener(_themeChannel!, _onTheme);
    }
    _themeChannel = channel;
    if (channel != null) session.messages.addListener(channel, _onTheme);
  }

  void _onTheme(SerializableModel m) {
    if (m is DocMetaChanged) _send(m);
  }

  void _onBus(SerializableModel model) {
    if (model is! DocBusMessage || _closed) return;
    final m = model;
    switch (m.type) {
      case 'op':
        final op = m.op;
        if (op == null || m.originSessionId == sessionId) return;
        _send(op);
      case 'cursor':
        if (m.cursor == null || m.originSessionId == sessionId) return;
        _send(m.cursor!);
      case 'hello':
        final p = m.participant;
        if (p == null || m.originSessionId == sessionId) return;
        _participants[p.sessionId] = p;
        _send(DocParticipantJoined(participant: p));
        if (_me != null) {
          unawaited(
            DocumentBus.post(
              session,
              documentUuid,
              DocBusMessage(
                type: 'here',
                originSessionId: sessionId,
                participant: _me,
                sessionId: p.sessionId,
              ),
            ),
          );
        }
      case 'here':
        final p = m.participant;
        if (p == null || m.sessionId != sessionId) return;
        if (_participants.containsKey(p.sessionId)) return;
        _participants[p.sessionId] = p;
        // Before Init the roster goes into DocInit.participants.
        if (_out.hasListener && _initSent) {
          _send(DocParticipantJoined(participant: p));
        }
      case 'left':
        final id = m.originSessionId;
        if (id == null || _participants.remove(id) == null) return;
        _send(DocParticipantLeft(sessionId: id));
      case 'meta':
        final meta = m.meta;
        if (meta == null) return;
        if (meta.field == 'themeId') {
          unawaited(_refreshDocument());
        }
        _send(meta);
      case 'role':
        if (m.userId == null || m.userId == actor.userId) {
          _queue = _queue.then((_) => _recheckRole());
        }
    }
  }

  bool get _initSent => _input != null;

  Future<void> _refreshDocument() async {
    final doc = await Document.db.findById(session, _document.id!);
    if (doc == null) return;
    _document = doc;
    _subscribeTheme(doc.themeId);
  }

  Future<void> _recheckRole() async {
    if (_closed) return;
    final item = await DriveItem.db.findById(session, _item.id!);
    final role = item == null
        ? null
        : await AccessService.effectiveRole(session, actor.userId, item);
    if (role == null || item!.trashedAt != null && role != Role.owner) {
      if (!_out.isClosed) {
        _out.addError(Errors.forbidden('You no longer have access.'));
      }
      await _close();
      return;
    }
    _item = item;
    if (role != _role) {
      _role = role;
      _send(DocRoleChanged(role: role.access));
    }
  }

  Future<void> _handle(DocClientMessage m) async {
    if (_closed) return;
    try {
      switch (m) {
        case DocSubmitOp():
          await _submit(m);
        case DocCursorUpdate():
          final (a, h) = OtService.transformCursor(
            _state,
            m.revision,
            m.anchor,
            m.head,
          );
          await DocumentBus.post(
            session,
            documentUuid,
            DocBusMessage(
              type: 'cursor',
              originSessionId: sessionId,
              cursor: DocRemoteCursor(
                sessionId: sessionId,
                userId: actor.userId,
                revision: _state.revision,
                anchor: a,
                head: h,
                focused: m.focused,
              ),
            ),
          );
        case DocRequestOps():
          final from = m.fromRevision < 1 ? 1 : m.fromRevision;
          final to = m.toRevision > _state.revision
              ? _state.revision
              : m.toRevision;
          if (to < from) return;
          final views = await _opViews(from, to);
          for (final v in views) {
            _send(
              DocRemoteOp(
                revision: v.revision,
                deltaJson: v.deltaJson,
                authorId: v.authorId,
                authorUuid: v.authorUuid,
                authorSessionId: v.sessionId,
                actorKind: v.actorKind,
                kind: v.kind,
              ),
            );
          }
        case DocPing():
          _send(DocPong(t: m.t));
        case DocHashCheck():
          final content = m.revision == _state.revision
              ? _state.content
              : await DocumentStore.contentAt(session, _document, m.revision);
          final hash = documentHash(content);
          _send(
            DocHashResult(
              revision: m.revision,
              sha256: hash,
              matches: hash == m.sha256,
            ),
          );
      }
    } on WonkyException catch (e) {
      session.log(
        'Document message failed: ${e.message}',
        level: LogLevel.info,
      );
    }
  }

  Future<void> _submit(DocSubmitOp m) async {
    try {
      final committed = await OtService.submit(
        session,
        actor: actor.copyWith(sessionId: sessionId),
        document: _document,
        item: _item,
        role: _role,
        clientOpId: m.clientOpId,
        baseRevision: m.baseRevision,
        deltaJson: m.deltaJson,
        kind: m.kind,
        sessionId: sessionId,
        groupId: m.groupId,
      );
      _send(DocAck(clientOpId: m.clientOpId, revision: committed.revision));
    } on OpRejection catch (r) {
      _send(
        DocOpRejected(
          clientOpId: m.clientOpId,
          code: r.code,
          message: r.message,
        ),
      );
    }
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    session.messages.removeListener(DocumentBus.channel(documentUuid), _onBus);
    if (_themeChannel != null) {
      session.messages.removeListener(_themeChannel!, _onTheme);
    }
    await _input?.cancel();
    try {
      DocumentCache.release(_state);
    } on Error {
      // Not started.
    }
    try {
      await DocumentBus.post(
        session,
        documentUuid,
        DocBusMessage(type: 'left', originSessionId: sessionId),
      );
    } on Exception {
      // The server is shutting down.
    }
    if (!_out.isClosed) await _out.close();
  }
}
