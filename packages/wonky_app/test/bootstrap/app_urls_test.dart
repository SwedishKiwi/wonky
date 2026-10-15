import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/bootstrap/app_urls.dart';
import 'package:wonky_client/wonky_client.dart';

void main() {
  group('Given a config.json', () {
    test('when it has no cookieAuth key then cookie auth is off', () {
      final urls = AppUrls.fromJson({
        'apiUrl': 'https://wonkywork.api.serverpod.space',
        'apps': {'write': 'https://wonkywork.serverpod.space/write/'},
      });

      expect(urls.cookieAuth, isFalse);
      expect(urls.apiUrl, 'https://wonkywork.api.serverpod.space/');
      expect(
        urls.apps[WonkyAppKind.write],
        'https://wonkywork.serverpod.space/write/',
      );
    });

    test('when the server enables cookieAuth then it is on', () {
      final urls = AppUrls.fromJson({
        'apiUrl': 'http://localhost:8080',
        'cookieAuth': true,
      });

      expect(urls.cookieAuth, isTrue);
    });

    test('when it has a webUrl then the legal pages are on that server', () {
      final urls = AppUrls.fromJson({
        'apiUrl': 'https://wonkywork.api.serverpod.space',
        'webUrl': 'https://wonkywork.serverpod.space',
      });

      expect(urls.page('terms'), 'https://wonkywork.serverpod.space/terms');
      expect(
        AppUrls.fromJson(const {}).page('privacy'),
        'http://localhost:8082/privacy',
      );
    });

    test('when it has a google client then Google sign-in is configured', () {
      final urls = AppUrls.fromJson({
        'apiUrl': 'https://wonkywork.api.serverpod.space',
        'webUrl': 'https://wonky.work/',
        'google': {
          'clientId': 'id.apps.googleusercontent.com',
          'redirectUri': 'https://wonky.work/auth/callback',
        },
      });

      expect(urls.google?.clientId, 'id.apps.googleusercontent.com');
      expect(urls.google?.redirectUri, 'https://wonky.work/auth/callback');
      expect(AppUrls.fromJson(const {}).google, isNull);
      expect(
        AppUrls.fromJson(const {
          'google': {'clientId': ''},
        }).google,
        isNull,
      );
    });
  });

  group('Given the four apps (v2)', () {
    test('when config.json lists only Write then the others use dev ports', () {
      final urls = AppUrls.fromJson({
        'apps': {'write': 'https://wonky.work/write'},
      });

      expect(urls.apps.keys, containsAll(WonkyAppKind.values));
      expect(urls.apps[WonkyAppKind.write], 'https://wonky.work/write/');
      expect(urls.apps[WonkyAppKind.drive], 'http://localhost:8100/');
      expect(urls.apps[WonkyAppKind.slides], 'http://localhost:8104/');
      expect(
        urls.urlFor(WonkyAppKind.drive, '/file/x'),
        'http://localhost:8100/file/x',
      );
    });

    test('when an AppUrls lacks an app then urlFor falls back', () {
      const urls = AppUrls(
        apiUrl: 'http://localhost:8080/',
        apps: {WonkyAppKind.write: 'http://localhost:8101/'},
      );

      expect(
        urls.urlFor(WonkyAppKind.slides, 'p/1'),
        'http://localhost:8104/p/1',
      );
    });

    test('when mapping kinds then each opens in its app and path', () {
      expect(
        WonkyAppKind.forItemKind(DriveItemKind.presentation),
        WonkyAppKind.slides,
      );
      expect(WonkyAppKind.forItemKind(DriveItemKind.file), WonkyAppKind.drive);
      expect(
        WonkyAppKind.forItemKind(
          DriveItemKind.folder,
          current: WonkyAppKind.sheets,
        ),
        WonkyAppKind.sheets,
      );
      expect(WonkyAppKind.itemPathFor(DriveItemKind.document, 'u'), '/d/u');
      expect(WonkyAppKind.itemPathFor(DriveItemKind.spreadsheet, 'u'), '/s/u');
      expect(WonkyAppKind.itemPathFor(DriveItemKind.presentation, 'u'), '/p/u');
      expect(WonkyAppKind.itemPathFor(DriveItemKind.file, 'u'), '/file/u');
      for (final k in DriveItemKind.values) {
        if (k == DriveItemKind.folder) continue;
        final path = WonkyAppKind.itemPathFor(k, 'u');
        expect(
          WonkyAppKind.ownerOfPath(path),
          WonkyAppKind.forItemKind(k),
          reason: k.name,
        );
      }
      expect(WonkyAppKind.ownerOfPath('/settings/app'), isNull);
    });

    test('when naming apps then product names and editor kinds match', () {
      expect(WonkyAppKind.values.map((k) => k.productName), [
        'Wonky Drive',
        'Wonky Write',
        'Wonky Sheets',
        'Wonky Slides',
      ]);
      expect(WonkyAppKind.drive.editorKind, isNull);
      expect(WonkyAppKind.slides.editorKind, DriveItemKind.presentation);
      expect(WonkyAppKind.sheets.urlScheme, 'wonkysheets');
    });
  });
}
