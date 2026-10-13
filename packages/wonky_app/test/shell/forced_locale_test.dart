import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';

void main() {
  test(
    'Given no WONKY_LOCALE when resolving then the system locale is used',
    () {
      expect(forcedLocale(''), isNull);
    },
  );

  test('Given the pseudo-locale tag when resolving then en_XA is forced', () {
    expect(forcedLocale('en_XA'), const Locale('en', 'XA'));
    expect(forcedLocale('en-xa'), const Locale('en', 'XA'));
    expect(
      WonkyAppLocalizations.supportedLocales,
      contains(const Locale('en', 'XA')),
    );
  });

  test('Given a supported language tag when resolving then it is forced', () {
    expect(forcedLocale('en'), const Locale('en'));
    expect(
      forcedLocale('en_Latn_GB'),
      const Locale.fromSubtags(
        languageCode: 'en',
        scriptCode: 'Latn',
        countryCode: 'GB',
      ),
    );
  });

  test('Given an unsupported language when resolving then it is ignored', () {
    expect(forcedLocale('xx_YY'), isNull);
  });

  test('Given en_XA when loading the localizations then messages are '
      'pseudo-localized and keep their placeholders', () async {
    final l = await WonkyAppLocalizations.delegate.load(
      const Locale('en', 'XA'),
    );
    expect(l.actionCancel, startsWith('[Çåñçéļ'));
    expect(l.assistantRemoveChip('Plan'), contains('Plan'));
    expect(l.selectedCount(3), contains('3'));
  });
}
