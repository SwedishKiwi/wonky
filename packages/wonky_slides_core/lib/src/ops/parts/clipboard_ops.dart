part of '../operations.dart';

// Clipboard (02 §12.1 "Clipboard", 03 §13; payload codec SL-8).

/// Theme handling of pasted slides (03 §13).
enum PasteThemeMode {
  /// Bring the source theme along (*Keep source formatting*).
  keepSource,

  /// Re-map to the destination theme (*Use destination theme*).
  useDestination,
}

/// Pastes slides from a clipboard payload (`SlidesClipboardCodec` JSON,
/// SL-8) at [target].
final class PasteSlides extends SlidesOperation {
  const PasteSlides(
    this.payload, {
    this.target,
    this.afterSlideId,
    this.themeMode = PasteThemeMode.useDestination,
  });

  /// The decoded clipboard payload (JSON map, SL-8).
  final Map<String, Object?> payload;
  final SlideTarget? target;
  final String? afterSlideId;
  final PasteThemeMode themeMode;

  @override
  String get name => 'PasteSlides';
}

/// Pastes elements onto [slideId]; [at] = top-left of the pasted bounds
/// (null = same position, offset when it would cover the source).
final class PasteElements extends SlidesOperation {
  const PasteElements(this.payload, this.slideId, {this.atX, this.atY});

  final Map<String, Object?> payload;
  final String slideId;
  final double? atX;
  final double? atY;

  @override
  String get name => 'PasteElements';
}
