import 'present_channel_io.dart'
    if (dart.library.js_interop) 'present_channel_web.dart';

/// A same-browser message channel between the tabs of one browser profile
/// (Slides 10 §5.2, the P1 same-browser fast path; SL-41): the web uses a
/// `BroadcastChannel`; other platforms (and tests) an in-process hub
/// ([MemoryPresentChannel]). Messages go to every *other* channel of the
/// same name, never back to the sender.
abstract class PresentChannel {
  /// Opens the channel [name]; tests replace the factory.
  static PresentChannel Function(String name) factory = openPresentChannel;

  static PresentChannel open(String name) => factory(name);

  /// Messages of the other channels with this name.
  Stream<String> get messages;

  /// Sends [message] to the other channels with this name.
  void post(String message);

  void close();
}
