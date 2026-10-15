import '../../schema/slides_schema.dart';
import '../api/deck_model.dart';
import '../api/events.dart';
import '../api/records.dart';
import 'element_tree.dart';
import 'placeholder_index.dart';
import 'slide_order.dart';
import 'table_index.dart';
import 'theme_index.dart';

/// The derived indexes of a [DeckModel] (02 §11): [order] (`SlideOrder`),
/// [tree] per owner (`ElementTree`), [themes] (`ThemeIndex`),
/// [placeholders] (`PlaceholderIndex`), [table] per table element
/// (`TableIndex`), builds by element (`BuildIndex`) and per-slide revision
/// counters for memoized resolution.
///
/// Built lazily and invalidated selectively from the model's change
/// batches (a silent ingestion invalidates everything). Get the instance of
/// a model with [DeckIndexes.of] (one per model).
final class DeckIndexes {
  DeckIndexes._(this.model) : _seen = model.version {
    model.addListener(_onBatch);
  }

  static final Expando<DeckIndexes> _cache = Expando('deckIndexes');

  /// The indexes of [model] (created on first use).
  static DeckIndexes of(DeckModel model) =>
      _cache[model] ??= DeckIndexes._(model);

  /// The indexed model.
  final DeckModel model;

  int _seen;
  SlideOrder? _order;
  ThemeIndex? _themes;
  PlaceholderIndex? _placeholders;
  final Map<String, ElementTree> _trees = {};
  final Map<String, TableIndex> _tables = {};
  Map<String, List<SlideBuildRec>>? _buildsByElement;
  final Map<String, int> _slideRev = {};
  int _globalRev = 0;

  void _invalidateAll() {
    _order = null;
    _themes = null;
    _placeholders = null;
    _trees.clear();
    _tables.clear();
    _buildsByElement = null;
    _slideRev.clear();
    _globalRev++;
  }

  void _sync() {
    if (model.version != _seen) {
      _invalidateAll();
      _seen = model.version;
    }
  }

  void _onBatch(DeckChangeBatch batch) {
    if (model.version != _seen + 1) {
      _invalidateAll();
      _seen = model.version;
      return;
    }
    _seen = model.version;
    for (final e in batch.events) {
      switch (e) {
        case DeckChanged():
          _order = null;
          _themes = null;
          _placeholders = null;
          _globalRev++;
        case SlidesChanged():
          _order = null;
          // layoutId/skip changes affect layout usage and numbering.
          _themes = null;
          _placeholders = null;
          for (final s in e.slideIds) {
            _bump(s);
          }
        case OrderChanged():
          _order = null;
          _globalRev++;
        case ElementsChanged():
          for (final o in e.ownerIds) {
            _trees.remove(o);
            _bump(o);
          }
          for (final id in e.elementIds) {
            _tables.remove(id);
          }
        case ThemeChanged():
          _themes = null;
          _placeholders = null;
          for (final id in [...e.layoutIds, ...e.masterIds]) {
            _trees.remove(id);
          }
          _globalRev++;
        case BuildsChanged():
          _buildsByElement = null;
          for (final s in e.slideIds) {
            _bump(s);
          }
        case OtherRowsChanged():
          break;
      }
    }
  }

  void _bump(String slideId) =>
      _slideRev[slideId] = (_slideRev[slideId] ?? 0) + 1;

  /// The presentation order.
  SlideOrder get order {
    _sync();
    return _order ??= SlideOrder.of(model);
  }

  /// Themes, masters and layouts.
  ThemeIndex get themes {
    _sync();
    return _themes ??= ThemeIndex.of(model);
  }

  /// Placeholder chains.
  PlaceholderIndex get placeholders {
    _sync();
    return _placeholders ??= PlaceholderIndex(model, themes);
  }

  /// The element tree of [ownerId] (slide, layout or master).
  ElementTree tree(String ownerId) {
    _sync();
    return _trees[ownerId] ??= ElementTree.of(model, ownerId);
  }

  /// The structure of table element [elementId].
  TableIndex table(String elementId) {
    _sync();
    return _tables[elementId] ??= TableIndex.of(model, elementId);
  }

  /// Builds targeting [elementId] (any slide), in table order.
  List<SlideBuildRec> buildsOfElement(String elementId) {
    _sync();
    final map = _buildsByElement ??= () {
      final out = <String, List<SlideBuildRec>>{};
      for (final r in model.records(SlidesTables.slideBuild)) {
        final b = r as SlideBuildRec;
        final el = b.elementId;
        if (el != null) (out[el] ??= []).add(b);
      }
      return out;
    }();
    return map[elementId] ?? const [];
  }

  /// A revision of what [slideId] renders from: changes of the slide, its
  /// elements and builds bump it; theme, deck and order changes bump every
  /// slide; the slide's number and effective skip are part of it (another
  /// slide's skip renumbers this one). Equal revisions mean an equal
  /// resolution.
  String revision(String slideId) {
    _sync();
    final e = order.entry(slideId);
    return '$_globalRev.${_slideRev[slideId] ?? 0}.${e?.number}.${e?.skipped}';
  }
}

/// Index accessors on [DeckModel].
extension DeckModelIndexes on DeckModel {
  /// The derived indexes of this model.
  DeckIndexes get indexes => DeckIndexes.of(this);
}
