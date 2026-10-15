import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'memory_present_channel.dart';
import 'present_channel.dart';

/// The browser's `BroadcastChannel` (same origin, same profile).
PresentChannel openPresentChannel(String name) {
  try {
    return _WebPresentChannel(web.BroadcastChannel(name));
  } on Object {
    // No BroadcastChannel (very old browsers): this tab only.
    return MemoryPresentChannel(name);
  }
}

class _WebPresentChannel implements PresentChannel {
  _WebPresentChannel(this._channel) {
    _channel.onmessage = ((web.MessageEvent e) {
      final data = e.data;
      if (data != null && data.isA<JSString>() && !_out.isClosed) {
        _out.add((data as JSString).toDart);
      }
    }).toJS;
  }

  final web.BroadcastChannel _channel;
  final _out = StreamController<String>.broadcast();

  @override
  Stream<String> get messages => _out.stream;

  @override
  void post(String message) {
    if (_out.isClosed) return;
    try {
      _channel.postMessage(message.toJS);
    } on Object {
      // Closed by the browser.
    }
  }

  @override
  void close() {
    if (_out.isClosed) return;
    _channel.onmessage = null;
    _channel.close();
    unawaited(_out.close());
  }
}
