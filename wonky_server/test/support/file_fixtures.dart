import 'dart:io';
import 'dart:typed_data';

/// Sample files of `test/fixtures/files/` (sniffing, previews, uploads).
abstract final class FileFixtures {
  static Directory get _dir {
    // Tests run from the package root (`dart test`).
    final dir = Directory('test/fixtures/files');
    if (!dir.existsSync()) {
      throw StateError('Run the tests from wonky_server/ ($dir not found).');
    }
    return dir;
  }

  /// The bytes of fixture [name].
  static Uint8List bytes(String name) =>
      File('${_dir.path}/$name').readAsBytesSync();
}
