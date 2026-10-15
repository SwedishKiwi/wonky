import 'package:flutter/foundation.dart';
import 'package:wonky_core/wonky_core.dart';

/// A planned Slides feature that is not built for M9 (Slides 12 §4; the
/// remaining work is in `TODO.md`, "Wonky Slides — later (M10/M11)").
///
/// Slides only shows what works (SL-23): while a feature is off, its
/// commands are not registered (so no menu, toolbar, context menu, palette
/// row, shortcut or MCP `ui.*` entry offers it), and its inspector tabs,
/// sections, settings and view modes are left out. The code paths and the
/// core logic stay; the work package that builds a feature turns it on in
/// [SlidesFeatures.enabled] (and replaces the placeholder commands of
/// `placeholder_commands.dart` with real ones).
enum SlidesFeature {
  /// Builds, transitions, Magic Move, the Animate tab and animation
  /// preview (06; SL-29, SL-30). The timeline core (SL-24) is built.
  animations('SL-29, SL-30'),

  /// Code blocks: insert, edit, highlight steps, states (07; SL-31). The
  /// code core (SL-26) is built and existing code elements render.
  codeBlocks('SL-31'),

  /// Linked Sheets charts and native charts (08; SL-27, SL-32). Existing
  /// chart elements render as a static placeholder.
  charts('SL-27, SL-32'),

  /// Masters and layout editing, the theme editor, placeholder insertion
  /// (05 §8; SL-28).
  masters('SL-28'),

  /// The outline view (04 §10; SL-34).
  outlineView('SL-34'),

  /// The Layers panel (03 §8.1; SL-34).
  layers('SL-34'),

  /// The accessibility checker (03 §17.4; SL-34).
  accessibilityChecker('SL-34'),

  /// PNG / PNG ZIP export (10 §13; SL-33) and Markdown export (P2).
  imageExports('SL-33'),

  /// *Print each build stage* (10 §11; SL-33).
  printBuilds('SL-33'),

  /// Comments on slides and elements, comment pins (09 §3; SL-38).
  comments('SL-38'),

  /// Version history (09 §4; SL-39).
  versionHistory('SL-39'),

  /// The assistant and AI commands (11 §6–§8; SL-43).
  assistant('SL-43'),

  /// Phone remote and rehearse timings (10 §5.2, §10; SL-41).
  remoteAndRehearse('SL-41'),

  /// Spelling, presentation language, special characters (03 §14; SL-44).
  spelling('SL-44'),

  /// Autoformat while typing and smart quotes (03 §6.2.1; SL-13
  /// leftovers), editor units and scroll-to-change-slides (04 §13.16).
  editorPreferences('04 §13.16'),

  /// *Import slides…* (04 §13.9, P1).
  importSlides('04 §13.9'),

  /// Snap to grid (03 §5.3, P2).
  snapGrid('03 §5.3'),

  /// Notification settings (suite 07).
  notificationSettings('suite 07');

  const SlidesFeature(this.workPackage);

  /// The work package (Slides 12 §4) or spec section that builds it.
  final String workPackage;
}

/// The feature switches of Wonky Slides ([SlidesFeature]).
abstract final class SlidesFeatures {
  /// The features that are on. Empty for M9: every [SlidesFeature] is
  /// hidden. Work packages add their feature here when they ship it;
  /// tests may switch one on (and restore the set in `tearDown`).
  static Set<SlidesFeature> enabled = const {};

  /// Whether [feature] is on.
  static bool isOn(SlidesFeature feature) => enabled.contains(feature);

  /// The feature a whole command belongs to (null = always available).
  /// Commands of a hidden feature are not registered.
  static SlidesFeature? featureOfCommand(String id) {
    for (final (prefix, feature) in _commandPrefixes) {
      if (id == prefix || (prefix.endsWith('.') && id.startsWith(prefix))) {
        return feature;
      }
    }
    return null;
  }

  /// The feature of one invocation (command + fixed arguments): adds the
  /// argument values that lead to unbuilt work (view modes, export
  /// formats, inspector tabs and sections, paste modes).
  static SlidesFeature? featureOf(
    String id, [
    Map<String, Object?> args = const {},
  ]) {
    final whole = featureOfCommand(id);
    if (whole != null) return whole;
    return switch (id) {
      'slides.view.setMode' => switch (args['mode']) {
        'outline' => SlidesFeature.outlineView,
        'masters' => SlidesFeature.masters,
        _ => null,
      },
      'slides.file.download' => switch (args['format']) {
        'png' || 'pngZip' || 'markdown' => SlidesFeature.imageExports,
        _ => null,
      },
      'slides.inspector.open' =>
        args['tab'] == 'animate'
            ? SlidesFeature.animations
            : switch (args['section']) {
                'code' => SlidesFeature.codeBlocks,
                'chart' => SlidesFeature.charts,
                _ => null,
              },
      'slides.edit.pasteSpecial' =>
        args['mode'] == 'unlinked' || args['mode'] == 'linked'
            ? SlidesFeature.charts
            : null,
      _ => null,
    };
  }

  /// Whether [id] with [args] is offered (its feature is on or it has
  /// none).
  static bool offers(String id, [Map<String, Object?> args = const {}]) {
    final f = featureOf(id, args);
    return f == null || isOn(f);
  }

  /// Whether the command [id] is registered.
  static bool registers(String id) {
    final f = featureOfCommand(id);
    return f == null || isOn(f);
  }

  /// [items] without the commands of hidden features; submenus left empty
  /// are dropped and separators tidied (no leading, trailing or double
  /// ones).
  static List<MenuSpec> prune(List<MenuSpec> items) {
    final out = <MenuSpec>[];
    for (final m in items) {
      switch (m) {
        case MenuCommand(:final commandId, :final args):
          if (offers(commandId, args)) out.add(m);
        case MenuSubmenu():
          final children = prune(m.children);
          if (children.any((c) => c is! MenuSeparator)) {
            out.add(m.copyWith(children: children));
          }
        case MenuSeparator():
          if (out.isNotEmpty && out.last is! MenuSeparator) out.add(m);
        case MenuSectionLabel() || MenuCustom():
          out.add(m);
      }
    }
    while (out.isNotEmpty && out.last is MenuSeparator) {
      out.removeLast();
    }
    return out;
  }

  /// [root] pruned ([prune]).
  static MenuRoot pruneRoot(MenuRoot root) => MenuRoot(prune(root.children));

  /// The shell's commands that Slides does not offer while their feature
  /// is off (`WonkyAppConfig.hidesShellCommand`).
  static bool hidesShellCommand(String id) =>
      id.startsWith('shell.') && !registers(id);

  /// Restores the M9 defaults (tests).
  @visibleForTesting
  static void reset() => enabled = const {};

  static const _commandPrefixes = <(String, SlidesFeature)>[
    ('slides.animate.', SlidesFeature.animations),
    ('slides.magicMove.', SlidesFeature.animations),
    ('slides.panel.animate', SlidesFeature.animations),
    ('slides.slide.duplicateForMagicMove', SlidesFeature.animations),
    ('slides.code.', SlidesFeature.codeBlocks),
    ('slides.insert.code', SlidesFeature.codeBlocks),
    ('slides.chart.', SlidesFeature.charts),
    ('slides.insert.chart', SlidesFeature.charts),
    ('slides.insert.chartFromSheets', SlidesFeature.charts),
    ('slides.panel.linkedObjects', SlidesFeature.charts),
    ('slides.theme.edit', SlidesFeature.masters),
    ('slides.layout.', SlidesFeature.masters),
    ('slides.panel.layers', SlidesFeature.layers),
    ('slides.panel.accessibility', SlidesFeature.accessibilityChecker),
    ('slides.tools.accessibilityCheck', SlidesFeature.accessibilityChecker),
    ('slides.view.toggleCommentPins', SlidesFeature.comments),
    ('slides.history.', SlidesFeature.versionHistory),
    ('slides.ai.', SlidesFeature.assistant),
    ('slides.present.rehearse', SlidesFeature.remoteAndRehearse),
    ('slides.present.remote', SlidesFeature.remoteAndRehearse),
    ('slides.spelling.', SlidesFeature.spelling),
    ('slides.file.setLanguage', SlidesFeature.spelling),
    ('slides.insert.specialCharacter', SlidesFeature.spelling),
    ('slides.file.importSlides', SlidesFeature.importSlides),
    ('slides.view.toggleSnapGrid', SlidesFeature.snapGrid),
    ('slides.notifications.', SlidesFeature.notificationSettings),
    // Shell features Slides doesn't support yet.
    ('shell.comments.', SlidesFeature.comments),
    ('shell.versions.', SlidesFeature.versionHistory),
    ('shell.ai.', SlidesFeature.assistant),
  ];
}
