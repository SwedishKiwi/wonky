import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';
import 'package:wonky_charts_flutter/gpu.dart';

import 'config/sheets_app_config.dart';

/// Wonky Sheets boots through the shared shell (suite 03).
void main() {
  // 3D charts render with flutter_scene once the first one is shown
  // (08 §23.7).
  Chart3DBackends.starter = installChart3DGpuBackend;
  WonkyShell.run(const SheetsAppConfig());
}
