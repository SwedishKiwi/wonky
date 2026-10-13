import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;

import '../model/memory_workbook_session.dart';
import '../model/workbook_session.dart';

/// Opens the [WorkbookSession] of a spreadsheet item (suite 12 §2.5).
///
/// Placeholder until the sync data layer lands: an in-memory spreadsheet.
/// The editor screen only depends on this function and [WorkbookSession].
Future<WorkbookSession> openWorkbookSession(
  ShellServices services,
  UuidValue itemUuid,
) async => MemoryWorkbookSession.blank(itemUuid: itemUuid);
