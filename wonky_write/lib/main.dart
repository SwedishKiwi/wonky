import 'package:wonky_app/wonky_app.dart';

import 'config/write_app_config.dart';
import 'features/themes/write_fonts.dart';

/// Wonky Write boots through the shared shell (suite 03).
void main() {
  registerWriteFontLicenses();
  WonkyShell.run(const WriteAppConfig());
}
