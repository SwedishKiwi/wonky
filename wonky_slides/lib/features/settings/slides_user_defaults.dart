import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides_core/motion.dart'
    show
        DeckMotionDefaults,
        EffectCatalog,
        EffectTarget,
        TransitionInfo,
        TransitionSpec;
import 'package:wonky_slides_core/themes.dart'
    show BuiltInThemes, SlideSizeKind;

/// A value check of one setting (`slides.prefs.set`, `slides.presenter.set`).
typedef SettingCheck = bool Function(Object? value);

bool _bool(Object? v) => v is bool;
SettingCheck _oneOf(Set<String> values) =>
    (v) => v is String && values.contains(v);
SettingCheck _intIn(int min, int max) =>
    (v) => v is num && v == v.roundToDouble() && v >= min && v <= max;

/// The Slides settings of the signed-in user (Slides 04 §13.16, §17
/// A-04-2): `UserPreferences.slidesDefaults` (new presentations, editing,
/// animations, code, charts, spelling) and `UserPreferences.slidesPresenter`
/// (presenting, 10 A-10-4). Synced per user through the shell's
/// `PreferencesController`; unknown or invalid stored values read as the
/// defaults. Every change goes through `slides.prefs.set` /
/// `slides.presenter.set` (MCP-operable, not undoable).
class SlidesUserDefaults {
  SlidesUserDefaults(this.services);

  /// The settings of [services]' user.
  static SlidesUserDefaults of(ShellServices services) =>
      SlidesUserDefaults(services);

  final ShellServices services;

  PreferencesController get _prefs => services.prefs;

  // ---- slidesDefaults keys (04 §17 A-04-2)
  static const keyDefaultThemeKey = 'defaultThemeKey';
  static const keyDefaultAppearance = 'defaultAppearance';
  static const keyDefaultSize = 'defaultSize';
  static const keyDefaultLanguage = 'defaultLanguage';
  static const keyUnits = 'units';
  static const keySmartGuides = 'smartGuides';
  static const keySnapObjects = 'snapObjects';
  static const keySnapGuides = 'snapGuides';
  static const keyScrollChangesSlides = 'scrollChangesSlides';
  static const keySmartQuotes = 'smartQuotes';
  static const keyAutoformatLists = 'autoformatLists';
  static const keyShowRemoteCursors = 'showRemoteCursors';
  static const keyDefaultTransition = 'defaultTransition';
  static const keyDefaultTransitionMs = 'defaultTransitionMs';
  static const keyDefaultBuild = 'defaultBuild';
  static const keyPreviewOnHover = 'previewOnHover';
  static const keyReduceEditorMotion = 'reduceEditorMotion';
  static const keyCodeFontSize = 'codeFontSize';
  static const keyCodeLanguage = 'codeLanguage';
  static const keyTypeInSound = 'typeInSound';
  static const keyTypingSpeed = 'typingSpeed';
  static const keyChartsAutoUpdate = 'chartsAutoUpdate';
  static const keyUnderlineSpelling = 'underlineSpelling';

  // ---- slidesPresenter keys (10 §3, A-10-4)
  static const keyPresenterLayout = 'layout';
  static const keyNotesSize = 'notesSize';
  static const keyTimerMode = 'timerMode';
  static const keyTimerTargetMinutes = 'timerTargetMinutes';
  static const keyLaserColor = 'laserColor';
  static const keyStartFullscreen = 'startFullscreen';
  static const keyStartWithPresenterView = 'startWithPresenterView';
  static const keyShowSkippedInPresenter = 'showSkippedInPresenter';

  /// Slide size presets (05 §7) offered for new presentations (custom
  /// sizes are set per deck in Page setup).
  static final List<String> sizes = [
    for (final k in SlideSizeKind.values)
      if (k != SlideSizeKind.custom) k.name,
  ];

  /// *Default transition* choices (06 §7.2; Magic Move only makes sense
  /// between prepared slides).
  static final List<String> transitions = [
    for (final t in TransitionInfo.all)
      if (t.id != 'magicMove') t.id,
  ];

  /// *Default build* choices: the build-in effects for every kind of
  /// object (06 §3.1).
  static final List<String> builds = [
    for (final e in EffectCatalog.buildIn)
      if (e.available && e.target == EffectTarget.visual) e.id,
  ];
  static const typingSpeeds = ['slow', 'normal', 'fast'];
  static const presenterLayouts = ['standard', 'notesFocus', 'nextLarge'];
  static const laserColors = ['red', 'green', 'blue', 'amber'];

  /// The accepted `slidesDefaults` keys and their value checks.
  static final Map<String, SettingCheck> defaultsKeys = {
    keyDefaultThemeKey: (v) => v is String && BuiltInThemes.byKey(v) != null,
    keyDefaultAppearance: _oneOf(const {'light', 'dark'}),
    keyDefaultSize: _oneOf(sizes.toSet()),
    keyDefaultLanguage: (v) => v is String && v.isNotEmpty,
    keyUnits: _oneOf(const {'su', 'px', 'in', 'cm'}),
    keySmartGuides: _bool,
    keySnapObjects: _bool,
    keySnapGuides: _bool,
    keyScrollChangesSlides: _bool,
    keySmartQuotes: _bool,
    keyAutoformatLists: _bool,
    keyShowRemoteCursors: _bool,
    keyDefaultTransition: _oneOf(transitions.toSet()),
    keyDefaultTransitionMs: _intIn(100, 5000),
    keyDefaultBuild: _oneOf(builds.toSet()),
    keyPreviewOnHover: _bool,
    keyReduceEditorMotion: _bool,
    keyCodeFontSize: _intIn(8, 72),
    keyCodeLanguage: (v) => v is String && v.isNotEmpty,
    keyTypeInSound: _bool,
    keyTypingSpeed: _oneOf(typingSpeeds.toSet()),
    keyChartsAutoUpdate: _bool,
    keyUnderlineSpelling: _bool,
  };

  /// The accepted `slidesPresenter` keys and their value checks.
  static final Map<String, SettingCheck> presenterKeys = {
    keyPresenterLayout: _oneOf(presenterLayouts.toSet()),
    keyNotesSize: _intIn(10, 48),
    keyTimerMode: _oneOf(const {'elapsed', 'countdown'}),
    keyTimerTargetMinutes: _intIn(1, 600),
    keyLaserColor: _oneOf(laserColors.toSet()),
    keyStartFullscreen: _bool,
    keyStartWithPresenterView: _bool,
    keyShowSkippedInPresenter: _bool,
  };

  /// Defaults of every key (what an unset or invalid value reads as).
  static const Map<String, Object> defaults = {
    keyDefaultThemeKey: BuiltInThemes.defaultKey,
    keyDefaultAppearance: 'light',
    keyDefaultSize: 'widescreen16x9',
    keyDefaultLanguage: 'en',
    keyUnits: 'su',
    keySmartGuides: true,
    keySnapObjects: true,
    keySnapGuides: true,
    keyScrollChangesSlides: false,
    keySmartQuotes: true,
    keyAutoformatLists: true,
    keyShowRemoteCursors: true,
    keyDefaultTransition: 'none',
    keyDefaultTransitionMs: 500,
    keyDefaultBuild: 'appear',
    keyPreviewOnHover: true,
    keyReduceEditorMotion: false,
    keyCodeFontSize: 24,
    keyCodeLanguage: 'dart',
    keyTypeInSound: false,
    keyTypingSpeed: 'normal',
    keyChartsAutoUpdate: false,
    keyUnderlineSpelling: true,
    keyPresenterLayout: 'standard',
    keyNotesSize: 18,
    keyTimerMode: 'elapsed',
    keyTimerTargetMinutes: 20,
    keyLaserColor: 'red',
    keyStartFullscreen: true,
    keyStartWithPresenterView: false,
    keyShowSkippedInPresenter: false,
  };

  /// The effective value of a `slidesDefaults` [key].
  Object value(String key) => _read(_prefs.slidesDefaults, defaultsKeys, key);

  /// The effective value of a `slidesPresenter` [key].
  Object presenterValue(String key) =>
      _read(_prefs.slidesPresenter, presenterKeys, key);

  static Object _read(
    Map<String, Object?> stored,
    Map<String, SettingCheck> checks,
    String key,
  ) {
    final v = stored[key];
    final check = checks[key];
    if (v != null && check != null && check(v)) {
      // JSON numbers may decode as doubles.
      return v is double && v == v.roundToDouble() ? v.toInt() : v;
    }
    return defaults[key]!;
  }

  /// The `Deck.defaultsJson` of a blank presentation (06 A-06-7): the
  /// *Default transition* with its duration, or null for none.
  static String? deckDefaultsJson(SlidesUserDefaults d) {
    final type = d.string(keyDefaultTransition);
    if (type == 'none' || TransitionInfo.of(type) == null) return null;
    final base = TransitionSpec.of(type);
    final spec = TransitionSpec(
      type: type,
      durationMs: d.integer(keyDefaultTransitionMs),
      easing: base.easing,
      params: base.params,
      magicMove: base.magicMove,
    );
    return DeckMotionDefaults.withTransition(null, spec);
  }

  bool flag(String key) => value(key) == true;
  String string(String key) => '${value(key)}';
  int integer(String key) => (value(key) as num).toInt();

  bool presenterFlag(String key) => presenterValue(key) == true;
  String presenterString(String key) => '${presenterValue(key)}';
  int presenterInt(String key) => (presenterValue(key) as num).toInt();

  /// Validates and stores a `slidesDefaults` value; returns an error text
  /// (for agents) or null.
  Future<String?> set(String key, Object? value) async {
    final check = defaultsKeys[key];
    if (check == null) return 'Unknown setting "$key"';
    if (value != null && !check(value)) return 'Invalid value for "$key"';
    await _prefs.setSlidesDefault(key, value);
    return null;
  }

  /// Validates and stores a `slidesPresenter` value.
  Future<String?> setPresenter(String key, Object? value) async {
    final check = presenterKeys[key];
    if (check == null) return 'Unknown setting "$key"';
    if (value != null && !check(value)) return 'Invalid value for "$key"';
    await _prefs.setSlidesPresenter(key, value);
    return null;
  }
}
