import 'package:serverpod/serverpod.dart';

import '../../platform/common/models.dart';
import '../../platform/users/user_service.dart';
import 'slides_chart_service.dart';

/// Linked charts from Wonky Sheets in Wonky Slides (Slides 08 §13, `slidesCharts`):
/// the insert dialog's chart list, snapshot resolution for insert/*Update*, and link status
/// checks. Access and errors: [SlidesChartService].
class SlidesChartsEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// The charts of spreadsheet [spreadsheetUuid] (drive item uuid) with ≤ 200-point
  /// previews. Viewer+. Errors: notFound (`no_access`, `spreadsheet_trashed`),
  /// limitExceeded.
  Future<ChartSourceList> listCharts(
    Session session,
    UuidValue spreadsheetUuid,
  ) async => SlidesChartService.listCharts(
    session,
    await UserService.actorOf(session),
    spreadsheetUuid,
  );

  /// The snapshot of chart [chartObjectId] of [spreadsheetUuid]. Viewer+ with the right to
  /// copy data. Errors: notFound (`no_access`, `spreadsheet_trashed`, `chart_not_found`),
  /// forbidden (`export_disabled`), invalidArgument (`unsupported_spec`), tooLarge
  /// (`chart_too_large`), limitExceeded.
  Future<ChartSnapshotView> resolveSnapshot(
    Session session,
    UuidValue spreadsheetUuid,
    String chartObjectId,
  ) async => SlidesChartService.resolveSnapshot(
    session,
    await UserService.actorOf(session),
    spreadsheetUuid,
    chartObjectId,
  );

  /// The status of each of ≤ 50 linked charts, in order (08 §5.2).
  Future<List<ChartLinkStatus>> checkLinks(
    Session session,
    List<ChartLinkProbe> probes,
  ) async => SlidesChartService.checkLinks(
    session,
    await UserService.actorOf(session),
    probes,
  );
}
