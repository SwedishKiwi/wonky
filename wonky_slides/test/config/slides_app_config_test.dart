import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show CommandStatus;
import 'package:wonky_slides/config/slides_app_config.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';

import '../support/slides_harness.dart';

/// The contract of [SlidesAppConfig] with the shared shell (suite 03,
/// Slides 12 SL-1).
void main() {
  const config = SlidesAppConfig();

  group('Given the Wonky Slides app config', () {
    test('when read then it is the Slides app editing presentations', () {
      expect(config.app, WonkyAppKind.slides);
      expect(config.appName, 'Wonky Slides');
      expect(config.shortAppName, 'Slides');
      expect(config.primaryKind, DriveItemKind.presentation);
      expect(config.primaryKind, WonkyAppKind.slides.editorKind);
      expect(config.brandColor, slidesBrandColor);
    });

    test('when asked for an item path then decks live under /p/', () {
      expect(config.itemPath('abc'), '/p/abc');
      expect(
        config.itemPath('abc'),
        WonkyAppKind.itemPathFor(DriveItemKind.presentation, 'abc'),
      );
    });

    test('when read then its home lists only presentations with the app-home '
        'menu', () {
      final scope = config.homeScope!;

      expect(scope, const HomeScope.kind(DriveItemKind.presentation));
      expect(scope.lists(DriveItemKind.presentation), isTrue);
      expect(scope.lists(DriveItemKind.document), isFalse);
      expect(scope.lists(DriveItemKind.spreadsheet), isFalse);
      expect(scope.lists(DriveItemKind.file), isFalse);
      expect(scope.newKinds, [DriveItemKind.presentation]);
      expect(scope.showsTypeFilter, isFalse);
      expect(config.homeNav, HomeNavSpec.appHome);
    });

    test('when read then it has a /new route and no import support', () {
      expect(config.newItemRoute, isNotNull);
      expect(config.importRoute, isNull);
      expect(config.importHandler, isNull);
    });

    test('when read then it brings the Slides localizations', () {
      expect(
        config.localizationsDelegates,
        contains(SlidesLocalizations.delegate),
      );
      expect(slidesL10nEnglish.untitledPresentation, 'Untitled presentation');
    });

    test('when the pseudo-locale is loaded then every string is '
        'pseudo-localized', () {
      final xa = lookupSlidesLocalizations(const Locale('en', 'XA'));

      expect(xa.untitledPresentation, startsWith('['));
      expect(xa.editorComingSoonTitle, startsWith('['));
      expect(xa.deckDownloading, startsWith('['));
      expect(xa.backToSlides, startsWith('['));
    });
  });

  group('Given the Slides data layer is not installed (no replica)', () {
    late CommandTestHarness h;

    setUp(() => h = slidesHarness());
    tearDown(() => h.dispose());

    test('when creating an item then the presentation is created on the '
        'server', () async {
      final uuid = await config.createItem(h.services, name: 'Pitch');

      final item = h.drive.item(uuid!);
      expect(item.kind, DriveItemKind.presentation);
      expect(item.name, 'Pitch');
      expect(h.drive.calls, contains('createPresentation'));
    });

    test('when the /new route runs then it creates a presentation', () async {
      final handler = config.newItemRoute!;
      final context = _FakeContext();

      final uuid = await handler(context, h.services, const NewItemRequest());

      expect(h.drive.item(uuid!).kind, DriveItemKind.presentation);
    });

    test('when New presentation is invoked then the command creates one and '
        'returns its uuid', () async {
      final result = await h.invoke('shell.file.new', {'kind': 'presentation'});

      expect(result.status, CommandStatus.ok);
      expect(
        h.drive.items.where((i) => i.kind == DriveItemKind.presentation),
        hasLength(1),
      );
    });
  });
}

class _FakeContext extends Fake implements BuildContext {}
