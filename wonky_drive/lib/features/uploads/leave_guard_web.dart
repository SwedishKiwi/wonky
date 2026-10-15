import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSFunction? _handler;

void setLeaveGuard(bool active) {
  final window = globalContext;
  if (active && _handler == null) {
    final h = ((JSObject event) {
      event.callMethod<JSAny?>('preventDefault'.toJS);
      // Older browsers show the prompt only with a return value.
      event['returnValue'] = ''.toJS;
    }).toJS;
    _handler = h;
    window.callMethod<JSAny?>('addEventListener'.toJS, 'beforeunload'.toJS, h);
  } else if (!active && _handler != null) {
    window.callMethod<JSAny?>(
      'removeEventListener'.toJS,
      'beforeunload'.toJS,
      _handler,
    );
    _handler = null;
  }
}
