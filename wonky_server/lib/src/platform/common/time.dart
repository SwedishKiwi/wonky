import 'package:clock/clock.dart';

/// The current UTC time. Services never call `DateTime.now()` directly so
/// tests can fix the time with `withClock` (specs/15 §4).
DateTime nowUtc() => clock.now().toUtc();
