import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_slides/config/slides_app_config.dart';
import 'package:wonky_slides/features/settings/slides_settings.dart';
import 'package:wonky_slides/features/settings/slides_user_defaults.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';
import 'package:wonky_ui/testing.dart';

import '../../support/slides_harness.dart';

/// Slides settings (Slides 04 §13.16): the app settings sections at
/// `/settings/app/<section>`, every control through `slides.prefs.set` /
/// `slides.presenter.set`.
void main() {
  final l = slidesL10nEnglish;
  late CommandTestHarness h;

  setUp(() => h = slidesHarness());
  tearDown(() => h.dispose());

  test(
    'Given the Slides app config when its settings are listed then the '
    'four sections are presentations, editing, animations and presenting',
    () {
      final sections = const SlidesAppConfig().appSettingsSections(h.services);
      expect(
        [for (final s in sections) s.id],
        ['presentations', 'editing', 'animations', 'presenting'],
      );
    },
  );

  for (final page in SlidesSettingsPage.values) {
    for (final (size, brightness) in [
      (const Size(1280, 900), Brightness.light),
      (const Size(360, 900), Brightness.dark),
    ]) {
      testWidgets('Given the ${page.name} settings at ${size.width.toInt()} px '
          '(${brightness.name}) when shown then they render without '
          'overflow', (tester) async {
        await pumpSlides(
          tester,
          h,
          SingleChildScrollView(
            child: SlidesSettingsSection(services: h.services, section: page),
          ),
          size: size,
          brightness: brightness,
        );

        expect(
          find.byKey(ValueKey<String>('settings.slides.${page.name}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await settleTooltips(tester);
      });
    }
  }

  testWidgets('Given the Editing settings when a switch is flipped then the '
      'synced Slides setting changes through slides.prefs.set', (tester) async {
    await pumpSlides(
      tester,
      h,
      SingleChildScrollView(
        child: SlidesSettingsSection(
          services: h.services,
          section: SlidesSettingsPage.editing,
        ),
      ),
    );
    final d = SlidesUserDefaults.of(h.services);
    expect(d.flag(SlidesUserDefaults.keySmartQuotes), isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('settings.slides.smartQuotes')),
    );
    await tester.pumpAndSettle();

    expect(d.flag(SlidesUserDefaults.keySmartQuotes), isFalse);
    expect(h.services.prefs.slidesDefaults['smartQuotes'], false);
    expect(find.text(l.settingsSmartQuotes), findsOneWidget);
    await settleTooltips(tester);
  });

  testWidgets('Given the Presenting settings when a switch is flipped then '
      'the presenter preference changes', (tester) async {
    await pumpSlides(
      tester,
      h,
      SingleChildScrollView(
        child: SlidesSettingsSection(
          services: h.services,
          section: SlidesSettingsPage.presenting,
        ),
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('settings.slides.startWithPresenterView'),
      ),
    );
    await tester.pumpAndSettle();

    expect(h.services.prefs.slidesPresenter['startWithPresenterView'], true);
    await settleTooltips(tester);
  });
}
