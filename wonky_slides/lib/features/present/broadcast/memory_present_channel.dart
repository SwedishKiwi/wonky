import 'dart:async';

import 'present_channel.dart';

/// An in-process [PresentChannel] (desktop builds and tests): channels of
/// the same name in this isolate see each other's messages (async, like
/// `BroadcastChannel`).
class MemoryPresentChannel implements PresentChannel {
  MemoryPresentChannel(this.name) {
    _hub.putIfAbsent(name, () => {}).add(this);
  }

  final String name;
  final _out = StreamController<String>.broadcast();
  bool _closed = false;

  static final Map<String, Set<MemoryPresentChannel>> _hub = {};

  /// Drops every open channel (tests).
  static void reset() {
    for (final set in _hub.values) {
      for (final c in [...set]) {
        c.close();
      }
    }
    _hub.clear();
  }

  /// Whether a channel named [name] is open (tests).
  static int openCount(String name) => _hub[name]?.length ?? 0;

  @override
  Stream<String> get messages => _out.stream;

  @override
  void post(String message) {
    if (_closed) return;
    for (final c in [...?_hub[name]]) {
      if (identical(c, this)) continue;
      scheduleMicrotask(() {
        if (!c._closed) c._out.add(message);
      });
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _hub[name]?.remove(this);
    unawaited(_out.close());
  }
}
