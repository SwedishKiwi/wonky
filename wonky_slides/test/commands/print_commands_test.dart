import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart' show CommandState;
import 'package:wonky_slides/features/print/slides_client_export.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';

import '../harness/deck_harness.dart';
import '../support/deck_screen.dart' show sampleDeck;

/// The print and PDF export commands (Slides 10 §11.6, §12, §14; SL-20)
/// through the real dispatcher on the deck harness.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = slidesL10nEnglish;
  late DeckHarness d;

  setUp(() => d = DeckHarness.open(fixture: sampleDeck()));
  tearDown(() => d.dispose());

  String location() =>
      d.services.router.routeInformationProvider.value.uri.toString();
  CommandState state(String id, [Map<String, Object?> args = const {}]) =>
      d.services.dispatcher.stateOf(id, args);
  String deckPath() => '/p/${d.session.itemUuid.uuid}';

  group('Given an open deck', () {
    test('when Print is invoked then the print preview route opens', () async {
      final r = await d.run('slides.print.open');

      expect(r.isOk, isTrue);
      expect(location(), '${deckPath()}/print');
    });

    test(
      'when Print is invoked for notes then the route carries the layout',
      () async {
        await d.run('slides.print.open', {'layout': 'notes'});

        expect(location(), '${deckPath()}/print?layout=notes');
      },
    );

    test('when downloading a PDF then the print preview opens', () async {
      await d.run('slides.file.download', {'format': 'pdf'});

      expect(location(), '${deckPath()}/print');
    });

    test('when downloading PNG then the item is disabled as not available '
        'yet', () {
      final st = state('slides.file.download', {'format': 'png'});

      expect(st.enabled, isFalse);
      expect(st.disabledReason, l.reasonNotAvailableYet);
    });

    test('when no preview is open then Print PDF is disabled', () {
      expect(state('slides.print.print').enabled, isFalse);
    });

    test('when exporting immediately with options then the PDF is saved with '
        'the deck title and the options become the last used', () async {
      final saved = <(String, Uint8List)>[];
      final previous = SlidesClientExport.saver;
      SlidesClientExport.saver = (bytes, name) async {
        saved.add((name, bytes));
        return true;
      };
      addTearDown(() => SlidesClientExport.saver = previous);

      final r = await d.run('slides.file.download', {
        'format': 'pdf',
        'immediate': true,
        'options': {'layout': 'handouts', 'handoutsPerPage': 2},
      });

      expect(r.isOk, isTrue, reason: '${r.message}');
      expect(saved.single.$1, 'Q3 review.pdf');
      expect(String.fromCharCodes(saved.single.$2.sublist(0, 5)), '%PDF-');
      expect((r.data! as Map)['pageCount'], 2);
      final stored = d.services.prefs.slidesDefaults['exportOptions'] as Map;
      expect(stored['layout'], 'handouts');
      expect(stored['handoutsPerPage'], 2);
      expect(location(), isNot(contains('/print')));
    });
  });
}
