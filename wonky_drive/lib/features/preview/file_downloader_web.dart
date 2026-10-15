import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Clicks a hidden `<a href download>` (same tab; the response is an
/// attachment, so the page does not navigate).
bool downloadUrl(String url, String fileName) {
  final document = globalContext['document']! as JSObject;
  final body = document['body'] as JSObject?;
  final a = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
  a['href'] = url.toJS;
  a['download'] = fileName.toJS;
  a['rel'] = 'noopener'.toJS;
  (a['style']! as JSObject)['display'] = 'none'.toJS;
  body?.callMethod<JSAny?>('appendChild'.toJS, a);
  a.callMethod<JSAny?>('click'.toJS);
  a.callMethod<JSAny?>('remove'.toJS);
  return true;
}
