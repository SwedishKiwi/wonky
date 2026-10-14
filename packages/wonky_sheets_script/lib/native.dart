/// Native (desktop and server) sandbox for scripts: isolates with a
/// synchronous `Mailbox` bridge (09 §8.2.1). Not available on the web; the
/// web uses `InlineScriptRunner` (see its documentation).
library;

export 'src/runner/isolate_runner.dart' show IsolateScriptRunner;
