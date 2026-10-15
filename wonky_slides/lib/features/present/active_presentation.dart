import 'package:flutter/foundation.dart';

import 'present_controller.dart';
import 'presentation_link.dart';

/// What the `slides.present.*` commands reach while a present screen is
/// open (one at a time: the window shows one route).
abstract interface class PresentHandle {
  /// The presentation (null while the deck opens).
  PresentController? get controller;

  /// The presentation session, if any.
  PresentationLink? get link;

  PresentView get view;

  /// Full screen on/off (`F`).
  Future<void> toggleFullscreen();

  /// The audience link + QR dialog (10 §5.2).
  Future<void> openOnAnotherDevice();
}

/// The open present screen, if any.
final ValueNotifier<PresentHandle?> activePresentation = ValueNotifier(null);
