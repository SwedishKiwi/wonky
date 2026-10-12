import '../registry.dart';
import 'calendar.dart';
import 'differences.dart';
import 'weeks.dart';
import 'workdays.dart';

/// Date & time functions (05 §15.6). Dates are serial days since 1899-12-30 (05 §6.5).
void registerDateTime(FunctionRegistryBuilder b) {
  b.category = FunctionCategory.dateTime;
  registerCalendar(b);
  registerDifferences(b);
  registerWeeks(b);
  registerWorkdays(b);
}
