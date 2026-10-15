/// Shared fonts of the Wonky Work apps (Slides 05 §3.1, Write 06 §8): the
/// curated [FontRegistry] (manifest only, weight snapping, script fallback
/// chains), the [FontProvider] interface used by the PDF/HTML exporters, and
/// the [BundledFonts] manifest of the static TTF faces shipped as package
/// assets (`fonts/`).
///
/// Pure Dart: runs on the server and in the apps. The Flutter side (loading
/// faces into the engine) stays with each app.
library;

export 'src/bundled_fonts.dart';
export 'src/font_provider.dart';
export 'src/font_registry.dart';
