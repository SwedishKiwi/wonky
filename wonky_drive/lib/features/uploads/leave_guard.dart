import 'leave_guard_io.dart'
    if (dart.library.js_interop) 'leave_guard_web.dart'
    as platform;

/// Asks before the page unloads while uploads run (Drive 02 §3.5): the
/// browser's own "Leave site?" prompt (`beforeunload`). Cross-app
/// navigation is a full page load, so it is covered too. Desktop: nothing
/// (single window, uploads end with the app).
void setLeaveGuard(bool active) => platform.setLeaveGuard(active);
