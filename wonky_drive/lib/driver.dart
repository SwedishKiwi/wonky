// Entry point for `serverpod start` (flutter_apps) and agents driving the app
// with flutter_driver. Never used for release builds.
// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';

import 'main.dart' as app;

void main() {
  enableFlutterDriverExtension(
    // Text entry emulation is disabled to allow manual usage of the app. Set
    // it to true (and hot restart) so agents can type through the driver.
    enableTextEntryEmulation: false,
  );
  app.main();
}
