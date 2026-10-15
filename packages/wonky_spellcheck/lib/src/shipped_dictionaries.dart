/// Where the bundled dictionaries live (package assets).
library;

/// The dictionaries bundled with `wonky_spellcheck` (`dictionaries/`, listed
/// in `dictionaries/index.json`; sources and licenses in
/// `dictionaries/LICENSES.md`).
abstract final class ShippedDictionaries {
  /// The folder inside the package.
  static const directory = 'dictionaries';

  /// The Flutter asset key prefix of the folder in an app that depends on
  /// this package (`AssetBundle.loadString('$assetRoot/index.json')`).
  static const assetRoot = 'packages/wonky_spellcheck/$directory';

  /// The index file (`{"dictionaries": [{"tag", "name", "aff", "dic",
  /// "license"}]}`).
  static const index = 'index.json';
}
