import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show PresenceRoster;
import 'package:wonky_core/wonky_core.dart' show KeyScope;
import 'package:wonky_sheets/features/collab/collab_overlay.dart';
import 'package:wonky_sheets/features/collab/presence/presence_cursor.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/l10n/sheets_l10n.dart';
import 'package:wonky_ui/wonky_ui.dart';

import 'support/collab_harness.dart';

Future<void> pumpOverlay(
  WidgetTester tester,
  CollabHarness s, {
  required bool dark,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    Provider<ShellServices>.value(
      value: s.services,
      child: ShadApp(
        theme: dark ? WonkyTheme.dark() : WonkyTheme.light(),
        localizationsDelegates: const [
          WonkyAppLocalizations.delegate,
          WonkyUiLocalizations.delegate,
          SheetsLocalizations.delegate,
        ],
        home: Material(
          type: MaterialType.transparency,
          child: WonkyThemeScope(
            data: const WonkyThemeExtension(),
            child: KeymapScope(
              scope: KeyScope.global,
              keymap: s.services.keymap,
              child: CollabGridOverlay(
                controller: s.editor,
                child: GridArea(controller: s.editor, services: s.services),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final dark in [false, true]) {
    for (final width in [1200.0, 360.0]) {
      final name = '${dark ? 'dark' : 'light'}, ${width.toInt()} px';
      testWidgets('when a comment is started ($name) then the composer docks '
          'next to the cell and Cancel closes it', (tester) async {
        late CollabHarness s;
        await tester.runAsync(() async => s = await CollabHarness.open());
        await tester.runAsync(() => s.select('B2'));
        await pumpOverlay(tester, s, dark: dark, size: Size(width, 700));
        await tester.runAsync(() => s.run('shell.comments.create'));
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('sheets.comments.composer')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        s.comments.cancelDraft();
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('sheets.comments.composer')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(s.dispose);
      });

      testWidgets('when a collaborator edits a cell ($name) then the grid '
          'paints the marching border and typing preview without errors', (
        tester,
      ) async {
        late CollabHarness s;
        await tester.runAsync(() async => s = await CollabHarness.open());
        await pumpOverlay(tester, s, dark: dark, size: Size(width, 700));
        final (r, c) = s.ids('B2');
        s.presenceRepo.emit(
          PresenceRoster(
            sessionId: 'me',
            participants: [
              participant('me', userId: 1, name: 'Anna'),
              participant(
                'bo',
                cursorJson: SheetsPresenceCursor(
                  sheetId: s.sheetId,
                  activeRowId: r,
                  activeColId: c,
                  editing: true,
                ).encode(),
              ),
            ],
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        s.collab.presence.setTyping(
          'bo',
          sheetId: s.sheetId,
          rowId: r,
          colId: c,
          text: 'Hello there',
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(s.collab.presence.marching, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(s.dispose);
      });
    }
  }
}
