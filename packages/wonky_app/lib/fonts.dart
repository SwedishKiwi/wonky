/// Bundled document fonts for the apps (Slides 05 §3.1/§3.3, Write 06 §8.3):
/// [AssetFontRegistry] registers `wonky_fonts` faces with the engine on
/// demand, and [BundledAssetFontProvider] hands the same TTF bytes to
/// client-side PDF exporters.
library;

export 'src/fonts/asset_font_registry.dart';
