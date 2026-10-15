import 'chart3d_gpu.dart';
import 'flutter_scene_renderer.dart';

/// Starts `flutter_scene` and installs it as the 3D chart backend (08
/// §23.7): Flutter GPU on native platforms (Impeller with
/// `FLTEnableFlutterGPU`), its built-in WebGL2 backend on the web (no build
/// flags). When it can't start, charts keep the software rendering.
Future<void> installChart3DGpuBackend() async {
  final r = await FlutterSceneChart3DRenderer.create();
  if (r != null) Chart3DBackends.install(r);
}
