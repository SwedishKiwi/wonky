import 'dart:async';
import 'dart:convert';

import 'package:wonky_client/wonky_client.dart'
    show
        PresentationCommandEvent,
        PresentationCommandUpdate,
        PresentationEndUpdate,
        PresentationEndedEvent,
        PresentationEvent,
        PresentationInkEvent,
        PresentationInkUpdate,
        PresentationLaserEvent,
        PresentationLaserUpdate,
        PresentationRole,
        PresentationState,
        PresentationStateEvent,
        PresentationStateUpdate,
        PresentationUpdate;

import 'present_channel.dart';

/// The same-browser fast path of a presentation session (Slides 10 §5.2,
/// P1; SL-41): the session messages of §6.2 additionally travel over
/// `BroadcastChannel('wonky-present-<sessionId>')` between the tabs of one
/// browser profile — no server round trip (≤ 1 frame lag), and a joined
/// pair keeps running through connection drops. The server session stays
/// the authority for joining: a [PresentationLink] opens its fast path only
/// after its first welcome.
///
/// The presenter posts `state`, `laser`, `ink` and `end`; audiences and
/// remotes post `command`s; everyone posts a `ping` every [pingEvery].
/// Times are local epoch ms (the tabs share the clock); [toServerMs] turns
/// them into the server time the events carry.
class PresentFastPath {
  PresentFastPath({
    required this.sessionId,
    required this.connectionId,
    required this.role,
    required this.onEvent,
    required this.toServerMs,
    int Function()? nowMs,
    this.pingEvery = const Duration(seconds: 2),
    this.liveFor = const Duration(seconds: 6),
    this.onLiveChanged,
  }) : _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _channel = PresentChannel.open(channelName(sessionId));
    _sub = _channel.messages.listen(_onMessage);
    _ping = Timer.periodic(pingEvery, (_) => _tick());
    _post({'t': 'ping'});
  }

  final String sessionId;
  final String connectionId;
  final PresentationRole role;

  /// A message of another tab, as the event the server would have sent.
  final void Function(PresentationEvent e) onEvent;

  /// Local epoch ms → server epoch ms (the link's clock offset).
  final int Function(int localMs) toServerMs;
  final int Function() _now;
  final Duration pingEvery;

  /// A peer counts as live this long after its last message.
  final Duration liveFor;

  /// [live] changed.
  final void Function()? onLiveChanged;

  static String channelName(String sessionId) => 'wonky-present-$sessionId';

  late final PresentChannel _channel;
  late final StreamSubscription<String> _sub;
  late final Timer _ping;
  int? _peerAt;
  bool _live = false;
  bool _closed = false;

  bool get _isPresenter => role == PresentationRole.presenter;

  /// Whether a peer that matters was heard within [liveFor]: the presenter
  /// (for audiences and remotes), any member (for the presenter).
  bool get live => _live;

  void _tick() {
    _post({'t': 'ping'});
    _updateLive();
  }

  void _updateLive() {
    final at = _peerAt;
    final live = at != null && _now() - at < liveFor.inMilliseconds;
    if (live == _live) return;
    _live = live;
    onLiveChanged?.call();
  }

  void _post(Map<String, Object?> m) {
    if (_closed) return;
    _channel.post(
      jsonEncode({
        'v': 1,
        'from': connectionId,
        'role': role.name,
        'at': _now(),
        ...m,
      }),
    );
  }

  /// Posts [u] to the other tabs (what this role may send; others are
  /// dropped). Returns whether it was posted.
  bool send(PresentationUpdate u) {
    if (_closed) return false;
    switch (u) {
      case PresentationStateUpdate(:final state) when _isPresenter:
        _post({'t': 'state', 'state': state.toJson()});
      case PresentationLaserUpdate(:final slideId, :final x, :final y)
          when _isPresenter:
        _post({'t': 'laser', 'slideId': slideId, 'x': x, 'y': y});
      case PresentationInkUpdate(
            :final slideId,
            :final op,
            :final strokeId,
            :final strokeJson,
          )
          when _isPresenter:
        _post({
          't': 'ink',
          'slideId': slideId,
          'op': op,
          'strokeId': strokeId,
          'strokeJson': strokeJson,
        });
      case PresentationEndUpdate() when _isPresenter:
        _post({'t': 'end'});
      case PresentationCommandUpdate(:final command, :final argsJson)
          when !_isPresenter && role != PresentationRole.follower:
        _post({'t': 'command', 'command': command, 'argsJson': argsJson});
      default:
        return false;
    }
    return true;
  }

  void _onMessage(String raw) {
    if (_closed) return;
    final Map<String, Object?> m;
    try {
      final v = jsonDecode(raw);
      if (v is! Map) return;
      m = v.cast<String, Object?>();
    } on FormatException {
      return;
    }
    if (m['v'] != 1 || m['from'] == connectionId) return;
    final from = '${m['from']}';
    final fromPresenter = m['role'] == PresentationRole.presenter.name;
    // Members only listen to the presenter; the presenter to members.
    if (_isPresenter == fromPresenter) return;
    _peerAt = _now();
    _updateLive();
    final at = m['at'];
    final server = toServerMs(at is int ? at : _now());
    final PresentationEvent? e = switch (m['t']) {
      'state' when m['state'] is Map => PresentationStateEvent(
        serverTimeMs: server,
        state: PresentationState.fromJson(
          (m['state']! as Map).cast<String, dynamic>(),
        ),
      ),
      'laser' => PresentationLaserEvent(
        serverTimeMs: server,
        slideId: m['slideId'] as String?,
        x: (m['x'] as num?)?.toDouble(),
        y: (m['y'] as num?)?.toDouble(),
      ),
      'ink' when m['slideId'] is String && m['op'] is String =>
        PresentationInkEvent(
          serverTimeMs: server,
          slideId: m['slideId']! as String,
          op: m['op']! as String,
          strokeId: m['strokeId'] as String?,
          strokeJson: m['strokeJson'] as String?,
        ),
      'end' => PresentationEndedEvent(serverTimeMs: server, reason: 'ended'),
      'command' when _isPresenter && m['command'] is String =>
        PresentationCommandEvent(
          serverTimeMs: server,
          command: m['command']! as String,
          argsJson: m['argsJson'] as String?,
          fromConnectionId: from,
        ),
      _ => null,
    };
    if (e != null) onEvent(e);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _ping.cancel();
    unawaited(_sub.cancel());
    _channel.close();
  }
}
