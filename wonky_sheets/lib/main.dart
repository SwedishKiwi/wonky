import 'package:wonky_app/wonky_app.dart';

import 'config/sheets_app_config.dart';
import 'features/charts3d/chart3d_gpu.dart';
import 'features/charts3d/gpu/install_chart3d_gpu.dart';

/// Wonky Sheets boots through the shared shell (suite 03).
void main() {
  // 3D charts render with flutter_scene once the first one is shown
  // (08 §23.7).
  Chart3DBackends.starter = installChart3DGpuBackend;
  WonkyShell.run(const SheetsAppConfig());
}
