import 'memory_present_channel.dart';
import 'present_channel.dart';

/// Desktop builds (deferred) and tests: an in-process channel.
PresentChannel openPresentChannel(String name) => MemoryPresentChannel(name);
