import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

/// Brand color of Wonky Sheets.
const sheetsBrandColor = Color(0xff16a34a);

/// Wonky Sheets' description for the shared shell. Sheets features are
/// frozen in this iteration: opening a spreadsheet shows a "coming soon"
/// screen inside the shell's editor frame.
class SheetsAppConfig extends WonkyAppConfig {
  const SheetsAppConfig();

  @override
  WonkyAppKind get app => WonkyAppKind.sheets;

  @override
  String get appName => 'Wonky Sheets';

  @override
  DriveItemKind get primaryKind => DriveItemKind.spreadsheet;

  @override
  Color get brandColor => sheetsBrandColor;

  @override
  Widget logo({double size = 28}) =>
      WonkyProductIcon(WonkyProduct.sheets, size: size);

  @override
  String itemPath(String uuid) => '/s/$uuid';

  @override
  String untitledName(BuildContext context) => 'Untitled spreadsheet';

  @override
  Widget buildEditor(BuildContext context, GoRouterState state, String uuid) =>
      SheetsComingSoon(
        key: ValueKey<String>('sheets.editor.$uuid'),
        services: ShellScope.of(context),
        uuid: uuid,
      );
}

/// `/s/:uuid` placeholder.
class SheetsComingSoon extends StatefulWidget {
  const SheetsComingSoon({
    super.key,
    required this.services,
    required this.uuid,
  });

  final ShellServices services;
  final String uuid;

  @override
  State<SheetsComingSoon> createState() => _SheetsComingSoonState();
}

class _SheetsComingSoonState extends State<SheetsComingSoon> {
  late final BasicDocumentController _doc = BasicDocumentController(
    itemUuid: UuidValue.fromString(widget.uuid),
    kind: DriveItemKind.spreadsheet,
  );

  @override
  void dispose() {
    _doc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditorScaffold(
    services: widget.services,
    itemUuid: widget.uuid,
    controller: _doc,
    onItemLoaded: (item) => _doc.update(title: item.name, role: item.myRole),
    body: (context, item) => const WonkyEmptyState(
      key: ValueKey<String>('sheets.comingSoon'),
      illustration: EmptyIllustration.spreadsheets,
      title: 'The spreadsheet editor is coming soon',
      description:
          'Wonky Sheets is still being built. Your spreadsheet is safe in your drive.',
    ),
  );
}
