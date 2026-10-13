import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'google_web_flow.dart';

/// Where `/auth/callback` (Serverpod's `FlutterWebAuth2CallbackRoute`)
/// leaves the callback URL when the popup has no opener — always, under
/// COOP `same-origin` — and the key of its `postMessage` otherwise.
const _key = 'flutter-web-auth-2';

/// One named popup: a new attempt reuses (navigates) the open one.
const _windowName = 'wonky-google-sign-in';

Completer<String?>? _pending;
Timer? _poll;
StreamSubscription<web.MessageEvent>? _messages;

void _finish(String? href) {
  _poll?.cancel();
  _poll = null;
  unawaited(_messages?.cancel());
  _messages = null;
  final pending = _pending;
  _pending = null;
  if (pending != null && !pending.isCompleted) pending.complete(href);
}

/// Opens [url] in the sign-in popup and completes with the callback URL that
/// [accepts] (matching `state`), or null when a newer attempt or
/// [cancelGooglePopup] replaces this one. Must run in the click's task
/// (popup blockers).
Future<String?> awaitGooglePopup(
  Uri url, {
  required bool Function(String href) accepts,
}) {
  _finish(null);
  final completer = _pending = Completer<String?>();
  final window = web.window;
  window.localStorage.removeItem(_key);

  const width = 480, height = 640;
  final left = window.screenX + (window.outerWidth - width) ~/ 2;
  final top = window.screenY + (window.outerHeight - height) ~/ 2;
  final popup = window.open(
    url.toString(),
    _windowName,
    'popup,width=$width,height=$height,left=$left,top=$top',
  );
  if (popup == null) {
    _pending = null;
    return Future.error(const GooglePopupBlockedException());
  }

  void offer(String? href) {
    if (href != null && accepts(href)) _finish(href);
  }

  _messages = window.onMessage.listen((event) {
    if (event.origin != window.location.origin) return;
    final data = event.data.dartify();
    if (data is Map) {
      final href = data[_key];
      if (href is String) offer(href);
    }
  });
  _poll = Timer.periodic(const Duration(milliseconds: 300), (_) {
    final href = window.localStorage.getItem(_key);
    if (href == null) return;
    // A stale attempt's result is dropped too.
    window.localStorage.removeItem(_key);
    offer(href);
  });
  return completer.future;
}

/// Gives up the pending attempt (its future completes with null).
void cancelGooglePopup() => _finish(null);
