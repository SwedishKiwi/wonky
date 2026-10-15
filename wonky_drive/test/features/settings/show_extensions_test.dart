import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

import '../../support/storage_fakes.dart';

/// *Show file extensions* (Drive 04 §8): off hides the extension of
/// uploaded files in the lists, live; other kinds keep their names.
void main() {
  late StorageTestbed t;

  setUp(() => t = StorageTestbed());
  tearDown(() => t.dispose());

  testWidgets('Given My Drive with a PDF when extensions are hidden in '
      'Drive settings then the list shows the name without it', (tester) async {
    t.h.drive.seed(name: 'notes.pdf', kind: DriveItemKind.file);
    t.h.drive.seed(name: 'v1.2 plan');
    await t.pump(tester, location: '/my-drive');
    expect(find.text('notes.pdf'), findsOneWidget);

    await t.h.invoke('drive.prefs.set', {
      'key': 'showExtensions',
      'value': false,
    });
    await tester.pumpAndSettle();

    expect(find.text('notes'), findsOneWidget);
    expect(find.text('notes.pdf'), findsNothing);
    expect(find.text('v1.2 plan'), findsOneWidget);
    await settleTooltips(tester);
  });
}
