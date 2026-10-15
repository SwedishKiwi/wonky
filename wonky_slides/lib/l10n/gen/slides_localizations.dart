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
