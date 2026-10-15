import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/themes.dart' show BuiltInThemes;

import '../../config/slides_features.dart';
import '../../l10n/slides_l10n.dart';
import '../builds/build_labels.dart';
import 'slides_user_defaults.dart';

/// Slides settings (Slides 04 §13.16, suite 04 §4.2, D4): the app settings
/// of Wonky Slides at `/settings/app/<section>`. Four sections group the
/// spec's seven: *New presentations* (+ Charts), *Editing* (+ Spelling),
/// *Animations & code*, *Presenting*. Settings of features that are off
/// ([SlidesFeatures]: charts, spelling, animations, code, editor
/// preferences) are hidden, and with them the whole *Animations & code*
/// section for M9. Values live in
/// `UserPreferences.slidesDefaults` / `slidesPresenter` and change through
/// `slides.prefs.set` / `slides.presenter.set`.
List<SettingsSectionSpec> slidesSettingsSections(ShellServices services) => [
  SettingsSectionSpec(
    id: 'presentations',
    title: (c) => slidesL10n(c).settingsSectionPresentations,
    icon: LucideIcons.presentation,
    builder: (_) => SlidesSettingsSection(
      services: services,
      section: SlidesSettingsPage.presentations,
    ),
  ),
  SettingsSectionSpec(
    id: 'editing',
    title: (c) => slidesL10n(c).settingsSectionEditing,
    icon: LucideIcons.mousePointer2,
    builder: (_) => SlidesSettingsSection(
      services: services,
      section: SlidesSettingsPage.editing,
    ),
  ),
  // Animations (SL-30) and code (SL-31) are hidden until built (SL-23).
  if (SlidesFeatures.isOn(SlidesFeature.animations) ||
      SlidesFeatures.isOn(SlidesFeature.codeBlocks))
    SettingsSectionSpec(
      id: 'animations',
      title: (c) => slidesL10n(c).settingsSectionAnimations,
      icon: LucideIcons.sparkles,
      builder: (_) => SlidesSettingsSection(
        services: services,
        section: SlidesSettingsPage.animations,
      ),
    ),
  SettingsSectionSpec(
    id: 'presenting',
    title: (c) => slidesL10n(c).settingsSectionPresenting,
    icon: LucideIcons.monitorPlay,
    builder: (_) => SlidesSettingsSection(
      services: services,
      section: SlidesSettingsPage.presenting,
    ),
  ),
];

/// `slides.prefs.set {key, value}` and `slides.presenter.set {key, value}`:
/// change one Slides setting (every control of Slides settings goes
/// through them, so MCP can change settings too; suite 04 §4.2). Not
/// undoable; work without an open presentation.
List<Command<CommandArgs>> slidesSettingsCommands(ShellServices s) => [
  CallbackCommand(
    id: 'slides.prefs.set',
    title: (c) => slidesL10n(c).cmdPrefsSet,
    icon: LucideIcons.slidersHorizontal,
    showInPalette: false,
    argsSchema: JsonSchema.object(
      properties: {
        'key': JsonSchema.string(
          enumValues: [
            for (final k in SlidesUserDefaults.defaultsKeys.keys)
              if (offersDefaultsKey(k)) k,
          ],
        ),
        'value': const JsonSchema.any(),
      },
      required: const ['key', 'value'],
    ),
    run: (ctx, a) async {
      final err = await SlidesUserDefaults.of(
        s,
      ).set(a.requireString('key'), a.values['value']);
      return err == null ? const CommandResult.ok() : CommandResult.failed(err);
    },
  ),
  CallbackCommand(
    id: 'slides.presenter.set',
    title: (c) => slidesL10n(c).cmdPresenterSet,
    icon: LucideIcons.presentation,
    showInPalette: false,
    argsSchema: JsonSchema.object(
      properties: {
        'key': JsonSchema.string(
          enumValues: SlidesUserDefaults.presenterKeys.keys.toList(),
        ),
        'value': const JsonSchema.any(),
      },
      required: const ['key', 'value'],
    ),
    run: (ctx, a) async {
      final err = await SlidesUserDefaults.of(
        s,
      ).setPresenter(a.requireString('key'), a.values['value']);
      return err == null ? const CommandResult.ok() : CommandResult.failed(err);
    },
  ),
];

/// Whether the `slidesDefaults` [key] belongs to a feature that is on
/// (hidden settings are neither shown nor advertised to MCP, SL-23).
bool offersDefaultsKey(String key) {
  // Key clicks while typing code (07 §5.3 `sound`) are P2 and not built.
  if (key == SlidesUserDefaults.keyTypeInSound) return false;
  final feature = switch (key) {
    SlidesUserDefaults.keyDefaultLanguage ||
    SlidesUserDefaults.keyUnderlineSpelling => SlidesFeature.spelling,
    SlidesUserDefaults.keyChartsAutoUpdate => SlidesFeature.charts,
    SlidesUserDefaults.keyUnits ||
    SlidesUserDefaults.keyScrollChangesSlides ||
    SlidesUserDefaults.keySmartQuotes ||
    SlidesUserDefaults.keyAutoformatLists => SlidesFeature.editorPreferences,
    SlidesUserDefaults.keyDefaultTransition ||
    SlidesUserDefaults.keyDefaultTransitionMs ||
    SlidesUserDefaults.keyDefaultBuild ||
    SlidesUserDefaults.keyPreviewOnHover ||
    SlidesUserDefaults.keyReduceEditorMotion => SlidesFeature.animations,
    SlidesUserDefaults.keyCodeFontSize ||
    SlidesUserDefaults.keyCodeLanguage ||
    SlidesUserDefaults.keyTypingSpeed => SlidesFeature.codeBlocks,
    _ => null,
  };
  return feature == null || SlidesFeatures.isOn(feature);
}

/// The pages of Slides settings.
enum SlidesSettingsPage { presentations, editing, animations, presenting }

/// One page of Slides settings.
class SlidesSettingsSection extends StatelessWidget {
  const SlidesSettingsSection({
    super.key,
    required this.services,
    required this.section,
  });

  final ShellServices services;
  final SlidesSettingsPage section;

  SlidesUserDefaults get _d => SlidesUserDefaults.of(services);

  void _set(String key, Object? value, {bool presenter = false}) => unawaited(
    services.dispatcher.invoke(
      presenter ? 'slides.presenter.set' : 'slides.prefs.set',
      args: {'key': key, 'value': value},
      source: InvocationSource.ui,
    ),
  );

  Widget _switch(
    String key,
    String label, {
    String? description,
    bool presenter = false,
  }) {
    final v = presenter ? _d.presenterFlag(key) : _d.flag(key);
    return SettingsRow(
      label: label,
      description: description,
      control: ShadSwitch(
        key: ValueKey<String>('settings.slides.$key'),
        value: v,
        onChanged: (nv) => _set(key, nv, presenter: presenter),
      ),
    );
  }

  Widget _select<T extends Object>(
    String key,
    String label,
    Map<T, String> options, {
    bool presenter = false,
    double width = 220,
  }) {
    final raw = presenter ? _d.presenterValue(key) : _d.value(key);
    final value = options.containsKey(raw) ? raw as T : options.keys.first;
    return SettingsRow(
      label: label,
      control: SizedBox(
        width: width,
        child: ShadSelect<T>(
          key: ValueKey<String>('settings.slides.$key'),
          initialValue: value,
          minWidth: width,
          options: [
            for (final e in options.entries)
              ShadOption<T>(value: e.key, child: Text(e.value)),
          ],
          selectedOptionBuilder: (context, v) =>
              Text(options[v] ?? '$v', overflow: TextOverflow.ellipsis),
          onChanged: (v) {
            if (v != null) _set(key, v, presenter: presenter);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: services.prefs,
    builder: (context, _) {
      final l = slidesL10n(context);
      return Column(
        key: ValueKey<String>('settings.slides.${section.name}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (section) {
          SlidesSettingsPage.presentations => _presentations(l),
          SlidesSettingsPage.editing => _editing(l),
          SlidesSettingsPage.animations => _animations(l),
          SlidesSettingsPage.presenting => _presenting(l),
        },
      );
    },
  );

  List<Widget> _presentations(SlidesLocalizations l) => [
    SettingsGroup(
      title: l.settingsNewPresentations,
      description: l.settingsNewPresentationsHint,
      children: [
        _select<String>(
          SlidesUserDefaults.keyDefaultThemeKey,
          l.settingsDefaultTheme,
          {for (final t in BuiltInThemes.all) t.key: t.name},
        ),
        _select<String>(
          SlidesUserDefaults.keyDefaultAppearance,
          l.settingsDefaultAppearance,
          {'light': l.appearanceLight, 'dark': l.appearanceDark},
        ),
        _select<String>(
          SlidesUserDefaults.keyDefaultSize,
          l.settingsDefaultSize,
          {for (final s in SlidesUserDefaults.sizes) s: slideSizeLabel(l, s)},
        ),
        // The presentation language drives spelling (SL-44).
        if (SlidesFeatures.isOn(SlidesFeature.spelling))
          _select<String>(
            SlidesUserDefaults.keyDefaultLanguage,
            l.settingsDefaultLanguage,
            {for (final (code, name) in slidesLanguages) code: name},
          ),
      ],
    ),
    if (SlidesFeatures.isOn(SlidesFeature.charts))
      SettingsGroup(
        title: l.settingsCharts,
        children: [
          _switch(
            SlidesUserDefaults.keyChartsAutoUpdate,
            l.settingsChartsAutoUpdate,
            description: l.settingsChartsAutoUpdateHint,
          ),
        ],
      ),
  ];

  List<Widget> _editing(SlidesLocalizations l) {
    final prefs = SlidesFeatures.isOn(SlidesFeature.editorPreferences);
    return _editingGroups(l, prefs);
  }

  List<Widget> _editingGroups(SlidesLocalizations l, bool prefs) => [
    SettingsGroup(
      title: l.settingsEditing,
      children: [
        // Units, scroll-to-change-slides, smart quotes and autoformat are
        // not built yet (SL-23: hidden, [SlidesFeature.editorPreferences]).
        if (prefs)
          _select<String>(SlidesUserDefaults.keyUnits, l.settingsUnits, {
            'su': l.unitsSu,
            'px': l.unitsPx,
            'in': l.unitsIn,
            'cm': l.unitsCm,
          }),
        _switch(SlidesUserDefaults.keySmartGuides, l.cmdViewToggleSmartGuides),
        _switch(SlidesUserDefaults.keySnapObjects, l.cmdViewToggleSnapObjects),
        _switch(SlidesUserDefaults.keySnapGuides, l.cmdViewToggleSnapGuides),
        if (prefs) ...[
          _switch(
            SlidesUserDefaults.keyScrollChangesSlides,
            l.settingsScrollChangesSlides,
          ),
          _switch(SlidesUserDefaults.keySmartQuotes, l.settingsSmartQuotes),
          _switch(
            SlidesUserDefaults.keyAutoformatLists,
            l.settingsAutoformatLists,
          ),
        ],
        _switch(
          SlidesUserDefaults.keyShowRemoteCursors,
          l.settingsShowRemoteCursors,
        ),
      ],
    ),
    if (SlidesFeatures.isOn(SlidesFeature.spelling))
      SettingsGroup(
        title: l.settingsSpelling,
        children: [
          _switch(
            SlidesUserDefaults.keyUnderlineSpelling,
            l.settingsUnderlineSpelling,
          ),
        ],
      ),
  ];

  List<Widget> _animations(SlidesLocalizations l) => [
    if (SlidesFeatures.isOn(SlidesFeature.animations))
      SettingsGroup(
        title: l.settingsAnimations,
        children: [
          _select<String>(
            SlidesUserDefaults.keyDefaultTransition,
            l.settingsDefaultTransition,
            {
              for (final id in SlidesUserDefaults.transitions)
                id: BuildLabels.transition(l, id),
            },
          ),
          _select<int>(
            SlidesUserDefaults.keyDefaultTransitionMs,
            l.settingsTransitionDuration,
            {
              for (final ms in const [250, 500, 750, 1000, 1500, 2000])
                ms: l.durationSeconds(
                  (ms / 1000).toStringAsFixed(ms % 1000 == 0 ? 0 : 2),
                ),
            },
            width: 140,
          ),
          _select<String>(
            SlidesUserDefaults.keyDefaultBuild,
            l.settingsDefaultBuild,
            {
              for (final id in SlidesUserDefaults.builds)
                id: BuildLabels.effect(l, id),
            },
          ),
          _switch(
            SlidesUserDefaults.keyPreviewOnHover,
            l.settingsPreviewOnHover,
          ),
          _switch(
            SlidesUserDefaults.keyReduceEditorMotion,
            l.settingsReduceEditorMotion,
            description: l.settingsReduceEditorMotionHint,
          ),
        ],
      ),
    if (SlidesFeatures.isOn(SlidesFeature.codeBlocks))
      SettingsGroup(
        title: l.settingsCode,
        children: [
          _select<int>(
            SlidesUserDefaults.keyCodeFontSize,
            l.settingsCodeFontSize,
            {
              for (final s in const [14, 16, 18, 20, 24, 28, 32, 40]) s: '$s',
            },
            width: 100,
          ),
          _select<String>(
            SlidesUserDefaults.keyCodeLanguage,
            l.settingsCodeLanguage,
            {
              for (final (id, name) in slidesCodeLanguages)
                id: id == 'plaintext' ? l.codePlainText : name,
            },
          ),
          _select<String>(
            SlidesUserDefaults.keyTypingSpeed,
            l.settingsTypingSpeed,
            {'slow': l.speedSlow, 'normal': l.speedNormal, 'fast': l.speedFast},
          ),
        ],
      ),
  ];

  List<Widget> _presenting(SlidesLocalizations l) => [
    SettingsGroup(
      title: l.settingsPresenting,
      description: l.settingsPresentingHint,
      children: [
        _select<String>(
          SlidesUserDefaults.keyPresenterLayout,
          l.settingsPresenterLayout,
          {
            'standard': l.presenterLayoutStandard,
            'notesFocus': l.presenterLayoutNotes,
            'nextLarge': l.presenterLayoutNext,
          },
          presenter: true,
        ),
        _select<int>(
          SlidesUserDefaults.keyNotesSize,
          l.settingsNotesSize,
          {
            for (final s in const [14, 16, 18, 22, 28, 36]) s: '$s',
          },
          presenter: true,
          width: 100,
        ),
        _select<String>(SlidesUserDefaults.keyTimerMode, l.settingsTimerMode, {
          'elapsed': l.timerElapsed,
          'countdown': l.timerCountdown,
        }, presenter: true),
        _select<int>(
          SlidesUserDefaults.keyTimerTargetMinutes,
          l.settingsTimerTarget,
          {
            for (final m in const [5, 10, 15, 20, 30, 45, 60, 90])
              m: l.durationMinutes(m),
          },
          presenter: true,
          width: 140,
        ),
        _select<String>(
          SlidesUserDefaults.keyLaserColor,
          l.settingsLaserColor,
          {
            'red': l.colorRed,
            'green': l.colorGreen,
            'blue': l.colorBlue,
            'amber': l.colorAmber,
          },
          presenter: true,
          width: 140,
        ),
        _switch(
          SlidesUserDefaults.keyStartFullscreen,
          l.settingsStartFullscreen,
          presenter: true,
        ),
        _switch(
          SlidesUserDefaults.keyStartWithPresenterView,
          l.settingsStartWithPresenterView,
          presenter: true,
        ),
        _switch(
          SlidesUserDefaults.keyShowSkippedInPresenter,
          l.settingsShowSkippedInPresenter,
          presenter: true,
        ),
      ],
    ),
  ];
}

/// Label of a slide size preset (`SlideSizeKind` name).
String slideSizeLabel(SlidesLocalizations l, String name) => switch (name) {
  'widescreen16x9' => l.sizeWidescreen16x9,
  'standard4x3' => l.sizeStandard4x3,
  'wide16x10' => l.sizeWide16x10,
  'square' => l.sizeSquare,
  'portrait9x16' => l.sizePortrait9x16,
  'a4' => l.sizeA4,
  'letter' => l.sizeLetter,
  _ => name,
};

/// Presentation languages (spelling, hyphenation; 03 §14) by BCP 47 code.
/// Names are endonyms, so they are not translated.
const slidesLanguages = <(String, String)>[
  ('en', 'English'),
  ('en-GB', 'English (UK)'),
  ('de', 'Deutsch'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('it', 'Italiano'),
  ('nl', 'Nederlands'),
  ('pt', 'Português'),
  ('sv', 'Svenska'),
  ('da', 'Dansk'),
  ('nb', 'Norsk bokmål'),
  ('fi', 'Suomi'),
  ('pl', 'Polski'),
];

/// Code languages offered as the default (07; names are product names).
const slidesCodeLanguages = <(String, String)>[
  ('dart', 'Dart'),
  ('javascript', 'JavaScript'),
  ('typescript', 'TypeScript'),
  ('python', 'Python'),
  ('kotlin', 'Kotlin'),
  ('swift', 'Swift'),
  ('java', 'Java'),
  ('go', 'Go'),
  ('rust', 'Rust'),
  ('csharp', 'C#'),
  ('cpp', 'C++'),
  ('sql', 'SQL'),
  ('shell', 'Shell'),
  ('yaml', 'YAML'),
  ('json', 'JSON'),
  ('plaintext', 'Plain text'), // Shown as `codePlainText`.
];
