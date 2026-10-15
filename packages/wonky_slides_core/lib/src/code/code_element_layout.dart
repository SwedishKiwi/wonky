/// The core's code element layout (Slides 07 §3, 12 §5.6): the
/// `CodeSceneSource` the scene builder uses by default. It resolves the
/// palette (`auto` by the effective background), font, chrome and box
/// defaults from the deck theme and composes scenes with
/// `CodeSceneComposer`.
library;

import 'package:wonky_code/wonky_code.dart';

import '../model/api/deck_reader.dart';
import '../model/api/resolved.dart';
import '../scene/nodes/code_scene.dart';
import '../scene/nodes/scene_nodes.dart';
import '../theme/model/common.dart';
import '../theme/resolve/resolved_theme.dart';
import 'code_element_data.dart';
import 'code_element_model.dart';
import 'code_scene_composer.dart';

/// Lays out code elements with `CodeElementModel` (replaces SL-10's basic
/// layout; `BasicCodeLayout` is now an alias).
final class CodeElementLayout implements CodeSceneSource {
  /// Creates the layout. [tokenizer] defaults to the shared cached
  /// tokenizer.
  const CodeElementLayout({this.tokenizer});

  final CodeTokenizer? tokenizer;

  static final _cache = Expando<_Entry>('codeComposer');

  /// The model of [element] (cached per resolved element revision).
  CodeElementModel model(ResolvedElement element, DeckReader? deck) =>
      _entry(element, deck).model;

  /// The composer of [element] for [theme] on a slide whose effective
  /// background is [background] (cached).
  CodeSceneComposer composer(
    ResolvedElement element,
    DeckReader? deck,
    ResolvedTheme theme, {
    int? background,
  }) {
    final entry = _entry(element, deck);
    final key = (theme.contentHash, theme.appearance, background);
    if (entry.composerKey == key) return entry.composer!;
    final composer = CodeSceneComposer(
      entry.model,
      styleOf(entry.model.data, theme, background: background),
    );
    entry
      ..composerKey = key
      ..composer = composer;
    return composer;
  }

  _Entry _entry(ResolvedElement element, DeckReader? deck) {
    final hit = _cache[element];
    if (hit != null && identical(hit.deck, deck)) return hit;
    final model = deck == null
        ? CodeElementModel(
            elementId: element.id,
            data: CodeElementData.fromJson(element.data),
            states: const [],
            tokenizer: tokenizer,
          )
        : CodeElementModel.fromDeck(
            deck,
            element.id,
            element.data,
            tokenizer: tokenizer,
          );
    return _cache[element] = _Entry(deck, model);
  }

  /// The render style of an element with [data] under [theme]; [background]
  /// is the effective slide background behind the element (07 §2.5 `auto`).
  static CodeRenderStyle styleOf(
    CodeElementData data,
    ResolvedTheme theme, {
    int? background,
  }) {
    final code = theme.codeStyle;
    final boxBackground = data.box.background == null
        ? null
        : theme.colorString(data.box.background, fallback: 0);
    final behind = boxBackground != null && (boxBackground >>> 24) != 0
        ? boxBackground
        : background;
    final palette = switch (data.palette) {
      'light' => theme.codeLight,
      'dark' => theme.codeDark,
      'auto' =>
        behind == null
            ? theme.codePalette
            : theme.codePaletteForBackground(behind),
      final id =>
        BuiltInPalettes.byId(id) ??
            (behind == null
                ? theme.codePalette
                : theme.codePaletteForBackground(behind)),
    };
    final family = theme
        .font(FontRef(data.fontFamily ?? code.font.value))
        .family;
    return CodeRenderStyle(
      palette: palette,
      fontFamily: family,
      metrics: MonoFontMetrics.forFamily(family),
      chromeDefault: code.chrome,
      cornerRadius: data.box.cornerRadius ?? code.cornerRadius,
      shadow: data.box.shadow ?? code.shadow,
      boxBackground: boxBackground != null && (boxBackground >>> 24) != 0
          ? boxBackground
          : null,
      boxBorder: data.box.borderColor == null
          ? null
          : theme.colorString(data.box.borderColor),
      borderWidth: data.box.borderColor == null ? 1 : data.box.borderWidth,
      barColorOverride: data.highlightStyle.barColor == null
          ? null
          : theme.colorString(data.highlightStyle.barColor),
      calloutColor: theme.colorOf('accent1'),
      calloutFontFamily: theme.font(const FontRef('@body')).family,
    );
  }

  @override
  CodeScene? codeScene(
    ResolvedElement element,
    DeckReader? deck,
    ResolvedTheme theme, {
    required double width,
    required double height,
    required ScenePurpose purpose,
    int? stateIndex,
    int? step,
    int? background,
  }) {
    final c = composer(element, deck, theme, background: background);
    final last = c.model.stateCount - 1;
    final index =
        stateIndex ??
        switch (purpose) {
          ScenePurpose.thumbnail || ScenePurpose.print => last,
          _ => 0,
        };
    final shownStep =
        step ??
        (purpose == ScenePurpose.present &&
                c.model.data.highlightStyle.startWithFirstStep &&
                c.model.state(index).stepCount > 0
            ? 0
            : null);
    return c.build(
      index,
      step: shownStep,
      width: width,
      height: height,
      dimming:
          purpose != ScenePurpose.print && purpose != ScenePurpose.thumbnail,
    );
  }
}

final class _Entry {
  _Entry(this.deck, this.model);

  final DeckReader? deck;
  final CodeElementModel model;
  Object? composerKey;
  CodeSceneComposer? composer;
}
