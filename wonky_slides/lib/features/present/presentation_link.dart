import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart' show ShellServices;
import 'package:wonky_client/wonky_client.dart';

/// The presentation session calls (Slides 10 §6.1): production uses the
/// generated client ([ClientPresentationTransport]); tests use fakes.
abstract interface class PresentationTransport {
  Stream<PresentationEvent> join(
    UuidValue deckUuid,
    PresentationJoin join,
    Stream<PresentationUpdate> updates,
  );

  Future<PresentationSessionInfo?> findSession(UuidValue deckUuid);

  /// The phone-remote route of a typed six-digit pairing code (SL-41, 10
  /// §6.4; server side built, client UI on hold), or null.
  Future<PresentationPairingTarget?> resolvePairingCode(String code);
}

/// [PresentationTransport] on `client.presentation`.
class ClientPresentationTransport implements PresentationTransport {
  ClientPresentationTransport(this.client);

  final Client client;

  @override
  Stream<PresentationEvent> join(
    UuidValue deckUuid,
    PresentationJoin join,
    Stream<PresentationUpdate> updates,
  ) => client.presentation.join(deckUuid, join, updates);

  @override
  Future<PresentationSessionInfo?> findSession(UuidValue deckUuid) =>
      client.presentation.findSession(deckUuid);

  @override
  Future<PresentationPairingTarget?> resolvePairingCode(String code) =>
      client.presentation.resolvePairingCode(code);
}

/// The transport of [s] (null without a server, e.g. widget tests).
PresentationTransport? presentationTransportOf(ShellServices s) {
  final o = debugPresentationTransport;
  if (o != null) return o;
  final c = s.client;
  return c == null ? null : ClientPresentationTransport(c);
}

/// Replaces the transport (tests).
@visibleForTesting
PresentationTransport? debugPresentationTransport;

/// Estimates the server clock from the server times of received events
/// (Slides 10 §6.2: followers seek with ±50 ms). Every sample is
/// `local − server` = clock difference + network delay; the smallest of
/// the recent samples has the least delay.
class ClockOffset {
  final List<int> _samples = [];

  /// Number of samples kept.
  static const window = 20;

  /// `local − server` in ms (0 before the first sample).
  int get offsetMs => _samples.isEmpty ? 0 : _samples.reduce(math.min);

  bool get hasSamples => _samples.isNotEmpty;

  void sample(int serverMs, int localMs) {
    _samples.add(localMs - serverMs);
    if (_samples.length > window) _samples.removeAt(0);
  }

  /// The server time at local time [localMs].
  int serverNow(int localMs) => localMs - offsetMs;

  /// Milliseconds since server time [serverMs], at local time [localMs]
  /// (never negative).
  int sinceServer(int serverMs, int localMs) =>
      math.max(0, serverNow(localMs) - serverMs);
}

/// The state of a [PresentationLink].
enum PresentationLinkStatus {
  /// Joining.
  connecting,

  /// Joined.
  connected,

  /// The connection dropped; retrying.
  reconnecting,

  /// No connection (presenting offline: other devices can't join, §7).
  offline,

  /// The session is over ([PresentationLink.endedReason]).
  ended,
}

/// One device's connection to a presentation session (Slides 10 §6): the
/// presenter view's (role presenter, creates the session) or an audience
/// view's on another device or browser. Reconnects after drops (the
/// presenter rejoins its session within the server's 30 s grace).
class PresentationLink extends ChangeNotifier {
  PresentationLink({
    required this.transport,
    required this.deckUuid,
    required this.role,
    required this.deviceLabel,
    this.sessionId,
    int Function()? nowMs,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 15),
    ],
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final PresentationTransport transport;
  final UuidValue deckUuid;
  final PresentationRole role;
  final String deviceLabel;
  final int Function() _nowMs;
  final List<Duration> retryDelays;

  /// The session (set by the welcome of a new presenter session).
  String? sessionId;

  /// This device's connection id.
  String? connectionId;

  PresentationLinkStatus _status = PresentationLinkStatus.connecting;
  PresentationLinkStatus get status => _status;

  /// Why the session ended (`ended`, `expired`, `takenOver`,
  /// `presenterActive`, `notFound`, `noAccess`, `error`).
  String? endedReason;

  /// The devices joined to the session (presenter only).
  List<PresentationParticipant> participants = const [];

  /// Whether the presenter is connected (members).
  bool presenterConnected = true;

  /// The presenter's device label (members).
  String? presenterDevice;

  final ClockOffset clock = ClockOffset();

  final _events = StreamController<PresentationEvent>.broadcast(sync: true);

  /// Every event (after the link updated itself).
  Stream<PresentationEvent> get events => _events.stream;

  StreamController<PresentationUpdate>? _updates;
  StreamSubscription<PresentationEvent>? _sub;
  Timer? _retry;
  int _attempt = 0;
  bool _disposed = false;
  bool _ending = false;

  bool get isConnected => _status == PresentationLinkStatus.connected;

  void _set(PresentationLinkStatus s) {
    if (_status == s) return;
    _status = s;
    if (!_disposed) notifyListeners();
  }

  /// Joins (again). A presenter [takeOver] replaces its other connection.
  void start({bool takeOver = false}) {
    if (_disposed) return;
    _retry?.cancel();
    unawaited(_sub?.cancel());
    unawaited(_updates?.close());
    endedReason = null;
    final updates = StreamController<PresentationUpdate>();
    _updates = updates;
    _set(
      _attempt == 0
          ? PresentationLinkStatus.connecting
          // A presenter that never joined stays offline while it retries.
          : sessionId == null
          ? PresentationLinkStatus.offline
          : PresentationLinkStatus.reconnecting,
    );
    final Stream<PresentationEvent> stream;
    try {
      stream = transport.join(
        deckUuid,
        PresentationJoin(
          sessionId: sessionId,
          role: role,
          deviceLabel: deviceLabel,
          takeOver: takeOver || (_attempt > 0 && sessionId != null)
              ? true
              : null,
        ),
        updates.stream,
      );
    } on Object {
      _scheduleRetry();
      return;
    }
    var ended = false;
    _sub = stream.listen(
      (e) {
        if (e is PresentationEndedEvent) ended = true;
        _onEvent(e);
      },
      onError: (Object e) {
        if (e is WonkyException &&
            (e.code == WonkyErrorCode.forbidden ||
                e.code == WonkyErrorCode.notFound ||
                e.code == WonkyErrorCode.invalidArgument)) {
          endedReason = e.code == WonkyErrorCode.forbidden
              ? 'noAccess'
              : 'notFound';
          ended = true;
          _set(PresentationLinkStatus.ended);
          _forward(
            PresentationEndedEvent(
              serverTimeMs: _nowMs(),
              reason: endedReason!,
            ),
          );
          return;
        }
        if (!ended) _scheduleRetry();
      },
      onDone: () {
        if (!ended && !_ending) _scheduleRetry();
      },
      cancelOnError: true,
    );
  }

  void _scheduleRetry() {
    if (_disposed || _ending) return;
    _set(
      sessionId == null
          ? PresentationLinkStatus.offline
          : PresentationLinkStatus.reconnecting,
    );
    final delay = retryDelays[math.min(_attempt, retryDelays.length - 1)];
    _attempt++;
    _retry = Timer(delay, start);
  }

  void _onEvent(PresentationEvent e) {
    clock.sample(e.serverTimeMs, _nowMs());
    switch (e) {
      case PresentationWelcome():
        sessionId = e.sessionId;
        connectionId = e.connectionId;
        presenterConnected = e.presenterConnected;
        presenterDevice = e.presenterDevice;
        _attempt = 0;
        _set(PresentationLinkStatus.connected);
      case PresentationRosterEvent():
        participants = e.participants;
        if (!_disposed) notifyListeners();
      case PresentationPresenterEvent():
        presenterConnected = e.connected;
        if (!_disposed) notifyListeners();
      case PresentationEndedEvent():
        endedReason = e.reason;
        _set(PresentationLinkStatus.ended);
      default:
        break;
    }
    _forward(e);
  }

  void _forward(PresentationEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  /// Sends [u] when connected (dropped otherwise: the presenter resends
  /// its full state after reconnecting).
  void send(PresentationUpdate u) {
    final c = _updates;
    if (c == null || c.isClosed || !isConnected) return;
    c.add(u);
  }

  /// Ends the session for everyone (presenter).
  Future<void> end() async {
    _ending = true;
    final c = _updates;
    if (c != null && !c.isClosed && isConnected) {
      c.add(PresentationEndUpdate());
      // Let the end reach the server before the stream closes.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await _close();
  }

  Future<void> _close() async {
    _ending = true;
    _retry?.cancel();
    await _sub?.cancel();
    await _updates?.close();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_close());
    unawaited(_events.close());
    super.dispose();
  }
}
