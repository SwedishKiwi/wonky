import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'slides_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of SlidesLocalizations
/// returned by `SlidesLocalizations.of(context)`.
///
/// Applications need to include `SlidesLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/slides_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: SlidesLocalizations.localizationsDelegates,
///   supportedLocales: SlidesLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the SlidesLocalizations.supportedLocales
/// property.
abstract class SlidesLocalizations {
  SlidesLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static SlidesLocalizations of(BuildContext context) {
    return Localizations.of<SlidesLocalizations>(context, SlidesLocalizations)!;
  }

  static const LocalizationsDelegate<SlidesLocalizations> delegate =
      _SlidesLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'XA'),
  ];

  /// Default name of a new presentation.
  ///
  /// In en, this message translates to:
  /// **'Untitled presentation'**
  String get untitledPresentation;

  /// Title of the placeholder deck editor while Wonky Slides is being built (Slides 12 SL-1).
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get editorComingSoonTitle;

  /// Description of the placeholder deck editor.
  ///
  /// In en, this message translates to:
  /// **'Wonky Slides is being built. The presentation editor is on its way — your presentations stay safe in Wonky Drive meanwhile.'**
  String get editorComingSoonBody;

  /// Button on placeholder pages that returns to the Slides home.
  ///
  /// In en, this message translates to:
  /// **'Back to Slides'**
  String get backToSlides;

  /// Load state while a presentation downloads to this device (with a percentage).
  ///
  /// In en, this message translates to:
  /// **'Downloading presentation…'**
  String get deckDownloading;

  /// Load state while a presentation is read from the device.
  ///
  /// In en, this message translates to:
  /// **'Opening presentation… ({rows} rows)'**
  String deckOpening(int rows);

  /// Shown when a presentation that isn't on this device is opened offline.
  ///
  /// In en, this message translates to:
  /// **'This presentation isn’t available offline.'**
  String get deckNotAvailableOffline;

  /// Shown when the server refuses to open a presentation.
  ///
  /// In en, this message translates to:
  /// **'You don’t have access to this presentation.'**
  String get deckNoAccess;

  /// Shown when a presentation didn't arrive on this device.
  ///
  /// In en, this message translates to:
  /// **'This presentation could not be downloaded.'**
  String get deckDownloadFailed;

  /// Shown when opening a presentation failed.
  ///
  /// In en, this message translates to:
  /// **'This presentation could not be opened.'**
  String get deckOpenFailed;

  /// Shown when the presentation's data is missing on this device.
  ///
  /// In en, this message translates to:
  /// **'This presentation isn’t on this device.'**
  String get deckNotOnDevice;

  /// Shown in an open presentation after it was unshared or trashed.
  ///
  /// In en, this message translates to:
  /// **'You no longer have access to this presentation.'**
  String get deckAccessRemoved;

  /// Refusal of an edit made before the presentation finished opening.
  ///
  /// In en, this message translates to:
  /// **'The presentation is still opening.'**
  String get deckStillOpening;

  /// Shown when the local presentation database could not be started.
  ///
  /// In en, this message translates to:
  /// **'The presentation storage on this device didn\'t start. Try again, or reload the page.'**
  String get screenStorageUnavailable;

  /// Toast when a presentation is created offline before this device prepared space for offline creation.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to create a presentation'**
  String get createNeedsConnectionTitle;

  /// Toast description when a presentation can't be created offline yet.
  ///
  /// In en, this message translates to:
  /// **'This device can create presentations offline once it has been online for a moment.'**
  String get createNeedsConnectionBody;

  /// Title of the warning that offline storage is limited (no OPFS).
  ///
  /// In en, this message translates to:
  /// **'Offline storage is limited in this browser'**
  String get storageLimitedTitle;

  /// Description of the limited offline storage warning.
  ///
  /// In en, this message translates to:
  /// **'This browser keeps offline presentations in memory. Only about {elements} objects stay available offline; the presentations you opened least recently are removed from this device first.'**
  String storageLimitedDescription(String elements);

  /// Toast when the local presentation database couldn't be opened.
  ///
  /// In en, this message translates to:
  /// **'Your offline presentation data couldn\'t be opened'**
  String get recoveryTitle;

  /// Toast description with the number of presentations with unsynced changes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 presentation had changes that weren\'t synced yet. Download them before they\'re lost.} other{{count} presentations had changes that weren\'t synced yet. Download them before they\'re lost.}}'**
  String recoveryDescription(int count);

  /// Toast action that downloads the unsynced presentations.
  ///
  /// In en, this message translates to:
  /// **'Download unsynced changes'**
  String get recoveryDownload;

  /// Error toast when the recovery download failed.
  ///
  /// In en, this message translates to:
  /// **'The unsynced changes could not be exported'**
  String get recoveryFailed;

  /// Title of the command `slides.file.importSlides` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Import slides…'**
  String get cmdFileImportSlides;

  /// Title of the command `slides.file.download` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get cmdFileDownload;

  /// Title of the command `slides.history.nameCurrentVersion` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Name current version'**
  String get cmdHistoryNameCurrentVersion;

  /// Title of the command `slides.history.open` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'See version history'**
  String get cmdHistoryOpen;

  /// Title of the command `slides.file.setLanguage` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get cmdFileSetLanguage;

  /// Title of the command `slides.file.pageSetup` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Page setup…'**
  String get cmdFilePageSetup;

  /// Title of the command `slides.print.open` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get cmdPrintOpen;

  /// Title of the command `slides.edit.pasteSpecial` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Paste special'**
  String get cmdEditPasteSpecial;

  /// Title of the command `slides.edit.duplicate` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get cmdEditDuplicate;

  /// Title of the command `slides.edit.delete` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get cmdEditDelete;

  /// Title of the command `slides.select.escape` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get cmdSelectEscape;

  /// Title of the command `slides.select.enterGroup` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Enter group'**
  String get cmdSelectEnterGroup;

  /// Title of the command `slides.element.activate` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Edit text'**
  String get cmdElementActivate;

  /// Title of the command `slides.find.open` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get cmdFindOpen;

  /// Title of the command `slides.find.openReplace` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Find and replace'**
  String get cmdFindOpenReplace;

  /// Title of the command `slides.format.copyStyle` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Copy style'**
  String get cmdFormatCopyStyle;

  /// Title of the command `slides.format.pasteStyle` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Paste style'**
  String get cmdFormatPasteStyle;

  /// Title of the command `slides.present.fromCurrent` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Present from current slide'**
  String get cmdPresentFromCurrent;

  /// Title of the command `slides.present.fromStart` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Present from beginning'**
  String get cmdPresentFromStart;

  /// Title of the command `slides.present.presenterView` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Presenter view'**
  String get cmdPresentPresenterView;

  /// Title of the command `slides.present.rehearse` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Rehearse'**
  String get cmdPresentRehearse;

  /// Title of the command `slides.present.openOnAnotherDevice` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Open on another device…'**
  String get cmdPresentOpenOnAnotherDevice;

  /// Title of the command `slides.present.remote` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Use phone as remote'**
  String get cmdPresentRemote;

  /// Title of the command `slides.present.fromSlide` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Present from this slide'**
  String get cmdPresentFromSlide;

  /// Title of the command `slides.view.setMode` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'View mode'**
  String get cmdViewSetMode;

  /// Title of the command `slides.view.toggleNavigator` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Navigator'**
  String get cmdViewToggleNavigator;

  /// Title of the command `slides.view.toggleInspector` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get cmdViewToggleInspector;

  /// Title of the command `slides.view.toggleNotes` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Speaker notes'**
  String get cmdViewToggleNotes;

  /// Title of the command `slides.view.toggleRulers` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Rulers'**
  String get cmdViewToggleRulers;

  /// Title of the command `slides.view.toggleGuides` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get cmdViewToggleGuides;

  /// Title of the command `slides.view.toggleCommentPins` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Comments on canvas'**
  String get cmdViewToggleCommentPins;

  /// Title of the command `slides.view.toggleRemoteCursors` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Collaborator cursors'**
  String get cmdViewToggleRemoteCursors;

  /// Title of the command `slides.presence.jumpTo` (avatar click: their slide, their selection flashes).
  ///
  /// In en, this message translates to:
  /// **'Jump to collaborator'**
  String get cmdPresenceJumpTo;

  /// Title of the command `slides.presence.follow` (follow a collaborator's slide and view).
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get cmdPresenceFollow;

  /// Title of the command `slides.presence.unfollow`.
  ///
  /// In en, this message translates to:
  /// **'Stop following'**
  String get cmdPresenceUnfollow;

  /// Title of the command `slides.presence.followPresenter`.
  ///
  /// In en, this message translates to:
  /// **'Follow presenter'**
  String get cmdPresenceFollowPresenter;

  /// Title of the command `slides.text.editAnyway` (edit a text someone else is editing).
  ///
  /// In en, this message translates to:
  /// **'Edit anyway'**
  String get cmdTextEditAnyway;

  /// An agent participant writing through MCP for a user.
  ///
  /// In en, this message translates to:
  /// **'Claude via MCP ({name})'**
  String actorViaMcp(String name);

  /// The AI assistant participant working for a user.
  ///
  /// In en, this message translates to:
  /// **'Assistant ({name})'**
  String actorViaAi(String name);

  /// Avatar tooltip: what a collaborator is doing.
  ///
  /// In en, this message translates to:
  /// **'Editing slide {number} · {title}'**
  String presenceEditingSlide(int number, String title);

  /// Avatar tooltip of a collaborator in Viewing mode.
  ///
  /// In en, this message translates to:
  /// **'Viewing slide {number} · {title}'**
  String presenceViewingSlide(int number, String title);

  /// Avatar tooltip of a collaborator who presents.
  ///
  /// In en, this message translates to:
  /// **'Presenting'**
  String get presencePresenting;

  /// Avatar tooltip of a collaborator in the masters view.
  ///
  /// In en, this message translates to:
  /// **'Editing layouts'**
  String get presenceEditingLayouts;

  /// Avatar tooltip suffix: this collaborator follows you.
  ///
  /// In en, this message translates to:
  /// **'Following you'**
  String get presenceFollowingYou;

  /// Screen reader label of the presence dots of a navigator row.
  ///
  /// In en, this message translates to:
  /// **'On this slide: {names}'**
  String presenceOnSlide(String names);

  /// Screen reader label of the presence dots of a collapsed group header.
  ///
  /// In en, this message translates to:
  /// **'In this group: {names}'**
  String presenceInGroup(String names);

  /// Flag above a text box a collaborator edits (soft lock).
  ///
  /// In en, this message translates to:
  /// **'✎ {name} is editing'**
  String presenceEditingFlag(String name);

  /// Flag above a text box several collaborators edit.
  ///
  /// In en, this message translates to:
  /// **'✎ {names} editing'**
  String presenceEditingFlagMany(String names);

  /// Flag text while hovering a text box a collaborator edits.
  ///
  /// In en, this message translates to:
  /// **'{name} is editing this text — double-click to edit anyway'**
  String presenceEditingHover(String name);

  /// Soft-lock popover (04 §13.11) when entering a text someone edits.
  ///
  /// In en, this message translates to:
  /// **'{name} is editing this text.'**
  String softLockMessage(String name);

  /// Soft-lock question when entering speaker notes someone edits.
  ///
  /// In en, this message translates to:
  /// **'{name} is editing these notes.'**
  String softLockNotesMessage(String name);

  /// Popover after two people started editing one text at once and the other was first.
  ///
  /// In en, this message translates to:
  /// **'{name} started editing this text first.'**
  String softLockRaceMessage(String name);

  /// Soft-lock popover: do not edit.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get softLockCancel;

  /// Soft-lock popover: edit although someone else edits.
  ///
  /// In en, this message translates to:
  /// **'Edit anyway'**
  String get softLockEditAnyway;

  /// Lost claim race: stop editing the text.
  ///
  /// In en, this message translates to:
  /// **'Stop editing'**
  String get softLockStop;

  /// Lost claim race: keep editing (both edit, the later write wins).
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get softLockKeep;

  /// Banner in the speaker notes while a collaborator edits them.
  ///
  /// In en, this message translates to:
  /// **'✎ {name} is editing the notes'**
  String notesEditingBanner(String name);

  /// Canvas banner while following a collaborator.
  ///
  /// In en, this message translates to:
  /// **'Following {name}'**
  String followBanner(String name);

  /// Stops following (canvas banner).
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get followStop;

  /// Status bar pill while a collaborator presents.
  ///
  /// In en, this message translates to:
  /// **'{name} is presenting'**
  String presenterPill(String name);

  /// Follows the presenter (status bar pill).
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get presenterFollow;

  /// Toast when following a presenter who stopped presenting.
  ///
  /// In en, this message translates to:
  /// **'That presentation has ended.'**
  String get toastPresenterNotFound;

  /// Title of the command `slides.view.toggleSmartGuides` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Smart guides'**
  String get cmdViewToggleSmartGuides;

  /// Title of the command `slides.view.toggleSnapObjects` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Snap to objects'**
  String get cmdViewToggleSnapObjects;

  /// Title of the command `slides.view.toggleSnapGuides` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Snap to guides'**
  String get cmdViewToggleSnapGuides;

  /// Title of the command `slides.view.toggleSnapGrid` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Snap to grid'**
  String get cmdViewToggleSnapGrid;

  /// Title of the command `slides.animate.toggleOrderOverlay` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Build order'**
  String get cmdAnimateToggleOrderOverlay;

  /// Title of the command `slides.magicMove.toggleMatches` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Magic Move matches'**
  String get cmdMagicMoveToggleMatches;

  /// Title of the command `slides.guides.add` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Add guide'**
  String get cmdGuidesAdd;

  /// Title of the command `slides.guides.clear` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Clear guides'**
  String get cmdGuidesClear;

  /// Title of the command `slides.view.zoomFit` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get cmdViewZoomFit;

  /// Title of the command `slides.view.zoom` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get cmdViewZoom;

  /// Title of the command `slides.view.zoomIn` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get cmdViewZoomIn;

  /// Title of the command `slides.view.zoomOut` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get cmdViewZoomOut;

  /// Title of the command `slides.view.zoomToSelection` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Zoom to selection'**
  String get cmdViewZoomToSelection;

  /// Title of the command `slides.panel.animate` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Animate'**
  String get cmdPanelAnimate;

  /// Title of the command `slides.panel.themes` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get cmdPanelThemes;

  /// Title of the command `slides.panel.layers` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get cmdPanelLayers;

  /// Title of the command `slides.panel.accessibility` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get cmdPanelAccessibility;

  /// Title of the command `slides.panel.linkedObjects` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Linked charts'**
  String get cmdPanelLinkedObjects;

  /// Title of the command `slides.mode.editing` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get cmdModeEditing;

  /// Title of the command `slides.mode.viewing` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Viewing'**
  String get cmdModeViewing;

  /// Title of the command `slides.inspector.open` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Format options…'**
  String get cmdInspectorOpen;

  /// Title of the command `slides.slide.new` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'New slide'**
  String get cmdSlideNew;

  /// Title of the command `slides.slide.duplicateForMagicMove` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Magic Move slide'**
  String get cmdSlideDuplicateForMagicMove;

  /// Title of the command `slides.insert.textBox` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Text box'**
  String get cmdInsertTextBox;

  /// Title of the command `slides.insert.image` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get cmdInsertImage;

  /// Title of the command `slides.insert.shape` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get cmdInsertShape;

  /// Title of the command `slides.insert.line` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get cmdInsertLine;

  /// Title of the command `slides.insert.table` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get cmdInsertTable;

  /// Title of the command `slides.insert.code` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get cmdInsertCode;

  /// Title of the command `slides.insert.chartFromSheets` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Chart from Wonky Sheets…'**
  String get cmdInsertChartFromSheets;

  /// Title of the command `slides.insert.chart` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get cmdInsertChart;

  /// Title of the command `slides.insert.icon` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Icon…'**
  String get cmdInsertIcon;

  /// Title of the command `slides.insert.emoji` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Emoji…'**
  String get cmdInsertEmoji;

  /// Title of the command `slides.insert.specialCharacter` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Special characters…'**
  String get cmdInsertSpecialCharacter;

  /// Title of the command `slides.insert.link` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get cmdInsertLink;

  /// Title of the command `slides.deck.openNumbering` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Slide numbers…'**
  String get cmdDeckOpenNumbering;

  /// Title of the command `slides.layout.insertPlaceholder` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Placeholder'**
  String get cmdLayoutInsertPlaceholder;

  /// Title of the command `slides.format.bold` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get cmdFormatBold;

  /// Title of the command `slides.format.italic` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get cmdFormatItalic;

  /// Title of the command `slides.format.underline` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get cmdFormatUnderline;

  /// Title of the command `slides.format.strikethrough` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get cmdFormatStrikethrough;

  /// Title of the command `slides.format.script` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Superscript / subscript'**
  String get cmdFormatScript;

  /// Title of the command `slides.format.increaseFontSize` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Increase font size'**
  String get cmdFormatIncreaseFontSize;

  /// Title of the command `slides.format.decreaseFontSize` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Decrease font size'**
  String get cmdFormatDecreaseFontSize;

  /// Title of the command `slides.format.caps` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Capitalization'**
  String get cmdFormatCaps;

  /// Title of the command `slides.format.textStyle` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Text style'**
  String get cmdFormatTextStyle;

  /// Title of the command `slides.format.font` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get cmdFormatFont;

  /// Title of the command `slides.format.fontSize` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get cmdFormatFontSize;

  /// Title of the command `slides.format.textColor` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get cmdFormatTextColor;

  /// Title of the command `slides.format.highlight` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Highlight color'**
  String get cmdFormatHighlight;

  /// Title of the command `slides.format.align` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Text alignment'**
  String get cmdFormatAlign;

  /// Title of the command `slides.format.anchor` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Vertical alignment'**
  String get cmdFormatAnchor;

  /// Title of the command `slides.format.indent` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Increase indent'**
  String get cmdFormatIndent;

  /// Title of the command `slides.format.outdent` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Decrease indent'**
  String get cmdFormatOutdent;

  /// Title of the command `slides.format.lineHeight` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get cmdFormatLineHeight;

  /// Title of the command `slides.format.paragraphSpacing` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Paragraph spacing…'**
  String get cmdFormatParagraphSpacing;

  /// Title of the command `slides.format.list` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get cmdFormatList;

  /// Title of the command `slides.format.listStyle` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'List style'**
  String get cmdFormatListStyle;

  /// Title of the command `slides.format.listStart` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Restart numbering'**
  String get cmdFormatListStart;

  /// Title of the command `slides.format.autofit` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Text fitting'**
  String get cmdFormatAutofit;

  /// Title of the command `slides.format.fill` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get cmdFormatFill;

  /// Title of the command `slides.format.stroke` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get cmdFormatStroke;

  /// Title of the command `slides.format.effects` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get cmdFormatEffects;

  /// Title of the command `slides.format.opacity` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Opacity…'**
  String get cmdFormatOpacity;

  /// Title of the command `slides.image.crop` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get cmdImageCrop;

  /// Title of the command `slides.image.mask` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Mask with shape'**
  String get cmdImageMask;

  /// Title of the command `slides.image.replace` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get cmdImageReplace;

  /// Title of the command `slides.image.adjust` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Adjustments…'**
  String get cmdImageAdjust;

  /// Title of the command `slides.image.reset` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Reset image'**
  String get cmdImageReset;

  /// Title of the command `slides.image.downloadOriginal` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Download original'**
  String get cmdImageDownloadOriginal;

  /// Title of the command `slides.table.insertRow` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Insert row'**
  String get cmdTableInsertRow;

  /// Title of the command `slides.table.insertColumn` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Insert column'**
  String get cmdTableInsertColumn;

  /// Title of the command `slides.table.deleteRows` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get cmdTableDeleteRows;

  /// Title of the command `slides.table.deleteColumns` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Delete column'**
  String get cmdTableDeleteColumns;

  /// Title of the command `slides.table.delete` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Delete table'**
  String get cmdTableDelete;

  /// Title of the command `slides.table.mergeCells` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Merge cells'**
  String get cmdTableMergeCells;

  /// Title of the command `slides.table.unmergeCells` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Unmerge cells'**
  String get cmdTableUnmergeCells;

  /// Title of the command `slides.table.distributeRows` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Distribute rows'**
  String get cmdTableDistributeRows;

  /// Title of the command `slides.table.distributeColumns` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Distribute columns'**
  String get cmdTableDistributeColumns;

  /// Title of the command `slides.table.setOptions` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Table options…'**
  String get cmdTableSetOptions;

  /// Title of the command `slides.table.setCellFill` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Cell fill'**
  String get cmdTableSetCellFill;

  /// Title of the command `slides.table.setBorders` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Borders'**
  String get cmdTableSetBorders;

  /// Title of the command `slides.table.setCellAlign` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Vertical align'**
  String get cmdTableSetCellAlign;

  /// Title of the command `slides.shape.change` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Change shape'**
  String get cmdShapeChange;

  /// Title of the command `slides.shape.applyQuickStyle` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Quick styles'**
  String get cmdShapeApplyQuickStyle;

  /// Title of the command `slides.line.setArrow` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Arrows'**
  String get cmdLineSetArrow;

  /// Title of the command `slides.line.setRouting` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get cmdLineSetRouting;

  /// Title of the command `slides.code.edit` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Edit code'**
  String get cmdCodeEdit;

  /// Title of the command `slides.code.setLanguage` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Code language'**
  String get cmdCodeSetLanguage;

  /// Title of the command `slides.code.updateOptions` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Line numbers'**
  String get cmdCodeUpdateOptions;

  /// Title of the command `slides.code.setHighlightSteps` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Highlight steps…'**
  String get cmdCodeSetHighlightSteps;

  /// Title of the command `slides.code.addState` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Add state'**
  String get cmdCodeAddState;

  /// Title of the command `slides.chart.update` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Update chart'**
  String get cmdChartUpdate;

  /// Title of the command `slides.chart.setAutoUpdate` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Update automatically'**
  String get cmdChartSetAutoUpdate;

  /// Title of the command `slides.chart.openSource` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Open source spreadsheet'**
  String get cmdChartOpenSource;

  /// Title of the command `slides.chart.unlink` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Unlink chart'**
  String get cmdChartUnlink;

  /// Title of the command `slides.chart.copyAsImage` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Copy chart as image'**
  String get cmdChartCopyAsImage;

  /// Title of the command `slides.element.editAltText` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Alt text…'**
  String get cmdElementEditAltText;

  /// Title of the command `slides.format.paintFormat` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Paint format'**
  String get cmdFormatPaintFormat;

  /// Title of the command `slides.format.clear` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Clear formatting'**
  String get cmdFormatClear;

  /// Title of the command `slides.slide.duplicate` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Duplicate slide'**
  String get cmdSlideDuplicate;

  /// Title of the command `slides.slide.delete` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Delete slide'**
  String get cmdSlideDelete;

  /// Title of the command `slides.slide.toggleSkip` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Skip slide'**
  String get cmdSlideToggleSkip;

  /// Title of the command `slides.slide.move` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Move slide'**
  String get cmdSlideMove;

  /// Title of the command `slides.slide.applyLayout` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Apply layout'**
  String get cmdSlideApplyLayout;

  /// Title of the command `slides.slide.resetToLayout` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Reset slide to layout'**
  String get cmdSlideResetToLayout;

  /// Title of the command `slides.slide.setBackground` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Change background…'**
  String get cmdSlideSetBackground;

  /// Title of the command `slides.slide.applyBackgroundToAll` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Apply background to all slides'**
  String get cmdSlideApplyBackgroundToAll;

  /// Title of the command `slides.slide.setHideMasterElements` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Hide master objects'**
  String get cmdSlideSetHideMasterElements;

  /// Title of the command `slides.deck.setAppearance` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Presentation appearance'**
  String get cmdDeckSetAppearance;

  /// Title of the command `slides.group.create` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Group slides'**
  String get cmdGroupCreate;

  /// Title of the command `slides.group.ungroup` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Ungroup slides'**
  String get cmdGroupUngroup;

  /// Title of the command `slides.group.addSlides` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Add to group'**
  String get cmdGroupAddSlides;

  /// Title of the command `slides.group.removeSlides` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get cmdGroupRemoveSlides;

  /// Title of the command `slides.group.startRename` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get cmdGroupStartRename;

  /// Title of the command `slides.group.setColor` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Group color'**
  String get cmdGroupSetColor;

  /// Title of the command `slides.group.toggleSkip` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Skip group'**
  String get cmdGroupToggleSkip;

  /// Title of the command `slides.group.collapse` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Collapse group'**
  String get cmdGroupCollapse;

  /// Title of the command `slides.group.expand` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Expand group'**
  String get cmdGroupExpand;

  /// Title of the command `slides.group.collapseAll` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Collapse all groups'**
  String get cmdGroupCollapseAll;

  /// Title of the command `slides.group.expandAll` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Expand all groups'**
  String get cmdGroupExpandAll;

  /// Title of the command `slides.group.duplicate` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Duplicate group'**
  String get cmdGroupDuplicate;

  /// Title of the command `slides.group.delete` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Delete group…'**
  String get cmdGroupDelete;

  /// Title of the command `slides.group.selectSlides` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Select slides in group'**
  String get cmdGroupSelectSlides;

  /// Title of the command `slides.animate.preview` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Preview animations'**
  String get cmdAnimatePreview;

  /// Title of the command `slides.animate.removeAll` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Remove all animations'**
  String get cmdAnimateRemoveAll;

  /// Title of the command `slides.animate.addBuild` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Add animation'**
  String get cmdAnimateAddBuild;

  /// Title of the command `slides.animate.copyBuilds` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Copy animation'**
  String get cmdAnimateCopyBuilds;

  /// Title of the command `slides.animate.pasteBuilds` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Paste animation'**
  String get cmdAnimatePasteBuilds;

  /// Title of the command `slides.animate.deleteBuilds` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Remove animations'**
  String get cmdAnimateDeleteBuilds;

  /// Title of the command `slides.theme.edit` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Edit theme…'**
  String get cmdThemeEdit;

  /// Title of the command `slides.nav.goToSlide` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Go to slide…'**
  String get cmdNavGoToSlide;

  /// Title of the command `slides.nav.goToGroup` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Go to group'**
  String get cmdNavGoToGroup;

  /// Title of the command `slides.nav.previousSlide` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Previous slide'**
  String get cmdNavPreviousSlide;

  /// Title of the command `slides.nav.nextSlide` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Next slide'**
  String get cmdNavNextSlide;

  /// Title of the command `slides.arrange.order` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get cmdArrangeOrder;

  /// Title of the command `slides.arrange.align` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Align objects'**
  String get cmdArrangeAlign;

  /// Title of the command `slides.arrange.distribute` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Distribute objects'**
  String get cmdArrangeDistribute;

  /// Title of the command `slides.arrange.centerOnSlide` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Center on slide'**
  String get cmdArrangeCenterOnSlide;

  /// Title of the command `slides.arrange.matchSize` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Match size'**
  String get cmdArrangeMatchSize;

  /// Title of the command `slides.arrange.rotate` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get cmdArrangeRotate;

  /// Title of the command `slides.arrange.flip` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get cmdArrangeFlip;

  /// Title of the command `slides.arrange.group` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get cmdArrangeGroup;

  /// Title of the command `slides.arrange.ungroup` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Ungroup'**
  String get cmdArrangeUngroup;

  /// Title of the command `slides.element.toggleLock` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get cmdElementToggleLock;

  /// Title of the command `slides.element.unlockAll` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Unlock all on slide'**
  String get cmdElementUnlockAll;

  /// Title of the command `slides.element.hide` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get cmdElementHide;

  /// Title of the command `slides.element.show` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get cmdElementShow;

  /// Title of the command `slides.element.setLink` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Link…'**
  String get cmdElementSetLink;

  /// Title of the command `slides.element.removeLink` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get cmdElementRemoveLink;

  /// Title of the command `slides.element.resetPlaceholder` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Reset to layout'**
  String get cmdElementResetPlaceholder;

  /// Title of the command `slides.spelling.check` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Check spelling'**
  String get cmdSpellingCheck;

  /// Title of the command `slides.spelling.toggleUnderline` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Underline errors'**
  String get cmdSpellingToggleUnderline;

  /// Title of the command `slides.tools.accessibilityCheck` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Accessibility check'**
  String get cmdToolsAccessibilityCheck;

  /// Title of the command `slides.notifications.openSettings` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get cmdNotificationsOpenSettings;

  /// Title of the command `slides.ai.generateDeck` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Generate presentation…'**
  String get cmdAiGenerateDeck;

  /// Title of the command `slides.ai.rewrite` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Rewrite text'**
  String get cmdAiRewrite;

  /// Title of the command `slides.ai.suggestLayouts` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Suggest layouts for this slide'**
  String get cmdAiSuggestLayouts;

  /// Title of the command `slides.ai.speakerNotes` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Write speaker notes'**
  String get cmdAiSpeakerNotes;

  /// Title of the command `slides.ai.altText` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Generate alt text'**
  String get cmdAiAltText;

  /// Title of the command `slides.ai.codeWalkthrough` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Make a code walkthrough…'**
  String get cmdAiCodeWalkthrough;

  /// Title of the command `slides.tool.select` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get cmdToolSelect;

  /// Title of the command `slides.prefs.set` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Change a Slides setting'**
  String get cmdPrefsSet;

  /// Title of the command `slides.presenter.set` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Change a presenting setting'**
  String get cmdPresenterSet;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get categoryFile;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get categoryEdit;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get categoryView;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get categoryInsert;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Canvas & objects'**
  String get categoryFormat;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get categoryText;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get categoryTables;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Slides & groups'**
  String get categorySlides;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Arrange'**
  String get categoryArrange;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Canvas & objects'**
  String get categoryCanvas;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get categoryPresent;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get categoryAnimations;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get categoryTools;

  /// Keyboard-shortcuts help category of Slides commands.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get categoryAi;

  /// Alignment option (Format › Align & indent, Arrange › Align).
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get alignLeft;

  /// Alignment option (Format › Align & indent, Arrange › Align).
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get alignCenter;

  /// Alignment option (Format › Align & indent, Arrange › Align).
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get alignRight;

  /// Alignment option (Format › Align & indent, Arrange › Align).
  ///
  /// In en, this message translates to:
  /// **'Justify'**
  String get alignJustify;

  /// Alignment option (Format › Align & indent, Arrange › Align).
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get anchorTop;

  /// Alignment option (Format › Align & indent, Arrange › Align).
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get anchorMiddle;

  /// Alignment option (Format › Align & indent, Arrange › Align).
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get anchorBottom;

  /// Element context menu › Animate.
  ///
  /// In en, this message translates to:
  /// **'Add build in'**
  String get animateAddBuildIn;

  /// Element context menu › Animate.
  ///
  /// In en, this message translates to:
  /// **'Add action'**
  String get animateAddAction;

  /// Element context menu › Animate.
  ///
  /// In en, this message translates to:
  /// **'Add build out'**
  String get animateAddBuildOut;

  /// Inspector › Animate sub-tab.
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get animateTabTransition;

  /// Inspector › Animate sub-tab.
  ///
  /// In en, this message translates to:
  /// **'Build'**
  String get animateTabBuild;

  /// Inspector › Animate sub-tab.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get animateTabOrder;

  /// Inspector › Animate › Transition placeholder text.
  ///
  /// In en, this message translates to:
  /// **'Slide transitions arrive here soon: effects, duration and how the slide advances.'**
  String get animateTransitionEmpty;

  /// Inspector › Animate › Build placeholder text.
  ///
  /// In en, this message translates to:
  /// **'Builds arrive here soon: select an object to animate it in, out or in place.'**
  String get animateBuildEmpty;

  /// Inspector › Animate › Order placeholder text.
  ///
  /// In en, this message translates to:
  /// **'The build order of this slide will be listed here.'**
  String get animateOrderEmpty;

  /// Deck appearance option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// Deck appearance option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// Format › Text fitting option.
  ///
  /// In en, this message translates to:
  /// **'Do not autofit'**
  String get autofitNone;

  /// Format › Text fitting option.
  ///
  /// In en, this message translates to:
  /// **'Shrink text on overflow'**
  String get autofitShrink;

  /// Format › Text fitting option.
  ///
  /// In en, this message translates to:
  /// **'Resize shape to fit text'**
  String get autofitResize;

  /// Arrange option.
  ///
  /// In en, this message translates to:
  /// **'Horizontally'**
  String get axisHorizontally;

  /// Arrange option.
  ///
  /// In en, this message translates to:
  /// **'Vertically'**
  String get axisVertically;

  /// Arrange option.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get axisBoth;

  /// Button that leaves a view mode.
  ///
  /// In en, this message translates to:
  /// **'Back to Normal view'**
  String get backToNormalView;

  /// Button on placeholder pages under a presentation.
  ///
  /// In en, this message translates to:
  /// **'Back to the presentation'**
  String get backToPresentation;

  /// Toolbar badge for viewers.
  ///
  /// In en, this message translates to:
  /// **'View only'**
  String get badgeViewOnly;

  /// Toolbar badge for commenters.
  ///
  /// In en, this message translates to:
  /// **'Comment only'**
  String get badgeCommentOnly;

  /// Toolbar badge for editors in Viewing mode.
  ///
  /// In en, this message translates to:
  /// **'Viewing'**
  String get badgeViewing;

  /// Build effect.
  ///
  /// In en, this message translates to:
  /// **'Appear'**
  String get buildAppear;

  /// Build effect.
  ///
  /// In en, this message translates to:
  /// **'Fly in'**
  String get buildFlyIn;

  /// Build effect.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get buildZoom;

  /// Empty deck action.
  ///
  /// In en, this message translates to:
  /// **'Choose a layout'**
  String get canvasChooseLayout;

  /// Empty deck title.
  ///
  /// In en, this message translates to:
  /// **'This presentation has no slides'**
  String get canvasEmptyTitle;

  /// Empty deck description.
  ///
  /// In en, this message translates to:
  /// **'Add a slide to start, or choose a layout for it.'**
  String get canvasEmptyBody;

  /// Screen reader label of the slide on the canvas.
  ///
  /// In en, this message translates to:
  /// **'Slide {number}: {title}'**
  String canvasSlideSemantics(int number, String title);

  /// Format › Text › Capitalization option.
  ///
  /// In en, this message translates to:
  /// **'UPPERCASE'**
  String get capsUpper;

  /// Format › Text › Capitalization option.
  ///
  /// In en, this message translates to:
  /// **'Small caps'**
  String get capsSmallCaps;

  /// Format › Text › Capitalization option.
  ///
  /// In en, this message translates to:
  /// **'Title Case'**
  String get capsTitle;

  /// Format › Text › Capitalization option.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get capsNone;

  /// Chart type.
  ///
  /// In en, this message translates to:
  /// **'Column'**
  String get chartColumn;

  /// Chart type.
  ///
  /// In en, this message translates to:
  /// **'Bar'**
  String get chartBar;

  /// Chart type.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get chartLine;

  /// Chart type.
  ///
  /// In en, this message translates to:
  /// **'Pie'**
  String get chartPie;

  /// Chart type.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get chartArea;

  /// Chart type.
  ///
  /// In en, this message translates to:
  /// **'Scatter'**
  String get chartScatter;

  /// Insert › Chart item.
  ///
  /// In en, this message translates to:
  /// **'From Wonky Sheets…'**
  String get chartFromSheets;

  /// Insert › Code block item.
  ///
  /// In en, this message translates to:
  /// **'All languages…'**
  String get codeAllLanguages;

  /// Format › Code item.
  ///
  /// In en, this message translates to:
  /// **'Line numbers'**
  String get codeLineNumbers;

  /// Code language without highlighting.
  ///
  /// In en, this message translates to:
  /// **'Plain text'**
  String get codePlainText;

  /// Format › Code item.
  ///
  /// In en, this message translates to:
  /// **'States…'**
  String get codeStates;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colorGray;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get colorAmber;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get colorTeal;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'Violet'**
  String get colorViolet;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// Color name (group colors, laser pointer).
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get colorNone;

  /// Loading state without progress.
  ///
  /// In en, this message translates to:
  /// **'Opening presentation…'**
  String get deckLoading;

  /// Loading state with a percentage, e.g. "Downloading presentation… 42 %".
  ///
  /// In en, this message translates to:
  /// **'{message} {percent} %'**
  String deckLoadingProgress(String message, int percent);

  /// Title when a presentation can’t be shown.
  ///
  /// In en, this message translates to:
  /// **'This presentation isn’t available'**
  String get deckUnavailable;

  /// Description of the offline unavailable state.
  ///
  /// In en, this message translates to:
  /// **'It opens by itself when you’re back online.'**
  String get deckOfflineHint;

  /// File › Download format.
  ///
  /// In en, this message translates to:
  /// **'PDF document (.pdf)'**
  String get downloadPdf;

  /// File › Download format.
  ///
  /// In en, this message translates to:
  /// **'PNG image (current slide)'**
  String get downloadPng;

  /// File › Download format.
  ///
  /// In en, this message translates to:
  /// **'PNG images (all slides, .zip)'**
  String get downloadPngZip;

  /// File › Download format.
  ///
  /// In en, this message translates to:
  /// **'Outline as Markdown (.md)'**
  String get downloadMarkdown;

  /// A duration in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// A duration in seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String durationSeconds(String seconds);

  /// Arrange › Rotate item.
  ///
  /// In en, this message translates to:
  /// **'Flip horizontally'**
  String get flipHorizontally;

  /// Arrange › Rotate item.
  ///
  /// In en, this message translates to:
  /// **'Flip vertically'**
  String get flipVertically;

  /// Go to slide dialog title.
  ///
  /// In en, this message translates to:
  /// **'Go to slide'**
  String get goToSlideTitle;

  /// Go to slide dialog field.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get goToSlideLabel;

  /// Go to slide dialog button.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get goToSlideButton;

  /// Name of a slide group without a title.
  ///
  /// In en, this message translates to:
  /// **'Untitled group'**
  String get groupUntitled;

  /// View › Guides item.
  ///
  /// In en, this message translates to:
  /// **'Add vertical guide'**
  String get guidesAddVertical;

  /// View › Guides item.
  ///
  /// In en, this message translates to:
  /// **'Add horizontal guide'**
  String get guidesAddHorizontal;

  /// Insert › Image source.
  ///
  /// In en, this message translates to:
  /// **'Upload from computer'**
  String get imageUpload;

  /// Insert › Image source.
  ///
  /// In en, this message translates to:
  /// **'From Wonky Drive'**
  String get imageFromDrive;

  /// Insert › Image source.
  ///
  /// In en, this message translates to:
  /// **'By URL'**
  String get imageByUrl;

  /// Insert › Image source.
  ///
  /// In en, this message translates to:
  /// **'From clipboard'**
  String get imageFromClipboard;

  /// Screen reader label of the inspector.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get inspectorLabel;

  /// Inspector tab.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get inspectorFormat;

  /// Inspector tab.
  ///
  /// In en, this message translates to:
  /// **'Animate'**
  String get inspectorAnimate;

  /// Inspector tab.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get inspectorSlide;

  /// Inspector close button.
  ///
  /// In en, this message translates to:
  /// **'Close inspector'**
  String get inspectorClose;

  /// Inspector › Format with nothing selected.
  ///
  /// In en, this message translates to:
  /// **'Select an object to format it'**
  String get inspectorFormatEmpty;

  /// Body of an inspector section that is not built yet.
  ///
  /// In en, this message translates to:
  /// **'These options are on their way.'**
  String get inspectorSectionSoon;

  /// Inspector › Slide row label.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get inspectorCurrentLayout;

  /// Inspector › Slide row label.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get inspectorAppearance;

  /// Inspector › Slide › Group.
  ///
  /// In en, this message translates to:
  /// **'Not in a group'**
  String get inspectorNotInGroup;

  /// Inspector › Slide row label.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get inspectorGroupName;

  /// Inspector › Slide › Info row label.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get inspectorSlideNumber;

  /// Inspector › Slide › Info row label.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get inspectorSkipped;

  /// Generic yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Line item.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get lineLine;

  /// Line item.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get lineArrow;

  /// Line item.
  ///
  /// In en, this message translates to:
  /// **'Double arrow'**
  String get lineDoubleArrow;

  /// Line item.
  ///
  /// In en, this message translates to:
  /// **'Elbow connector'**
  String get lineElbowConnector;

  /// Line item.
  ///
  /// In en, this message translates to:
  /// **'Curved connector'**
  String get lineCurvedConnector;

  /// Line item.
  ///
  /// In en, this message translates to:
  /// **'Start arrow'**
  String get lineStartArrow;

  /// Line item.
  ///
  /// In en, this message translates to:
  /// **'End arrow'**
  String get lineEndArrow;

  /// Format › Bullets & numbering item.
  ///
  /// In en, this message translates to:
  /// **'Bulleted list'**
  String get listBulleted;

  /// Format › Bullets & numbering item.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get listNumbered;

  /// Format › Bullets & numbering item.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get listChecklist;

  /// Format › Bullets & numbering item.
  ///
  /// In en, this message translates to:
  /// **'List options…'**
  String get listOptions;

  /// Masters mode placeholder title.
  ///
  /// In en, this message translates to:
  /// **'Editing masters and layouts is coming soon'**
  String get mastersSoonTitle;

  /// Masters mode placeholder description.
  ///
  /// In en, this message translates to:
  /// **'You’ll edit the theme’s masters and layouts here. Your slides are unchanged.'**
  String get mastersSoonBody;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Add to group'**
  String get menuAddToGroup;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get menuAi;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Align'**
  String get menuAlign;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Align & indent'**
  String get menuAlignIndent;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Animate'**
  String get menuAnimate;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Animate…'**
  String get menuAnimateEllipsis;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Animation…'**
  String get menuAnimation;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Apply layout'**
  String get menuApplyLayout;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Arrange'**
  String get menuArrange;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Border…'**
  String get menuBorderEllipsis;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Capitalization'**
  String get menuCapitalization;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Center on slide'**
  String get menuCenterOnSlide;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Change background…'**
  String get menuChangeBackground;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Change theme…'**
  String get menuChangeTheme;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get menuChart;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Choose a group…'**
  String get menuChooseGroup;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get menuCode;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get menuCodeBlock;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Comment on slide'**
  String get menuCommentOnSlide;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Distribute'**
  String get menuDistribute;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get menuDownload;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Edit layout'**
  String get menuEditLayout;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Edit masters and layouts'**
  String get menuEditMasters;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Effects…'**
  String get menuEffectsEllipsis;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get menuExtensions;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Fill…'**
  String get menuFillEllipsis;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get menuFormat;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Format options…'**
  String get menuFormatOptions;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get menuGroup;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get menuGroupColor;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Guides'**
  String get menuGuides;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get menuImage;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get menuInsert;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get menuLanguage;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get menuLine;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Bullets & numbering'**
  String get menuLists;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Magic Move ID…'**
  String get menuMagicMoveId;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Match size'**
  String get menuMatchSize;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get menuMcp;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Move slide'**
  String get menuMoveSlide;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get menuNewGroup;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'New slide in group'**
  String get menuNewSlideInGroup;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'New slide with layout'**
  String get menuNewSlideWithLayout;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get menuOrder;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Panels'**
  String get menuPanels;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Paste special'**
  String get menuPasteSpecial;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Personal dictionary'**
  String get menuPersonalDictionary;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Placeholder'**
  String get menuPlaceholder;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get menuPresent;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Present from this group'**
  String get menuPresentFromGroup;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Presenting settings…'**
  String get menuPresentingSettings;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Rehearse presentation'**
  String get menuRehearsePresentation;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Rewrite text'**
  String get menuRewriteText;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get menuRotate;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get menuShape;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'All shapes…'**
  String get menuShapeGallery;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get menuShow;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get menuSize;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Size and position…'**
  String get menuSizePosition;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get menuSlide;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Snap'**
  String get menuSnap;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Line & paragraph spacing'**
  String get menuSpacing;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Spelling'**
  String get menuSpelling;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get menuTable;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get menuText;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Text fitting'**
  String get menuTextFitting;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Text style'**
  String get menuTextStyle;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Transition…'**
  String get menuTransition;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get menuVersionHistory;

  /// Menu or submenu label (Slides 04 §4).
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get menuZoom;

  /// Slide › Move slide item.
  ///
  /// In en, this message translates to:
  /// **'To beginning'**
  String get moveToBeginning;

  /// Slide › Move slide item.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get moveUp;

  /// Slide › Move slide item.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get moveDown;

  /// Slide › Move slide item.
  ///
  /// In en, this message translates to:
  /// **'To end'**
  String get moveToEnd;

  /// Screen reader label of the slide navigator.
  ///
  /// In en, this message translates to:
  /// **'Slides'**
  String get navigatorLabel;

  /// Navigator with no slides.
  ///
  /// In en, this message translates to:
  /// **'No slides'**
  String get navigatorEmpty;

  /// Button that opens the navigator drawer on narrow screens.
  ///
  /// In en, this message translates to:
  /// **'Show slides'**
  String get navigatorOpen;

  /// Screen reader label of a group header.
  ///
  /// In en, this message translates to:
  /// **'Group {title}, {count, plural, =1{1 slide} other{{count} slides}}'**
  String navigatorGroupSemantics(String title, int count);

  /// Screen reader label of a navigator slide row.
  ///
  /// In en, this message translates to:
  /// **'Slide {number} of {total}: {title}'**
  String navigatorSlideSemantics(int number, int total, String title);

  /// Speaker notes pane handle.
  ///
  /// In en, this message translates to:
  /// **'Speaker notes'**
  String get notesLabel;

  /// Empty speaker notes.
  ///
  /// In en, this message translates to:
  /// **'Click to add speaker notes'**
  String get notesPlaceholder;

  /// Arrange › Order item.
  ///
  /// In en, this message translates to:
  /// **'Bring to front'**
  String get orderBringToFront;

  /// Arrange › Order item.
  ///
  /// In en, this message translates to:
  /// **'Bring forward'**
  String get orderBringForward;

  /// Arrange › Order item.
  ///
  /// In en, this message translates to:
  /// **'Send backward'**
  String get orderSendBackward;

  /// Arrange › Order item.
  ///
  /// In en, this message translates to:
  /// **'Send to back'**
  String get orderSendToBack;

  /// Outline view: slide without a title.
  ///
  /// In en, this message translates to:
  /// **'(no title)'**
  String get outlineNoTitle;

  /// Outline view note.
  ///
  /// In en, this message translates to:
  /// **'Outline view shows each slide’s title and main text. Editing here comes soon.'**
  String get outlineReadOnlyNote;

  /// Paste special option.
  ///
  /// In en, this message translates to:
  /// **'Keep source formatting'**
  String get pasteKeepSource;

  /// Paste special option.
  ///
  /// In en, this message translates to:
  /// **'Use destination theme'**
  String get pasteUseDestination;

  /// Paste special option.
  ///
  /// In en, this message translates to:
  /// **'Paste chart unlinked'**
  String get pasteChartUnlinked;

  /// Placeholder type.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get placeholderPicture;

  /// Placeholder type.
  ///
  /// In en, this message translates to:
  /// **'Object'**
  String get placeholderObject;

  /// Placeholder type.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get placeholderFooter;

  /// Placeholder type.
  ///
  /// In en, this message translates to:
  /// **'Slide number'**
  String get placeholderSlideNumber;

  /// Placeholder type.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get placeholderDate;

  /// The Present button in the title row.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get presentButton;

  /// Chevron of the Present split button.
  ///
  /// In en, this message translates to:
  /// **'Presenting options'**
  String get presentOptions;

  /// Presenter view layout preset.
  ///
  /// In en, this message translates to:
  /// **'Current, next and notes'**
  String get presenterLayoutStandard;

  /// Presenter view layout preset.
  ///
  /// In en, this message translates to:
  /// **'Large notes'**
  String get presenterLayoutNotes;

  /// Presenter view layout preset.
  ///
  /// In en, this message translates to:
  /// **'Large next slide'**
  String get presenterLayoutNext;

  /// Reason shown on a disabled command.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get reasonNotAvailableYet;

  /// Reason shown on a disabled command.
  ///
  /// In en, this message translates to:
  /// **'The presentation is still opening'**
  String get reasonDeckLoading;

  /// Reason shown on a disabled command.
  ///
  /// In en, this message translates to:
  /// **'You have view access'**
  String get reasonViewAccess;

  /// Reason shown on a disabled command.
  ///
  /// In en, this message translates to:
  /// **'You’re in Viewing mode'**
  String get reasonViewingMode;

  /// Reason shown on a disabled command.
  ///
  /// In en, this message translates to:
  /// **'This is the first slide'**
  String get reasonFirstSlide;

  /// Reason shown on a disabled command.
  ///
  /// In en, this message translates to:
  /// **'This is the last slide'**
  String get reasonLastSlide;

  /// Reason shown on a disabled command.
  ///
  /// In en, this message translates to:
  /// **'The presentation has no slides'**
  String get reasonNoSlides;

  /// AI › Rewrite text option.
  ///
  /// In en, this message translates to:
  /// **'Shorter'**
  String get rewriteShorter;

  /// AI › Rewrite text option.
  ///
  /// In en, this message translates to:
  /// **'Longer'**
  String get rewriteLonger;

  /// AI › Rewrite text option.
  ///
  /// In en, this message translates to:
  /// **'Clearer'**
  String get rewriteClearer;

  /// AI › Rewrite text option.
  ///
  /// In en, this message translates to:
  /// **'More formal'**
  String get rewriteFormal;

  /// AI › Rewrite text option.
  ///
  /// In en, this message translates to:
  /// **'Fix grammar'**
  String get rewriteGrammar;

  /// AI › Rewrite text option.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get rewriteCustom;

  /// Arrange › Rotate item.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° clockwise'**
  String get rotateClockwise;

  /// Arrange › Rotate item.
  ///
  /// In en, this message translates to:
  /// **'Rotate 90° counter-clockwise'**
  String get rotateCounterClockwise;

  /// Title of the present route placeholder.
  ///
  /// In en, this message translates to:
  /// **'Presenting'**
  String get routePresentTitle;

  /// Title of the print route placeholder.
  ///
  /// In en, this message translates to:
  /// **'Print and PDF'**
  String get routePrintTitle;

  /// Title of the history route placeholder.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get routeHistoryTitle;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get sectionText;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get sectionLine;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get sectionImage;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get sectionTable;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Cell'**
  String get sectionCell;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get sectionIcon;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get sectionCode;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get sectionChart;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get sectionFill;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get sectionBorder;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get sectionEffects;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Arrange'**
  String get sectionArrange;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get sectionLink;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get sectionAccessibility;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get sectionLayout;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get sectionBackground;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get sectionTheme;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get sectionVisibility;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get sectionGroup;

  /// Inspector section title (Slides 04 §7).
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get sectionInfo;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'New presentations'**
  String get settingsSectionPresentations;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get settingsSectionEditing;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Animations & code'**
  String get settingsSectionAnimations;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Presenting'**
  String get settingsSectionPresenting;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'New presentations'**
  String get settingsNewPresentations;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Used when you create a presentation. Existing presentations keep their own settings.'**
  String get settingsNewPresentationsHint;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsDefaultTheme;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsDefaultAppearance;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Slide size'**
  String get settingsDefaultSize;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsDefaultLanguage;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get settingsCharts;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Update linked charts automatically'**
  String get settingsChartsAutoUpdate;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'New charts from Wonky Sheets follow their spreadsheet.'**
  String get settingsChartsAutoUpdateHint;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get settingsEditing;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settingsUnits;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Scroll to change slides'**
  String get settingsScrollChangesSlides;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Smart quotes'**
  String get settingsSmartQuotes;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Automatically format lists'**
  String get settingsAutoformatLists;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Show collaborator cursors'**
  String get settingsShowRemoteCursors;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Spelling'**
  String get settingsSpelling;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Underline spelling errors'**
  String get settingsUnderlineSpelling;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get settingsAnimations;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Default transition'**
  String get settingsDefaultTransition;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Transition duration'**
  String get settingsTransitionDuration;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Default build'**
  String get settingsDefaultBuild;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Preview animations on hover'**
  String get settingsPreviewOnHover;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Reduce motion in the editor'**
  String get settingsReduceEditorMotion;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Previews show the end state instead of playing.'**
  String get settingsReduceEditorMotionHint;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get settingsCode;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Code font size'**
  String get settingsCodeFontSize;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Default code language'**
  String get settingsCodeLanguage;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Type-in speed'**
  String get settingsTypingSpeed;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Type-in click sound'**
  String get settingsTypeInSound;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Presenting'**
  String get settingsPresenting;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'How you present. The audience view follows the presentation.'**
  String get settingsPresentingHint;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Presenter view layout'**
  String get settingsPresenterLayout;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Notes text size'**
  String get settingsNotesSize;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get settingsTimerMode;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Countdown length'**
  String get settingsTimerTarget;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Laser pointer color'**
  String get settingsLaserColor;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Start presenting in full screen'**
  String get settingsStartFullscreen;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Start with presenter view'**
  String get settingsStartWithPresenterView;

  /// Slides settings (Slides 04 §13.16).
  ///
  /// In en, this message translates to:
  /// **'Show skipped slides in presenter view'**
  String get settingsShowSkippedInPresenter;

  /// Slide size preset or dimension.
  ///
  /// In en, this message translates to:
  /// **'Widescreen 16:9'**
  String get sizeWidescreen16x9;

  /// Slide size preset or dimension.
  ///
  /// In en, this message translates to:
  /// **'Standard 4:3'**
  String get sizeStandard4x3;

  /// Slide size preset or dimension.
  ///
  /// In en, this message translates to:
  /// **'Widescreen 16:10'**
  String get sizeWide16x10;

  /// Slide size preset or dimension.
  ///
  /// In en, this message translates to:
  /// **'Square 1:1'**
  String get sizeSquare;

  /// Slide size preset or dimension.
  ///
  /// In en, this message translates to:
  /// **'Portrait 9:16'**
  String get sizePortrait9x16;

  /// Slide size preset or dimension.
  ///
  /// In en, this message translates to:
  /// **'A4 landscape'**
  String get sizeA4;

  /// Slide size preset or dimension.
  ///
  /// In en, this message translates to:
  /// **'Letter landscape'**
  String get sizeLetter;

  /// Slide size preset or dimension.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get sizeWidth;

  /// Slide size preset or dimension.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get sizeHeight;

  /// A slide without a title.
  ///
  /// In en, this message translates to:
  /// **'Untitled slide'**
  String get slideUntitled;

  /// Format › Line & paragraph spacing item.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get spacingSingle;

  /// Format › Line & paragraph spacing item.
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get spacingDouble;

  /// Format › Line & paragraph spacing item.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get spacingCustom;

  /// Format › Line & paragraph spacing item.
  ///
  /// In en, this message translates to:
  /// **'Add space before paragraph'**
  String get spacingAddBefore;

  /// Format › Line & paragraph spacing item.
  ///
  /// In en, this message translates to:
  /// **'Add space after paragraph'**
  String get spacingAddAfter;

  /// Type-in speed.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get speedSlow;

  /// Type-in speed.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get speedNormal;

  /// Type-in speed.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get speedFast;

  /// Status bar with an empty deck.
  ///
  /// In en, this message translates to:
  /// **'No slides'**
  String get statusNoSlides;

  /// Status bar position.
  ///
  /// In en, this message translates to:
  /// **'Slide {number} of {total}'**
  String statusSlideOf(int number, int total);

  /// Status bar: number of skipped slides.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String statusSkipped(int count);

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get styleTitle;

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get styleSubtitle;

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get styleHeading;

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get styleBody;

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Body 2'**
  String get styleBody2;

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get styleCaption;

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get styleQuote;

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Attribution'**
  String get styleAttribution;

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Big number'**
  String get styleBigNumber;

  /// Theme text style (05 §2.5).
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get styleLabel;

  /// Table item.
  ///
  /// In en, this message translates to:
  /// **'Insert row above'**
  String get tableInsertRowAbove;

  /// Table item.
  ///
  /// In en, this message translates to:
  /// **'Insert row below'**
  String get tableInsertRowBelow;

  /// Table item.
  ///
  /// In en, this message translates to:
  /// **'Insert column left'**
  String get tableInsertColumnLeft;

  /// Table item.
  ///
  /// In en, this message translates to:
  /// **'Insert column right'**
  String get tableInsertColumnRight;

  /// Format › Text item.
  ///
  /// In en, this message translates to:
  /// **'Superscript'**
  String get textSuperscript;

  /// Format › Text item.
  ///
  /// In en, this message translates to:
  /// **'Subscript'**
  String get textSubscript;

  /// Presenter timer mode.
  ///
  /// In en, this message translates to:
  /// **'Elapsed time'**
  String get timerElapsed;

  /// Presenter timer mode.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get timerCountdown;

  /// Screen reader label of the toolbar.
  ///
  /// In en, this message translates to:
  /// **'Slides toolbar'**
  String get toolbarLabel;

  /// Toolbar undo without a label.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get toolbarUndo;

  /// Toolbar redo without a label.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get toolbarRedo;

  /// Toolbar undo tooltip.
  ///
  /// In en, this message translates to:
  /// **'Undo {label}'**
  String toolbarUndoLabel(String label);

  /// Toolbar redo tooltip.
  ///
  /// In en, this message translates to:
  /// **'Redo {label}'**
  String toolbarRedoLabel(String label);

  /// Toolbar zoom tooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get toolbarZoom;

  /// Toolbar comment button.
  ///
  /// In en, this message translates to:
  /// **'Add comment'**
  String get toolbarAddComment;

  /// Toolbar align dropdown.
  ///
  /// In en, this message translates to:
  /// **'Align'**
  String get toolbarAlign;

  /// Toolbar Animate button.
  ///
  /// In en, this message translates to:
  /// **'Animate'**
  String get toolbarAnimate;

  /// Toolbar background button (nothing selected).
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get toolbarBackground;

  /// Toolbar layout dropdown (nothing selected).
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get toolbarLayout;

  /// Toolbar theme button (nothing selected).
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get toolbarTheme;

  /// Toolbar transition button (nothing selected).
  ///
  /// In en, this message translates to:
  /// **'Transition'**
  String get toolbarTransition;

  /// Transition effect.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get transitionNone;

  /// Transition effect.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get transitionFade;

  /// Transition effect.
  ///
  /// In en, this message translates to:
  /// **'Push'**
  String get transitionPush;

  /// Transition effect.
  ///
  /// In en, this message translates to:
  /// **'Wipe'**
  String get transitionWipe;

  /// Transition effect.
  ///
  /// In en, this message translates to:
  /// **'Dissolve'**
  String get transitionDissolve;

  /// Units option.
  ///
  /// In en, this message translates to:
  /// **'Slide units'**
  String get unitsSu;

  /// Units option.
  ///
  /// In en, this message translates to:
  /// **'Pixels'**
  String get unitsPx;

  /// Units option.
  ///
  /// In en, this message translates to:
  /// **'Inches'**
  String get unitsIn;

  /// Units option.
  ///
  /// In en, this message translates to:
  /// **'Centimeters'**
  String get unitsCm;

  /// View mode.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get viewNormal;

  /// View mode.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get viewGrid;

  /// View mode.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get viewOutline;

  /// Zoom to fit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get zoomFit;

  /// A zoom level.
  ///
  /// In en, this message translates to:
  /// **'{percent} %'**
  String zoomPercent(int percent);

  /// Toast when an undo skipped a collaborator’s newer changes.
  ///
  /// In en, this message translates to:
  /// **'Some changes weren’t undone because a collaborator changed them since'**
  String get toastUndoPartial;

  /// Title of the command `slides.select.elements` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Select objects'**
  String get cmdSelectElements;

  /// Title of the command `slides.select.next` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Select next object'**
  String get cmdSelectNext;

  /// Title of the command `slides.select.previous` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Select previous object'**
  String get cmdSelectPrevious;

  /// Title of the command `slides.element.move` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get cmdElementMove;

  /// Title of the command `slides.element.resize` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Resize'**
  String get cmdElementResize;

  /// Title of the command `slides.element.nudge` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Nudge'**
  String get cmdElementNudge;

  /// Title of the command `slides.element.adjust` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Adjust shape'**
  String get cmdElementAdjust;

  /// Title of the command `slides.element.setLineEnds` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Move line end'**
  String get cmdElementSetLineEnds;

  /// Title of the command `slides.element.lock` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get cmdElementLock;

  /// Title of the command `slides.element.unlock` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get cmdElementUnlock;

  /// Title of the command `slides.guides.move` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Move guide'**
  String get cmdGuidesMove;

  /// Title of the command `slides.guides.delete` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Delete guide'**
  String get cmdGuidesDelete;

  /// Undo label of a rotation (drag or Rotate 90°).
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get undoRotate;

  /// Undo label of Flip horizontally/vertically.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get undoFlip;

  /// Reason shown on a disabled command that needs a selected object.
  ///
  /// In en, this message translates to:
  /// **'Select an object'**
  String get reasonSelectObject;

  /// Reason shown on a disabled command (match size).
  ///
  /// In en, this message translates to:
  /// **'Select at least 2 objects'**
  String get reasonSelectTwoObjects;

  /// Reason shown on a disabled command (distribute).
  ///
  /// In en, this message translates to:
  /// **'Select at least 3 objects'**
  String get reasonSelectThreeObjects;

  /// Reason shown on a disabled command when a selected object is locked.
  ///
  /// In en, this message translates to:
  /// **'Unlock the object first'**
  String get reasonObjectLocked;

  /// Reason shown on a disabled command when the selection is inside an element group.
  ///
  /// In en, this message translates to:
  /// **'Not available for objects inside a group'**
  String get reasonInsideGroup;

  /// Reason shown on a disabled command that needs a selected element group.
  ///
  /// In en, this message translates to:
  /// **'Select a group'**
  String get reasonSelectGroup;

  /// Reason shown on a disabled Unlock all.
  ///
  /// In en, this message translates to:
  /// **'No locked objects on this slide'**
  String get reasonNoLockedObjects;

  /// Reason shown on disabled guide commands.
  ///
  /// In en, this message translates to:
  /// **'There are no guides'**
  String get reasonNoGuides;

  /// Reason shown when the selected object has no such action yet.
  ///
  /// In en, this message translates to:
  /// **'Not available for this object'**
  String get reasonNotOnCanvas;

  /// Name of an element kind (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Text box'**
  String get elementKindText;

  /// Name of an element kind (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get elementKindShape;

  /// Name of an element kind (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get elementKindLine;

  /// Name of an element kind (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get elementKindImage;

  /// Name of an element kind (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get elementKindTable;

  /// Name of an element kind (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get elementKindCode;

  /// Name of an element kind (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get elementKindChart;

  /// Name of an element kind (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get elementKindIcon;

  /// Name of an element kind (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get elementKindGroup;

  /// Name of an empty placeholder (screen reader announcements).
  ///
  /// In en, this message translates to:
  /// **'Placeholder'**
  String get elementKindPlaceholder;

  /// Screen reader announcement when one object is selected on the canvas.
  ///
  /// In en, this message translates to:
  /// **'{name} selected, {index} of {count} objects'**
  String canvasAnnounceSelected(String name, int index, int count);

  /// Screen reader announcement when several objects are selected.
  ///
  /// In en, this message translates to:
  /// **'{count} objects selected'**
  String canvasAnnounceSelectedMany(int count);

  /// Screen reader announcement after a move.
  ///
  /// In en, this message translates to:
  /// **'Moved to x {x}, y {y}'**
  String canvasAnnounceMoved(int x, int y);

  /// Semantics label of a canvas element: its name and state.
  ///
  /// In en, this message translates to:
  /// **'{name}, {state}'**
  String canvasElementSemantics(String name, String state);

  /// Semantics state of a selected canvas element.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get canvasStateSelected;

  /// Semantics state of a locked canvas element.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get canvasStateLocked;

  /// Dimensions badge while resizing (slide units).
  ///
  /// In en, this message translates to:
  /// **'{width} × {height}'**
  String canvasDimensions(int width, int height);

  /// Position badge while moving (slide units).
  ///
  /// In en, this message translates to:
  /// **'{x}, {y}'**
  String canvasPosition(int x, int y);

  /// Angle badge while rotating.
  ///
  /// In en, this message translates to:
  /// **'{degrees}°'**
  String canvasAngle(int degrees);

  /// Command: print the PDF from the print preview (Slides 10 §14)
  ///
  /// In en, this message translates to:
  /// **'Print PDF'**
  String get cmdPrintPrint;

  /// Print preview route title (10 §12)
  ///
  /// In en, this message translates to:
  /// **'Print preview'**
  String get printPreviewTitle;

  /// Print preview title with the deck name
  ///
  /// In en, this message translates to:
  /// **'Print preview — {name}'**
  String printPreviewTitleWithName(String name);

  /// Print preview: back button
  ///
  /// In en, this message translates to:
  /// **'Back to the presentation'**
  String get printBack;

  /// Print preview: download button
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get printDownloadPdf;

  /// Print preview: print button
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get printPrint;

  /// Print preview: settings column heading
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get printSettings;

  /// Print preview (narrow): back to the preview
  ///
  /// In en, this message translates to:
  /// **'Show preview'**
  String get printShowPreview;

  /// Print preview: page count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String printPageCount(int count);

  /// Print preview: rendering
  ///
  /// In en, this message translates to:
  /// **'Updating preview…'**
  String get printUpdatingPreview;

  /// Print preview: waiting for the deck
  ///
  /// In en, this message translates to:
  /// **'Loading presentation…'**
  String get printLoadingDeck;

  /// Print preview: error title
  ///
  /// In en, this message translates to:
  /// **'The preview could not be created'**
  String get printPreviewFailed;

  /// Print preview: retry
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get printTryAgain;

  /// Print preview: viewers may not export
  ///
  /// In en, this message translates to:
  /// **'Downloads are turned off'**
  String get printDownloadsDisabledTitle;

  /// Print preview: viewers may not export
  ///
  /// In en, this message translates to:
  /// **'The owner has turned off downloading and printing for viewers and commenters.'**
  String get printDownloadsDisabledBody;

  /// Toast when printing is not supported
  ///
  /// In en, this message translates to:
  /// **'Printing isn\'t available here'**
  String get printUnavailableTitle;

  /// Toast when printing is not supported
  ///
  /// In en, this message translates to:
  /// **'Download the PDF and print it from your PDF viewer.'**
  String get printUnavailableBody;

  /// Semantics label of the PDF viewer
  ///
  /// In en, this message translates to:
  /// **'PDF preview'**
  String get printPdfPreviewLabel;

  /// Print preview on desktop
  ///
  /// In en, this message translates to:
  /// **'The PDF is ready'**
  String get printPdfReady;

  /// Print preview on desktop
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The PDF is ready: 1 page} other{The PDF is ready: {count} pages}}'**
  String printPdfReadyPages(int count);

  /// Print preview on desktop
  ///
  /// In en, this message translates to:
  /// **'Download the PDF to view or print it.'**
  String get printPdfDesktopHint;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get printLayout;

  /// Print layout: one slide per page
  ///
  /// In en, this message translates to:
  /// **'Slides'**
  String get printLayoutSlides;

  /// Print layout: slide with speaker notes
  ///
  /// In en, this message translates to:
  /// **'Notes pages'**
  String get printLayoutNotes;

  /// Print layout: several slides per page
  ///
  /// In en, this message translates to:
  /// **'Handouts'**
  String get printLayoutHandouts;

  /// Print setting (handouts)
  ///
  /// In en, this message translates to:
  /// **'Slides per page'**
  String get printPerPage;

  /// Print setting (handouts)
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get printOrder;

  /// Handout order
  ///
  /// In en, this message translates to:
  /// **'Across, then down'**
  String get printOrderHorizontal;

  /// Handout order
  ///
  /// In en, this message translates to:
  /// **'Down, then across'**
  String get printOrderVertical;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Slides to print'**
  String get printRange;

  /// Print range
  ///
  /// In en, this message translates to:
  /// **'All slides'**
  String get printRangeAll;

  /// Print range
  ///
  /// In en, this message translates to:
  /// **'Current slide'**
  String get printRangeCurrent;

  /// Print range
  ///
  /// In en, this message translates to:
  /// **'Selected slides'**
  String get printRangeSelection;

  /// Print range
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get printRangeCustom;

  /// Placeholder of the custom range
  ///
  /// In en, this message translates to:
  /// **'e.g. 1-3, 7'**
  String get printRangeHint;

  /// Invalid custom range
  ///
  /// In en, this message translates to:
  /// **'Enter slide numbers like 1-3, 7'**
  String get printRangeInvalid;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get printPaper;

  /// Paper size: the slide's own size
  ///
  /// In en, this message translates to:
  /// **'Slide size'**
  String get printPaperSlide;

  /// Paper size
  ///
  /// In en, this message translates to:
  /// **'Letter'**
  String get printPaperLetter;

  /// Paper size
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get printPaperLegal;

  /// Paper size
  ///
  /// In en, this message translates to:
  /// **'Tabloid'**
  String get printPaperTabloid;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get printOrientation;

  /// Orientation
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get printOrientationAuto;

  /// Orientation
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get printOrientationPortrait;

  /// Orientation
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get printOrientationLandscape;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Margins'**
  String get printMargins;

  /// Margins
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get printMarginsNone;

  /// Margins
  ///
  /// In en, this message translates to:
  /// **'Narrow'**
  String get printMarginsNarrow;

  /// Margins
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get printMarginsNormal;

  /// Print setting (builds as pages, M10)
  ///
  /// In en, this message translates to:
  /// **'Print each build stage'**
  String get printBuilds;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Include skipped slides'**
  String get printSkipped;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Frame slides'**
  String get printFrame;

  /// Print setting (notes, handouts)
  ///
  /// In en, this message translates to:
  /// **'Header and footer'**
  String get printHeaderFooter;

  /// Print setting (handouts)
  ///
  /// In en, this message translates to:
  /// **'Slide numbers'**
  String get printSlideNumbers;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Bookmarks for sections and slides'**
  String get printBookmarks;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Clickable links'**
  String get printLinks;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Ink saver (no slide backgrounds)'**
  String get printInkSaver;

  /// Print setting
  ///
  /// In en, this message translates to:
  /// **'Image quality'**
  String get printQuality;

  /// Image quality
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get printQualityHigh;

  /// Image quality
  ///
  /// In en, this message translates to:
  /// **'Compact (smaller file)'**
  String get printQualityCompact;

  /// Heading of export warnings
  ///
  /// In en, this message translates to:
  /// **'About this PDF'**
  String get printWarnings;

  /// Export warning
  ///
  /// In en, this message translates to:
  /// **'A font could not be embedded; a standard font was used.'**
  String get printWarningFonts;

  /// Export warning
  ///
  /// In en, this message translates to:
  /// **'Some characters have no glyph in the embedded fonts.'**
  String get printWarningGlyphs;

  /// Export warning
  ///
  /// In en, this message translates to:
  /// **'Some icons could not be drawn.'**
  String get printWarningIcons;

  /// Export warning
  ///
  /// In en, this message translates to:
  /// **'Some images could not be loaded.'**
  String get printWarningImages;

  /// Export warning
  ///
  /// In en, this message translates to:
  /// **'Links to slides that are not printed were removed.'**
  String get printWarningLinks;

  /// Export warning
  ///
  /// In en, this message translates to:
  /// **'Only the first 500 pages were exported.'**
  String get printWarningPages;

  /// Export warning
  ///
  /// In en, this message translates to:
  /// **'No slides match these settings.'**
  String get printWarningEmpty;

  /// Toast after a download
  ///
  /// In en, this message translates to:
  /// **'Exported “{name}”'**
  String exportedToast(String name);

  /// Toast when an export fails
  ///
  /// In en, this message translates to:
  /// **'The export failed'**
  String get exportFailed;

  /// Download of PNG/Markdown (P1/P2)
  ///
  /// In en, this message translates to:
  /// **'This format is not available yet'**
  String get exportFormatUnavailable;

  /// PDF bookmark of an untitled slide
  ///
  /// In en, this message translates to:
  /// **'Slide {number}'**
  String pdfSlide(int number);

  /// PDF notes continuation heading
  ///
  /// In en, this message translates to:
  /// **'Notes (continued) — Slide {number}'**
  String pdfNotesContinued(int number);

  /// PDF footer
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {count}'**
  String pdfPageOf(int page, int count);

  /// PDF bookmark of an untitled group
  ///
  /// In en, this message translates to:
  /// **'Untitled section'**
  String get pdfUntitledSection;

  /// Title of a deck without one
  ///
  /// In en, this message translates to:
  /// **'Untitled presentation'**
  String get pdfUntitledPresentation;

  /// Title of the command `slides.group.rename` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get cmdGroupRename;

  /// Title of the command `slides.group.move` (menus, palette, tooltips, undo).
  ///
  /// In en, this message translates to:
  /// **'Move group'**
  String get cmdGroupMove;

  /// Title of the command `slides.group.toggleCollapsed`.
  ///
  /// In en, this message translates to:
  /// **'Collapse or expand group'**
  String get cmdGroupToggleCollapsed;

  /// Title of the command `slides.nav.selectAllSlides` (⌘A in the navigator).
  ///
  /// In en, this message translates to:
  /// **'Select all slides'**
  String get cmdNavSelectAllSlides;

  /// Title of the command `slides.navigator.copy`.
  ///
  /// In en, this message translates to:
  /// **'Copy slides'**
  String get cmdNavigatorCopy;

  /// Title of the command `slides.navigator.cut` (undo label).
  ///
  /// In en, this message translates to:
  /// **'Cut slides'**
  String get cmdNavigatorCut;

  /// Title of the command `slides.navigator.paste` (undo label).
  ///
  /// In en, this message translates to:
  /// **'Paste slides'**
  String get cmdNavigatorPaste;

  /// Title of the command `slides.notes.zoom`.
  ///
  /// In en, this message translates to:
  /// **'Speaker notes zoom'**
  String get cmdNotesZoom;

  /// Dynamic label of Delete slide with the selection count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete slide} other{Delete {count} slides}}'**
  String cmdSlideDeleteCount(int count);

  /// Dynamic label of Duplicate slide with the selection count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Duplicate slide} other{Duplicate {count} slides}}'**
  String cmdSlideDuplicateCount(int count);

  /// Undo label of typing in the speaker notes.
  ///
  /// In en, this message translates to:
  /// **'Edit speaker notes'**
  String get cmdEditNotes;

  /// Disabled reason: no slide is selected.
  ///
  /// In en, this message translates to:
  /// **'Select slides in the navigator'**
  String get reasonSelectSlides;

  /// Disabled reason of Group slides when the selection is exactly one group.
  ///
  /// In en, this message translates to:
  /// **'These slides are already a group'**
  String get reasonAlreadyGroup;

  /// Disabled reason of Skip slide for a slide inside a skipped group.
  ///
  /// In en, this message translates to:
  /// **'Skipped with group'**
  String get reasonSkippedWithGroup;

  /// Disabled reason of Remove from group / Ungroup.
  ///
  /// In en, this message translates to:
  /// **'The slide isn’t in a group'**
  String get reasonNotInGroup;

  /// Disabled reason of the collapse/expand all commands.
  ///
  /// In en, this message translates to:
  /// **'The presentation has no groups'**
  String get reasonNoGroups;

  /// Drop indicator tooltip and disabled reason when groups would go inside a group.
  ///
  /// In en, this message translates to:
  /// **'Groups can’t be nested'**
  String get reasonGroupsCantNest;

  /// Disabled reason of moving slides at the start/end.
  ///
  /// In en, this message translates to:
  /// **'The slides can’t move further'**
  String get reasonCantMoveFurther;

  /// Disabled reason of Paste in the navigator.
  ///
  /// In en, this message translates to:
  /// **'Copy slides or groups first'**
  String get reasonClipboardNoSlides;

  /// Disabled reason of Collapse group.
  ///
  /// In en, this message translates to:
  /// **'The group is already collapsed'**
  String get reasonAllCollapsed;

  /// Disabled reason of Expand group.
  ///
  /// In en, this message translates to:
  /// **'The group is already expanded'**
  String get reasonAllExpanded;

  /// Drop zone of an empty, expanded group in the navigator.
  ///
  /// In en, this message translates to:
  /// **'Drop slides here'**
  String get navigatorDropHere;

  /// Tooltip of the layout chevron next to + New slide.
  ///
  /// In en, this message translates to:
  /// **'New slide with layout'**
  String get navigatorNewSlideLayout;

  /// Badge of the drag ghost.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 slide} other{{count} slides}}'**
  String navigatorDragSlides(int count);

  /// Badge of the drag ghost of a group.
  ///
  /// In en, this message translates to:
  /// **'{title} · {count, plural, =1{1 slide} other{{count} slides}}'**
  String navigatorDragGroup(String title, int count);

  /// Screen reader state of an expanded group header.
  ///
  /// In en, this message translates to:
  /// **'expanded'**
  String get navigatorGroupExpanded;

  /// Screen reader state of a collapsed group header.
  ///
  /// In en, this message translates to:
  /// **'collapsed'**
  String get navigatorGroupCollapsed;

  /// Screen reader state of a skipped slide or group.
  ///
  /// In en, this message translates to:
  /// **'skipped'**
  String get navigatorSkipped;

  /// Screen reader label of a slide row inside a group.
  ///
  /// In en, this message translates to:
  /// **'Slide {number} of {total}, in group {group}: {title}'**
  String navigatorSlideInGroupSemantics(
    int number,
    int total,
    String group,
    String title,
  );

  /// Tooltip of the ⋮ button of a group header.
  ///
  /// In en, this message translates to:
  /// **'Group actions'**
  String get navigatorGroupMenu;

  /// Tooltip of the ⋮ button of a slide row.
  ///
  /// In en, this message translates to:
  /// **'Slide actions'**
  String get navigatorSlideMenu;

  /// Tooltip of the chevron of an expanded group header.
  ///
  /// In en, this message translates to:
  /// **'Collapse group (Alt+click: all groups)'**
  String get navigatorCollapseGroup;

  /// Tooltip of the chevron of a collapsed group header.
  ///
  /// In en, this message translates to:
  /// **'Expand group (Alt+click: all groups)'**
  String get navigatorExpandGroup;

  /// Tooltip of the color dot of a group header.
  ///
  /// In en, this message translates to:
  /// **'Group color'**
  String get navigatorGroupColor;

  /// Label of the inline rename field of a group.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get navigatorRenameField;

  /// Tooltip of the skip badge of a slide inside a skipped group.
  ///
  /// In en, this message translates to:
  /// **'Skipped with group'**
  String get navigatorSkippedWithGroup;

  /// Title of the Delete group dialog (04 §13.4).
  ///
  /// In en, this message translates to:
  /// **'Delete group ‘{title}’?'**
  String deleteGroupTitle(String title);

  /// Body of the Delete group dialog.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The group contains 1 slide.} other{The group contains {count} slides.}}'**
  String deleteGroupBody(int count);

  /// Title of the Delete group dialog for several groups.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} groups?'**
  String deleteGroupsTitle(int count);

  /// Delete group dialog: keep the slides.
  ///
  /// In en, this message translates to:
  /// **'Ungroup only'**
  String get deleteGroupUngroupOnly;

  /// Delete group dialog: destructive button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete group and 1 slide} other{Delete group and {count} slides}}'**
  String deleteGroupWithSlides(int count);

  /// Toast after deleting a group (Undo action next to it).
  ///
  /// In en, this message translates to:
  /// **'Group deleted'**
  String get toastGroupDeleted;

  /// Title of the dialog choosing the group for Add to group.
  ///
  /// In en, this message translates to:
  /// **'Add to group'**
  String get chooseGroupTitle;

  /// Field label of the Add to group dialog.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get chooseGroupLabel;

  /// Primary button of the Add to group dialog.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get chooseGroupButton;

  /// Label of the grid view thumbnail size slider.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail size'**
  String get gridThumbSize;

  /// Hint in the grid view toolbar.
  ///
  /// In en, this message translates to:
  /// **'Double-click a slide to open it'**
  String get gridOpenHint;

  /// Speaker notes mini toolbar.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get notesBold;

  /// Speaker notes mini toolbar.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get notesItalic;

  /// Speaker notes mini toolbar.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get notesUnderline;

  /// Speaker notes mini toolbar.
  ///
  /// In en, this message translates to:
  /// **'Bulleted list'**
  String get notesBulletList;

  /// Speaker notes mini toolbar.
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get notesNumberedList;

  /// Speaker notes mini toolbar.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get notesLink;

  /// Title of the speaker notes link dialog.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get notesLinkTitle;

  /// Field of the speaker notes link dialog.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get notesLinkUrl;

  /// Primary button of the speaker notes link dialog.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get notesLinkApply;

  /// Button of the speaker notes link dialog.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get notesLinkRemove;

  /// Validation of the speaker notes link dialog.
  ///
  /// In en, this message translates to:
  /// **'Enter an http or https address'**
  String get notesLinkInvalid;

  /// Speaker notes of a viewer (read-only).
  ///
  /// In en, this message translates to:
  /// **'View only'**
  String get notesReadOnly;

  /// Speaker notes when the deck has no slides.
  ///
  /// In en, this message translates to:
  /// **'No slide selected'**
  String get notesNoSlide;

  /// Undo step of a typing burst in a text box (SL-13).
  ///
  /// In en, this message translates to:
  /// **'Typing'**
  String get undoTyping;

  /// Primary button of the Slides value dialogs (font size, link, …).
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get dialogApply;

  /// Title of the link dialog (04 §13.5).
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkDialogTitle;

  /// Label of the link target select.
  ///
  /// In en, this message translates to:
  /// **'Link to'**
  String get linkTargetLabel;

  /// Link target option: a URL typed below.
  ///
  /// In en, this message translates to:
  /// **'Web address'**
  String get linkTargetUrl;

  /// Label of the URL field of the link dialog.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get linkUrlLabel;

  /// Button of the link dialog that removes the link.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get linkRemove;

  /// Element link action.
  ///
  /// In en, this message translates to:
  /// **'Next slide'**
  String get linkActionNext;

  /// Element link action.
  ///
  /// In en, this message translates to:
  /// **'Previous slide'**
  String get linkActionPrevious;

  /// Element link action.
  ///
  /// In en, this message translates to:
  /// **'First slide'**
  String get linkActionFirst;

  /// Element link action.
  ///
  /// In en, this message translates to:
  /// **'Last slide'**
  String get linkActionLast;

  /// Element link action.
  ///
  /// In en, this message translates to:
  /// **'End show'**
  String get linkActionEnd;

  /// Label of the font select.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontLabel;

  /// Label of the font size field.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fontSizeLabel;

  /// Label of the color field of the text color dialog.
  ///
  /// In en, this message translates to:
  /// **'Color (#RRGGBB or theme:accent1; empty = automatic)'**
  String get colorLabel;

  /// Label of the custom line spacing field.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get lineHeightLabel;

  /// Label of the list style select.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get listStyleLabel;

  /// Label of the list start field.
  ///
  /// In en, this message translates to:
  /// **'Start numbering at'**
  String get listStartLabel;

  /// Font option: the theme's heading font.
  ///
  /// In en, this message translates to:
  /// **'Theme heading font'**
  String get fontThemeHeading;

  /// Font option: the theme's body font.
  ///
  /// In en, this message translates to:
  /// **'Theme body font'**
  String get fontThemeBody;

  /// Font option: the theme's monospace font.
  ///
  /// In en, this message translates to:
  /// **'Theme monospace font'**
  String get fontThemeMono;

  /// Bullet style.
  ///
  /// In en, this message translates to:
  /// **'Disc'**
  String get listStyleDisc;

  /// Bullet style.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get listStyleCircle;

  /// Bullet style.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get listStyleSquare;

  /// Bullet style.
  ///
  /// In en, this message translates to:
  /// **'Dash'**
  String get listStyleDash;

  /// Bullet style.
  ///
  /// In en, this message translates to:
  /// **'Arrow'**
  String get listStyleArrow;

  /// Bullet style.
  ///
  /// In en, this message translates to:
  /// **'Check mark'**
  String get listStyleCheck;

  /// Bullet style.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get listStyleStar;

  /// Bullet style.
  ///
  /// In en, this message translates to:
  /// **'No bullet'**
  String get listStyleNone;

  /// Command: letter spacing of the selected text.
  ///
  /// In en, this message translates to:
  /// **'Letter spacing'**
  String get cmdFormatLetterSpacing;

  /// Command: text insets of a text box.
  ///
  /// In en, this message translates to:
  /// **'Text insets'**
  String get cmdFormatInsets;

  /// Command: stops editing text and selects the box.
  ///
  /// In en, this message translates to:
  /// **'Exit text editing'**
  String get cmdTextExitEditing;

  /// Command: removes the link of the selected text.
  ///
  /// In en, this message translates to:
  /// **'Remove link from text'**
  String get cmdTextRemoveLink;

  /// Disabled reason.
  ///
  /// In en, this message translates to:
  /// **'No text is being edited'**
  String get reasonNotEditingText;

  /// Disabled reason of text format commands.
  ///
  /// In en, this message translates to:
  /// **'Select text or a text box'**
  String get reasonSelectText;

  /// Disabled reason of Insert link.
  ///
  /// In en, this message translates to:
  /// **'Select text or an object'**
  String get reasonSelectTextOrObject;

  /// Disabled reason of Remove link.
  ///
  /// In en, this message translates to:
  /// **'The selection has no link'**
  String get reasonNoLink;

  /// Disabled reason of Reset to layout.
  ///
  /// In en, this message translates to:
  /// **'Select a placeholder'**
  String get reasonSelectPlaceholder;

  /// Toast when formatting skipped soft-locked text boxes (03 §6.1).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Skipped 1 text box {name} is editing} other{Skipped {count} text boxes others are editing}}'**
  String toastSkippedLocked(int count, String name);

  /// Validation message of number fields.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from {min} to {max}'**
  String validationNumberRange(String min, String max);

  /// Text of a link to a slide inserted at the caret.
  ///
  /// In en, this message translates to:
  /// **'Slide {number}'**
  String slideNumberLabel(int number);

  /// Theme color name (color picker swatch).
  ///
  /// In en, this message translates to:
  /// **'Background 1'**
  String get themeColorBg1;

  /// Theme color name (color picker swatch).
  ///
  /// In en, this message translates to:
  /// **'Background 2'**
  String get themeColorBg2;

  /// Theme color name (color picker swatch).
  ///
  /// In en, this message translates to:
  /// **'Text 1'**
  String get themeColorText1;

  /// Theme color name (color picker swatch).
  ///
  /// In en, this message translates to:
  /// **'Text 2'**
  String get themeColorText2;

  /// Theme accent color name.
  ///
  /// In en, this message translates to:
  /// **'Accent {n}'**
  String themeColorAccent(int n);

  /// Theme color name (color picker swatch).
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get themeColorLink;

  /// Name of a shape geometry (shape gallery, Change shape, MCP).
  ///
  /// In en, this message translates to:
  /// **'{geometry, select, rect{Rectangle} roundRect{Rounded rectangle} ellipse{Ellipse} triangle{Triangle} rightTriangle{Right triangle} diamond{Diamond} pentagon{Pentagon} hexagon{Hexagon} octagon{Octagon} parallelogram{Parallelogram} trapezoid{Trapezoid} donut{Donut} arc{Arc} blockArc{Block arc} pie{Pie} chord{Chord} frame{Frame} halfFrame{Half frame} plus{Plus} cross{Cross} cylinder{Cylinder} cube{Cube} can{Can} heart{Heart} cloud{Cloud} moon{Moon} sun{Sun} lightning{Lightning bolt} arrowRight{Right arrow} arrowLeft{Left arrow} arrowUp{Up arrow} arrowDown{Down arrow} arrowLeftRight{Left-right arrow} arrowUpDown{Up-down arrow} chevron{Chevron} homePlate{Pentagon arrow} notchedArrow{Notched arrow} curvedArrow{Curved arrow} circularArrow{Circular arrow} uTurn{U-turn arrow} star4{4-point star} star5{5-point star} star6{6-point star} star8{8-point star} star12{12-point star} burst{Burst} ribbon{Ribbon} wave{Wave} seal{Seal} speech{Speech bubble} speechRound{Round speech bubble} thought{Thought bubble} calloutRect{Rectangular callout} calloutLine{Line callout} banner{Banner} process{Process} decision{Decision} terminator{Terminator} document{Document} data{Data} manualInput{Manual input} predefinedProcess{Predefined process} connector{Connector} offPage{Off-page connector} delay{Delay} storage{Stored data} brace{Brace} bracket{Bracket} doubleBrace{Double brace} custom{Custom shape} other{Shape}}'**
  String shapeName(String geometry);

  /// Category heading of the shape gallery.
  ///
  /// In en, this message translates to:
  /// **'{category, select, basic{Basic shapes} arrows{Arrows} stars{Stars and badges} callouts{Callouts} flowchart{Flowchart} brackets{Brackets} custom{Custom} other{Shapes}}'**
  String shapeCategory(String category);

  /// Category of the icon picker sidebar.
  ///
  /// In en, this message translates to:
  /// **'{category, select, all{All icons} recent{Recently used} arrows{Arrows} business{Business} charts{Charts} communication{Communication} devices{Devices} development{Development} files{Files} food{Food and drink} media{Media} nature{Nature} people{People} security{Security} shapes{Shapes} text{Text} clock{Time} tools{Tools} travel{Travel} weather{Weather} other{Icons}}'**
  String iconCategory(String category);

  /// Arrowhead style of a line end.
  ///
  /// In en, this message translates to:
  /// **'{style, select, none{None} triangle{Arrow} open{Open arrow} stealth{Stealth arrow} circle{Circle} diamond{Diamond} bar{Bar} other{Arrow}}'**
  String arrowStyleName(String style);

  /// Arrowhead size.
  ///
  /// In en, this message translates to:
  /// **'{size, select, s{Small} m{Medium} l{Large} other{Medium}}'**
  String arrowSizeName(String size);

  /// Border/line dash style.
  ///
  /// In en, this message translates to:
  /// **'{dash, select, solid{Solid} dash{Dashed} dot{Dotted} dashDot{Dash-dot} longDash{Long dash} other{Solid}}'**
  String dashName(String dash);

  /// Line cap style.
  ///
  /// In en, this message translates to:
  /// **'{cap, select, butt{Flat} round{Round} square{Square} other{Flat}}'**
  String capName(String cap);

  /// Line routing.
  ///
  /// In en, this message translates to:
  /// **'{routing, select, straight{Straight} elbow{Elbow} curved{Curved} other{Straight}}'**
  String routingName(String routing);

  /// Name of a shape quick style (toolbar and Format › Shape menu).
  ///
  /// In en, this message translates to:
  /// **'{index, select, 0{Accent 1} 1{Accent 2} 2{Accent 3} 3{Accent 4} 4{Accent 5} 5{Accent 6} 6{Outline} 7{Soft tint} other{Style}}'**
  String quickStyleName(String index);

  /// Border/line weight in the weight menu.
  ///
  /// In en, this message translates to:
  /// **'{width} pt'**
  String strokeWidthLabel(String width);

  /// Command: choose another icon for the selected icon.
  ///
  /// In en, this message translates to:
  /// **'Replace icon…'**
  String get cmdIconReplace;

  /// Command: set the stroke width of Lucide icons.
  ///
  /// In en, this message translates to:
  /// **'Icon stroke width'**
  String get cmdIconSetStrokeWidth;

  /// Command: set an element's name (Layers panel, Arrange section).
  ///
  /// In en, this message translates to:
  /// **'Rename object'**
  String get cmdElementRename;

  /// Submenu: change the geometry of the selected shapes.
  ///
  /// In en, this message translates to:
  /// **'Change shape'**
  String get menuChangeShape;

  /// Submenu: theme-based shape styles.
  ///
  /// In en, this message translates to:
  /// **'Quick styles'**
  String get menuQuickStyles;

  /// Submenu: line routing.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get menuRouting;

  /// Border/line weight menu.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get menuWeight;

  /// Border/line dash menu.
  ///
  /// In en, this message translates to:
  /// **'Dash'**
  String get menuDash;

  /// Toolbar: border color picker.
  ///
  /// In en, this message translates to:
  /// **'Border color'**
  String get menuBorderColor;

  /// Toolbar: line color picker.
  ///
  /// In en, this message translates to:
  /// **'Line color'**
  String get menuLineColor;

  /// Toolbar: fill color picker.
  ///
  /// In en, this message translates to:
  /// **'Fill color'**
  String get menuFillColor;

  /// Toolbar: icon color picker.
  ///
  /// In en, this message translates to:
  /// **'Icon color'**
  String get menuIconColor;

  /// Color picker reset: use the theme's default object style.
  ///
  /// In en, this message translates to:
  /// **'Theme default'**
  String get colorThemeDefault;

  /// Inspector label.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get styleLabelColor;

  /// Inspector label (border/line width).
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get styleLabelWeight;

  /// Inspector label.
  ///
  /// In en, this message translates to:
  /// **'Dash'**
  String get styleLabelDash;

  /// Inspector label: line cap.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get styleLabelCap;

  /// Inspector label.
  ///
  /// In en, this message translates to:
  /// **'Arrow size'**
  String get styleLabelArrowSize;

  /// Inspector label.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get styleLabelRouting;

  /// Inspector label: drop shadow switch.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get styleLabelShadow;

  /// Inspector label: glow switch.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get styleLabelGlow;

  /// Inspector label.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get styleLabelOpacity;

  /// Fill picker: transparent.
  ///
  /// In en, this message translates to:
  /// **'No fill'**
  String get styleLabelNoFill;

  /// Border: none.
  ///
  /// In en, this message translates to:
  /// **'No border'**
  String get styleLabelNoBorder;

  /// Inspector label: the shape geometry.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get styleLabelGeometry;

  /// Icon stroke width label.
  ///
  /// In en, this message translates to:
  /// **'Stroke width'**
  String get styleLabelStrokeWidth;

  /// Inspector label: the icon's name.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get styleLabelIcon;

  /// A value differs between the selected objects.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get styleMixed;

  /// Arrange section: x position (slide units).
  ///
  /// In en, this message translates to:
  /// **'X'**
  String get arrangeLabelX;

  /// Arrange section: y position (slide units).
  ///
  /// In en, this message translates to:
  /// **'Y'**
  String get arrangeLabelY;

  /// Arrange section: width (slide units).
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get arrangeLabelW;

  /// Arrange section: height (slide units).
  ///
  /// In en, this message translates to:
  /// **'H'**
  String get arrangeLabelH;

  /// Arrange section: rotation in degrees.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get arrangeLabelRotation;

  /// Arrange section: object name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get arrangeLabelName;

  /// Arrange section button for element groups.
  ///
  /// In en, this message translates to:
  /// **'Edit inside group'**
  String get arrangeEditInsideGroup;

  /// Arrange section: lock switch.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get arrangeLocked;

  /// Accessibility section: description of the object.
  ///
  /// In en, this message translates to:
  /// **'Alt text'**
  String get accessibilityAltText;

  /// Placeholder of the alt text field.
  ///
  /// In en, this message translates to:
  /// **'Describe the object for people using screen readers'**
  String get accessibilityAltTextHint;

  /// Accessibility section: skipped by screen readers and alt text checks.
  ///
  /// In en, this message translates to:
  /// **'Decorative'**
  String get accessibilityDecorative;

  /// Accessibility section: the object's position in reading order.
  ///
  /// In en, this message translates to:
  /// **'Reading order: {position} of {count}'**
  String accessibilityReadingOrder(int position, int count);

  /// Title of the alt text dialog.
  ///
  /// In en, this message translates to:
  /// **'Alt text'**
  String get altTextDialogTitle;

  /// Checkbox of the alt text dialog.
  ///
  /// In en, this message translates to:
  /// **'Mark as decorative (screen readers skip it)'**
  String get altTextDialogDecorative;

  /// Primary button of Slides dialogs that save a value.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dialogSave;

  /// Title of the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Insert icon'**
  String get iconPickerTitle;

  /// Title of the icon picker when replacing an icon.
  ///
  /// In en, this message translates to:
  /// **'Replace icon'**
  String get iconPickerReplaceTitle;

  /// Search field of the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Search icons'**
  String get iconPickerSearch;

  /// Icon picker without results.
  ///
  /// In en, this message translates to:
  /// **'No icons match “{query}”'**
  String iconPickerEmpty(String query);

  /// Number of icons shown in the picker.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 icon} other{{count} icons}}'**
  String iconPickerCount(int count);

  /// Empty Recently used category of the icon picker.
  ///
  /// In en, this message translates to:
  /// **'Icons you insert show up here'**
  String get iconPickerRecentEmpty;

  /// Icon picker: stroke width.
  ///
  /// In en, this message translates to:
  /// **'Stroke'**
  String get iconPickerStroke;

  /// Icon picker: icon color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get iconPickerColor;

  /// Icon picker: category select (narrow widths).
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get iconPickerCategory;

  /// Icon picker primary button.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get iconPickerInsert;

  /// Icon picker primary button when replacing.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get iconPickerReplace;

  /// Title of the All shapes dialog.
  ///
  /// In en, this message translates to:
  /// **'Shapes'**
  String get shapeGalleryTitle;

  /// Primary button of the All shapes dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get shapeGalleryChoose;

  /// Disabled reason.
  ///
  /// In en, this message translates to:
  /// **'Select a shape'**
  String get reasonSelectShape;

  /// Disabled reason.
  ///
  /// In en, this message translates to:
  /// **'Select a line'**
  String get reasonSelectLine;

  /// Disabled reason.
  ///
  /// In en, this message translates to:
  /// **'Select an icon'**
  String get reasonSelectIcon;

  /// Disabled reason.
  ///
  /// In en, this message translates to:
  /// **'Select one object'**
  String get reasonSelectOneObject;

  /// Disabled reason of fill commands.
  ///
  /// In en, this message translates to:
  /// **'Select a shape, text box or icon'**
  String get reasonNoFill;

  /// Disabled reason of border commands.
  ///
  /// In en, this message translates to:
  /// **'Select a shape, line, text box, image or icon'**
  String get reasonNoBorder;

  /// Disabled reason of Group.
  ///
  /// In en, this message translates to:
  /// **'Placeholders can\'t be grouped'**
  String get reasonPlaceholdersCantGroup;

  /// Disabled reason of Group.
  ///
  /// In en, this message translates to:
  /// **'Select objects in the same group'**
  String get reasonSameLevel;

  /// Disabled reason of Paste style.
  ///
  /// In en, this message translates to:
  /// **'Copy a style first'**
  String get reasonNoStyleCopied;

  /// Announcement when Paint format is armed.
  ///
  /// In en, this message translates to:
  /// **'Click an object to apply the format'**
  String get painterArmed;

  /// Announcement when a shape tool is armed.
  ///
  /// In en, this message translates to:
  /// **'Click or drag on the slide to insert the shape'**
  String get toolArmedShape;

  /// Announcement when a line tool is armed.
  ///
  /// In en, this message translates to:
  /// **'Drag on the slide to draw the line'**
  String get toolArmedLine;

  /// Reset option of the text color picker (the style's color).
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get colorAutomatic;

  /// Inspector value when the selection has different values.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get inspectorMixed;

  /// Inspector › Text: space before paragraphs (su).
  ///
  /// In en, this message translates to:
  /// **'Space before'**
  String get spacingBeforeLabel;

  /// Inspector › Text: space after paragraphs (su).
  ///
  /// In en, this message translates to:
  /// **'Space after'**
  String get spacingAfterLabel;

  /// Disabled reason of image commands.
  ///
  /// In en, this message translates to:
  /// **'Select an image'**
  String get reasonSelectImage;

  /// Disabled reason of Download original.
  ///
  /// In en, this message translates to:
  /// **'Downloading isn\'t allowed for this presentation'**
  String get reasonNoDownload;

  /// Disabled reason of table commands.
  ///
  /// In en, this message translates to:
  /// **'Select a table'**
  String get reasonSelectTable;

  /// Disabled reason of commands that need a cell range.
  ///
  /// In en, this message translates to:
  /// **'Select table cells'**
  String get reasonSelectCells;

  /// Disabled reason of Unmerge cells.
  ///
  /// In en, this message translates to:
  /// **'No merged cells in the selection'**
  String get reasonNoMergedCells;

  /// Undo label of a crop.
  ///
  /// In en, this message translates to:
  /// **'Crop image'**
  String get undoCropImage;

  /// Enter in crop mode.
  ///
  /// In en, this message translates to:
  /// **'Apply crop'**
  String get cmdImageCropApply;

  /// Esc in crop mode.
  ///
  /// In en, this message translates to:
  /// **'Cancel crop'**
  String get cmdImageCropCancel;

  /// Retries an image upload refused for storage.
  ///
  /// In en, this message translates to:
  /// **'Retry upload'**
  String get cmdImageRetryUpload;

  /// Removes an image that couldn't be uploaded.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get cmdImageRemoveNotUploaded;

  /// Command: write row heights / column widths (border drag).
  ///
  /// In en, this message translates to:
  /// **'Resize rows or columns'**
  String get cmdTableResizeAxes;

  /// Command: cell padding.
  ///
  /// In en, this message translates to:
  /// **'Cell padding'**
  String get cmdTableSetCellPadding;

  /// Command: clear the text of the selected cells.
  ///
  /// In en, this message translates to:
  /// **'Clear cells'**
  String get cmdTableClearCells;

  /// Command: select a cell range.
  ///
  /// In en, this message translates to:
  /// **'Select cells'**
  String get cmdTableSelectCells;

  /// Command: arrow keys in a table.
  ///
  /// In en, this message translates to:
  /// **'Move cell selection'**
  String get cmdTableMoveSelection;

  /// Command: Tab in a table.
  ///
  /// In en, this message translates to:
  /// **'Next cell'**
  String get cmdTableNextCell;

  /// Command: Shift+Tab in a table.
  ///
  /// In en, this message translates to:
  /// **'Previous cell'**
  String get cmdTablePreviousCell;

  /// Command: edit the active cell's text.
  ///
  /// In en, this message translates to:
  /// **'Edit cell'**
  String get cmdTableEditCell;

  /// Command: Esc in a cell selection.
  ///
  /// In en, this message translates to:
  /// **'Select the whole table'**
  String get cmdTableClearCellSelection;

  /// Toast when an image's bytes can't be loaded.
  ///
  /// In en, this message translates to:
  /// **'This image isn\'t available right now.'**
  String get imageNotAvailable;

  /// File picker title for images.
  ///
  /// In en, this message translates to:
  /// **'Choose images'**
  String get imagePickTitle;

  /// Insert from clipboard without an image.
  ///
  /// In en, this message translates to:
  /// **'There\'s no image on the clipboard.'**
  String get imageClipboardEmpty;

  /// URL validation message.
  ///
  /// In en, this message translates to:
  /// **'Enter an https:// image address.'**
  String get imageUrlInvalid;

  /// Insert by URL / Drive failure.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this image.'**
  String get imageFetchFailed;

  /// Insert refused for quota (agents).
  ///
  /// In en, this message translates to:
  /// **'You\'re out of storage.'**
  String get imageOutOfStorage;

  /// Image too large.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t insert \'{name}\' — images can be at most 50 MB.'**
  String imageRejectedTooLarge(String name);

  /// Unsupported image type (03 §6.5.1).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t insert \'{name}\' — this image type isn\'t supported.'**
  String imageRejectedFormat(String name);

  /// Title of the image source dialog.
  ///
  /// In en, this message translates to:
  /// **'Insert image'**
  String get imageInsertDialogTitle;

  /// Title of the image source dialog when replacing.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get imageReplaceDialogTitle;

  /// Field label of the image source select.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get imageSourceLabel;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get dialogContinue;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get dialogInsert;

  /// Dialog button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogCancel;

  /// Title of the URL dialog (04 §13.2).
  ///
  /// In en, this message translates to:
  /// **'Insert image by URL'**
  String get imageUrlDialogTitle;

  /// Description of the URL dialog.
  ///
  /// In en, this message translates to:
  /// **'The image is fetched through Wonky Work and stored with the presentation.'**
  String get imageUrlDialogBody;

  /// URL field label.
  ///
  /// In en, this message translates to:
  /// **'Image address'**
  String get imageUrlLabel;

  /// Title of the mask dialog.
  ///
  /// In en, this message translates to:
  /// **'Mask with shape'**
  String get imageMaskDialogTitle;

  /// Mask shape field.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get imageMaskShape;

  /// Removes the mask.
  ///
  /// In en, this message translates to:
  /// **'No mask'**
  String get imageMaskNone;

  /// Title of the Drive image picker.
  ///
  /// In en, this message translates to:
  /// **'Insert image from Wonky Drive'**
  String get imageDriveDialogTitle;

  /// Search field of the Drive image picker.
  ///
  /// In en, this message translates to:
  /// **'Search images'**
  String get imageDriveSearch;

  /// Select field of the Drive image picker (MCP).
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get imageDriveImage;

  /// Drive picker error.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your images. Check your connection.'**
  String get imageDriveFailed;

  /// Drive picker without results.
  ///
  /// In en, this message translates to:
  /// **'No images found.'**
  String get imageDriveEmpty;

  /// Crop aspect preset.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get cropAspectFree;

  /// Crop aspect preset.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get cropAspectOriginal;

  /// Crop bar: image covers the box.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get cropFill;

  /// Crop bar: whole image in the box.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get cropFit;

  /// Crop bar: commit.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get cropDone;

  /// Badge on an image refused for storage (Drive 03 §6.3).
  ///
  /// In en, this message translates to:
  /// **'Not uploaded — out of storage'**
  String get imageNotUploadedOutOfStorage;

  /// Retry button of the badge.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get imageRetry;

  /// Remove button of the badge.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get imageRemove;

  /// Insert table dialog validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to {max}.'**
  String tableSizeInvalid(int max);

  /// Insert table dialog title.
  ///
  /// In en, this message translates to:
  /// **'Insert table'**
  String get tableInsertDialogTitle;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get tableRows;

  /// Field label.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get tableColumns;

  /// Title of `slides.theme.apply` (Themes panel; undo label).
  ///
  /// In en, this message translates to:
  /// **'Apply theme'**
  String get cmdThemeApply;

  /// Title of `slides.theme.import`.
  ///
  /// In en, this message translates to:
  /// **'Import theme from a presentation…'**
  String get cmdThemeImport;

  /// Title of `slides.theme.rename`.
  ///
  /// In en, this message translates to:
  /// **'Rename theme…'**
  String get cmdThemeRename;

  /// Title of `slides.theme.duplicate`.
  ///
  /// In en, this message translates to:
  /// **'Duplicate theme'**
  String get cmdThemeDuplicate;

  /// Title of `slides.theme.setDefault`.
  ///
  /// In en, this message translates to:
  /// **'Set as default theme'**
  String get cmdThemeSetDefault;

  /// Title of `slides.theme.delete`.
  ///
  /// In en, this message translates to:
  /// **'Remove theme'**
  String get cmdThemeDelete;

  /// Title of `slides.theme.removeUnused`.
  ///
  /// In en, this message translates to:
  /// **'Remove unused themes'**
  String get cmdThemeRemoveUnused;

  /// Title of `slides.deck.setSize`.
  ///
  /// In en, this message translates to:
  /// **'Change slide size'**
  String get cmdDeckSetSize;

  /// Title of `slides.deck.setNumbering`.
  ///
  /// In en, this message translates to:
  /// **'Set slide numbers and footer'**
  String get cmdDeckSetNumbering;

  /// Undo label of Page setup.
  ///
  /// In en, this message translates to:
  /// **'Change slide size'**
  String get undoChangeSlideSize;

  /// Undo label of the slide numbers dialog.
  ///
  /// In en, this message translates to:
  /// **'Slide numbers and footer'**
  String get undoNumbering;

  /// Disabled reason of Remove theme.
  ///
  /// In en, this message translates to:
  /// **'Used by slides — apply another theme to them first'**
  String get reasonThemeInUse;

  /// Disabled reason of Set as default theme.
  ///
  /// In en, this message translates to:
  /// **'Already the default theme'**
  String get reasonThemeIsDefault;

  /// Disabled reason of Remove unused themes.
  ///
  /// In en, this message translates to:
  /// **'Every theme is in use'**
  String get reasonNoUnusedThemes;

  /// Title of the Themes side panel.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get themesPanelTitle;

  /// Themes panel: heading of the scope choice.
  ///
  /// In en, this message translates to:
  /// **'Apply to'**
  String get themesApplyTo;

  /// Themes panel scope: every slide.
  ///
  /// In en, this message translates to:
  /// **'All slides'**
  String get themesApplyAll;

  /// Themes panel scope: the selected slides.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Selected slide} other{Selected slides ({count})}}'**
  String themesApplySelected(int count);

  /// Themes panel: heading of the deck's themes.
  ///
  /// In en, this message translates to:
  /// **'In this presentation'**
  String get themesInPresentation;

  /// Themes panel: heading of the built-in themes.
  ///
  /// In en, this message translates to:
  /// **'Built-in themes'**
  String get themesBuiltIn;

  /// Themes panel button.
  ///
  /// In en, this message translates to:
  /// **'Import theme from a presentation…'**
  String get themesImport;

  /// Badge of the deck's default theme.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get themesDefault;

  /// Usage of a theme.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Not used} =1{Used by 1 slide} other{Used by {count} slides}}'**
  String themesUsedBy(int count);

  /// Semantics label of a theme's ⋮ button.
  ///
  /// In en, this message translates to:
  /// **'More actions for {name}'**
  String themesMore(String name);

  /// Name shown for a theme without a name.
  ///
  /// In en, this message translates to:
  /// **'Untitled theme'**
  String get themeUntitled;

  /// Subtitle drawn on theme previews.
  ///
  /// In en, this message translates to:
  /// **'Title and subtitle'**
  String get themePreviewSubtitle;

  /// Name of a duplicated theme.
  ///
  /// In en, this message translates to:
  /// **'{name} copy'**
  String themeCopyName(String name);

  /// Rename theme dialog title.
  ///
  /// In en, this message translates to:
  /// **'Rename theme'**
  String get themeRenameTitle;

  /// Rename theme dialog field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get themeNameLabel;

  /// Rename theme validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get themeNameEmpty;

  /// Rename theme dialog button.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get themeRenameButton;

  /// Presentation picker title.
  ///
  /// In en, this message translates to:
  /// **'Import theme from a presentation'**
  String get themeImportPickTitle;

  /// Presentation picker search field.
  ///
  /// In en, this message translates to:
  /// **'Search presentations'**
  String get themeImportSearch;

  /// Presentation picker field (MCP).
  ///
  /// In en, this message translates to:
  /// **'Presentation'**
  String get themeImportPresentation;

  /// Presentation picker empty state.
  ///
  /// In en, this message translates to:
  /// **'No other presentations'**
  String get themeImportNoPresentations;

  /// Theme import needs the server.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to import a theme'**
  String get themeImportOffline;

  /// Theme chooser title (decks with several themes).
  ///
  /// In en, this message translates to:
  /// **'Choose a theme'**
  String get themeImportChooseTitle;

  /// A theme of the source deck in the chooser.
  ///
  /// In en, this message translates to:
  /// **'{name} — {count, plural, =0{not used} =1{1 slide} other{{count} slides}}'**
  String themeImportOption(String name, int count);

  /// Theme chooser button.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get themeImportButton;

  /// Toast after importing a theme.
  ///
  /// In en, this message translates to:
  /// **'Theme “{name}” added'**
  String themeImported(String name);

  /// Toast action after importing a theme.
  ///
  /// In en, this message translates to:
  /// **'Apply to all slides'**
  String get themeApplyToAll;

  /// Inspector › Slide › Background.
  ///
  /// In en, this message translates to:
  /// **'Reset to layout background'**
  String get backgroundResetToLayout;

  /// Page setup dialog title.
  ///
  /// In en, this message translates to:
  /// **'Page setup'**
  String get pageSetupTitle;

  /// Page setup: size preset.
  ///
  /// In en, this message translates to:
  /// **'Slide size'**
  String get pageSetupPreset;

  /// Page setup: unit of width and height.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get pageSetupUnit;

  /// Page setup: scaling choice heading.
  ///
  /// In en, this message translates to:
  /// **'Existing content'**
  String get pageSetupContent;

  /// Page setup: scale content.
  ///
  /// In en, this message translates to:
  /// **'Scale content to fit'**
  String get pageSetupScale;

  /// Page setup: keep frames.
  ///
  /// In en, this message translates to:
  /// **'Don\'t scale'**
  String get pageSetupDontScale;

  /// Page setup: preview label.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get pageSetupPreview;

  /// Apply button of page setup and slide numbers.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get pageSetupApply;

  /// Page setup validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a width and a height.'**
  String get pageSetupEnterSize;

  /// Page setup validation.
  ///
  /// In en, this message translates to:
  /// **'Each side must be between 320 and 7,680 su.'**
  String get pageSetupSideRange;

  /// Page setup validation.
  ///
  /// In en, this message translates to:
  /// **'The aspect ratio must be between 1:4 and 4:1.'**
  String get pageSetupAspectRange;

  /// Custom slide size.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get sizeCustom;

  /// Slide numbers dialog title.
  ///
  /// In en, this message translates to:
  /// **'Slide numbers and footer'**
  String get numberingTitle;

  /// Slide numbers dialog field.
  ///
  /// In en, this message translates to:
  /// **'Show slide numbers'**
  String get numberingShow;

  /// Slide numbers dialog field.
  ///
  /// In en, this message translates to:
  /// **'First slide number'**
  String get numberingFirst;

  /// Slide numbers validation.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 0 to 9999'**
  String get numberingFirstInvalid;

  /// Slide numbers dialog field.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show on title slides'**
  String get numberingHideOnTitle;

  /// Slide numbers dialog field.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get numberingFooter;

  /// Slide numbers dialog placeholder.
  ///
  /// In en, this message translates to:
  /// **'Empty = no footer'**
  String get numberingFooterHint;

  /// Image section: the image is still uploading from this device.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get imageUploading;

  /// Image section heading.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get imageAdjustments;

  /// Image adjustment.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get imageBrightness;

  /// Image adjustment.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get imageContrast;

  /// Image adjustment.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get imageSaturation;

  /// Image adjustment.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get imageTemperature;

  /// Image adjustment.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get imageBlur;

  /// Image adjustment toggle.
  ///
  /// In en, this message translates to:
  /// **'Grayscale'**
  String get imageGrayscale;

  /// Image adjustment toggle.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get imageSepia;

  /// Image adjustment toggle.
  ///
  /// In en, this message translates to:
  /// **'Invert'**
  String get imageInvert;

  /// Table section: table style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get tableStyle;

  /// Table style: the theme's.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get tableStyleTheme;

  /// Table style: plain.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get tableStyleNone;

  /// Table option.
  ///
  /// In en, this message translates to:
  /// **'Header row'**
  String get tableHeaderRow;

  /// Table option.
  ///
  /// In en, this message translates to:
  /// **'First column'**
  String get tableFirstColumn;

  /// Table option.
  ///
  /// In en, this message translates to:
  /// **'Banded rows'**
  String get tableBandedRows;

  /// Table option.
  ///
  /// In en, this message translates to:
  /// **'Banded columns'**
  String get tableBandedColumns;

  /// Table option.
  ///
  /// In en, this message translates to:
  /// **'Total row'**
  String get tableTotalRow;

  /// Cell section: size of the cell selection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 cell selected} other{{count} cells selected}}'**
  String tableCellsSelected(int count);

  /// Cell section: cell fill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get tableCellFill;

  /// Reset of the cell fill (back to the table style).
  ///
  /// In en, this message translates to:
  /// **'Table style'**
  String get tableStyleFill;

  /// Cell section: vertical alignment.
  ///
  /// In en, this message translates to:
  /// **'Align'**
  String get tableVerticalAlign;

  /// Cell section: cell padding (su).
  ///
  /// In en, this message translates to:
  /// **'Padding'**
  String get tableCellPadding;

  /// Placeholder of the padding select.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get tableStyleDefault;

  /// Cell section: borders.
  ///
  /// In en, this message translates to:
  /// **'Borders'**
  String get tableBorders;

  /// Edge buttons of the border picker.
  ///
  /// In en, this message translates to:
  /// **'{edge, select, all{All borders} outer{Outer borders} inner{Inner borders} horizontal{Inner horizontal borders} vertical{Inner vertical borders} top{Top border} bottom{Bottom border} left{Left border} right{Right border} none{Clear borders} other{Borders}}'**
  String tableBorderEdge(String edge);

  /// Border styles.
  ///
  /// In en, this message translates to:
  /// **'{style, select, solid{Solid} dashed{Dashed} dotted{Dotted} other{Solid}}'**
  String tableBorderStyle(String style);

  /// Title of the command `slides.present.end`.
  ///
  /// In en, this message translates to:
  /// **'End presentation'**
  String get cmdPresentEnd;

  /// Title of the command `slides.present.next` (next step or slide).
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get cmdPresentNext;

  /// Title of the command `slides.present.previous`.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get cmdPresentPrevious;

  /// Title of the command `slides.present.nextSlide` (skips remaining builds).
  ///
  /// In en, this message translates to:
  /// **'Next slide'**
  String get cmdPresentNextSlide;

  /// Title of the command `slides.present.previousSlide`.
  ///
  /// In en, this message translates to:
  /// **'Previous slide'**
  String get cmdPresentPreviousSlide;

  /// Title of the command `slides.present.goTo`.
  ///
  /// In en, this message translates to:
  /// **'Go to slide'**
  String get cmdPresentGoTo;

  /// Title of the command `slides.present.first`.
  ///
  /// In en, this message translates to:
  /// **'First slide'**
  String get cmdPresentFirst;

  /// Title of the command `slides.present.last`.
  ///
  /// In en, this message translates to:
  /// **'Last slide'**
  String get cmdPresentLast;

  /// Title of the command `slides.present.blank`.
  ///
  /// In en, this message translates to:
  /// **'Black or white screen'**
  String get cmdPresentBlank;

  /// Title of the command `slides.present.picker`.
  ///
  /// In en, this message translates to:
  /// **'Slide picker'**
  String get cmdPresentPicker;

  /// Title of the command `slides.present.tool` (laser, pen, highlighter, eraser).
  ///
  /// In en, this message translates to:
  /// **'Pointer tool'**
  String get cmdPresentTool;

  /// Title of the command `slides.present.clearInk`.
  ///
  /// In en, this message translates to:
  /// **'Clear ink on this slide'**
  String get cmdPresentClearInk;

  /// Title of the command `slides.present.undoInk`.
  ///
  /// In en, this message translates to:
  /// **'Undo last ink stroke'**
  String get cmdPresentUndoInk;

  /// Title of the command `slides.present.timer` (start, pause, reset).
  ///
  /// In en, this message translates to:
  /// **'Presenter timer'**
  String get cmdPresentTimer;

  /// Title of the command `slides.present.joinAsAudience`.
  ///
  /// In en, this message translates to:
  /// **'Show audience view here'**
  String get cmdPresentJoinAsAudience;

  /// Title of the command `slides.present.toggleFullscreen`.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get cmdPresentToggleFullscreen;

  /// Title of the command `slides.present.toggleSkipped` (presenter view).
  ///
  /// In en, this message translates to:
  /// **'Show skipped slides'**
  String get cmdPresentToggleSkipped;

  /// Title of the command `slides.present.notesSize`.
  ///
  /// In en, this message translates to:
  /// **'Speaker notes size'**
  String get cmdPresentNotesSize;

  /// Title of the command `slides.present.help` (the help overlay while presenting).
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get cmdPresentHelp;

  /// Title (and undo label) of the command `slides.deck.setPresentSettings`.
  ///
  /// In en, this message translates to:
  /// **'Presentation settings'**
  String get cmdDeckSetPresentSettings;

  /// Disabled reason of in-presentation commands.
  ///
  /// In en, this message translates to:
  /// **'Not presenting'**
  String get reasonNotPresenting;

  /// Disabled reason of presenter-view commands.
  ///
  /// In en, this message translates to:
  /// **'Only in the presenter view'**
  String get reasonPresenterViewOnly;

  /// Error of a go-to command with an unknown slide.
  ///
  /// In en, this message translates to:
  /// **'That slide isn’t in this presentation'**
  String get presentUnknownSlide;

  /// Screen reader label of the presented slide.
  ///
  /// In en, this message translates to:
  /// **'Slide {number} of {total}'**
  String presentSlideLabel(int number, int total);

  /// End screen after the last slide.
  ///
  /// In en, this message translates to:
  /// **'End of presentation — click to exit'**
  String get presentEndScreen;

  /// Audience view while the presenter's slide is still syncing.
  ///
  /// In en, this message translates to:
  /// **'Catching up…'**
  String get presentCatchingUp;

  /// Screen reader label of the present toolbar.
  ///
  /// In en, this message translates to:
  /// **'Presentation controls'**
  String get presentToolbarLabel;

  /// Screen reader label of the toolbar's slide counter.
  ///
  /// In en, this message translates to:
  /// **'Slide {number} of {total}. Open the slide picker'**
  String presentCounterLabel(int number, int total);

  /// Present tool.
  ///
  /// In en, this message translates to:
  /// **'Laser pointer'**
  String get presentToolLaser;

  /// Present tool.
  ///
  /// In en, this message translates to:
  /// **'Pen'**
  String get presentToolPen;

  /// Present tool.
  ///
  /// In en, this message translates to:
  /// **'Highlighter'**
  String get presentToolHighlighter;

  /// Present tool.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get presentToolEraser;

  /// Present action covering the slide in black.
  ///
  /// In en, this message translates to:
  /// **'Black screen'**
  String get presentBlackScreen;

  /// Present action covering the slide in white.
  ///
  /// In en, this message translates to:
  /// **'White screen'**
  String get presentWhiteScreen;

  /// Button that ends the presentation.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get presentEnd;

  /// Overlay while digits are typed to go to a slide.
  ///
  /// In en, this message translates to:
  /// **'Go to {number}'**
  String presentGoToNumber(String number);

  /// Title of the shortcut help overlay while presenting.
  ///
  /// In en, this message translates to:
  /// **'Presenting shortcuts'**
  String get presentHelpTitle;

  /// Help overlay row.
  ///
  /// In en, this message translates to:
  /// **'Go to slide number'**
  String get presentHelpGoToNumber;

  /// Help overlay keys for going to a slide by number.
  ///
  /// In en, this message translates to:
  /// **'1 2 3 … Enter'**
  String get presentHelpDigits;

  /// Help overlay row for holding Cmd/Ctrl.
  ///
  /// In en, this message translates to:
  /// **'Laser while held (move the mouse)'**
  String get presentHelpTemporaryLaser;

  /// Present timer action.
  ///
  /// In en, this message translates to:
  /// **'Pause or resume the timer'**
  String get presentTimerPause;

  /// Present timer action.
  ///
  /// In en, this message translates to:
  /// **'Resume the timer'**
  String get presentTimerResume;

  /// Present timer action.
  ///
  /// In en, this message translates to:
  /// **'Reset the timer'**
  String get presentTimerReset;

  /// Presenter view notes size.
  ///
  /// In en, this message translates to:
  /// **'Larger notes'**
  String get presentNotesLarger;

  /// Presenter view notes size.
  ///
  /// In en, this message translates to:
  /// **'Smaller notes'**
  String get presentNotesSmaller;

  /// Help overlay row: F5 resumes while presenting.
  ///
  /// In en, this message translates to:
  /// **'Resume (clicker F5)'**
  String get presentResume;

  /// Hint when the browser refused full screen.
  ///
  /// In en, this message translates to:
  /// **'Press F11 (⌃⌘F on Mac) for full screen'**
  String get presentFullscreenHint;

  /// Button that enters full screen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get presentFullscreenButton;

  /// Title of the audience view's start card.
  ///
  /// In en, this message translates to:
  /// **'Audience view'**
  String get presentAudienceTitle;

  /// Audience view start card.
  ///
  /// In en, this message translates to:
  /// **'This screen shows the slides of your presentation.'**
  String get presentAudienceBody;

  /// Audience view start card with the presenter's device.
  ///
  /// In en, this message translates to:
  /// **'This screen shows the slides you present on {device}.'**
  String presentAudienceBodyFrom(String device);

  /// Audience view start card hint.
  ///
  /// In en, this message translates to:
  /// **'A clicker or the arrow keys here also move the presentation.'**
  String get presentAudienceKeys;

  /// Audience view start card: keep the window.
  ///
  /// In en, this message translates to:
  /// **'Stay in window'**
  String get presentAudienceStay;

  /// Present context menu item that opens the slide picker.
  ///
  /// In en, this message translates to:
  /// **'Go to slide…'**
  String get presentGoToSlideMenu;

  /// Title of the slide picker while presenting.
  ///
  /// In en, this message translates to:
  /// **'Go to slide'**
  String get presentPickerTitle;

  /// Placeholder of the slide picker filter.
  ///
  /// In en, this message translates to:
  /// **'Filter by title or number'**
  String get presentPickerFilter;

  /// Closes the slide picker.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get presentPickerClose;

  /// Slide picker with a filter that matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No slides match'**
  String get presentPickerNoMatch;

  /// Screen reader label of a group header in the slide picker.
  ///
  /// In en, this message translates to:
  /// **'{title}, {count, plural, =1{1 slide} other{{count} slides}}'**
  String presentPickerGroup(String title, int count);

  /// Screen reader label of a slide in the picker and the strip.
  ///
  /// In en, this message translates to:
  /// **'Slide {number}: {title}'**
  String presentPickerSlide(int number, String title);

  /// Screen reader hint of a skipped slide.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get presentPickerSkipped;

  /// Title of the audience link dialog.
  ///
  /// In en, this message translates to:
  /// **'Open on another device'**
  String get presentOpenOnDeviceTitle;

  /// Body of the audience link dialog.
  ///
  /// In en, this message translates to:
  /// **'Open this link on the computer or browser that shows the slides — for example the one connected to the projector. Sign in with your account there.'**
  String get presentOpenOnDeviceBody;

  /// Hint in the audience link dialog.
  ///
  /// In en, this message translates to:
  /// **'Or open this presentation there and choose “Show audience view here”.'**
  String get presentOpenOnDeviceHint;

  /// Label of the audience link field.
  ///
  /// In en, this message translates to:
  /// **'Audience link'**
  String get presentAudienceLink;

  /// Copies the audience link.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get presentCopyLink;

  /// Button label after the link was copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get presentLinkCopied;

  /// Closes the audience link dialog.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get presentDone;

  /// Screen reader label of the QR code.
  ///
  /// In en, this message translates to:
  /// **'QR code of the audience link'**
  String get presentQrLabel;

  /// Presenting without a connection.
  ///
  /// In en, this message translates to:
  /// **'Offline — other devices can’t join'**
  String get presentOfflineNoDevices;

  /// Presenting without a connection, details.
  ///
  /// In en, this message translates to:
  /// **'You can keep presenting here. Other devices join once you’re back online.'**
  String get presentOfflineNoDevicesBody;

  /// Presentation session status.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get presentConnecting;

  /// Presenter view: the session ended.
  ///
  /// In en, this message translates to:
  /// **'Not connected to other devices'**
  String get presentSessionEnded;

  /// Presenter view: devices showing the audience view.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No other devices yet} =1{1 other device} other{{count} other devices}}'**
  String presentAudienceDevices(int count);

  /// Audience view while the presenter reconnects.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the presenter…'**
  String get presentPresenterAway;

  /// Audience view before the first state arrives.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the presenter'**
  String get presentWaitingForPresenter;

  /// Toast on the audience device when the presenter ends.
  ///
  /// In en, this message translates to:
  /// **'The presentation ended'**
  String get presentAudienceEndedToast;

  /// Audience link of a session that ended or never existed.
  ///
  /// In en, this message translates to:
  /// **'This presentation isn’t running'**
  String get presentAudienceNotFound;

  /// Audience link that can't be joined, details.
  ///
  /// In en, this message translates to:
  /// **'Ask the presenter for a new link, or open the presentation and choose “Show audience view here”.'**
  String get presentAudienceNotFoundBody;

  /// Audience link opened by another account.
  ///
  /// In en, this message translates to:
  /// **'Only the presenter can show this audience view'**
  String get presentAudienceNoAccess;

  /// Dialog when the presenter view is already open elsewhere.
  ///
  /// In en, this message translates to:
  /// **'Take over the presentation?'**
  String get presentTakeOverTitle;

  /// Body of the take-over dialog.
  ///
  /// In en, this message translates to:
  /// **'You’re presenting this in another window. Take over the presentation from your other window?'**
  String get presentTakeOverBody;

  /// Confirms taking over the presentation.
  ///
  /// In en, this message translates to:
  /// **'Take over'**
  String get presentTakeOver;

  /// Keeps the other window's session; presents alone here.
  ///
  /// In en, this message translates to:
  /// **'Present here only'**
  String get presentTakeOverCancel;

  /// Toast when another window took over the presentation.
  ///
  /// In en, this message translates to:
  /// **'Your presentation continues in another window'**
  String get presentTakenOverToast;

  /// One-time hint with an extended display.
  ///
  /// In en, this message translates to:
  /// **'Showing the slides on a projector?'**
  String get presentExtendedHintTitle;

  /// One-time hint with an extended display, details.
  ///
  /// In en, this message translates to:
  /// **'Open this presentation in a window there and choose “Show audience view here” — or use “Open on another device…”.'**
  String get presentExtendedHintBody;

  /// Title of the presenter view (narrow).
  ///
  /// In en, this message translates to:
  /// **'Presenter view'**
  String get presenterViewTitle;

  /// Title of the presenter view.
  ///
  /// In en, this message translates to:
  /// **'Presenter view — {name}'**
  String presenterViewTitleWithName(String name);

  /// Presenter view header button: open on another device.
  ///
  /// In en, this message translates to:
  /// **'Other device…'**
  String get presenterOtherDevice;

  /// Presenter view: label of the current slide.
  ///
  /// In en, this message translates to:
  /// **'Current slide'**
  String get presenterCurrent;

  /// Presenter view: current slide with builds.
  ///
  /// In en, this message translates to:
  /// **'Current slide · step {step} of {count}'**
  String presenterCurrentStep(int step, int count);

  /// Presenter view while the screen is black.
  ///
  /// In en, this message translates to:
  /// **'Audience: black screen'**
  String get presenterAudienceBlack;

  /// Presenter view while the screen is white.
  ///
  /// In en, this message translates to:
  /// **'Audience: white screen'**
  String get presenterAudienceWhite;

  /// Presenter view: returns from black/white.
  ///
  /// In en, this message translates to:
  /// **'Show slide'**
  String get presenterShowSlide;

  /// Presenter view: the next step of this slide.
  ///
  /// In en, this message translates to:
  /// **'Next: build {step} of {count}'**
  String presenterNextBuild(int step, int count);

  /// Presenter view: the next slide.
  ///
  /// In en, this message translates to:
  /// **'Next slide: {title}'**
  String presenterNextSlide(String title);

  /// Presenter view: the next slide without a title.
  ///
  /// In en, this message translates to:
  /// **'Next slide'**
  String get presenterNextSlideUntitled;

  /// Presenter view: nothing follows.
  ///
  /// In en, this message translates to:
  /// **'End of presentation'**
  String get presenterNextEnd;

  /// Presenter view on the end screen.
  ///
  /// In en, this message translates to:
  /// **'Next: exit'**
  String get presenterNextExit;

  /// Presenter view notes label.
  ///
  /// In en, this message translates to:
  /// **'Speaker notes'**
  String get presenterNotes;

  /// Presenter view: empty notes.
  ///
  /// In en, this message translates to:
  /// **'No speaker notes for this slide'**
  String get presenterNoNotes;

  /// Screen reader label of the timer.
  ///
  /// In en, this message translates to:
  /// **'Elapsed {time}'**
  String presenterElapsed(String time);

  /// Screen reader label of the countdown.
  ///
  /// In en, this message translates to:
  /// **'Remaining {time}'**
  String presenterRemaining(String time);

  /// Presenter view: slide counter.
  ///
  /// In en, this message translates to:
  /// **'Slide {number} / {total}'**
  String presenterSlideOf(int number, int total);

  /// Pacing against rehearsed timings.
  ///
  /// In en, this message translates to:
  /// **'{time} ahead'**
  String presenterAhead(String time);

  /// Pacing against rehearsed timings.
  ///
  /// In en, this message translates to:
  /// **'{time} behind'**
  String presenterBehind(String time);

  /// Screen reader label of the presenter view's strip.
  ///
  /// In en, this message translates to:
  /// **'Slides'**
  String get presenterStrip;

  /// Editor banner while a presentation session of the user is live.
  ///
  /// In en, this message translates to:
  /// **'You’re presenting on {device}'**
  String presentBannerTitle(String device);

  /// Editor banner while a session is live (no device label).
  ///
  /// In en, this message translates to:
  /// **'You’re presenting this presentation'**
  String get presentBannerTitleNoDevice;

  /// Hides the presenting banner.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get presentBannerDismiss;

  /// Copies the selection: objects, text or table cells (SL-18).
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get cmdEditCopy;

  /// Cuts the selection: objects, text or table cells (SL-18).
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cmdEditCut;

  /// Pastes the clipboard into the selection or the slide (SL-18).
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get cmdEditPaste;

  /// Disabled reason of Copy for viewers when copying is off.
  ///
  /// In en, this message translates to:
  /// **'The owner turned off copying for viewers'**
  String get reasonCopyNotAllowed;

  /// Paste in the navigator when the clipboard holds objects.
  ///
  /// In en, this message translates to:
  /// **'Paste objects on a slide'**
  String get reasonPasteObjectsOnSlide;

  /// Paste into table cells when the clipboard holds slides.
  ///
  /// In en, this message translates to:
  /// **'Paste slides in the slide navigator'**
  String get reasonPasteSlidesNotInCells;

  /// Paste with an empty (or unreadable) clipboard.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to paste'**
  String get toastClipboardEmpty;

  /// Pasting a chart copied in Wonky Sheets while charts in Slides are not available (M9).
  ///
  /// In en, this message translates to:
  /// **'Charts from Wonky Sheets can\'t be pasted into presentations'**
  String get toastPasteChartsUnavailable;

  /// Paste into table cells larger than the table.
  ///
  /// In en, this message translates to:
  /// **'Only the cells that fit in the table were pasted'**
  String get toastPasteClipped;

  /// A pasted grid larger than the table limits.
  ///
  /// In en, this message translates to:
  /// **'Only the first 50 rows and 20 columns were pasted'**
  String get toastPasteTruncated;

  /// Paste options chip: the chart stays linked to Wonky Sheets.
  ///
  /// In en, this message translates to:
  /// **'Linked to the spreadsheet'**
  String get pasteChartLinked;

  /// Screen reader label of the paste options chip.
  ///
  /// In en, this message translates to:
  /// **'Paste options'**
  String get pasteOptionsLabel;

  /// Command: next find match.
  ///
  /// In en, this message translates to:
  /// **'Find next'**
  String get cmdFindNext;

  /// Command: previous find match.
  ///
  /// In en, this message translates to:
  /// **'Find previous'**
  String get cmdFindPrevious;

  /// Command/button: replace the current match.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get cmdFindReplace;

  /// Command/button: replace every match.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get cmdFindReplaceAll;

  /// Undo step label of Replace all.
  ///
  /// In en, this message translates to:
  /// **'Replace all'**
  String get undoReplaceAll;

  /// Closes the find bar or the find and replace panel.
  ///
  /// In en, this message translates to:
  /// **'Close find'**
  String get findClose;

  /// Placeholder of the find bar.
  ///
  /// In en, this message translates to:
  /// **'Find in presentation'**
  String get findPlaceholder;

  /// Find status without matches.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get findNoResults;

  /// Find status: current match of all.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String findOfCount(int current, int total);

  /// Find status before stepping to a match.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match} other{{count} matches}}'**
  String findMatchesCount(int count);

  /// Title of the find and replace panel.
  ///
  /// In en, this message translates to:
  /// **'Find and replace'**
  String get findReplaceTitle;

  /// Find field label.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get findLabel;

  /// Replace field label.
  ///
  /// In en, this message translates to:
  /// **'Replace with'**
  String get replaceLabel;

  /// Find option.
  ///
  /// In en, this message translates to:
  /// **'Match case'**
  String get findMatchCase;

  /// Find option.
  ///
  /// In en, this message translates to:
  /// **'Whole words'**
  String get findWholeWords;

  /// Find option.
  ///
  /// In en, this message translates to:
  /// **'Use regular expressions'**
  String get findUseRegex;

  /// Find option.
  ///
  /// In en, this message translates to:
  /// **'Include speaker notes'**
  String get findIncludeNotes;

  /// Find option.
  ///
  /// In en, this message translates to:
  /// **'Include skipped slides'**
  String get findIncludeSkipped;

  /// Find scope label.
  ///
  /// In en, this message translates to:
  /// **'Search in'**
  String get findScope;

  /// Find scope option.
  ///
  /// In en, this message translates to:
  /// **'All slides'**
  String get findScopeAll;

  /// Find scope option.
  ///
  /// In en, this message translates to:
  /// **'Current slide'**
  String get findScopeCurrent;

  /// Find scope option.
  ///
  /// In en, this message translates to:
  /// **'Selected slides'**
  String get findScopeSelected;

  /// Find panel button.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get findButtonPrevious;

  /// Find panel button.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get findButtonNext;

  /// Find error for an invalid regular expression.
  ///
  /// In en, this message translates to:
  /// **'This regular expression is not valid'**
  String get findInvalidRegex;

  /// Toast after Replace all (03 §13).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing was replaced} =1{Replaced 1 instance of “{find}” with “{replace}”} other{Replaced {count} instances of “{find}” with “{replace}”}}'**
  String toastReplacedAll(int count, String find, String replace);

  /// Replace all skipped bodies soft-locked by another person.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 match in text {name} is editing was skipped} other{{count} matches in text {name} is editing were skipped}}'**
  String toastReplaceSkipped(int count, String name);

  /// Replace refused on a body soft-locked by another person.
  ///
  /// In en, this message translates to:
  /// **'{name} is editing this text'**
  String toastFindBodyLocked(String name);
}

class _SlidesLocalizationsDelegate
    extends LocalizationsDelegate<SlidesLocalizations> {
  const _SlidesLocalizationsDelegate();

  @override
  Future<SlidesLocalizations> load(Locale locale) {
    return SynchronousFuture<SlidesLocalizations>(
      lookupSlidesLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SlidesLocalizationsDelegate old) => false;
}

SlidesLocalizations lookupSlidesLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'XA':
            return SlidesLocalizationsEnXa();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SlidesLocalizationsEn();
  }

  throw FlutterError(
    'SlidesLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
