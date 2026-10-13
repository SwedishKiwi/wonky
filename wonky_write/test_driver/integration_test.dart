// Host side of `flutter drive` for the E2E journeys on web
// (`flutter test integration_test` does not support web devices):
//   flutter drive -d chrome --driver=test_driver/integration_test.dart \
//     --target=integration_test/journey_01_sign_up_type_persist_test.dart
// needs a chromedriver listening on port 4444.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
