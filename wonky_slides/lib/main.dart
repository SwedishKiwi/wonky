import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_charts_flutter/gpu.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart'
    show Chart3DBackends;

import 'config/slides_app_config.dart';

/// Wonky Slides boots through the shared shell (suite 03, Slides 01 §7).
void main() {
  // 3D charts render with flutter_scene once the first one is shown
  // (Slides 08 §10.1).
  Chart3DBackends.starter = installChart3DGpuBackend;
  WonkyShell.run(const SlidesAppConfig());
}
