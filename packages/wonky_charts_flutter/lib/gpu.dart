/// The `flutter_scene` GPU backend of 3D charts (Sheets 08 §23.7): Flutter GPU on native
/// platforms, its WebGL2 backend on the web. The app's entry point registers it:
///
/// ```dart
/// Chart3DBackends.starter = installChart3DGpuBackend;
/// ```
library;

export 'src/three_d/flutter_scene_renderer.dart';
export 'src/three_d/install_chart3d_gpu.dart';
export 'src/three_d/mesh_winding.dart';
