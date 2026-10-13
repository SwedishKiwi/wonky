import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/bootstrap/app_urls.dart';

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
  });
}
