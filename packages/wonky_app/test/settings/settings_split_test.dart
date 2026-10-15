import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/src/routing/router.dart';
import 'package:wonky_app/src/settings/settings_catalog.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/testing.dart';

import '../support/screen_pump.dart';

/// An app with two settings sections of its own.
class _AppWithSettings extends TestAppConfig {
  const _AppWithSettings({super.extraCommands});

  @override
  List<SettingsSectionSpec> appSettingsSections(ShellServices services) => [
    SettingsSectionSpec(
      id: 'editor',
      title: (_) => 'Editor',
      icon: LucideIcons.squarePen,
      builder: (_) => const Text('Editor body'),
    ),
    SettingsSectionSpec(
      id: 'themes',
      title: (_) => 'Document themes',
      icon: LucideIcons.palette,
      builder: (_) => const Text('Themes body'),
    ),
  ];
}

/// The settings split (D-12, suite 04 §4): two nav groups, the
/// `/settings/app[/:section]` and `/settings/:section` routes, redirects of
/// the v1 section ids, keyboard groups, the storage section and 360 px.
void main() {
  late CommandTestHarness h;

  Future<void> pumpRouter(
    WidgetTester tester, {
    WonkyAppConfig config = const _AppWithSettings(),
    required String initial,
    Size size = const Size(1280, 900),
    Brightness brightness = Brightness.light,
  }) async {
    h = CommandTestHarness(config: config);
    h.services.router = buildShellRouter(h.services);
    await pumpScreen(
      tester,
      h,
      Router.withConfig(config: h.services.router),
      size: size,
      brightness: brightness,
    );
    h.services.router.go(initial);
    await tester.pumpAndSettle();
  }

  String location() => h.services.router.state.uri.toString();
  Finder key(String k) => find.byKey(ValueKey<String>(k));

  tearDown(() => h.dispose());

  group('Routes', () {
    testWidgets('Given /settings/app when it opens then the first app '
        'section shows under the app settings title', (tester) async {
      await pumpRouter(tester, initial: '/settings/app');

      expect(location(), '/settings/app/editor');
      expect(key('settings.section.app.editor'), findsOneWidget);
      expect(find.text('Editor body'), findsOneWidget);
      // The page header names the group of the open section.
      expect(find.text('Test settings'), findsWidgets);
      expect(key('settings.group.app'), findsOneWidget);
      expect(key('settings.group.work'), findsOneWidget);
      await settleTooltips(tester);
    });

    testWidgets('Given /settings when it opens then Wonky Work settings › '
        'Account & profile show', (tester) async {
      await pumpRouter(tester, initial: '/settings');

      expect(location(), '/settings/account');
      expect(key('settings.section.account'), findsOneWidget);
      expect(find.text('Wonky Work settings'), findsWidgets);
      await settleTooltips(tester);
    });

    testWidgets('Given every Wonky Work section id when it opens then that '
        'section shows', (tester) async {
      await pumpRouter(tester, initial: '/settings/account');
      for (final id in workSettingsSectionIds) {
        h.services.router.go('/settings/$id');
        await tester.pumpAndSettle();
        expect(key('settings.section.$id'), findsOneWidget, reason: id);
        expect(key('settings.nav.$id'), findsOneWidget, reason: id);
      }
      await settleTooltips(tester);
    });

    testWidgets('Given Write when the v1 /settings/write and '
        '/settings/themes open then they redirect to its app settings', (
      tester,
    ) async {
      await pumpRouter(tester, initial: '/settings/write');
      expect(location(), '/settings/app/editor');

      h.services.router.go('/settings/themes');
      await tester.pumpAndSettle();
      expect(location(), '/settings/app/themes');
      expect(find.text('Themes body'), findsOneWidget);
      await settleTooltips(tester);
    });

    testWidgets('Given Write when the v1 /settings/sheets opens then Sheets '
        'settings open in Sheets', (tester) async {
      await pumpRouter(tester, initial: '/settings/sheets');

      expect(key('settings.handoff'), findsOneWidget);
      expect(h.crossApp.opened, [
        (WonkyAppKind.sheets, '/settings/app/defaults'),
      ]);
      await settleTooltips(tester);
    });

    testWidgets('Given an app without settings of its own when '
        '/settings/app opens then Wonky Work settings show', (tester) async {
      await pumpRouter(
        tester,
        config: const TestAppConfig(app: WonkyAppKind.slides),
        initial: '/settings/app',
      );
      expect(location(), '/settings/account');

      h.services.router.go('/settings/app/anything');
      await tester.pumpAndSettle();
      expect(location(), '/settings/account');
      // No app group in the nav.
      expect(key('settings.group.app'), findsNothing);
      await settleTooltips(tester);
    });

    testWidgets('Given an unknown app section when it opens then the first '
        'app section shows', (tester) async {
      await pumpRouter(tester, initial: '/settings/app/nope');

      expect(key('settings.section.app.editor'), findsOneWidget);
      await settleTooltips(tester);
    });
  });

  group('Commands', () {
    testWidgets('Given the v1 section ids when shell.settings.open runs '
        'then they map to the app settings', (tester) async {
      await pumpRouter(tester, initial: '/');

      await h.invoke('shell.settings.open', {'section': 'write'});
      await tester.pumpAndSettle();
      expect(location(), '/settings/app/editor');

      await h.invoke('shell.settings.open', {'section': 'ai-providers'});
      await tester.pumpAndSettle();
      expect(location(), '/settings/ai-providers');

      await h.invoke('shell.settings.openApp', {'section': 'themes'});
      await tester.pumpAndSettle();
      expect(location(), '/settings/app/themes');

      await h.invoke('shell.settings.openApp');
      await tester.pumpAndSettle();
      expect(location(), '/settings/app/editor');
      await settleTooltips(tester);
    });

    test('Given Mod+, on desktop when bound then it opens the app '
        'settings', () {
      h = CommandTestHarness(config: const _AppWithSettings());
      final open = h.services.registry.byId('shell.settings.openApp')!;
      expect(open.defaultBindings.single.key, ',');
      expect(
        h.services.registry.byId('shell.settings.open')!.defaultBindings,
        isEmpty,
      );
    });
  });

  group('Nav', () {
    testWidgets('Given the wide nav when sections and other apps are '
        'tapped then they navigate (other apps in their app)', (tester) async {
      await pumpRouter(tester, initial: '/settings/app/editor');

      await tester.tap(key('settings.nav.app.themes'));
      await tester.pumpAndSettle();
      expect(location(), '/settings/app/themes');

      await tester.tap(key('settings.nav.appearance'));
      await tester.pumpAndSettle();
      expect(location(), '/settings/appearance');

      expect(key('settings.nav.other.sheets'), findsNothing);
      await tester.tap(key('settings.nav.otherApps'));
      await tester.pumpAndSettle();
      // The three other apps, never the current one.
      expect(key('settings.nav.other.write'), findsNothing);
      for (final a in ['drive', 'sheets', 'slides']) {
        expect(key('settings.nav.other.$a'), findsOneWidget);
      }
      await tester.tap(key('settings.nav.other.sheets'));
      await tester.pumpAndSettle();
      expect(h.crossApp.opened, [(WonkyAppKind.sheets, '/settings/app')]);
      await settleTooltips(tester);
    });

    test('Given visited routes when leaving settings then Back returns to '
        'the last non-settings route, else home', () {
      h = CommandTestHarness();
      expect(settingsBackTarget(h.services), '/');
      h.services.recordLocation('/d/abc');
      h.services.recordLocation('/settings/app/editor');
      h.services.recordLocation('/settings/account');
      expect(settingsBackTarget(h.services), '/d/abc');
    });

    for (final b in Brightness.values) {
      testWidgets('Given 360 px in ${b.name} when settings show then the nav '
          'is a select, nothing overflows and the page is accessible', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpRouter(
          tester,
          initial: '/settings/keyboard',
          size: const Size(360, 780),
          brightness: b,
        );

        expect(key('settings.nav.select.work:keyboard'), findsOneWidget);
        expect(key('settings.nav.keyboard'), findsNothing);
        expect(key('settings.section.keyboard'), findsOneWidget);
        await expectAccessible(tester);

        h.services.router.go('/settings/app/editor');
        await tester.pumpAndSettle();
        expect(key('settings.nav.select.app:editor'), findsOneWidget);
        await expectAccessible(tester);
        semantics.dispose();
        await settleTooltips(tester);
      });
    }

    testWidgets('Given the narrow select when another section is chosen '
        'then it navigates', (tester) async {
      await pumpRouter(
        tester,
        initial: '/settings/app/editor',
        size: const Size(360, 780),
      );

      await tester.tap(key('settings.nav.select.app:editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language & region').last);
      await tester.pumpAndSettle();
      expect(location(), '/settings/language');
      await settleTooltips(tester);
    });
  });

  group('Keyboard shortcuts', () {
    testWidgets('Given shared and app commands when the section shows then '
        'they are grouped, and Reset all keeps the other apps\' overrides', (
      tester,
    ) async {
      final appCommand = CallbackCommand(
        id: 'write.test.bold',
        title: (_) => 'Test bold',
        run: (ctx, a) async => const CommandResult.ok(),
      );
      await pumpRouter(
        tester,
        config: _AppWithSettings(extraCommands: [appCommand]),
        initial: '/settings/keyboard',
      );
      final km = h.services.keymap;
      km.loadOverrides(
        '{"shell.nav.home":["Mod+J"],"write.test.bold":["Mod+B"],'
        '"sheets.format.bold":["Mod+K"]}',
      );
      await tester.pumpAndSettle();

      expect(key('settings.keyboard.group.shared'), findsOneWidget);
      expect(key('settings.keyboard.group.app'), findsOneWidget);
      expect(key('settings.keyboard.write.test.bold'), findsOneWidget);

      final saved = <String>[];
      km.onOverridesChanged = saved.add;
      await tester.tap(key('settings.keyboard.resetAll'));
      await tester.pumpAndSettle();

      expect(km.overrides.keys, ['sheets.format.bold']);
      expect(saved, hasLength(1));
      await settleTooltips(tester);
    });

    test('Given a removed override when the keymap is saved then the patch '
        'deletes it on the server', () async {
      h = CommandTestHarness();
      final p = h.services.prefs;
      await p.setKeymapOverrides('{"a":["Mod+J"],"b":["Mod+K"]}');
      await p.setKeymapOverrides('{"b":["Mod+K"]}');

      expect(h.users.patches.last.keymapOverrides, '{"b":["Mod+K"],"a":null}');
      expect(p.keymapOverrides, '{"b":["Mod+K"]}');
    });
  });

  group('Storage', () {
    testWidgets('Given a usage when Settings › Storage shows then the meter, '
        'the breakdown and Manage storage in Wonky Drive work', (tester) async {
      h = CommandTestHarness(
        storage: FakeStorage.used(12 * 1024 * 1024, trashBytes: 1024 * 1024),
      );
      await pumpScreen(
        tester,
        h,
        SettingsScreen(services: h.services, section: 'storage'),
      );

      expect(key('settings.storage.meter'), findsOneWidget);
      expect(find.textContaining('of 50 MB used'), findsOneWidget);
      for (final k in [
        'documents',
        'spreadsheets',
        'presentations',
        'files',
        'trash',
      ]) {
        expect(key('settings.storage.$k'), findsOneWidget, reason: k);
      }

      await tester.tap(key('settings.storage.manage'));
      await tester.pumpAndSettle();
      expect(h.crossApp.opened, [(WonkyAppKind.drive, '/storage')]);
    });

    testWidgets('Given no storage controller when the section shows then '
        'it says the usage is unavailable', (tester) async {
      h = CommandTestHarness();
      await pumpScreen(
        tester,
        h,
        SettingsScreen(services: h.services, section: 'storage'),
      );

      expect(key('settings.storage.meter'), findsNothing);
      expect(find.text("Storage usage isn't available right now."), findsOne);
      expect(key('settings.storage.manage'), findsOneWidget);
    });
  });

  group('Preferences', () {
    test('Given Drive and Slides settings when set then they are patched '
        'key by key', () async {
      h = CommandTestHarness();
      final p = h.services.prefs;
      await p.setDriveDefault('layout', 'grid');
      await p.setSlidesDefault('slideSize', '16:9');
      await p.setSlidesPresenter('timer', true);

      expect(p.driveDefaults, {'layout': 'grid'});
      expect(p.slidesDefaults, {'slideSize': '16:9'});
      expect(p.slidesPresenter, {'timer': true});
      expect(h.users.patches.map((x) => x.driveDefaults).nonNulls, [
        '{"layout":"grid"}',
      ]);

      await p.setDriveDefault('layout', null);
      expect(p.driveDefaults, isEmpty);
      expect(h.users.patches.last.driveDefaults, '{"layout":null}');
    });
  });
}
