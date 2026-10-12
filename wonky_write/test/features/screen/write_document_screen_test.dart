import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_ui/wonky_ui.dart';
import 'package:wonky_write/config/write_app_config.dart';
import 'package:wonky_write/features/document/write_document_session.dart';
import 'package:wonky_write/features/screen/write_document_screen.dart';
import 'package:wonky_write/features/sync/connection_keeper.dart';
import 'package:wonky_write/features/themes/document_theme.dart';
import 'package:wonky_write_core/wonky_write_core.dart' hide ThemeCatalog;

import '../document/support/session_harness.dart';
import '../sync/support/fake_document_server.dart';

void main() {
  late FakeDocumentServer server;
  late CommandTestHarness h;
  late WriteDocumentSession session;
  late SimpleConnectionKeeper keeper;

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      Provider<ShellServices>.value(
        value: h.services,
        child: ActiveDocumentHostScope(
          host: h.services,
          child: ShadApp(
            theme: dark ? WonkyTheme.dark() : WonkyTheme.light(),
            localizationsDelegates: const [
              WonkyAppLocalizations.delegate,
              WonkyUiLocalizations.delegate,
            ],
            home: Material(
              type: MaterialType.transparency,
              child: WonkyThemeScope(
                data: const WonkyThemeExtension(),
                child: WriteDocumentScreen(
                  services: h.services,
                  itemUuid: itemUuid,
                  themes: WriteThemeCatalog(),
                  sessionFactory: (s, uuid) => session,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(pumpEventQueue);
      await tester.pump(const Duration(milliseconds: 50));
      if (session.phase.value == WriteSessionPhase.ready && i > 10) break;
    }
    // Derived data (word count) is debounced.
    await tester.pump(const Duration(milliseconds: 400));
  }

  setUp(() {
    server = FakeDocumentServer(
      initial: const MarkdownCodec()
          .importMarkdown('# Plan\n\nHello world\n\n## Budget\n\nMoney\n')
          .delta,
    );
    h = CommandTestHarness(
      config: const WriteAppConfig(),
      comments: FakeComments(),
    );
    h.drive.seed(name: 'Plan', uuid: UuidValue.fromString(itemUuid));
    keeper = SimpleConnectionKeeper(minDelay: Duration.zero);
    session = WriteDocumentSession(
      services: h.services,
      itemUuid: itemUuid,
      api: FakeWriteApi(server),
      keeper: keeper,
    );
  });

  tearDown(() async {
    // Let the screen's disposal (undo stack close, stream cancels) settle
    // before the services go away.
    await pumpEventQueue();
    keeper.dispose();
    await pumpEventQueue();
    await h.dispose();
  });

  testWidgets('Given an open document when the screen loads then the '
      'header, menubar, toolbar, canvas and status bar render', (tester) async {
    await pumpScreen(tester);

    expect(session.phase.value, WriteSessionPhase.ready);
    for (final menu in ['File', 'Edit', 'View', 'Insert', 'Format', 'Tools']) {
      expect(find.text(menu), findsWidgets);
    }
    expect(find.byKey(const ValueKey('write.toolbar.style')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('write.toolbar.modeSwitcher')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('write.status.wordCount')),
      findsOneWidget,
    );
    expect(find.textContaining('5 words'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Given the screen when toggling the outline then the panel lists '
      'the headings', (tester) async {
    await pumpScreen(tester);

    await tester.runAsync(
      () => h.invoke('write.view.toggleOutline', const {}, InvocationSource.ui),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(pumpEventQueue);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('outline.item.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('outline.item.1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Given the screen when opening find then the find panel shows '
      'and highlights matches', (tester) async {
    await pumpScreen(tester);

    await tester.runAsync(
      () => h.invoke('write.find.open', const {
        'query': 'world',
      }, InvocationSource.ui),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('find.query')), findsOneWidget);
    expect(session.editor.view.findMatches, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  for (final (width, dark) in const [
    (768.0, true),
    (1024.0, false),
    (1440.0, true),
  ]) {
    testWidgets(
      'Given a ${width.toInt()} px window in ${dark ? 'dark' : 'light'} '
      'mode when the screen renders then nothing overflows',
      (tester) async {
        await pumpScreen(tester, size: Size(width, 900), dark: dark);

        expect(
          find.byKey(const ValueKey('write.toolbar.modeSwitcher')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
