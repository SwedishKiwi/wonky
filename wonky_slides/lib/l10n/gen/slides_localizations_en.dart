// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'slides_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SlidesLocalizationsEn extends SlidesLocalizations {
  SlidesLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get untitledPresentation => 'Untitled presentation';

  @override
  String get editorComingSoonTitle => 'Coming soon';

  @override
  String get editorComingSoonBody =>
      'Wonky Slides is being built. The presentation editor is on its way — your presentations stay safe in Wonky Drive meanwhile.';

  @override
  String get backToSlides => 'Back to Slides';

  @override
  String get deckDownloading => 'Downloading presentation…';

  @override
  String deckOpening(int rows) {
    return 'Opening presentation… ($rows rows)';
  }

  @override
  String get deckNotAvailableOffline =>
      'This presentation isn’t available offline.';

  @override
  String get deckNoAccess => 'You don’t have access to this presentation.';

  @override
  String get deckDownloadFailed => 'This presentation could not be downloaded.';

  @override
  String get deckOpenFailed => 'This presentation could not be opened.';

  @override
  String get deckNotOnDevice => 'This presentation isn’t on this device.';

  @override
  String get deckAccessRemoved =>
      'You no longer have access to this presentation.';

  @override
  String get deckStillOpening => 'The presentation is still opening.';

  @override
  String get screenStorageUnavailable =>
      'The presentation storage on this device didn\'t start. Try again, or reload the page.';

  @override
  String get createNeedsConnectionTitle =>
      'Connect to the internet to create a presentation';

  @override
  String get createNeedsConnectionBody =>
      'This device can create presentations offline once it has been online for a moment.';

  @override
  String get storageLimitedTitle =>
      'Offline storage is limited in this browser';

  @override
  String storageLimitedDescription(String elements) {
    return 'This browser keeps offline presentations in memory. Only about $elements objects stay available offline; the presentations you opened least recently are removed from this device first.';
  }

  @override
  String get recoveryTitle =>
      'Your offline presentation data couldn\'t be opened';

  @override
  String recoveryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count presentations had changes that weren\'t synced yet. Download them before they\'re lost.',
      one:
          '1 presentation had changes that weren\'t synced yet. Download them before they\'re lost.',
    );
    return '$_temp0';
  }

  @override
  String get recoveryDownload => 'Download unsynced changes';

  @override
  String get recoveryFailed => 'The unsynced changes could not be exported';

  @override
  String get cmdFileImportSlides => 'Import slides…';

  @override
  String get cmdFileDownload => 'Download';

  @override
  String get cmdHistoryNameCurrentVersion => 'Name current version';

  @override
  String get cmdHistoryOpen => 'See version history';

  @override
  String get cmdFileSetLanguage => 'Language';

  @override
  String get cmdFilePageSetup => 'Page setup…';

  @override
  String get cmdPrintOpen => 'Print';

  @override
  String get cmdEditPasteSpecial => 'Paste special';

  @override
  String get cmdEditDuplicate => 'Duplicate';

  @override
  String get cmdEditDelete => 'Delete';

  @override
  String get cmdSelectEscape => 'Select none';

  @override
  String get cmdSelectEnterGroup => 'Enter group';

  @override
  String get cmdElementActivate => 'Edit text';

  @override
  String get cmdFindOpen => 'Find';

  @override
  String get cmdFindOpenReplace => 'Find and replace';

  @override
  String get cmdFormatCopyStyle => 'Copy style';

  @override
  String get cmdFormatPasteStyle => 'Paste style';

  @override
  String get cmdPresentFromCurrent => 'Present from current slide';

  @override
  String get cmdPresentFromStart => 'Present from beginning';

  @override
  String get cmdPresentPresenterView => 'Presenter view';

  @override
  String get cmdPresentRehearse => 'Rehearse';

  @override
  String get cmdPresentOpenOnAnotherDevice => 'Open on another device…';

  @override
  String get cmdPresentRemote => 'Use phone as remote';

  @override
  String get cmdPresentFromSlide => 'Present from this slide';

  @override
  String get cmdViewSetMode => 'View mode';

  @override
  String get cmdViewToggleNavigator => 'Navigator';

  @override
  String get cmdViewToggleInspector => 'Inspector';

  @override
  String get cmdViewToggleNotes => 'Speaker notes';

  @override
  String get cmdViewToggleRulers => 'Rulers';

  @override
  String get cmdViewToggleGuides => 'Guides';

  @override
  String get cmdViewToggleCommentPins => 'Comments on canvas';

  @override
  String get cmdViewToggleRemoteCursors => 'Collaborator cursors';

  @override
  String get cmdPresenceJumpTo => 'Jump to collaborator';

  @override
  String get cmdPresenceFollow => 'Follow';

  @override
  String get cmdPresenceUnfollow => 'Stop following';

  @override
  String get cmdPresenceFollowPresenter => 'Follow presenter';

  @override
  String get cmdTextEditAnyway => 'Edit anyway';

  @override
  String actorViaMcp(String name) {
    return 'Claude via MCP ($name)';
  }

  @override
  String actorViaAi(String name) {
    return 'Assistant ($name)';
  }

  @override
  String presenceEditingSlide(int number, String title) {
    return 'Editing slide $number · $title';
  }

  @override
  String presenceViewingSlide(int number, String title) {
    return 'Viewing slide $number · $title';
  }

  @override
  String get presencePresenting => 'Presenting';

  @override
  String get presenceEditingLayouts => 'Editing layouts';

  @override
  String get presenceFollowingYou => 'Following you';

  @override
  String presenceOnSlide(String names) {
    return 'On this slide: $names';
  }

  @override
  String presenceInGroup(String names) {
    return 'In this group: $names';
  }

  @override
  String presenceEditingFlag(String name) {
    return '✎ $name is editing';
  }

  @override
  String presenceEditingFlagMany(String names) {
    return '✎ $names editing';
  }

  @override
  String presenceEditingHover(String name) {
    return '$name is editing this text — double-click to edit anyway';
  }

  @override
  String softLockMessage(String name) {
    return '$name is editing this text.';
  }

  @override
  String softLockNotesMessage(String name) {
    return '$name is editing these notes.';
  }

  @override
  String softLockRaceMessage(String name) {
    return '$name started editing this text first.';
  }

  @override
  String get softLockCancel => 'Cancel';

  @override
  String get softLockEditAnyway => 'Edit anyway';

  @override
  String get softLockStop => 'Stop editing';

  @override
  String get softLockKeep => 'Keep editing';

  @override
  String notesEditingBanner(String name) {
    return '✎ $name is editing the notes';
  }

  @override
  String followBanner(String name) {
    return 'Following $name';
  }

  @override
  String get followStop => 'Stop';

  @override
  String presenterPill(String name) {
    return '$name is presenting';
  }

  @override
  String get presenterFollow => 'Follow';

  @override
  String get toastPresenterNotFound => 'That presentation has ended.';

  @override
  String get cmdViewToggleSmartGuides => 'Smart guides';

  @override
  String get cmdViewToggleSnapObjects => 'Snap to objects';

  @override
  String get cmdViewToggleSnapGuides => 'Snap to guides';

  @override
  String get cmdViewToggleSnapGrid => 'Snap to grid';

  @override
  String get cmdAnimateToggleOrderOverlay => 'Build order';

  @override
  String get cmdMagicMoveToggleMatches => 'Magic Move matches';

  @override
  String get cmdGuidesAdd => 'Add guide';

  @override
  String get cmdGuidesClear => 'Clear guides';

  @override
  String get cmdViewZoomFit => 'Fit';

  @override
  String get cmdViewZoom => 'Zoom';

  @override
  String get cmdViewZoomIn => 'Zoom in';

  @override
  String get cmdViewZoomOut => 'Zoom out';

  @override
  String get cmdViewZoomToSelection => 'Zoom to selection';

  @override
  String get cmdPanelAnimate => 'Animate';

  @override
  String get cmdPanelThemes => 'Themes';

  @override
  String get cmdPanelLayers => 'Layers';

  @override
  String get cmdPanelAccessibility => 'Accessibility';

  @override
  String get cmdPanelLinkedObjects => 'Linked charts';

  @override
  String get cmdModeEditing => 'Editing';

  @override
  String get cmdModeViewing => 'Viewing';

  @override
  String get cmdInspectorOpen => 'Format options…';

  @override
  String get cmdSlideNew => 'New slide';

  @override
  String get cmdSlideDuplicateForMagicMove => 'Magic Move slide';

  @override
  String get cmdInsertTextBox => 'Text box';

  @override
  String get cmdInsertImage => 'Image';

  @override
  String get cmdInsertShape => 'Shape';

  @override
  String get cmdInsertLine => 'Line';

  @override
  String get cmdInsertTable => 'Table';

  @override
  String get cmdInsertCode => 'Code block';

  @override
  String get cmdInsertChartFromSheets => 'Chart from Wonky Sheets…';

  @override
  String get cmdInsertChart => 'Chart';

  @override
  String get cmdInsertIcon => 'Icon…';

  @override
  String get cmdInsertEmoji => 'Emoji…';

  @override
  String get cmdInsertSpecialCharacter => 'Special characters…';

  @override
  String get cmdInsertLink => 'Link';

  @override
  String get cmdDeckOpenNumbering => 'Slide numbers…';

  @override
  String get cmdLayoutInsertPlaceholder => 'Placeholder';

  @override
  String get cmdFormatBold => 'Bold';

  @override
  String get cmdFormatItalic => 'Italic';

  @override
  String get cmdFormatUnderline => 'Underline';

  @override
  String get cmdFormatStrikethrough => 'Strikethrough';

  @override
  String get cmdFormatScript => 'Superscript / subscript';

  @override
  String get cmdFormatIncreaseFontSize => 'Increase font size';

  @override
  String get cmdFormatDecreaseFontSize => 'Decrease font size';

  @override
  String get cmdFormatCaps => 'Capitalization';

  @override
  String get cmdFormatTextStyle => 'Text style';

  @override
  String get cmdFormatFont => 'Font';

  @override
  String get cmdFormatFontSize => 'Font size';

  @override
  String get cmdFormatTextColor => 'Text color';

  @override
  String get cmdFormatHighlight => 'Highlight color';

  @override
  String get cmdFormatAlign => 'Text alignment';

  @override
  String get cmdFormatAnchor => 'Vertical alignment';

  @override
  String get cmdFormatIndent => 'Increase indent';

  @override
  String get cmdFormatOutdent => 'Decrease indent';

  @override
  String get cmdFormatLineHeight => 'Line spacing';

  @override
  String get cmdFormatParagraphSpacing => 'Paragraph spacing…';

  @override
  String get cmdFormatList => 'Lists';

  @override
  String get cmdFormatListStyle => 'List style';

  @override
  String get cmdFormatListStart => 'Restart numbering';

  @override
  String get cmdFormatAutofit => 'Text fitting';

  @override
  String get cmdFormatFill => 'Fill';

  @override
  String get cmdFormatStroke => 'Border';

  @override
  String get cmdFormatEffects => 'Effects';

  @override
  String get cmdFormatOpacity => 'Opacity…';

  @override
  String get cmdImageCrop => 'Crop';

  @override
  String get cmdImageMask => 'Mask with shape';

  @override
  String get cmdImageReplace => 'Replace image';

  @override
  String get cmdImageAdjust => 'Adjustments…';

  @override
  String get cmdImageReset => 'Reset image';

  @override
  String get cmdImageDownloadOriginal => 'Download original';

  @override
  String get cmdTableInsertRow => 'Insert row';

  @override
  String get cmdTableInsertColumn => 'Insert column';

  @override
  String get cmdTableDeleteRows => 'Delete row';

  @override
  String get cmdTableDeleteColumns => 'Delete column';

  @override
  String get cmdTableDelete => 'Delete table';

  @override
  String get cmdTableMergeCells => 'Merge cells';

  @override
  String get cmdTableUnmergeCells => 'Unmerge cells';

  @override
  String get cmdTableDistributeRows => 'Distribute rows';

  @override
  String get cmdTableDistributeColumns => 'Distribute columns';

  @override
  String get cmdTableSetOptions => 'Table options…';

  @override
  String get cmdTableSetCellFill => 'Cell fill';

  @override
  String get cmdTableSetBorders => 'Borders';

  @override
  String get cmdTableSetCellAlign => 'Vertical align';

  @override
  String get cmdShapeChange => 'Change shape';

  @override
  String get cmdShapeApplyQuickStyle => 'Quick styles';

  @override
  String get cmdLineSetArrow => 'Arrows';

  @override
  String get cmdLineSetRouting => 'Routing';

  @override
  String get cmdCodeEdit => 'Edit code';

  @override
  String get cmdCodeSetLanguage => 'Code language';

  @override
  String get cmdCodeUpdateOptions => 'Line numbers';

  @override
  String get cmdCodeSetHighlightSteps => 'Highlight steps…';

  @override
  String get cmdCodeAddState => 'Add state';

  @override
  String get cmdChartUpdate => 'Update chart';

  @override
  String get cmdChartSetAutoUpdate => 'Update automatically';

  @override
  String get cmdChartOpenSource => 'Open source spreadsheet';

  @override
  String get cmdChartUnlink => 'Unlink chart';

  @override
  String get cmdChartCopyAsImage => 'Copy chart as image';

  @override
  String get cmdElementEditAltText => 'Alt text…';

  @override
  String get cmdFormatPaintFormat => 'Paint format';

  @override
  String get cmdFormatClear => 'Clear formatting';

  @override
  String get cmdSlideDuplicate => 'Duplicate slide';

  @override
  String get cmdSlideDelete => 'Delete slide';

  @override
  String get cmdSlideToggleSkip => 'Skip slide';

  @override
  String get cmdSlideMove => 'Move slide';

  @override
  String get cmdSlideApplyLayout => 'Apply layout';

  @override
  String get cmdSlideResetToLayout => 'Reset slide to layout';

  @override
  String get cmdSlideSetBackground => 'Change background…';

  @override
  String get cmdSlideApplyBackgroundToAll => 'Apply background to all slides';

  @override
  String get cmdSlideSetHideMasterElements => 'Hide master objects';

  @override
  String get cmdDeckSetAppearance => 'Presentation appearance';

  @override
  String get cmdGroupCreate => 'Group slides';

  @override
  String get cmdGroupUngroup => 'Ungroup slides';

  @override
  String get cmdGroupAddSlides => 'Add to group';

  @override
  String get cmdGroupRemoveSlides => 'Remove from group';

  @override
  String get cmdGroupStartRename => 'Rename group';

  @override
  String get cmdGroupSetColor => 'Group color';

  @override
  String get cmdGroupToggleSkip => 'Skip group';

  @override
  String get cmdGroupCollapse => 'Collapse group';

  @override
  String get cmdGroupExpand => 'Expand group';

  @override
  String get cmdGroupCollapseAll => 'Collapse all groups';

  @override
  String get cmdGroupExpandAll => 'Expand all groups';

  @override
  String get cmdGroupDuplicate => 'Duplicate group';

  @override
  String get cmdGroupDelete => 'Delete group…';

  @override
  String get cmdGroupSelectSlides => 'Select slides in group';

  @override
  String get cmdAnimatePreview => 'Preview animations';

  @override
  String get cmdAnimateRemoveAll => 'Remove all animations';

  @override
  String get cmdAnimateAddBuild => 'Add animation';

  @override
  String get cmdAnimateCopyBuilds => 'Copy animation';

  @override
  String get cmdAnimatePasteBuilds => 'Paste animation';

  @override
  String get cmdAnimateDeleteBuilds => 'Remove animations';

  @override
  String get cmdThemeEdit => 'Edit theme…';

  @override
  String get cmdNavGoToSlide => 'Go to slide…';

  @override
  String get cmdNavGoToGroup => 'Go to group';

  @override
  String get cmdNavPreviousSlide => 'Previous slide';

  @override
  String get cmdNavNextSlide => 'Next slide';

  @override
  String get cmdArrangeOrder => 'Order';

  @override
  String get cmdArrangeAlign => 'Align objects';

  @override
  String get cmdArrangeDistribute => 'Distribute objects';

  @override
  String get cmdArrangeCenterOnSlide => 'Center on slide';

  @override
  String get cmdArrangeMatchSize => 'Match size';

  @override
  String get cmdArrangeRotate => 'Rotate';

  @override
  String get cmdArrangeFlip => 'Flip';

  @override
  String get cmdArrangeGroup => 'Group';

  @override
  String get cmdArrangeUngroup => 'Ungroup';

  @override
  String get cmdElementToggleLock => 'Lock';

  @override
  String get cmdElementUnlockAll => 'Unlock all on slide';

  @override
  String get cmdElementHide => 'Hide';

  @override
  String get cmdElementShow => 'Show';

  @override
  String get cmdElementSetLink => 'Link…';

  @override
  String get cmdElementRemoveLink => 'Remove link';

  @override
  String get cmdElementResetPlaceholder => 'Reset to layout';

  @override
  String get cmdSpellingCheck => 'Check spelling';

  @override
  String get cmdSpellingToggleUnderline => 'Underline errors';

  @override
  String get cmdToolsAccessibilityCheck => 'Accessibility check';

  @override
  String get cmdNotificationsOpenSettings => 'Notification settings';

  @override
  String get cmdAiGenerateDeck => 'Generate presentation…';

  @override
  String get cmdAiRewrite => 'Rewrite text';

  @override
  String get cmdAiSuggestLayouts => 'Suggest layouts for this slide';

  @override
  String get cmdAiSpeakerNotes => 'Write speaker notes';

  @override
  String get cmdAiAltText => 'Generate alt text';

  @override
  String get cmdAiCodeWalkthrough => 'Make a code walkthrough…';

  @override
  String get cmdToolSelect => 'Select';

  @override
  String get cmdPrefsSet => 'Change a Slides setting';

  @override
  String get cmdPresenterSet => 'Change a presenting setting';

  @override
  String get categoryFile => 'File';

  @override
  String get categoryEdit => 'Common';

  @override
  String get categoryView => 'View';

  @override
  String get categoryInsert => 'Insert';

  @override
  String get categoryFormat => 'Canvas & objects';

  @override
  String get categoryText => 'Text';

  @override
  String get categoryTables => 'Tables';

  @override
  String get categorySlides => 'Slides & groups';

  @override
  String get categoryArrange => 'Arrange';

  @override
  String get categoryCanvas => 'Canvas & objects';

  @override
  String get categoryPresent => 'Present';

  @override
  String get categoryAnimations => 'Animations';

  @override
  String get categoryTools => 'Tools';

  @override
  String get categoryAi => 'AI';

  @override
  String get alignLeft => 'Left';

  @override
  String get alignCenter => 'Center';

  @override
  String get alignRight => 'Right';

  @override
  String get alignJustify => 'Justify';

  @override
  String get anchorTop => 'Top';

  @override
  String get anchorMiddle => 'Middle';

  @override
  String get anchorBottom => 'Bottom';

  @override
  String get animateAddBuildIn => 'Add build in';

  @override
  String get animateAddAction => 'Add action';

  @override
  String get animateAddBuildOut => 'Add build out';

  @override
  String get animateTabTransition => 'Transition';

  @override
  String get animateTabBuild => 'Build';

  @override
  String get animateTabOrder => 'Order';

  @override
  String get animateTransitionEmpty =>
      'Slide transitions arrive here soon: effects, duration and how the slide advances.';

  @override
  String get animateBuildEmpty =>
      'Builds arrive here soon: select an object to animate it in, out or in place.';

  @override
  String get animateOrderEmpty =>
      'The build order of this slide will be listed here.';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get autofitNone => 'Do not autofit';

  @override
  String get autofitShrink => 'Shrink text on overflow';

  @override
  String get autofitResize => 'Resize shape to fit text';

  @override
  String get axisHorizontally => 'Horizontally';

  @override
  String get axisVertically => 'Vertically';

  @override
  String get axisBoth => 'Both';

  @override
  String get backToNormalView => 'Back to Normal view';

  @override
  String get backToPresentation => 'Back to the presentation';

  @override
  String get badgeViewOnly => 'View only';

  @override
  String get badgeCommentOnly => 'Comment only';

  @override
  String get badgeViewing => 'Viewing';

  @override
  String get buildAppear => 'Appear';

  @override
  String get buildFlyIn => 'Fly in';

  @override
  String get buildZoom => 'Zoom';

  @override
  String get canvasChooseLayout => 'Choose a layout';

  @override
  String get canvasEmptyTitle => 'This presentation has no slides';

  @override
  String get canvasEmptyBody =>
      'Add a slide to start, or choose a layout for it.';

  @override
  String canvasSlideSemantics(int number, String title) {
    return 'Slide $number: $title';
  }

  @override
  String get capsUpper => 'UPPERCASE';

  @override
  String get capsSmallCaps => 'Small caps';

  @override
  String get capsTitle => 'Title Case';

  @override
  String get capsNone => 'None';

  @override
  String get chartColumn => 'Column';

  @override
  String get chartBar => 'Bar';

  @override
  String get chartLine => 'Line';

  @override
  String get chartPie => 'Pie';

  @override
  String get chartArea => 'Area';

  @override
  String get chartScatter => 'Scatter';

  @override
  String get chartFromSheets => 'From Wonky Sheets…';

  @override
  String get codeAllLanguages => 'All languages…';

  @override
  String get codeLineNumbers => 'Line numbers';

  @override
  String get codePlainText => 'Plain text';

  @override
  String get codeStates => 'States…';

  @override
  String get colorGray => 'Gray';

  @override
  String get colorRed => 'Red';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorViolet => 'Violet';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorNone => 'None';

  @override
  String get deckLoading => 'Opening presentation…';

  @override
  String deckLoadingProgress(String message, int percent) {
    return '$message $percent %';
  }

  @override
  String get deckUnavailable => 'This presentation isn’t available';

  @override
  String get deckOfflineHint => 'It opens by itself when you’re back online.';

  @override
  String get downloadPdf => 'PDF document (.pdf)';

  @override
  String get downloadPng => 'PNG image (current slide)';

  @override
  String get downloadPngZip => 'PNG images (all slides, .zip)';

  @override
  String get downloadMarkdown => 'Outline as Markdown (.md)';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationSeconds(String seconds) {
    return '$seconds s';
  }

  @override
  String get flipHorizontally => 'Flip horizontally';

  @override
  String get flipVertically => 'Flip vertically';

  @override
  String get goToSlideTitle => 'Go to slide';

  @override
  String get goToSlideLabel => 'Slide';

  @override
  String get goToSlideButton => 'Go';

  @override
  String get groupUntitled => 'Untitled group';

  @override
  String get guidesAddVertical => 'Add vertical guide';

  @override
  String get guidesAddHorizontal => 'Add horizontal guide';

  @override
  String get imageUpload => 'Upload from computer';

  @override
  String get imageFromDrive => 'From Wonky Drive';

  @override
  String get imageByUrl => 'By URL';

  @override
  String get imageFromClipboard => 'From clipboard';

  @override
  String get inspectorLabel => 'Inspector';

  @override
  String get inspectorFormat => 'Format';

  @override
  String get inspectorAnimate => 'Animate';

  @override
  String get inspectorSlide => 'Slide';

  @override
  String get inspectorClose => 'Close inspector';

  @override
  String get inspectorFormatEmpty => 'Select an object to format it';

  @override
  String get inspectorSectionSoon => 'These options are on their way.';

  @override
  String get inspectorCurrentLayout => 'Layout';

  @override
  String get inspectorAppearance => 'Appearance';

  @override
  String get inspectorNotInGroup => 'Not in a group';

  @override
  String get inspectorGroupName => 'Group';

  @override
  String get inspectorSlideNumber => 'Position';

  @override
  String get inspectorSkipped => 'Skipped';

  @override
  String get yes => 'Yes';

  @override
  String get lineLine => 'Line';

  @override
  String get lineArrow => 'Arrow';

  @override
  String get lineDoubleArrow => 'Double arrow';

  @override
  String get lineElbowConnector => 'Elbow connector';

  @override
  String get lineCurvedConnector => 'Curved connector';

  @override
  String get lineStartArrow => 'Start arrow';

  @override
  String get lineEndArrow => 'End arrow';

  @override
  String get listBulleted => 'Bulleted list';

  @override
  String get listNumbered => 'Numbered list';

  @override
  String get listChecklist => 'Checklist';

  @override
  String get listOptions => 'List options…';

  @override
  String get mastersSoonTitle => 'Editing masters and layouts is coming soon';

  @override
  String get mastersSoonBody =>
      'You’ll edit the theme’s masters and layouts here. Your slides are unchanged.';

  @override
  String get menuAddToGroup => 'Add to group';

  @override
  String get menuAi => 'AI';

  @override
  String get menuAlign => 'Align';

  @override
  String get menuAlignIndent => 'Align & indent';

  @override
  String get menuAnimate => 'Animate';

  @override
  String get menuAnimateEllipsis => 'Animate…';

  @override
  String get menuAnimation => 'Animation…';

  @override
  String get menuApplyLayout => 'Apply layout';

  @override
  String get menuArrange => 'Arrange';

  @override
  String get menuBorderEllipsis => 'Border…';

  @override
  String get menuCapitalization => 'Capitalization';

  @override
  String get menuCenterOnSlide => 'Center on slide';

  @override
  String get menuChangeBackground => 'Change background…';

  @override
  String get menuChangeTheme => 'Change theme…';

  @override
  String get menuChart => 'Chart';

  @override
  String get menuChooseGroup => 'Choose a group…';

  @override
  String get menuCode => 'Code';

  @override
  String get menuCodeBlock => 'Code block';

  @override
  String get menuCommentOnSlide => 'Comment on slide';

  @override
  String get menuDistribute => 'Distribute';

  @override
  String get menuDownload => 'Download';

  @override
  String get menuEditLayout => 'Edit layout';

  @override
  String get menuEditMasters => 'Edit masters and layouts';

  @override
  String get menuEffectsEllipsis => 'Effects…';

  @override
  String get menuExtensions => 'Extensions';

  @override
  String get menuFillEllipsis => 'Fill…';

  @override
  String get menuFormat => 'Format';

  @override
  String get menuFormatOptions => 'Format options…';

  @override
  String get menuGroup => 'Group';

  @override
  String get menuGroupColor => 'Color';

  @override
  String get menuGuides => 'Guides';

  @override
  String get menuImage => 'Image';

  @override
  String get menuInsert => 'Insert';

  @override
  String get menuLanguage => 'Language';

  @override
  String get menuLine => 'Line';

  @override
  String get menuLists => 'Bullets & numbering';

  @override
  String get menuMagicMoveId => 'Magic Move ID…';

  @override
  String get menuMatchSize => 'Match size';

  @override
  String get menuMcp => 'MCP';

  @override
  String get menuMoveSlide => 'Move slide';

  @override
  String get menuNewGroup => 'New group';

  @override
  String get menuNewSlideInGroup => 'New slide in group';

  @override
  String get menuNewSlideWithLayout => 'New slide with layout';

  @override
  String get menuOrder => 'Order';

  @override
  String get menuPanels => 'Panels';

  @override
  String get menuPasteSpecial => 'Paste special';

  @override
  String get menuPersonalDictionary => 'Personal dictionary';

  @override
  String get menuPlaceholder => 'Placeholder';

  @override
  String get menuPresent => 'Present';

  @override
  String get menuPresentFromGroup => 'Present from this group';

  @override
  String get menuPresentingSettings => 'Presenting settings…';

  @override
  String get menuRehearsePresentation => 'Rehearse presentation';

  @override
  String get menuRewriteText => 'Rewrite text';

  @override
  String get menuRotate => 'Rotate';

  @override
  String get menuShape => 'Shape';

  @override
  String get menuShapeGallery => 'All shapes…';

  @override
  String get menuShow => 'Show';

  @override
  String get menuSize => 'Size';

  @override
  String get menuSizePosition => 'Size and position…';

  @override
  String get menuSlide => 'Slide';

  @override
  String get menuSnap => 'Snap';

  @override
  String get menuSpacing => 'Line & paragraph spacing';

  @override
  String get menuSpelling => 'Spelling';

  @override
  String get menuTable => 'Table';

  @override
  String get menuText => 'Text';

  @override
  String get menuTextFitting => 'Text fitting';

  @override
  String get menuTextStyle => 'Text style';

  @override
  String get menuTransition => 'Transition…';

  @override
  String get menuVersionHistory => 'Version history';

  @override
  String get menuZoom => 'Zoom';

  @override
  String get moveToBeginning => 'To beginning';

  @override
  String get moveUp => 'Up';

  @override
  String get moveDown => 'Down';

  @override
  String get moveToEnd => 'To end';

  @override
  String get navigatorLabel => 'Slides';

  @override
  String get navigatorEmpty => 'No slides';

  @override
  String get navigatorOpen => 'Show slides';

  @override
  String navigatorGroupSemantics(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slides',
      one: '1 slide',
    );
    return 'Group $title, $_temp0';
  }

  @override
  String navigatorSlideSemantics(int number, int total, String title) {
    return 'Slide $number of $total: $title';
  }

  @override
  String get notesLabel => 'Speaker notes';

  @override
  String get notesPlaceholder => 'Click to add speaker notes';

  @override
  String get orderBringToFront => 'Bring to front';

  @override
  String get orderBringForward => 'Bring forward';

  @override
  String get orderSendBackward => 'Send backward';

  @override
  String get orderSendToBack => 'Send to back';

  @override
  String get outlineNoTitle => '(no title)';

  @override
  String get outlineReadOnlyNote =>
      'Outline view shows each slide’s title and main text. Editing here comes soon.';

  @override
  String get pasteKeepSource => 'Keep source formatting';

  @override
  String get pasteUseDestination => 'Use destination theme';

  @override
  String get pasteChartUnlinked => 'Paste chart unlinked';

  @override
  String get placeholderPicture => 'Picture';

  @override
  String get placeholderObject => 'Object';

  @override
  String get placeholderFooter => 'Footer';

  @override
  String get placeholderSlideNumber => 'Slide number';

  @override
  String get placeholderDate => 'Date';

  @override
  String get presentButton => 'Present';

  @override
  String get presentOptions => 'Presenting options';

  @override
  String get presenterLayoutStandard => 'Current, next and notes';

  @override
  String get presenterLayoutNotes => 'Large notes';

  @override
  String get presenterLayoutNext => 'Large next slide';

  @override
  String get reasonNotAvailableYet => 'Not available yet';

  @override
  String get reasonDeckLoading => 'The presentation is still opening';

  @override
  String get reasonViewAccess => 'You have view access';

  @override
  String get reasonViewingMode => 'You’re in Viewing mode';

  @override
  String get reasonFirstSlide => 'This is the first slide';

  @override
  String get reasonLastSlide => 'This is the last slide';

  @override
  String get reasonNoSlides => 'The presentation has no slides';

  @override
  String get rewriteShorter => 'Shorter';

  @override
  String get rewriteLonger => 'Longer';

  @override
  String get rewriteClearer => 'Clearer';

  @override
  String get rewriteFormal => 'More formal';

  @override
  String get rewriteGrammar => 'Fix grammar';

  @override
  String get rewriteCustom => 'Custom…';

  @override
  String get rotateClockwise => 'Rotate 90° clockwise';

  @override
  String get rotateCounterClockwise => 'Rotate 90° counter-clockwise';

  @override
  String get routePresentTitle => 'Presenting';

  @override
  String get routePrintTitle => 'Print and PDF';

  @override
  String get routeHistoryTitle => 'Version history';

  @override
  String get sectionText => 'Text';

  @override
  String get sectionLine => 'Line';

  @override
  String get sectionImage => 'Image';

  @override
  String get sectionTable => 'Table';

  @override
  String get sectionCell => 'Cell';

  @override
  String get sectionIcon => 'Icon';

  @override
  String get sectionCode => 'Code';

  @override
  String get sectionChart => 'Chart';

  @override
  String get sectionFill => 'Fill';

  @override
  String get sectionBorder => 'Border';

  @override
  String get sectionEffects => 'Effects';

  @override
  String get sectionArrange => 'Arrange';

  @override
  String get sectionLink => 'Link';

  @override
  String get sectionAccessibility => 'Accessibility';

  @override
  String get sectionLayout => 'Layout';

  @override
  String get sectionBackground => 'Background';

  @override
  String get sectionTheme => 'Theme';

  @override
  String get sectionVisibility => 'Visibility';

  @override
  String get sectionGroup => 'Group';

  @override
  String get sectionInfo => 'Info';

  @override
  String get settingsSectionPresentations => 'New presentations';

  @override
  String get settingsSectionEditing => 'Editing';

  @override
  String get settingsSectionAnimations => 'Animations & code';

  @override
  String get settingsSectionPresenting => 'Presenting';

  @override
  String get settingsNewPresentations => 'New presentations';

  @override
  String get settingsNewPresentationsHint =>
      'Used when you create a presentation. Existing presentations keep their own settings.';

  @override
  String get settingsDefaultTheme => 'Theme';

  @override
  String get settingsDefaultAppearance => 'Appearance';

  @override
  String get settingsDefaultSize => 'Slide size';

  @override
  String get settingsDefaultLanguage => 'Language';

  @override
  String get settingsCharts => 'Charts';

  @override
  String get settingsChartsAutoUpdate => 'Update linked charts automatically';

  @override
  String get settingsChartsAutoUpdateHint =>
      'New charts from Wonky Sheets follow their spreadsheet.';

  @override
  String get settingsEditing => 'Editing';

  @override
  String get settingsUnits => 'Units';

  @override
  String get settingsScrollChangesSlides => 'Scroll to change slides';

  @override
  String get settingsSmartQuotes => 'Smart quotes';

  @override
  String get settingsAutoformatLists => 'Automatically format lists';

  @override
  String get settingsShowRemoteCursors => 'Show collaborator cursors';

  @override
  String get settingsSpelling => 'Spelling';

  @override
  String get settingsUnderlineSpelling => 'Underline spelling errors';

  @override
  String get settingsAnimations => 'Animations';

  @override
  String get settingsDefaultTransition => 'Default transition';

  @override
  String get settingsTransitionDuration => 'Transition duration';

  @override
  String get settingsDefaultBuild => 'Default build';

  @override
  String get settingsPreviewOnHover => 'Preview animations on hover';

  @override
  String get settingsReduceEditorMotion => 'Reduce motion in the editor';

  @override
  String get settingsReduceEditorMotionHint =>
      'Previews show the end state instead of playing.';

  @override
  String get settingsCode => 'Code';

  @override
  String get settingsCodeFontSize => 'Code font size';

  @override
  String get settingsCodeLanguage => 'Default code language';

  @override
  String get settingsTypingSpeed => 'Type-in speed';

  @override
  String get settingsTypeInSound => 'Type-in click sound';

  @override
  String get settingsPresenting => 'Presenting';

  @override
  String get settingsPresentingHint =>
      'How you present. The audience view follows the presentation.';

  @override
  String get settingsPresenterLayout => 'Presenter view layout';

  @override
  String get settingsNotesSize => 'Notes text size';

  @override
  String get settingsTimerMode => 'Timer';

  @override
  String get settingsTimerTarget => 'Countdown length';

  @override
  String get settingsLaserColor => 'Laser pointer color';

  @override
  String get settingsStartFullscreen => 'Start presenting in full screen';

  @override
  String get settingsStartWithPresenterView => 'Start with presenter view';

  @override
  String get settingsShowSkippedInPresenter =>
      'Show skipped slides in presenter view';

  @override
  String get sizeWidescreen16x9 => 'Widescreen 16:9';

  @override
  String get sizeStandard4x3 => 'Standard 4:3';

  @override
  String get sizeWide16x10 => 'Widescreen 16:10';

  @override
  String get sizeSquare => 'Square 1:1';

  @override
  String get sizePortrait9x16 => 'Portrait 9:16';

  @override
  String get sizeA4 => 'A4 landscape';

  @override
  String get sizeLetter => 'Letter landscape';

  @override
  String get sizeWidth => 'Width';

  @override
  String get sizeHeight => 'Height';

  @override
  String get slideUntitled => 'Untitled slide';

  @override
  String get spacingSingle => 'Single';

  @override
  String get spacingDouble => 'Double';

  @override
  String get spacingCustom => 'Custom…';

  @override
  String get spacingAddBefore => 'Add space before paragraph';

  @override
  String get spacingAddAfter => 'Add space after paragraph';

  @override
  String get speedSlow => 'Slow';

  @override
  String get speedNormal => 'Normal';

  @override
  String get speedFast => 'Fast';

  @override
  String get statusNoSlides => 'No slides';

  @override
  String statusSlideOf(int number, int total) {
    return 'Slide $number of $total';
  }

  @override
  String statusSkipped(int count) {
    return '$count skipped';
  }

  @override
  String get styleTitle => 'Title';

  @override
  String get styleSubtitle => 'Subtitle';

  @override
  String get styleHeading => 'Heading';

  @override
  String get styleBody => 'Body';

  @override
  String get styleBody2 => 'Body 2';

  @override
  String get styleCaption => 'Caption';

  @override
  String get styleQuote => 'Quote';

  @override
  String get styleAttribution => 'Attribution';

  @override
  String get styleBigNumber => 'Big number';

  @override
  String get styleLabel => 'Label';

  @override
  String get tableInsertRowAbove => 'Insert row above';

  @override
  String get tableInsertRowBelow => 'Insert row below';

  @override
  String get tableInsertColumnLeft => 'Insert column left';

  @override
  String get tableInsertColumnRight => 'Insert column right';

  @override
  String get textSuperscript => 'Superscript';

  @override
  String get textSubscript => 'Subscript';

  @override
  String get timerElapsed => 'Elapsed time';

  @override
  String get timerCountdown => 'Countdown';

  @override
  String get toolbarLabel => 'Slides toolbar';

  @override
  String get toolbarUndo => 'Undo';

  @override
  String get toolbarRedo => 'Redo';

  @override
  String toolbarUndoLabel(String label) {
    return 'Undo $label';
  }

  @override
  String toolbarRedoLabel(String label) {
    return 'Redo $label';
  }

  @override
  String get toolbarZoom => 'Zoom';

  @override
  String get toolbarAddComment => 'Add comment';

  @override
  String get toolbarAlign => 'Align';

  @override
  String get toolbarAnimate => 'Animate';

  @override
  String get toolbarBackground => 'Background';

  @override
  String get toolbarLayout => 'Layout';

  @override
  String get toolbarTheme => 'Theme';

  @override
  String get toolbarTransition => 'Transition';

  @override
  String get transitionNone => 'None';

  @override
  String get transitionFade => 'Fade';

  @override
  String get transitionPush => 'Push';

  @override
  String get transitionWipe => 'Wipe';

  @override
  String get transitionDissolve => 'Dissolve';

  @override
  String get unitsSu => 'Slide units';

  @override
  String get unitsPx => 'Pixels';

  @override
  String get unitsIn => 'Inches';

  @override
  String get unitsCm => 'Centimeters';

  @override
  String get viewNormal => 'Normal';

  @override
  String get viewGrid => 'Grid';

  @override
  String get viewOutline => 'Outline';

  @override
  String get zoomFit => 'Fit';

  @override
  String zoomPercent(int percent) {
    return '$percent %';
  }

  @override
  String get toastUndoPartial =>
      'Some changes weren’t undone because a collaborator changed them since';

  @override
  String get cmdSelectElements => 'Select objects';

  @override
  String get cmdSelectNext => 'Select next object';

  @override
  String get cmdSelectPrevious => 'Select previous object';

  @override
  String get cmdElementMove => 'Move';

  @override
  String get cmdElementResize => 'Resize';

  @override
  String get cmdElementNudge => 'Nudge';

  @override
  String get cmdElementAdjust => 'Adjust shape';

  @override
  String get cmdElementSetLineEnds => 'Move line end';

  @override
  String get cmdElementLock => 'Lock';

  @override
  String get cmdElementUnlock => 'Unlock';

  @override
  String get cmdGuidesMove => 'Move guide';

  @override
  String get cmdGuidesDelete => 'Delete guide';

  @override
  String get undoRotate => 'Rotate';

  @override
  String get undoFlip => 'Flip';

  @override
  String get reasonSelectObject => 'Select an object';

  @override
  String get reasonSelectTwoObjects => 'Select at least 2 objects';

  @override
  String get reasonSelectThreeObjects => 'Select at least 3 objects';

  @override
  String get reasonObjectLocked => 'Unlock the object first';

  @override
  String get reasonInsideGroup => 'Not available for objects inside a group';

  @override
  String get reasonSelectGroup => 'Select a group';

  @override
  String get reasonNoLockedObjects => 'No locked objects on this slide';

  @override
  String get reasonNoGuides => 'There are no guides';

  @override
  String get reasonNotOnCanvas => 'Not available for this object';

  @override
  String get elementKindText => 'Text box';

  @override
  String get elementKindShape => 'Shape';

  @override
  String get elementKindLine => 'Line';

  @override
  String get elementKindImage => 'Image';

  @override
  String get elementKindTable => 'Table';

  @override
  String get elementKindCode => 'Code';

  @override
  String get elementKindChart => 'Chart';

  @override
  String get elementKindIcon => 'Icon';

  @override
  String get elementKindGroup => 'Group';

  @override
  String get elementKindPlaceholder => 'Placeholder';

  @override
  String canvasAnnounceSelected(String name, int index, int count) {
    return '$name selected, $index of $count objects';
  }

  @override
  String canvasAnnounceSelectedMany(int count) {
    return '$count objects selected';
  }

  @override
  String canvasAnnounceMoved(int x, int y) {
    return 'Moved to x $x, y $y';
  }

  @override
  String canvasElementSemantics(String name, String state) {
    return '$name, $state';
  }

  @override
  String get canvasStateSelected => 'selected';

  @override
  String get canvasStateLocked => 'locked';

  @override
  String canvasDimensions(int width, int height) {
    return '$width × $height';
  }

  @override
  String canvasPosition(int x, int y) {
    return '$x, $y';
  }

  @override
  String canvasAngle(int degrees) {
    return '$degrees°';
  }

  @override
  String get cmdPrintPrint => 'Print PDF';

  @override
  String get printPreviewTitle => 'Print preview';

  @override
  String printPreviewTitleWithName(String name) {
    return 'Print preview — $name';
  }

  @override
  String get printBack => 'Back to the presentation';

  @override
  String get printDownloadPdf => 'Download PDF';

  @override
  String get printPrint => 'Print';

  @override
  String get printSettings => 'Settings';

  @override
  String get printShowPreview => 'Show preview';

  @override
  String printPageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get printUpdatingPreview => 'Updating preview…';

  @override
  String get printLoadingDeck => 'Loading presentation…';

  @override
  String get printPreviewFailed => 'The preview could not be created';

  @override
  String get printTryAgain => 'Try again';

  @override
  String get printDownloadsDisabledTitle => 'Downloads are turned off';

  @override
  String get printDownloadsDisabledBody =>
      'The owner has turned off downloading and printing for viewers and commenters.';

  @override
  String get printUnavailableTitle => 'Printing isn\'t available here';

  @override
  String get printUnavailableBody =>
      'Download the PDF and print it from your PDF viewer.';

  @override
  String get printPdfPreviewLabel => 'PDF preview';

  @override
  String get printPdfReady => 'The PDF is ready';

  @override
  String printPdfReadyPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The PDF is ready: $count pages',
      one: 'The PDF is ready: 1 page',
    );
    return '$_temp0';
  }

  @override
  String get printPdfDesktopHint => 'Download the PDF to view or print it.';

  @override
  String get printLayout => 'Layout';

  @override
  String get printLayoutSlides => 'Slides';

  @override
  String get printLayoutNotes => 'Notes pages';

  @override
  String get printLayoutHandouts => 'Handouts';

  @override
  String get printPerPage => 'Slides per page';

  @override
  String get printOrder => 'Order';

  @override
  String get printOrderHorizontal => 'Across, then down';

  @override
  String get printOrderVertical => 'Down, then across';

  @override
  String get printRange => 'Slides to print';

  @override
  String get printRangeAll => 'All slides';

  @override
  String get printRangeCurrent => 'Current slide';

  @override
  String get printRangeSelection => 'Selected slides';

  @override
  String get printRangeCustom => 'Custom range';

  @override
  String get printRangeHint => 'e.g. 1-3, 7';

  @override
  String get printRangeInvalid => 'Enter slide numbers like 1-3, 7';

  @override
  String get printPaper => 'Paper';

  @override
  String get printPaperSlide => 'Slide size';

  @override
  String get printPaperLetter => 'Letter';

  @override
  String get printPaperLegal => 'Legal';

  @override
  String get printPaperTabloid => 'Tabloid';

  @override
  String get printOrientation => 'Orientation';

  @override
  String get printOrientationAuto => 'Automatic';

  @override
  String get printOrientationPortrait => 'Portrait';

  @override
  String get printOrientationLandscape => 'Landscape';

  @override
  String get printMargins => 'Margins';

  @override
  String get printMarginsNone => 'None';

  @override
  String get printMarginsNarrow => 'Narrow';

  @override
  String get printMarginsNormal => 'Normal';

  @override
  String get printBuilds => 'Print each build stage';

  @override
  String get printSkipped => 'Include skipped slides';

  @override
  String get printFrame => 'Frame slides';

  @override
  String get printHeaderFooter => 'Header and footer';

  @override
  String get printSlideNumbers => 'Slide numbers';

  @override
  String get printBookmarks => 'Bookmarks for sections and slides';

  @override
  String get printLinks => 'Clickable links';

  @override
  String get printInkSaver => 'Ink saver (no slide backgrounds)';

  @override
  String get printQuality => 'Image quality';

  @override
  String get printQualityHigh => 'High';

  @override
  String get printQualityCompact => 'Compact (smaller file)';

  @override
  String get printWarnings => 'About this PDF';

  @override
  String get printWarningFonts =>
      'A font could not be embedded; a standard font was used.';

  @override
  String get printWarningGlyphs =>
      'Some characters have no glyph in the embedded fonts.';

  @override
  String get printWarningIcons => 'Some icons could not be drawn.';

  @override
  String get printWarningImages => 'Some images could not be loaded.';

  @override
  String get printWarningLinks =>
      'Links to slides that are not printed were removed.';

  @override
  String get printWarningPages => 'Only the first 500 pages were exported.';

  @override
  String get printWarningEmpty => 'No slides match these settings.';

  @override
  String exportedToast(String name) {
    return 'Exported “$name”';
  }

  @override
  String get exportFailed => 'The export failed';

  @override
  String get exportFormatUnavailable => 'This format is not available yet';

  @override
  String pdfSlide(int number) {
    return 'Slide $number';
  }

  @override
  String pdfNotesContinued(int number) {
    return 'Notes (continued) — Slide $number';
  }

  @override
  String pdfPageOf(int page, int count) {
    return 'Page $page of $count';
  }

  @override
  String get pdfUntitledSection => 'Untitled section';

  @override
  String get pdfUntitledPresentation => 'Untitled presentation';

  @override
  String get cmdGroupRename => 'Rename group';

  @override
  String get cmdGroupMove => 'Move group';

  @override
  String get cmdGroupToggleCollapsed => 'Collapse or expand group';

  @override
  String get cmdNavSelectAllSlides => 'Select all slides';

  @override
  String get cmdNavigatorCopy => 'Copy slides';

  @override
  String get cmdNavigatorCut => 'Cut slides';

  @override
  String get cmdNavigatorPaste => 'Paste slides';

  @override
  String get cmdNotesZoom => 'Speaker notes zoom';

  @override
  String cmdSlideDeleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count slides',
      one: 'Delete slide',
    );
    return '$_temp0';
  }

  @override
  String cmdSlideDuplicateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Duplicate $count slides',
      one: 'Duplicate slide',
    );
    return '$_temp0';
  }

  @override
  String get cmdEditNotes => 'Edit speaker notes';

  @override
  String get reasonSelectSlides => 'Select slides in the navigator';

  @override
  String get reasonAlreadyGroup => 'These slides are already a group';

  @override
  String get reasonSkippedWithGroup => 'Skipped with group';

  @override
  String get reasonNotInGroup => 'The slide isn’t in a group';

  @override
  String get reasonNoGroups => 'The presentation has no groups';

  @override
  String get reasonGroupsCantNest => 'Groups can’t be nested';

  @override
  String get reasonCantMoveFurther => 'The slides can’t move further';

  @override
  String get reasonClipboardNoSlides => 'Copy slides or groups first';

  @override
  String get reasonAllCollapsed => 'The group is already collapsed';

  @override
  String get reasonAllExpanded => 'The group is already expanded';

  @override
  String get navigatorDropHere => 'Drop slides here';

  @override
  String get navigatorNewSlideLayout => 'New slide with layout';

  @override
  String navigatorDragSlides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slides',
      one: '1 slide',
    );
    return '$_temp0';
  }

  @override
  String navigatorDragGroup(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slides',
      one: '1 slide',
    );
    return '$title · $_temp0';
  }

  @override
  String get navigatorGroupExpanded => 'expanded';

  @override
  String get navigatorGroupCollapsed => 'collapsed';

  @override
  String get navigatorSkipped => 'skipped';

  @override
  String navigatorSlideInGroupSemantics(
    int number,
    int total,
    String group,
    String title,
  ) {
    return 'Slide $number of $total, in group $group: $title';
  }

  @override
  String get navigatorGroupMenu => 'Group actions';

  @override
  String get navigatorSlideMenu => 'Slide actions';

  @override
  String get navigatorCollapseGroup => 'Collapse group (Alt+click: all groups)';

  @override
  String get navigatorExpandGroup => 'Expand group (Alt+click: all groups)';

  @override
  String get navigatorGroupColor => 'Group color';

  @override
  String get navigatorRenameField => 'Group name';

  @override
  String get navigatorSkippedWithGroup => 'Skipped with group';

  @override
  String deleteGroupTitle(String title) {
    return 'Delete group ‘$title’?';
  }

  @override
  String deleteGroupBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The group contains $count slides.',
      one: 'The group contains 1 slide.',
    );
    return '$_temp0';
  }

  @override
  String deleteGroupsTitle(int count) {
    return 'Delete $count groups?';
  }

  @override
  String get deleteGroupUngroupOnly => 'Ungroup only';

  @override
  String deleteGroupWithSlides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete group and $count slides',
      one: 'Delete group and 1 slide',
    );
    return '$_temp0';
  }

  @override
  String get toastGroupDeleted => 'Group deleted';

  @override
  String get chooseGroupTitle => 'Add to group';

  @override
  String get chooseGroupLabel => 'Group';

  @override
  String get chooseGroupButton => 'Add';

  @override
  String get gridThumbSize => 'Thumbnail size';

  @override
  String get gridOpenHint => 'Double-click a slide to open it';

  @override
  String get notesBold => 'Bold';

  @override
  String get notesItalic => 'Italic';

  @override
  String get notesUnderline => 'Underline';

  @override
  String get notesBulletList => 'Bulleted list';

  @override
  String get notesNumberedList => 'Numbered list';

  @override
  String get notesLink => 'Link';

  @override
  String get notesLinkTitle => 'Link';

  @override
  String get notesLinkUrl => 'URL';

  @override
  String get notesLinkApply => 'Apply';

  @override
  String get notesLinkRemove => 'Remove link';

  @override
  String get notesLinkInvalid => 'Enter an http or https address';

  @override
  String get notesReadOnly => 'View only';

  @override
  String get notesNoSlide => 'No slide selected';

  @override
  String get undoTyping => 'Typing';

  @override
  String get dialogApply => 'Apply';

  @override
  String get linkDialogTitle => 'Link';

  @override
  String get linkTargetLabel => 'Link to';

  @override
  String get linkTargetUrl => 'Web address';

  @override
  String get linkUrlLabel => 'Address';

  @override
  String get linkRemove => 'Remove link';

  @override
  String get linkActionNext => 'Next slide';

  @override
  String get linkActionPrevious => 'Previous slide';

  @override
  String get linkActionFirst => 'First slide';

  @override
  String get linkActionLast => 'Last slide';

  @override
  String get linkActionEnd => 'End show';

  @override
  String get fontLabel => 'Font';

  @override
  String get fontSizeLabel => 'Size';

  @override
  String get colorLabel =>
      'Color (#RRGGBB or theme:accent1; empty = automatic)';

  @override
  String get lineHeightLabel => 'Line spacing';

  @override
  String get listStyleLabel => 'Style';

  @override
  String get listStartLabel => 'Start numbering at';

  @override
  String get fontThemeHeading => 'Theme heading font';

  @override
  String get fontThemeBody => 'Theme body font';

  @override
  String get fontThemeMono => 'Theme monospace font';

  @override
  String get listStyleDisc => 'Disc';

  @override
  String get listStyleCircle => 'Circle';

  @override
  String get listStyleSquare => 'Square';

  @override
  String get listStyleDash => 'Dash';

  @override
  String get listStyleArrow => 'Arrow';

  @override
  String get listStyleCheck => 'Check mark';

  @override
  String get listStyleStar => 'Star';

  @override
  String get listStyleNone => 'No bullet';

  @override
  String get cmdFormatLetterSpacing => 'Letter spacing';

  @override
  String get cmdFormatInsets => 'Text insets';

  @override
  String get cmdTextExitEditing => 'Exit text editing';

  @override
  String get cmdTextRemoveLink => 'Remove link from text';

  @override
  String get reasonNotEditingText => 'No text is being edited';

  @override
  String get reasonSelectText => 'Select text or a text box';

  @override
  String get reasonSelectTextOrObject => 'Select text or an object';

  @override
  String get reasonNoLink => 'The selection has no link';

  @override
  String get reasonSelectPlaceholder => 'Select a placeholder';

  @override
  String toastSkippedLocked(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skipped $count text boxes others are editing',
      one: 'Skipped 1 text box $name is editing',
    );
    return '$_temp0';
  }

  @override
  String validationNumberRange(String min, String max) {
    return 'Enter a number from $min to $max';
  }

  @override
  String slideNumberLabel(int number) {
    return 'Slide $number';
  }

  @override
  String get themeColorBg1 => 'Background 1';

  @override
  String get themeColorBg2 => 'Background 2';

  @override
  String get themeColorText1 => 'Text 1';

  @override
  String get themeColorText2 => 'Text 2';

  @override
  String themeColorAccent(int n) {
    return 'Accent $n';
  }

  @override
  String get themeColorLink => 'Link';

  @override
  String shapeName(String geometry) {
    String _temp0 = intl.Intl.selectLogic(geometry, {
      'rect': 'Rectangle',
      'roundRect': 'Rounded rectangle',
      'ellipse': 'Ellipse',
      'triangle': 'Triangle',
      'rightTriangle': 'Right triangle',
      'diamond': 'Diamond',
      'pentagon': 'Pentagon',
      'hexagon': 'Hexagon',
      'octagon': 'Octagon',
      'parallelogram': 'Parallelogram',
      'trapezoid': 'Trapezoid',
      'donut': 'Donut',
      'arc': 'Arc',
      'blockArc': 'Block arc',
      'pie': 'Pie',
      'chord': 'Chord',
      'frame': 'Frame',
      'halfFrame': 'Half frame',
      'plus': 'Plus',
      'cross': 'Cross',
      'cylinder': 'Cylinder',
      'cube': 'Cube',
      'can': 'Can',
      'heart': 'Heart',
      'cloud': 'Cloud',
      'moon': 'Moon',
      'sun': 'Sun',
      'lightning': 'Lightning bolt',
      'arrowRight': 'Right arrow',
      'arrowLeft': 'Left arrow',
      'arrowUp': 'Up arrow',
      'arrowDown': 'Down arrow',
      'arrowLeftRight': 'Left-right arrow',
      'arrowUpDown': 'Up-down arrow',
      'chevron': 'Chevron',
      'homePlate': 'Pentagon arrow',
      'notchedArrow': 'Notched arrow',
      'curvedArrow': 'Curved arrow',
      'circularArrow': 'Circular arrow',
      'uTurn': 'U-turn arrow',
      'star4': '4-point star',
      'star5': '5-point star',
      'star6': '6-point star',
      'star8': '8-point star',
      'star12': '12-point star',
      'burst': 'Burst',
      'ribbon': 'Ribbon',
      'wave': 'Wave',
      'seal': 'Seal',
      'speech': 'Speech bubble',
      'speechRound': 'Round speech bubble',
      'thought': 'Thought bubble',
      'calloutRect': 'Rectangular callout',
      'calloutLine': 'Line callout',
      'banner': 'Banner',
      'process': 'Process',
      'decision': 'Decision',
      'terminator': 'Terminator',
      'document': 'Document',
      'data': 'Data',
      'manualInput': 'Manual input',
      'predefinedProcess': 'Predefined process',
      'connector': 'Connector',
      'offPage': 'Off-page connector',
      'delay': 'Delay',
      'storage': 'Stored data',
      'brace': 'Brace',
      'bracket': 'Bracket',
      'doubleBrace': 'Double brace',
      'custom': 'Custom shape',
      'other': 'Shape',
    });
    return '$_temp0';
  }

  @override
  String shapeCategory(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'basic': 'Basic shapes',
      'arrows': 'Arrows',
      'stars': 'Stars and badges',
      'callouts': 'Callouts',
      'flowchart': 'Flowchart',
      'brackets': 'Brackets',
      'custom': 'Custom',
      'other': 'Shapes',
    });
    return '$_temp0';
  }

  @override
  String iconCategory(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'all': 'All icons',
      'recent': 'Recently used',
      'arrows': 'Arrows',
      'business': 'Business',
      'charts': 'Charts',
      'communication': 'Communication',
      'devices': 'Devices',
      'development': 'Development',
      'files': 'Files',
      'food': 'Food and drink',
      'media': 'Media',
      'nature': 'Nature',
      'people': 'People',
      'security': 'Security',
      'shapes': 'Shapes',
      'text': 'Text',
      'clock': 'Time',
      'tools': 'Tools',
      'travel': 'Travel',
      'weather': 'Weather',
      'other': 'Icons',
    });
    return '$_temp0';
  }

  @override
  String arrowStyleName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'none': 'None',
      'triangle': 'Arrow',
      'open': 'Open arrow',
      'stealth': 'Stealth arrow',
      'circle': 'Circle',
      'diamond': 'Diamond',
      'bar': 'Bar',
      'other': 'Arrow',
    });
    return '$_temp0';
  }

  @override
  String arrowSizeName(String size) {
    String _temp0 = intl.Intl.selectLogic(size, {
      's': 'Small',
      'm': 'Medium',
      'l': 'Large',
      'other': 'Medium',
    });
    return '$_temp0';
  }

  @override
  String dashName(String dash) {
    String _temp0 = intl.Intl.selectLogic(dash, {
      'solid': 'Solid',
      'dash': 'Dashed',
      'dot': 'Dotted',
      'dashDot': 'Dash-dot',
      'longDash': 'Long dash',
      'other': 'Solid',
    });
    return '$_temp0';
  }

  @override
  String capName(String cap) {
    String _temp0 = intl.Intl.selectLogic(cap, {
      'butt': 'Flat',
      'round': 'Round',
      'square': 'Square',
      'other': 'Flat',
    });
    return '$_temp0';
  }

  @override
  String routingName(String routing) {
    String _temp0 = intl.Intl.selectLogic(routing, {
      'straight': 'Straight',
      'elbow': 'Elbow',
      'curved': 'Curved',
      'other': 'Straight',
    });
    return '$_temp0';
  }

  @override
  String quickStyleName(String index) {
    String _temp0 = intl.Intl.selectLogic(index, {
      '0': 'Accent 1',
      '1': 'Accent 2',
      '2': 'Accent 3',
      '3': 'Accent 4',
      '4': 'Accent 5',
      '5': 'Accent 6',
      '6': 'Outline',
      '7': 'Soft tint',
      'other': 'Style',
    });
    return '$_temp0';
  }

  @override
  String strokeWidthLabel(String width) {
    return '$width pt';
  }

  @override
  String get cmdIconReplace => 'Replace icon…';

  @override
  String get cmdIconSetStrokeWidth => 'Icon stroke width';

  @override
  String get cmdElementRename => 'Rename object';

  @override
  String get menuChangeShape => 'Change shape';

  @override
  String get menuQuickStyles => 'Quick styles';

  @override
  String get menuRouting => 'Routing';

  @override
  String get menuWeight => 'Weight';

  @override
  String get menuDash => 'Dash';

  @override
  String get menuBorderColor => 'Border color';

  @override
  String get menuLineColor => 'Line color';

  @override
  String get menuFillColor => 'Fill color';

  @override
  String get menuIconColor => 'Icon color';

  @override
  String get colorThemeDefault => 'Theme default';

  @override
  String get styleLabelColor => 'Color';

  @override
  String get styleLabelWeight => 'Weight';

  @override
  String get styleLabelDash => 'Dash';

  @override
  String get styleLabelCap => 'Ends';

  @override
  String get styleLabelArrowSize => 'Arrow size';

  @override
  String get styleLabelRouting => 'Routing';

  @override
  String get styleLabelShadow => 'Shadow';

  @override
  String get styleLabelGlow => 'Glow';

  @override
  String get styleLabelOpacity => 'Opacity';

  @override
  String get styleLabelNoFill => 'No fill';

  @override
  String get styleLabelNoBorder => 'No border';

  @override
  String get styleLabelGeometry => 'Shape';

  @override
  String get styleLabelStrokeWidth => 'Stroke width';

  @override
  String get styleLabelIcon => 'Icon';

  @override
  String get styleMixed => 'Mixed';

  @override
  String get arrangeLabelX => 'X';

  @override
  String get arrangeLabelY => 'Y';

  @override
  String get arrangeLabelW => 'W';

  @override
  String get arrangeLabelH => 'H';

  @override
  String get arrangeLabelRotation => 'Rotation';

  @override
  String get arrangeLabelName => 'Name';

  @override
  String get arrangeEditInsideGroup => 'Edit inside group';

  @override
  String get arrangeLocked => 'Locked';

  @override
  String get accessibilityAltText => 'Alt text';

  @override
  String get accessibilityAltTextHint =>
      'Describe the object for people using screen readers';

  @override
  String get accessibilityDecorative => 'Decorative';

  @override
  String accessibilityReadingOrder(int position, int count) {
    return 'Reading order: $position of $count';
  }

  @override
  String get altTextDialogTitle => 'Alt text';

  @override
  String get altTextDialogDecorative =>
      'Mark as decorative (screen readers skip it)';

  @override
  String get dialogSave => 'Save';

  @override
  String get iconPickerTitle => 'Insert icon';

  @override
  String get iconPickerReplaceTitle => 'Replace icon';

  @override
  String get iconPickerSearch => 'Search icons';

  @override
  String iconPickerEmpty(String query) {
    return 'No icons match “$query”';
  }

  @override
  String iconPickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count icons',
      one: '1 icon',
    );
    return '$_temp0';
  }

  @override
  String get iconPickerRecentEmpty => 'Icons you insert show up here';

  @override
  String get iconPickerStroke => 'Stroke';

  @override
  String get iconPickerColor => 'Color';

  @override
  String get iconPickerCategory => 'Category';

  @override
  String get iconPickerInsert => 'Insert';

  @override
  String get iconPickerReplace => 'Replace';

  @override
  String get shapeGalleryTitle => 'Shapes';

  @override
  String get shapeGalleryChoose => 'Choose';

  @override
  String get reasonSelectShape => 'Select a shape';

  @override
  String get reasonSelectLine => 'Select a line';

  @override
  String get reasonSelectIcon => 'Select an icon';

  @override
  String get reasonSelectOneObject => 'Select one object';

  @override
  String get reasonNoFill => 'Select a shape, text box or icon';

  @override
  String get reasonNoBorder => 'Select a shape, line, text box, image or icon';

  @override
  String get reasonPlaceholdersCantGroup => 'Placeholders can\'t be grouped';

  @override
  String get reasonSameLevel => 'Select objects in the same group';

  @override
  String get reasonNoStyleCopied => 'Copy a style first';

  @override
  String get painterArmed => 'Click an object to apply the format';

  @override
  String get toolArmedShape => 'Click or drag on the slide to insert the shape';

  @override
  String get toolArmedLine => 'Drag on the slide to draw the line';

  @override
  String get colorAutomatic => 'Automatic';

  @override
  String get inspectorMixed => 'Mixed';

  @override
  String get spacingBeforeLabel => 'Space before';

  @override
  String get spacingAfterLabel => 'Space after';

  @override
  String get reasonSelectImage => 'Select an image';

  @override
  String get reasonNoDownload =>
      'Downloading isn\'t allowed for this presentation';

  @override
  String get reasonSelectTable => 'Select a table';

  @override
  String get reasonSelectCells => 'Select table cells';

  @override
  String get reasonNoMergedCells => 'No merged cells in the selection';

  @override
  String get undoCropImage => 'Crop image';

  @override
  String get cmdImageCropApply => 'Apply crop';

  @override
  String get cmdImageCropCancel => 'Cancel crop';

  @override
  String get cmdImageRetryUpload => 'Retry upload';

  @override
  String get cmdImageRemoveNotUploaded => 'Remove image';

  @override
  String get cmdTableResizeAxes => 'Resize rows or columns';

  @override
  String get cmdTableSetCellPadding => 'Cell padding';

  @override
  String get cmdTableClearCells => 'Clear cells';

  @override
  String get cmdTableSelectCells => 'Select cells';

  @override
  String get cmdTableMoveSelection => 'Move cell selection';

  @override
  String get cmdTableNextCell => 'Next cell';

  @override
  String get cmdTablePreviousCell => 'Previous cell';

  @override
  String get cmdTableEditCell => 'Edit cell';

  @override
  String get cmdTableClearCellSelection => 'Select the whole table';

  @override
  String get imageNotAvailable => 'This image isn\'t available right now.';

  @override
  String get imagePickTitle => 'Choose images';

  @override
  String get imageClipboardEmpty => 'There\'s no image on the clipboard.';

  @override
  String get imageUrlInvalid => 'Enter an https:// image address.';

  @override
  String get imageFetchFailed => 'Couldn\'t load this image.';

  @override
  String get imageOutOfStorage => 'You\'re out of storage.';

  @override
  String imageRejectedTooLarge(String name) {
    return 'Couldn\'t insert \'$name\' — images can be at most 50 MB.';
  }

  @override
  String imageRejectedFormat(String name) {
    return 'Couldn\'t insert \'$name\' — this image type isn\'t supported.';
  }

  @override
  String get imageInsertDialogTitle => 'Insert image';

  @override
  String get imageReplaceDialogTitle => 'Replace image';

  @override
  String get imageSourceLabel => 'Source';

  @override
  String get dialogContinue => 'Continue';

  @override
  String get dialogInsert => 'Insert';

  @override
  String get dialogCancel => 'Cancel';

  @override
  String get imageUrlDialogTitle => 'Insert image by URL';

  @override
  String get imageUrlDialogBody =>
      'The image is fetched through Wonky Work and stored with the presentation.';

  @override
  String get imageUrlLabel => 'Image address';

  @override
  String get imageMaskDialogTitle => 'Mask with shape';

  @override
  String get imageMaskShape => 'Shape';

  @override
  String get imageMaskNone => 'No mask';

  @override
  String get imageDriveDialogTitle => 'Insert image from Wonky Drive';

  @override
  String get imageDriveSearch => 'Search images';

  @override
  String get imageDriveImage => 'Image';

  @override
  String get imageDriveFailed =>
      'Couldn\'t load your images. Check your connection.';

  @override
  String get imageDriveEmpty => 'No images found.';

  @override
  String get cropAspectFree => 'Free';

  @override
  String get cropAspectOriginal => 'Original';

  @override
  String get cropFill => 'Fill';

  @override
  String get cropFit => 'Fit';

  @override
  String get cropDone => 'Done';

  @override
  String get imageNotUploadedOutOfStorage => 'Not uploaded — out of storage';

  @override
  String get imageRetry => 'Retry';

  @override
  String get imageRemove => 'Remove';

  @override
  String tableSizeInvalid(int max) {
    return 'Enter a number from 1 to $max.';
  }

  @override
  String get tableInsertDialogTitle => 'Insert table';

  @override
  String get tableRows => 'Rows';

  @override
  String get tableColumns => 'Columns';

  @override
  String get cmdThemeApply => 'Apply theme';

  @override
  String get cmdThemeImport => 'Import theme from a presentation…';

  @override
  String get cmdThemeRename => 'Rename theme…';

  @override
  String get cmdThemeDuplicate => 'Duplicate theme';

  @override
  String get cmdThemeSetDefault => 'Set as default theme';

  @override
  String get cmdThemeDelete => 'Remove theme';

  @override
  String get cmdThemeRemoveUnused => 'Remove unused themes';

  @override
  String get cmdDeckSetSize => 'Change slide size';

  @override
  String get cmdDeckSetNumbering => 'Set slide numbers and footer';

  @override
  String get undoChangeSlideSize => 'Change slide size';

  @override
  String get undoNumbering => 'Slide numbers and footer';

  @override
  String get reasonThemeInUse =>
      'Used by slides — apply another theme to them first';

  @override
  String get reasonThemeIsDefault => 'Already the default theme';

  @override
  String get reasonNoUnusedThemes => 'Every theme is in use';

  @override
  String get themesPanelTitle => 'Themes';

  @override
  String get themesApplyTo => 'Apply to';

  @override
  String get themesApplyAll => 'All slides';

  @override
  String themesApplySelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Selected slides ($count)',
      one: 'Selected slide',
    );
    return '$_temp0';
  }

  @override
  String get themesInPresentation => 'In this presentation';

  @override
  String get themesBuiltIn => 'Built-in themes';

  @override
  String get themesImport => 'Import theme from a presentation…';

  @override
  String get themesDefault => 'Default';

  @override
  String themesUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Used by $count slides',
      one: 'Used by 1 slide',
      zero: 'Not used',
    );
    return '$_temp0';
  }

  @override
  String themesMore(String name) {
    return 'More actions for $name';
  }

  @override
  String get themeUntitled => 'Untitled theme';

  @override
  String get themePreviewSubtitle => 'Title and subtitle';

  @override
  String themeCopyName(String name) {
    return '$name copy';
  }

  @override
  String get themeRenameTitle => 'Rename theme';

  @override
  String get themeNameLabel => 'Name';

  @override
  String get themeNameEmpty => 'Enter a name';

  @override
  String get themeRenameButton => 'Rename';

  @override
  String get themeImportPickTitle => 'Import theme from a presentation';

  @override
  String get themeImportSearch => 'Search presentations';

  @override
  String get themeImportPresentation => 'Presentation';

  @override
  String get themeImportNoPresentations => 'No other presentations';

  @override
  String get themeImportOffline => 'Connect to the internet to import a theme';

  @override
  String get themeImportChooseTitle => 'Choose a theme';

  @override
  String themeImportOption(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slides',
      one: '1 slide',
      zero: 'not used',
    );
    return '$name — $_temp0';
  }

  @override
  String get themeImportButton => 'Import';

  @override
  String themeImported(String name) {
    return 'Theme “$name” added';
  }

  @override
  String get themeApplyToAll => 'Apply to all slides';

  @override
  String get backgroundResetToLayout => 'Reset to layout background';

  @override
  String get pageSetupTitle => 'Page setup';

  @override
  String get pageSetupPreset => 'Slide size';

  @override
  String get pageSetupUnit => 'Unit';

  @override
  String get pageSetupContent => 'Existing content';

  @override
  String get pageSetupScale => 'Scale content to fit';

  @override
  String get pageSetupDontScale => 'Don\'t scale';

  @override
  String get pageSetupPreview => 'Preview';

  @override
  String get pageSetupApply => 'Apply';

  @override
  String get pageSetupEnterSize => 'Enter a width and a height.';

  @override
  String get pageSetupSideRange =>
      'Each side must be between 320 and 7,680 su.';

  @override
  String get pageSetupAspectRange =>
      'The aspect ratio must be between 1:4 and 4:1.';

  @override
  String get sizeCustom => 'Custom';

  @override
  String get numberingTitle => 'Slide numbers and footer';

  @override
  String get numberingShow => 'Show slide numbers';

  @override
  String get numberingFirst => 'First slide number';

  @override
  String get numberingFirstInvalid => 'Enter a number from 0 to 9999';

  @override
  String get numberingHideOnTitle => 'Don\'t show on title slides';

  @override
  String get numberingFooter => 'Footer';

  @override
  String get numberingFooterHint => 'Empty = no footer';

  @override
  String get imageUploading => 'Uploading…';

  @override
  String get imageAdjustments => 'Adjustments';

  @override
  String get imageBrightness => 'Brightness';

  @override
  String get imageContrast => 'Contrast';

  @override
  String get imageSaturation => 'Saturation';

  @override
  String get imageTemperature => 'Temperature';

  @override
  String get imageBlur => 'Blur';

  @override
  String get imageGrayscale => 'Grayscale';

  @override
  String get imageSepia => 'Sepia';

  @override
  String get imageInvert => 'Invert';

  @override
  String get tableStyle => 'Style';

  @override
  String get tableStyleTheme => 'Theme';

  @override
  String get tableStyleNone => 'None';

  @override
  String get tableHeaderRow => 'Header row';

  @override
  String get tableFirstColumn => 'First column';

  @override
  String get tableBandedRows => 'Banded rows';

  @override
  String get tableBandedColumns => 'Banded columns';

  @override
  String get tableTotalRow => 'Total row';

  @override
  String tableCellsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cells selected',
      one: '1 cell selected',
    );
    return '$_temp0';
  }

  @override
  String get tableCellFill => 'Fill';

  @override
  String get tableStyleFill => 'Table style';

  @override
  String get tableVerticalAlign => 'Align';

  @override
  String get tableCellPadding => 'Padding';

  @override
  String get tableStyleDefault => 'Default';

  @override
  String get tableBorders => 'Borders';

  @override
  String tableBorderEdge(String edge) {
    String _temp0 = intl.Intl.selectLogic(edge, {
      'all': 'All borders',
      'outer': 'Outer borders',
      'inner': 'Inner borders',
      'horizontal': 'Inner horizontal borders',
      'vertical': 'Inner vertical borders',
      'top': 'Top border',
      'bottom': 'Bottom border',
      'left': 'Left border',
      'right': 'Right border',
      'none': 'Clear borders',
      'other': 'Borders',
    });
    return '$_temp0';
  }

  @override
  String tableBorderStyle(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'solid': 'Solid',
      'dashed': 'Dashed',
      'dotted': 'Dotted',
      'other': 'Solid',
    });
    return '$_temp0';
  }

  @override
  String get cmdPresentEnd => 'End presentation';

  @override
  String get cmdPresentNext => 'Next';

  @override
  String get cmdPresentPrevious => 'Previous';

  @override
  String get cmdPresentNextSlide => 'Next slide';

  @override
  String get cmdPresentPreviousSlide => 'Previous slide';

  @override
  String get cmdPresentGoTo => 'Go to slide';

  @override
  String get cmdPresentFirst => 'First slide';

  @override
  String get cmdPresentLast => 'Last slide';

  @override
  String get cmdPresentBlank => 'Black or white screen';

  @override
  String get cmdPresentPicker => 'Slide picker';

  @override
  String get cmdPresentTool => 'Pointer tool';

  @override
  String get cmdPresentClearInk => 'Clear ink on this slide';

  @override
  String get cmdPresentUndoInk => 'Undo last ink stroke';

  @override
  String get cmdPresentTimer => 'Presenter timer';

  @override
  String get cmdPresentJoinAsAudience => 'Show audience view here';

  @override
  String get cmdPresentToggleFullscreen => 'Full screen';

  @override
  String get cmdPresentToggleSkipped => 'Show skipped slides';

  @override
  String get cmdPresentNotesSize => 'Speaker notes size';

  @override
  String get cmdPresentHelp => 'Keyboard shortcuts';

  @override
  String get cmdDeckSetPresentSettings => 'Presentation settings';

  @override
  String get reasonNotPresenting => 'Not presenting';

  @override
  String get reasonPresenterViewOnly => 'Only in the presenter view';

  @override
  String get presentUnknownSlide => 'That slide isn’t in this presentation';

  @override
  String presentSlideLabel(int number, int total) {
    return 'Slide $number of $total';
  }

  @override
  String get presentEndScreen => 'End of presentation — click to exit';

  @override
  String get presentCatchingUp => 'Catching up…';

  @override
  String get presentToolbarLabel => 'Presentation controls';

  @override
  String presentCounterLabel(int number, int total) {
    return 'Slide $number of $total. Open the slide picker';
  }

  @override
  String get presentToolLaser => 'Laser pointer';

  @override
  String get presentToolPen => 'Pen';

  @override
  String get presentToolHighlighter => 'Highlighter';

  @override
  String get presentToolEraser => 'Eraser';

  @override
  String get presentBlackScreen => 'Black screen';

  @override
  String get presentWhiteScreen => 'White screen';

  @override
  String get presentEnd => 'End';

  @override
  String presentGoToNumber(String number) {
    return 'Go to $number';
  }

  @override
  String get presentHelpTitle => 'Presenting shortcuts';

  @override
  String get presentHelpGoToNumber => 'Go to slide number';

  @override
  String get presentHelpDigits => '1 2 3 … Enter';

  @override
  String get presentHelpTemporaryLaser => 'Laser while held (move the mouse)';

  @override
  String get presentTimerPause => 'Pause or resume the timer';

  @override
  String get presentTimerResume => 'Resume the timer';

  @override
  String get presentTimerReset => 'Reset the timer';

  @override
  String get presentNotesLarger => 'Larger notes';

  @override
  String get presentNotesSmaller => 'Smaller notes';

  @override
  String get presentResume => 'Resume (clicker F5)';

  @override
  String get presentFullscreenHint => 'Press F11 (⌃⌘F on Mac) for full screen';

  @override
  String get presentFullscreenButton => 'Full screen';

  @override
  String get presentAudienceTitle => 'Audience view';

  @override
  String get presentAudienceBody =>
      'This screen shows the slides of your presentation.';

  @override
  String presentAudienceBodyFrom(String device) {
    return 'This screen shows the slides you present on $device.';
  }

  @override
  String get presentAudienceKeys =>
      'A clicker or the arrow keys here also move the presentation.';

  @override
  String get presentAudienceStay => 'Stay in window';

  @override
  String get presentGoToSlideMenu => 'Go to slide…';

  @override
  String get presentPickerTitle => 'Go to slide';

  @override
  String get presentPickerFilter => 'Filter by title or number';

  @override
  String get presentPickerClose => 'Close';

  @override
  String get presentPickerNoMatch => 'No slides match';

  @override
  String presentPickerGroup(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slides',
      one: '1 slide',
    );
    return '$title, $_temp0';
  }

  @override
  String presentPickerSlide(int number, String title) {
    return 'Slide $number: $title';
  }

  @override
  String get presentPickerSkipped => 'Skipped';

  @override
  String get presentOpenOnDeviceTitle => 'Open on another device';

  @override
  String get presentOpenOnDeviceBody =>
      'Open this link on the computer or browser that shows the slides — for example the one connected to the projector. Sign in with your account there.';

  @override
  String get presentOpenOnDeviceHint =>
      'Or open this presentation there and choose “Show audience view here”.';

  @override
  String get presentAudienceLink => 'Audience link';

  @override
  String get presentCopyLink => 'Copy link';

  @override
  String get presentLinkCopied => 'Copied';

  @override
  String get presentDone => 'Done';

  @override
  String get presentQrLabel => 'QR code of the audience link';

  @override
  String get presentOfflineNoDevices => 'Offline — other devices can’t join';

  @override
  String get presentOfflineNoDevicesBody =>
      'You can keep presenting here. Other devices join once you’re back online.';

  @override
  String get presentConnecting => 'Connecting…';

  @override
  String get presentSessionEnded => 'Not connected to other devices';

  @override
  String presentAudienceDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other devices',
      one: '1 other device',
      zero: 'No other devices yet',
    );
    return '$_temp0';
  }

  @override
  String get presentPresenterAway => 'Waiting for the presenter…';

  @override
  String get presentWaitingForPresenter => 'Waiting for the presenter';

  @override
  String get presentAudienceEndedToast => 'The presentation ended';

  @override
  String get presentAudienceNotFound => 'This presentation isn’t running';

  @override
  String get presentAudienceNotFoundBody =>
      'Ask the presenter for a new link, or open the presentation and choose “Show audience view here”.';

  @override
  String get presentAudienceNoAccess =>
      'Only the presenter can show this audience view';

  @override
  String get presentTakeOverTitle => 'Take over the presentation?';

  @override
  String get presentTakeOverBody =>
      'You’re presenting this in another window. Take over the presentation from your other window?';

  @override
  String get presentTakeOver => 'Take over';

  @override
  String get presentTakeOverCancel => 'Present here only';

  @override
  String get presentTakenOverToast =>
      'Your presentation continues in another window';

  @override
  String get presentExtendedHintTitle => 'Showing the slides on a projector?';

  @override
  String get presentExtendedHintBody =>
      'Open this presentation in a window there and choose “Show audience view here” — or use “Open on another device…”.';

  @override
  String get presenterViewTitle => 'Presenter view';

  @override
  String presenterViewTitleWithName(String name) {
    return 'Presenter view — $name';
  }

  @override
  String get presenterOtherDevice => 'Other device…';

  @override
  String get presenterCurrent => 'Current slide';

  @override
  String presenterCurrentStep(int step, int count) {
    return 'Current slide · step $step of $count';
  }

  @override
  String get presenterAudienceBlack => 'Audience: black screen';

  @override
  String get presenterAudienceWhite => 'Audience: white screen';

  @override
  String get presenterShowSlide => 'Show slide';

  @override
  String presenterNextBuild(int step, int count) {
    return 'Next: build $step of $count';
  }

  @override
  String presenterNextSlide(String title) {
    return 'Next slide: $title';
  }

  @override
  String get presenterNextSlideUntitled => 'Next slide';

  @override
  String get presenterNextEnd => 'End of presentation';

  @override
  String get presenterNextExit => 'Next: exit';

  @override
  String get presenterNotes => 'Speaker notes';

  @override
  String get presenterNoNotes => 'No speaker notes for this slide';

  @override
  String presenterElapsed(String time) {
    return 'Elapsed $time';
  }

  @override
  String presenterRemaining(String time) {
    return 'Remaining $time';
  }

  @override
  String presenterSlideOf(int number, int total) {
    return 'Slide $number / $total';
  }

  @override
  String presenterAhead(String time) {
    return '$time ahead';
  }

  @override
  String presenterBehind(String time) {
    return '$time behind';
  }

  @override
  String get presenterStrip => 'Slides';

  @override
  String presentBannerTitle(String device) {
    return 'You’re presenting on $device';
  }

  @override
  String get presentBannerTitleNoDevice =>
      'You’re presenting this presentation';

  @override
  String get presentBannerDismiss => 'Dismiss';

  @override
  String get cmdEditCopy => 'Copy';

  @override
  String get cmdEditCut => 'Cut';

  @override
  String get cmdEditPaste => 'Paste';

  @override
  String get reasonCopyNotAllowed => 'The owner turned off copying for viewers';

  @override
  String get reasonPasteObjectsOnSlide => 'Paste objects on a slide';

  @override
  String get reasonPasteSlidesNotInCells =>
      'Paste slides in the slide navigator';

  @override
  String get toastClipboardEmpty => 'There is nothing to paste';

  @override
  String get toastPasteClipped =>
      'Only the cells that fit in the table were pasted';

  @override
  String get toastPasteTruncated =>
      'Only the first 50 rows and 20 columns were pasted';

  @override
  String get pasteChartLinked => 'Linked to the spreadsheet';

  @override
  String get pasteOptionsLabel => 'Paste options';

  @override
  String get cmdFindNext => 'Find next';

  @override
  String get cmdFindPrevious => 'Find previous';

  @override
  String get cmdFindReplace => 'Replace';

  @override
  String get cmdFindReplaceAll => 'Replace all';

  @override
  String get undoReplaceAll => 'Replace all';

  @override
  String get findClose => 'Close find';

  @override
  String get findPlaceholder => 'Find in presentation';

  @override
  String get findNoResults => 'No results';

  @override
  String findOfCount(int current, int total) {
    return '$current of $total';
  }

  @override
  String findMatchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches',
      one: '1 match',
    );
    return '$_temp0';
  }

  @override
  String get findReplaceTitle => 'Find and replace';

  @override
  String get findLabel => 'Find';

  @override
  String get replaceLabel => 'Replace with';

  @override
  String get findMatchCase => 'Match case';

  @override
  String get findWholeWords => 'Whole words';

  @override
  String get findUseRegex => 'Use regular expressions';

  @override
  String get findIncludeNotes => 'Include speaker notes';

  @override
  String get findIncludeSkipped => 'Include skipped slides';

  @override
  String get findScope => 'Search in';

  @override
  String get findScopeAll => 'All slides';

  @override
  String get findScopeCurrent => 'Current slide';

  @override
  String get findScopeSelected => 'Selected slides';

  @override
  String get findButtonPrevious => 'Previous';

  @override
  String get findButtonNext => 'Next';

  @override
  String get findInvalidRegex => 'This regular expression is not valid';

  @override
  String toastReplacedAll(int count, String find, String replace) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Replaced $count instances of “$find” with “$replace”',
      one: 'Replaced 1 instance of “$find” with “$replace”',
      zero: 'Nothing was replaced',
    );
    return '$_temp0';
  }

  @override
  String toastReplaceSkipped(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches in text $name is editing were skipped',
      one: '1 match in text $name is editing was skipped',
    );
    return '$_temp0';
  }

  @override
  String toastFindBodyLocked(String name) {
    return '$name is editing this text';
  }
}

/// The translations for English (`en_XA`).
class SlidesLocalizationsEnXa extends SlidesLocalizationsEn {
  SlidesLocalizationsEnXa() : super('en_XA');

  @override
  String get untitledPresentation => '[Ûñţîţļéð þŕéšéñţåţîöñ one two]';

  @override
  String get editorComingSoonTitle => '[Çöɱîñĝ šööñ one]';

  @override
  String get editorComingSoonBody =>
      '[Ŵöñķý Šļîðéš îš ƀéîñĝ ƀûîļţ. Ţĥé þŕéšéñţåţîöñ éðîţöŕ îš öñ îţš ŵåý — ýöûŕ þŕéšéñţåţîöñš šţåý šåƒé îñ Ŵöñķý Ðŕîṽé ɱéåñŵĥîļé. one two three four five six seven eig]';

  @override
  String get backToSlides => '[Ɓåçķ ţö Šļîðéš one t]';

  @override
  String get deckDownloading => '[Ðöŵñļöåðîñĝ þŕéšéñţåţîöñ… one two t]';

  @override
  String deckOpening(int rows) {
    return '[Öþéñîñĝ þŕéšéñţåţîöñ… ($rows ŕöŵš) one two th]';
  }

  @override
  String get deckNotAvailableOffline =>
      '[Ţĥîš þŕéšéñţåţîöñ îšñ’ţ åṽåîļåƀļé öƒƒļîñé. one two three]';

  @override
  String get deckNoAccess =>
      '[Ýöû ðöñ’ţ ĥåṽé åççéšš ţö ţĥîš þŕéšéñţåţîöñ. one two three]';

  @override
  String get deckDownloadFailed =>
      '[Ţĥîš þŕéšéñţåţîöñ çöûļð ñöţ ƀé ðöŵñļöåðéð. one two three]';

  @override
  String get deckOpenFailed =>
      '[Ţĥîš þŕéšéñţåţîöñ çöûļð ñöţ ƀé öþéñéð. one two thre]';

  @override
  String get deckNotOnDevice =>
      '[Ţĥîš þŕéšéñţåţîöñ îšñ’ţ öñ ţĥîš ðéṽîçé. one two thre]';

  @override
  String get deckAccessRemoved =>
      '[Ýöû ñö ļöñĝéŕ ĥåṽé åççéšš ţö ţĥîš þŕéšéñţåţîöñ. one two three]';

  @override
  String get deckStillOpening =>
      '[Ţĥé þŕéšéñţåţîöñ îš šţîļļ öþéñîñĝ. one two thr]';

  @override
  String get screenStorageUnavailable =>
      '[Ţĥé þŕéšéñţåţîöñ šţöŕåĝé öñ ţĥîš ðéṽîçé ðîðñ\'ţ šţåŕţ. Ţŕý åĝåîñ, öŕ ŕéļöåð ţĥé þåĝé. one two three four five s]';

  @override
  String get createNeedsConnectionTitle =>
      '[Çöññéçţ ţö ţĥé îñţéŕñéţ ţö çŕéåţé å þŕéšéñţåţîöñ one two three f]';

  @override
  String get createNeedsConnectionBody =>
      '[Ţĥîš ðéṽîçé çåñ çŕéåţé þŕéšéñţåţîöñš öƒƒļîñé öñçé îţ ĥåš ƀééñ öñļîñé ƒöŕ å ɱöɱéñţ. one two three four five s]';

  @override
  String get storageLimitedTitle =>
      '[Öƒƒļîñé šţöŕåĝé îš ļîɱîţéð îñ ţĥîš ƀŕöŵšéŕ one two three]';

  @override
  String storageLimitedDescription(String elements) {
    return '[Ţĥîš ƀŕöŵšéŕ ķééþš öƒƒļîñé þŕéšéñţåţîöñš îñ ɱéɱöŕý. Öñļý åƀöûţ $elements öƀĵéçţš šţåý åṽåîļåƀļé öƒƒļîñé; ţĥé þŕéšéñţåţîöñš ýöû öþéñéð ļéåšţ ŕéçéñţļý åŕé ŕéɱöṽéð ƒŕöɱ ţĥîš ðéṽîçé ƒîŕšţ. one two three four five six seven eight nine ten one]';
  }

  @override
  String get recoveryTitle =>
      '[Ýöûŕ öƒƒļîñé þŕéšéñţåţîöñ ðåţå çöûļðñ\'ţ ƀé öþéñéð one two three fo]';

  @override
  String recoveryDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count þŕéšéñţåţîöñš ĥåð çĥåñĝéš ţĥåţ ŵéŕéñ\'ţ šýñçéð ýéţ. Ðöŵñļöåð ţĥéɱ ƀéƒöŕé ţĥéý\'ŕé ļöšţ.',
      one:
          '1 þŕéšéñţåţîöñ ĥåð çĥåñĝéš ţĥåţ ŵéŕéñ\'ţ šýñçéð ýéţ. Ðöŵñļöåð ţĥéɱ ƀéƒöŕé ţĥéý\'ŕé ļöšţ.',
    );
    return '[$_temp0 one two three four five six seven eight nine ten one]';
  }

  @override
  String get recoveryDownload => '[Ðöŵñļöåð ûñšýñçéð çĥåñĝéš one two t]';

  @override
  String get recoveryFailed =>
      '[Ţĥé ûñšýñçéð çĥåñĝéš çöûļð ñöţ ƀé éẋþöŕţéð one two three]';

  @override
  String get cmdFileImportSlides => '[Îɱþöŕţ šļîðéš… one t]';

  @override
  String get cmdFileDownload => '[Ðöŵñļöåð one]';

  @override
  String get cmdHistoryNameCurrentVersion => '[Ñåɱé çûŕŕéñţ ṽéŕšîöñ one two]';

  @override
  String get cmdHistoryOpen => '[Šéé ṽéŕšîöñ ĥîšţöŕý one tw]';

  @override
  String get cmdFileSetLanguage => '[Ļåñĝûåĝé one]';

  @override
  String get cmdFilePageSetup => '[Þåĝé šéţûþ… one]';

  @override
  String get cmdPrintOpen => '[Þŕîñţ on]';

  @override
  String get cmdEditPasteSpecial => '[Þåšţé šþéçîåļ one t]';

  @override
  String get cmdEditDuplicate => '[Ðûþļîçåţé one]';

  @override
  String get cmdEditDelete => '[Ðéļéţé one]';

  @override
  String get cmdSelectEscape => '[Šéļéçţ ñöñé one]';

  @override
  String get cmdSelectEnterGroup => '[Éñţéŕ ĝŕöûþ one]';

  @override
  String get cmdElementActivate => '[Éðîţ ţéẋţ one]';

  @override
  String get cmdFindOpen => '[Ƒîñð on]';

  @override
  String get cmdFindOpenReplace => '[Ƒîñð åñð ŕéþļåçé one t]';

  @override
  String get cmdFormatCopyStyle => '[Çöþý šţýļé one]';

  @override
  String get cmdFormatPasteStyle => '[Þåšţé šţýļé one]';

  @override
  String get cmdPresentFromCurrent => '[Þŕéšéñţ ƒŕöɱ çûŕŕéñţ šļîðé one two t]';

  @override
  String get cmdPresentFromStart => '[Þŕéšéñţ ƒŕöɱ ƀéĝîññîñĝ one two]';

  @override
  String get cmdPresentPresenterView => '[Þŕéšéñţéŕ ṽîéŵ one t]';

  @override
  String get cmdPresentRehearse => '[Ŕéĥéåŕšé one]';

  @override
  String get cmdPresentOpenOnAnotherDevice =>
      '[Öþéñ öñ åñöţĥéŕ ðéṽîçé… one two]';

  @override
  String get cmdPresentRemote => '[Ûšé þĥöñé åš ŕéɱöţé one tw]';

  @override
  String get cmdPresentFromSlide => '[Þŕéšéñţ ƒŕöɱ ţĥîš šļîðé one two]';

  @override
  String get cmdViewSetMode => '[Ṽîéŵ ɱöðé one]';

  @override
  String get cmdViewToggleNavigator => '[Ñåṽîĝåţöŕ one]';

  @override
  String get cmdViewToggleInspector => '[Îñšþéçţöŕ one]';

  @override
  String get cmdViewToggleNotes => '[Šþéåķéŕ ñöţéš one t]';

  @override
  String get cmdViewToggleRulers => '[Ŕûļéŕš one]';

  @override
  String get cmdViewToggleGuides => '[Ĝûîðéš one]';

  @override
  String get cmdViewToggleCommentPins => '[Çöɱɱéñţš öñ çåñṽåš one tw]';

  @override
  String get cmdViewToggleRemoteCursors => '[Çöļļåƀöŕåţöŕ çûŕšöŕš one two]';

  @override
  String get cmdPresenceJumpTo => '[Ĵûɱþ ţö çöļļåƀöŕåţöŕ one two]';

  @override
  String get cmdPresenceFollow => '[Ƒöļļöŵ one]';

  @override
  String get cmdPresenceUnfollow => '[Šţöþ ƒöļļöŵîñĝ one t]';

  @override
  String get cmdPresenceFollowPresenter => '[Ƒöļļöŵ þŕéšéñţéŕ one tw]';

  @override
  String get cmdTextEditAnyway => '[Éðîţ åñýŵåý one]';

  @override
  String actorViaMcp(String name) {
    return '[Çļåûðé ṽîå ṀÇÞ ($name) one t]';
  }

  @override
  String actorViaAi(String name) {
    return '[Åššîšţåñţ ($name) one]';
  }

  @override
  String presenceEditingSlide(int number, String title) {
    return '[Éðîţîñĝ šļîðé $number · $title one t]';
  }

  @override
  String presenceViewingSlide(int number, String title) {
    return '[Ṽîéŵîñĝ šļîðé $number · $title one t]';
  }

  @override
  String get presencePresenting => '[Þŕéšéñţîñĝ one]';

  @override
  String get presenceEditingLayouts => '[Éðîţîñĝ ļåýöûţš one t]';

  @override
  String get presenceFollowingYou => '[Ƒöļļöŵîñĝ ýöû one t]';

  @override
  String presenceOnSlide(String names) {
    return '[Öñ ţĥîš šļîðé: $names one t]';
  }

  @override
  String presenceInGroup(String names) {
    return '[Îñ ţĥîš ĝŕöûþ: $names one t]';
  }

  @override
  String presenceEditingFlag(String name) {
    return '[✎ $name îš éðîţîñĝ one]';
  }

  @override
  String presenceEditingFlagMany(String names) {
    return '[✎ $names éðîţîñĝ one]';
  }

  @override
  String presenceEditingHover(String name) {
    return '[$name îš éðîţîñĝ ţĥîš ţéẋţ — ðöûƀļé-çļîçķ ţö éðîţ åñýŵåý one two three f]';
  }

  @override
  String softLockMessage(String name) {
    return '[$name îš éðîţîñĝ ţĥîš ţéẋţ. one two]';
  }

  @override
  String softLockNotesMessage(String name) {
    return '[$name îš éðîţîñĝ ţĥéšé ñöţéš. one two]';
  }

  @override
  String softLockRaceMessage(String name) {
    return '[$name šţåŕţéð éðîţîñĝ ţĥîš ţéẋţ ƒîŕšţ. one two th]';
  }

  @override
  String get softLockCancel => '[Çåñçéļ one]';

  @override
  String get softLockEditAnyway => '[Éðîţ åñýŵåý one]';

  @override
  String get softLockStop => '[Šţöþ éðîţîñĝ one]';

  @override
  String get softLockKeep => '[Ķééþ éðîţîñĝ one]';

  @override
  String notesEditingBanner(String name) {
    return '[✎ $name îš éðîţîñĝ ţĥé ñöţéš one two]';
  }

  @override
  String followBanner(String name) {
    return '[Ƒöļļöŵîñĝ $name one]';
  }

  @override
  String get followStop => '[Šţöþ on]';

  @override
  String presenterPill(String name) {
    return '[$name îš þŕéšéñţîñĝ one t]';
  }

  @override
  String get presenterFollow => '[Ƒöļļöŵ one]';

  @override
  String get toastPresenterNotFound =>
      '[Ţĥåţ þŕéšéñţåţîöñ ĥåš éñðéð. one two t]';

  @override
  String get cmdViewToggleSmartGuides => '[Šɱåŕţ ĝûîðéš one]';

  @override
  String get cmdViewToggleSnapObjects => '[Šñåþ ţö öƀĵéçţš one t]';

  @override
  String get cmdViewToggleSnapGuides => '[Šñåþ ţö ĝûîðéš one t]';

  @override
  String get cmdViewToggleSnapGrid => '[Šñåþ ţö ĝŕîð one]';

  @override
  String get cmdAnimateToggleOrderOverlay => '[Ɓûîļð öŕðéŕ one]';

  @override
  String get cmdMagicMoveToggleMatches => '[Ṁåĝîç Ṁöṽé ɱåţçĥéš one tw]';

  @override
  String get cmdGuidesAdd => '[Åðð ĝûîðé one]';

  @override
  String get cmdGuidesClear => '[Çļéåŕ ĝûîðéš one]';

  @override
  String get cmdViewZoomFit => '[Ƒîţ on]';

  @override
  String get cmdViewZoom => '[Žööɱ on]';

  @override
  String get cmdViewZoomIn => '[Žööɱ îñ one]';

  @override
  String get cmdViewZoomOut => '[Žööɱ öûţ one]';

  @override
  String get cmdViewZoomToSelection => '[Žööɱ ţö šéļéçţîöñ one tw]';

  @override
  String get cmdPanelAnimate => '[Åñîɱåţé one]';

  @override
  String get cmdPanelThemes => '[Ţĥéɱéš one]';

  @override
  String get cmdPanelLayers => '[Ļåýéŕš one]';

  @override
  String get cmdPanelAccessibility => '[Åççéššîƀîļîţý one t]';

  @override
  String get cmdPanelLinkedObjects => '[Ļîñķéð çĥåŕţš one t]';

  @override
  String get cmdModeEditing => '[Éðîţîñĝ one]';

  @override
  String get cmdModeViewing => '[Ṽîéŵîñĝ one]';

  @override
  String get cmdInspectorOpen => '[Ƒöŕɱåţ öþţîöñš… one t]';

  @override
  String get cmdSlideNew => '[Ñéŵ šļîðé one]';

  @override
  String get cmdSlideDuplicateForMagicMove => '[Ṁåĝîç Ṁöṽé šļîðé one t]';

  @override
  String get cmdInsertTextBox => '[Ţéẋţ ƀöẋ one]';

  @override
  String get cmdInsertImage => '[Îɱåĝé on]';

  @override
  String get cmdInsertShape => '[Šĥåþé on]';

  @override
  String get cmdInsertLine => '[Ļîñé on]';

  @override
  String get cmdInsertTable => '[Ţåƀļé on]';

  @override
  String get cmdInsertCode => '[Çöðé ƀļöçķ one]';

  @override
  String get cmdInsertChartFromSheets => '[Çĥåŕţ ƒŕöɱ Ŵöñķý Šĥééţš… one two]';

  @override
  String get cmdInsertChart => '[Çĥåŕţ on]';

  @override
  String get cmdInsertIcon => '[Îçöñ… on]';

  @override
  String get cmdInsertEmoji => '[Éɱöĵî… one]';

  @override
  String get cmdInsertSpecialCharacter => '[Šþéçîåļ çĥåŕåçţéŕš… one two]';

  @override
  String get cmdInsertLink => '[Ļîñķ on]';

  @override
  String get cmdDeckOpenNumbering => '[Šļîðé ñûɱƀéŕš… one t]';

  @override
  String get cmdLayoutInsertPlaceholder => '[Þļåçéĥöļðéŕ one]';

  @override
  String get cmdFormatBold => '[Ɓöļð on]';

  @override
  String get cmdFormatItalic => '[Îţåļîç one]';

  @override
  String get cmdFormatUnderline => '[Ûñðéŕļîñé one]';

  @override
  String get cmdFormatStrikethrough => '[Šţŕîķéţĥŕöûĝĥ one t]';

  @override
  String get cmdFormatScript => '[Šûþéŕšçŕîþţ / šûƀšçŕîþţ one two]';

  @override
  String get cmdFormatIncreaseFontSize => '[Îñçŕéåšé ƒöñţ šîžé one tw]';

  @override
  String get cmdFormatDecreaseFontSize => '[Ðéçŕéåšé ƒöñţ šîžé one tw]';

  @override
  String get cmdFormatCaps => '[Çåþîţåļîžåţîöñ one t]';

  @override
  String get cmdFormatTextStyle => '[Ţéẋţ šţýļé one]';

  @override
  String get cmdFormatFont => '[Ƒöñţ on]';

  @override
  String get cmdFormatFontSize => '[Ƒöñţ šîžé one]';

  @override
  String get cmdFormatTextColor => '[Ţéẋţ çöļöŕ one]';

  @override
  String get cmdFormatHighlight => '[Ĥîĝĥļîĝĥţ çöļöŕ one t]';

  @override
  String get cmdFormatAlign => '[Ţéẋţ åļîĝñɱéñţ one t]';

  @override
  String get cmdFormatAnchor => '[Ṽéŕţîçåļ åļîĝñɱéñţ one tw]';

  @override
  String get cmdFormatIndent => '[Îñçŕéåšé îñðéñţ one t]';

  @override
  String get cmdFormatOutdent => '[Ðéçŕéåšé îñðéñţ one t]';

  @override
  String get cmdFormatLineHeight => '[Ļîñé šþåçîñĝ one]';

  @override
  String get cmdFormatParagraphSpacing => '[Þåŕåĝŕåþĥ šþåçîñĝ… one tw]';

  @override
  String get cmdFormatList => '[Ļîšţš on]';

  @override
  String get cmdFormatListStyle => '[Ļîšţ šţýļé one]';

  @override
  String get cmdFormatListStart => '[Ŕéšţåŕţ ñûɱƀéŕîñĝ one tw]';

  @override
  String get cmdFormatAutofit => '[Ţéẋţ ƒîţţîñĝ one]';

  @override
  String get cmdFormatFill => '[Ƒîļļ on]';

  @override
  String get cmdFormatStroke => '[Ɓöŕðéŕ one]';

  @override
  String get cmdFormatEffects => '[Éƒƒéçţš one]';

  @override
  String get cmdFormatOpacity => '[Öþåçîţý… one]';

  @override
  String get cmdImageCrop => '[Çŕöþ on]';

  @override
  String get cmdImageMask => '[Ṁåšķ ŵîţĥ šĥåþé one t]';

  @override
  String get cmdImageReplace => '[Ŕéþļåçé îɱåĝé one t]';

  @override
  String get cmdImageAdjust => '[Åðĵûšţɱéñţš… one t]';

  @override
  String get cmdImageReset => '[Ŕéšéţ îɱåĝé one]';

  @override
  String get cmdImageDownloadOriginal => '[Ðöŵñļöåð öŕîĝîñåļ one tw]';

  @override
  String get cmdTableInsertRow => '[Îñšéŕţ ŕöŵ one]';

  @override
  String get cmdTableInsertColumn => '[Îñšéŕţ çöļûɱñ one t]';

  @override
  String get cmdTableDeleteRows => '[Ðéļéţé ŕöŵ one]';

  @override
  String get cmdTableDeleteColumns => '[Ðéļéţé çöļûɱñ one t]';

  @override
  String get cmdTableDelete => '[Ðéļéţé ţåƀļé one]';

  @override
  String get cmdTableMergeCells => '[Ṁéŕĝé çéļļš one]';

  @override
  String get cmdTableUnmergeCells => '[Ûñɱéŕĝé çéļļš one t]';

  @override
  String get cmdTableDistributeRows => '[Ðîšţŕîƀûţé ŕöŵš one t]';

  @override
  String get cmdTableDistributeColumns => '[Ðîšţŕîƀûţé çöļûɱñš one tw]';

  @override
  String get cmdTableSetOptions => '[Ţåƀļé öþţîöñš… one t]';

  @override
  String get cmdTableSetCellFill => '[Çéļļ ƒîļļ one]';

  @override
  String get cmdTableSetBorders => '[Ɓöŕðéŕš one]';

  @override
  String get cmdTableSetCellAlign => '[Ṽéŕţîçåļ åļîĝñ one t]';

  @override
  String get cmdShapeChange => '[Çĥåñĝé šĥåþé one]';

  @override
  String get cmdShapeApplyQuickStyle => '[Ǫûîçķ šţýļéš one]';

  @override
  String get cmdLineSetArrow => '[Åŕŕöŵš one]';

  @override
  String get cmdLineSetRouting => '[Ŕöûţîñĝ one]';

  @override
  String get cmdCodeEdit => '[Éðîţ çöðé one]';

  @override
  String get cmdCodeSetLanguage => '[Çöðé ļåñĝûåĝé one t]';

  @override
  String get cmdCodeUpdateOptions => '[Ļîñé ñûɱƀéŕš one]';

  @override
  String get cmdCodeSetHighlightSteps => '[Ĥîĝĥļîĝĥţ šţéþš… one tw]';

  @override
  String get cmdCodeAddState => '[Åðð šţåţé one]';

  @override
  String get cmdChartUpdate => '[Ûþðåţé çĥåŕţ one]';

  @override
  String get cmdChartSetAutoUpdate => '[Ûþðåţé åûţöɱåţîçåļļý one two]';

  @override
  String get cmdChartOpenSource => '[Öþéñ šöûŕçé šþŕéåðšĥééţ one two]';

  @override
  String get cmdChartUnlink => '[Ûñļîñķ çĥåŕţ one]';

  @override
  String get cmdChartCopyAsImage => '[Çöþý çĥåŕţ åš îɱåĝé one tw]';

  @override
  String get cmdElementEditAltText => '[Åļţ ţéẋţ… one]';

  @override
  String get cmdFormatPaintFormat => '[Þåîñţ ƒöŕɱåţ one]';

  @override
  String get cmdFormatClear => '[Çļéåŕ ƒöŕɱåţţîñĝ one tw]';

  @override
  String get cmdSlideDuplicate => '[Ðûþļîçåţé šļîðé one t]';

  @override
  String get cmdSlideDelete => '[Ðéļéţé šļîðé one]';

  @override
  String get cmdSlideToggleSkip => '[Šķîþ šļîðé one]';

  @override
  String get cmdSlideMove => '[Ṁöṽé šļîðé one]';

  @override
  String get cmdSlideApplyLayout => '[Åþþļý ļåýöûţ one]';

  @override
  String get cmdSlideResetToLayout => '[Ŕéšéţ šļîðé ţö ļåýöûţ one two]';

  @override
  String get cmdSlideSetBackground => '[Çĥåñĝé ƀåçķĝŕöûñð… one tw]';

  @override
  String get cmdSlideApplyBackgroundToAll =>
      '[Åþþļý ƀåçķĝŕöûñð ţö åļļ šļîðéš one two th]';

  @override
  String get cmdSlideSetHideMasterElements => '[Ĥîðé ɱåšţéŕ öƀĵéçţš one tw]';

  @override
  String get cmdDeckSetAppearance => '[Þŕéšéñţåţîöñ åþþéåŕåñçé one two]';

  @override
  String get cmdGroupCreate => '[Ĝŕöûþ šļîðéš one]';

  @override
  String get cmdGroupUngroup => '[Ûñĝŕöûþ šļîðéš one t]';

  @override
  String get cmdGroupAddSlides => '[Åðð ţö ĝŕöûþ one]';

  @override
  String get cmdGroupRemoveSlides => '[Ŕéɱöṽé ƒŕöɱ ĝŕöûþ one tw]';

  @override
  String get cmdGroupStartRename => '[Ŕéñåɱé ĝŕöûþ one]';

  @override
  String get cmdGroupSetColor => '[Ĝŕöûþ çöļöŕ one]';

  @override
  String get cmdGroupToggleSkip => '[Šķîþ ĝŕöûþ one]';

  @override
  String get cmdGroupCollapse => '[Çöļļåþšé ĝŕöûþ one t]';

  @override
  String get cmdGroupExpand => '[Éẋþåñð ĝŕöûþ one]';

  @override
  String get cmdGroupCollapseAll => '[Çöļļåþšé åļļ ĝŕöûþš one tw]';

  @override
  String get cmdGroupExpandAll => '[Éẋþåñð åļļ ĝŕöûþš one tw]';

  @override
  String get cmdGroupDuplicate => '[Ðûþļîçåţé ĝŕöûþ one t]';

  @override
  String get cmdGroupDelete => '[Ðéļéţé ĝŕöûþ… one t]';

  @override
  String get cmdGroupSelectSlides => '[Šéļéçţ šļîðéš îñ ĝŕöûþ one two]';

  @override
  String get cmdAnimatePreview => '[Þŕéṽîéŵ åñîɱåţîöñš one tw]';

  @override
  String get cmdAnimateRemoveAll => '[Ŕéɱöṽé åļļ åñîɱåţîöñš one two]';

  @override
  String get cmdAnimateAddBuild => '[Åðð åñîɱåţîöñ one t]';

  @override
  String get cmdAnimateCopyBuilds => '[Çöþý åñîɱåţîöñ one t]';

  @override
  String get cmdAnimatePasteBuilds => '[Þåšţé åñîɱåţîöñ one t]';

  @override
  String get cmdAnimateDeleteBuilds => '[Ŕéɱöṽé åñîɱåţîöñš one tw]';

  @override
  String get cmdThemeEdit => '[Éðîţ ţĥéɱé… one]';

  @override
  String get cmdNavGoToSlide => '[Ĝö ţö šļîðé… one]';

  @override
  String get cmdNavGoToGroup => '[Ĝö ţö ĝŕöûþ one]';

  @override
  String get cmdNavPreviousSlide => '[Þŕéṽîöûš šļîðé one t]';

  @override
  String get cmdNavNextSlide => '[Ñéẋţ šļîðé one]';

  @override
  String get cmdArrangeOrder => '[Öŕðéŕ on]';

  @override
  String get cmdArrangeAlign => '[Åļîĝñ öƀĵéçţš one t]';

  @override
  String get cmdArrangeDistribute => '[Ðîšţŕîƀûţé öƀĵéçţš one tw]';

  @override
  String get cmdArrangeCenterOnSlide => '[Çéñţéŕ öñ šļîðé one t]';

  @override
  String get cmdArrangeMatchSize => '[Ṁåţçĥ šîžé one]';

  @override
  String get cmdArrangeRotate => '[Ŕöţåţé one]';

  @override
  String get cmdArrangeFlip => '[Ƒļîþ on]';

  @override
  String get cmdArrangeGroup => '[Ĝŕöûþ on]';

  @override
  String get cmdArrangeUngroup => '[Ûñĝŕöûþ one]';

  @override
  String get cmdElementToggleLock => '[Ļöçķ on]';

  @override
  String get cmdElementUnlockAll => '[Ûñļöçķ åļļ öñ šļîðé one tw]';

  @override
  String get cmdElementHide => '[Ĥîðé on]';

  @override
  String get cmdElementShow => '[Šĥöŵ on]';

  @override
  String get cmdElementSetLink => '[Ļîñķ… on]';

  @override
  String get cmdElementRemoveLink => '[Ŕéɱöṽé ļîñķ one]';

  @override
  String get cmdElementResetPlaceholder => '[Ŕéšéţ ţö ļåýöûţ one t]';

  @override
  String get cmdSpellingCheck => '[Çĥéçķ šþéļļîñĝ one t]';

  @override
  String get cmdSpellingToggleUnderline => '[Ûñðéŕļîñé éŕŕöŕš one tw]';

  @override
  String get cmdToolsAccessibilityCheck => '[Åççéššîƀîļîţý çĥéçķ one two]';

  @override
  String get cmdNotificationsOpenSettings => '[Ñöţîƒîçåţîöñ šéţţîñĝš one two]';

  @override
  String get cmdAiGenerateDeck => '[Ĝéñéŕåţé þŕéšéñţåţîöñ… one two]';

  @override
  String get cmdAiRewrite => '[Ŕéŵŕîţé ţéẋţ one]';

  @override
  String get cmdAiSuggestLayouts =>
      '[Šûĝĝéšţ ļåýöûţš ƒöŕ ţĥîš šļîðé one two th]';

  @override
  String get cmdAiSpeakerNotes => '[Ŵŕîţé šþéåķéŕ ñöţéš one tw]';

  @override
  String get cmdAiAltText => '[Ĝéñéŕåţé åļţ ţéẋţ one tw]';

  @override
  String get cmdAiCodeWalkthrough => '[Ṁåķé å çöðé ŵåļķţĥŕöûĝĥ… one two]';

  @override
  String get cmdToolSelect => '[Šéļéçţ one]';

  @override
  String get cmdPrefsSet => '[Çĥåñĝé å Šļîðéš šéţţîñĝ one two]';

  @override
  String get cmdPresenterSet => '[Çĥåñĝé å þŕéšéñţîñĝ šéţţîñĝ one two t]';

  @override
  String get categoryFile => '[Ƒîļé on]';

  @override
  String get categoryEdit => '[Çöɱɱöñ one]';

  @override
  String get categoryView => '[Ṽîéŵ on]';

  @override
  String get categoryInsert => '[Îñšéŕţ one]';

  @override
  String get categoryFormat => '[Çåñṽåš & öƀĵéçţš one t]';

  @override
  String get categoryText => '[Ţéẋţ on]';

  @override
  String get categoryTables => '[Ţåƀļéš one]';

  @override
  String get categorySlides => '[Šļîðéš & ĝŕöûþš one t]';

  @override
  String get categoryArrange => '[Åŕŕåñĝé one]';

  @override
  String get categoryCanvas => '[Çåñṽåš & öƀĵéçţš one t]';

  @override
  String get categoryPresent => '[Þŕéšéñţ one]';

  @override
  String get categoryAnimations => '[Åñîɱåţîöñš one]';

  @override
  String get categoryTools => '[Ţööļš on]';

  @override
  String get categoryAi => '[ÅÎ o]';

  @override
  String get alignLeft => '[Ļéƒţ on]';

  @override
  String get alignCenter => '[Çéñţéŕ one]';

  @override
  String get alignRight => '[Ŕîĝĥţ on]';

  @override
  String get alignJustify => '[Ĵûšţîƒý one]';

  @override
  String get anchorTop => '[Ţöþ on]';

  @override
  String get anchorMiddle => '[Ṁîððļé one]';

  @override
  String get anchorBottom => '[Ɓöţţöɱ one]';

  @override
  String get animateAddBuildIn => '[Åðð ƀûîļð îñ one]';

  @override
  String get animateAddAction => '[Åðð åçţîöñ one]';

  @override
  String get animateAddBuildOut => '[Åðð ƀûîļð öûţ one]';

  @override
  String get animateTabTransition => '[Ţŕåñšîţîöñ one]';

  @override
  String get animateTabBuild => '[Ɓûîļð on]';

  @override
  String get animateTabOrder => '[Öŕðéŕ on]';

  @override
  String get animateTransitionEmpty =>
      '[Šļîðé ţŕåñšîţîöñš åŕŕîṽé ĥéŕé šööñ: éƒƒéçţš, ðûŕåţîöñ åñð ĥöŵ ţĥé šļîðé åðṽåñçéš. one two three four five s]';

  @override
  String get animateBuildEmpty =>
      '[Ɓûîļðš åŕŕîṽé ĥéŕé šööñ: šéļéçţ åñ öƀĵéçţ ţö åñîɱåţé îţ îñ, öûţ öŕ îñ þļåçé. one two three four fiv]';

  @override
  String get animateOrderEmpty =>
      '[Ţĥé ƀûîļð öŕðéŕ öƒ ţĥîš šļîðé ŵîļļ ƀé ļîšţéð ĥéŕé. one two three f]';

  @override
  String get appearanceLight => '[Ļîĝĥţ on]';

  @override
  String get appearanceDark => '[Ðåŕķ on]';

  @override
  String get autofitNone => '[Ðö ñöţ åûţöƒîţ one t]';

  @override
  String get autofitShrink => '[Šĥŕîñķ ţéẋţ öñ öṽéŕƒļöŵ one two]';

  @override
  String get autofitResize => '[Ŕéšîžé šĥåþé ţö ƒîţ ţéẋţ one two]';

  @override
  String get axisHorizontally => '[Ĥöŕîžöñţåļļý one t]';

  @override
  String get axisVertically => '[Ṽéŕţîçåļļý one]';

  @override
  String get axisBoth => '[Ɓöţĥ on]';

  @override
  String get backToNormalView => '[Ɓåçķ ţö Ñöŕɱåļ ṽîéŵ one tw]';

  @override
  String get backToPresentation => '[Ɓåçķ ţö ţĥé þŕéšéñţåţîöñ one two]';

  @override
  String get badgeViewOnly => '[Ṽîéŵ öñļý one]';

  @override
  String get badgeCommentOnly => '[Çöɱɱéñţ öñļý one]';

  @override
  String get badgeViewing => '[Ṽîéŵîñĝ one]';

  @override
  String get buildAppear => '[Åþþéåŕ one]';

  @override
  String get buildFlyIn => '[Ƒļý îñ on]';

  @override
  String get buildZoom => '[Žööɱ on]';

  @override
  String get canvasChooseLayout => '[Çĥööšé å ļåýöûţ one t]';

  @override
  String get canvasEmptyTitle => '[Ţĥîš þŕéšéñţåţîöñ ĥåš ñö šļîðéš one two th]';

  @override
  String get canvasEmptyBody =>
      '[Åðð å šļîðé ţö šţåŕţ, öŕ çĥööšé å ļåýöûţ ƒöŕ îţ. one two three]';

  @override
  String canvasSlideSemantics(int number, String title) {
    return '[Šļîðé $number: $title one]';
  }

  @override
  String get capsUpper => '[ÛÞÞÉŔÇÅŠÉ one]';

  @override
  String get capsSmallCaps => '[Šɱåļļ çåþš one]';

  @override
  String get capsTitle => '[Ţîţļé Çåšé one]';

  @override
  String get capsNone => '[Ñöñé on]';

  @override
  String get chartColumn => '[Çöļûɱñ one]';

  @override
  String get chartBar => '[Ɓåŕ on]';

  @override
  String get chartLine => '[Ļîñé on]';

  @override
  String get chartPie => '[Þîé on]';

  @override
  String get chartArea => '[Åŕéå on]';

  @override
  String get chartScatter => '[Šçåţţéŕ one]';

  @override
  String get chartFromSheets => '[Ƒŕöɱ Ŵöñķý Šĥééţš… one tw]';

  @override
  String get codeAllLanguages => '[Åļļ ļåñĝûåĝéš… one t]';

  @override
  String get codeLineNumbers => '[Ļîñé ñûɱƀéŕš one]';

  @override
  String get codePlainText => '[Þļåîñ ţéẋţ one]';

  @override
  String get codeStates => '[Šţåţéš… one]';

  @override
  String get colorGray => '[Ĝŕåý on]';

  @override
  String get colorRed => '[Ŕéð on]';

  @override
  String get colorOrange => '[Öŕåñĝé one]';

  @override
  String get colorAmber => '[Åɱƀéŕ on]';

  @override
  String get colorGreen => '[Ĝŕééñ on]';

  @override
  String get colorTeal => '[Ţéåļ on]';

  @override
  String get colorBlue => '[Ɓļûé on]';

  @override
  String get colorViolet => '[Ṽîöļéţ one]';

  @override
  String get colorPink => '[Þîñķ on]';

  @override
  String get colorNone => '[Ñöñé on]';

  @override
  String get deckLoading => '[Öþéñîñĝ þŕéšéñţåţîöñ… one two]';

  @override
  String deckLoadingProgress(String message, int percent) {
    return '[$message $percent % o]';
  }

  @override
  String get deckUnavailable =>
      '[Ţĥîš þŕéšéñţåţîöñ îšñ’ţ åṽåîļåƀļé one two thr]';

  @override
  String get deckOfflineHint =>
      '[Îţ öþéñš ƀý îţšéļƒ ŵĥéñ ýöû’ŕé ƀåçķ öñļîñé. one two three]';

  @override
  String get downloadPdf => '[ÞÐƑ ðöçûɱéñţ (.þðƒ) one tw]';

  @override
  String get downloadPng => '[ÞÑĜ îɱåĝé (çûŕŕéñţ šļîðé) one two]';

  @override
  String get downloadPngZip => '[ÞÑĜ îɱåĝéš (åļļ šļîðéš, .žîþ) one two t]';

  @override
  String get downloadMarkdown => '[Öûţļîñé åš Ṁåŕķðöŵñ (.ɱð) one two]';

  @override
  String durationMinutes(int minutes) {
    return '[$minutes ɱîñ on]';
  }

  @override
  String durationSeconds(String seconds) {
    return '[$seconds š o]';
  }

  @override
  String get flipHorizontally => '[Ƒļîþ ĥöŕîžöñţåļļý one tw]';

  @override
  String get flipVertically => '[Ƒļîþ ṽéŕţîçåļļý one t]';

  @override
  String get goToSlideTitle => '[Ĝö ţö šļîðé one]';

  @override
  String get goToSlideLabel => '[Šļîðé on]';

  @override
  String get goToSlideButton => '[Ĝö o]';

  @override
  String get groupUntitled => '[Ûñţîţļéð ĝŕöûþ one t]';

  @override
  String get guidesAddVertical => '[Åðð ṽéŕţîçåļ ĝûîðé one tw]';

  @override
  String get guidesAddHorizontal => '[Åðð ĥöŕîžöñţåļ ĝûîðé one two]';

  @override
  String get imageUpload => '[Ûþļöåð ƒŕöɱ çöɱþûţéŕ one two]';

  @override
  String get imageFromDrive => '[Ƒŕöɱ Ŵöñķý Ðŕîṽé one t]';

  @override
  String get imageByUrl => '[Ɓý ÛŔĻ on]';

  @override
  String get imageFromClipboard => '[Ƒŕöɱ çļîþƀöåŕð one t]';

  @override
  String get inspectorLabel => '[Îñšþéçţöŕ one]';

  @override
  String get inspectorFormat => '[Ƒöŕɱåţ one]';

  @override
  String get inspectorAnimate => '[Åñîɱåţé one]';

  @override
  String get inspectorSlide => '[Šļîðé on]';

  @override
  String get inspectorClose => '[Çļöšé îñšþéçţöŕ one t]';

  @override
  String get inspectorFormatEmpty =>
      '[Šéļéçţ åñ öƀĵéçţ ţö ƒöŕɱåţ îţ one two t]';

  @override
  String get inspectorSectionSoon =>
      '[Ţĥéšé öþţîöñš åŕé öñ ţĥéîŕ ŵåý. one two th]';

  @override
  String get inspectorCurrentLayout => '[Ļåýöûţ one]';

  @override
  String get inspectorAppearance => '[Åþþéåŕåñçé one]';

  @override
  String get inspectorNotInGroup => '[Ñöţ îñ å ĝŕöûþ one]';

  @override
  String get inspectorGroupName => '[Ĝŕöûþ on]';

  @override
  String get inspectorSlideNumber => '[Þöšîţîöñ one]';

  @override
  String get inspectorSkipped => '[Šķîþþéð one]';

  @override
  String get yes => '[Ýéš on]';

  @override
  String get lineLine => '[Ļîñé on]';

  @override
  String get lineArrow => '[Åŕŕöŵ on]';

  @override
  String get lineDoubleArrow => '[Ðöûƀļé åŕŕöŵ one]';

  @override
  String get lineElbowConnector => '[Éļƀöŵ çöññéçţöŕ one t]';

  @override
  String get lineCurvedConnector => '[Çûŕṽéð çöññéçţöŕ one tw]';

  @override
  String get lineStartArrow => '[Šţåŕţ åŕŕöŵ one]';

  @override
  String get lineEndArrow => '[Éñð åŕŕöŵ one]';

  @override
  String get listBulleted => '[Ɓûļļéţéð ļîšţ one t]';

  @override
  String get listNumbered => '[Ñûɱƀéŕéð ļîšţ one t]';

  @override
  String get listChecklist => '[Çĥéçķļîšţ one]';

  @override
  String get listOptions => '[Ļîšţ öþţîöñš… one t]';

  @override
  String get mastersSoonTitle =>
      '[Éðîţîñĝ ɱåšţéŕš åñð ļåýöûţš îš çöɱîñĝ šööñ one two three]';

  @override
  String get mastersSoonBody =>
      '[Ýöû’ļļ éðîţ ţĥé ţĥéɱé’š ɱåšţéŕš åñð ļåýöûţš ĥéŕé. Ýöûŕ šļîðéš åŕé ûñçĥåñĝéð. one two three four five]';

  @override
  String get menuAddToGroup => '[Åðð ţö ĝŕöûþ one]';

  @override
  String get menuAi => '[ÅÎ o]';

  @override
  String get menuAlign => '[Åļîĝñ on]';

  @override
  String get menuAlignIndent => '[Åļîĝñ & îñðéñţ one t]';

  @override
  String get menuAnimate => '[Åñîɱåţé one]';

  @override
  String get menuAnimateEllipsis => '[Åñîɱåţé… one]';

  @override
  String get menuAnimation => '[Åñîɱåţîöñ… one]';

  @override
  String get menuApplyLayout => '[Åþþļý ļåýöûţ one]';

  @override
  String get menuArrange => '[Åŕŕåñĝé one]';

  @override
  String get menuBorderEllipsis => '[Ɓöŕðéŕ… one]';

  @override
  String get menuCapitalization => '[Çåþîţåļîžåţîöñ one t]';

  @override
  String get menuCenterOnSlide => '[Çéñţéŕ öñ šļîðé one t]';

  @override
  String get menuChangeBackground => '[Çĥåñĝé ƀåçķĝŕöûñð… one tw]';

  @override
  String get menuChangeTheme => '[Çĥåñĝé ţĥéɱé… one t]';

  @override
  String get menuChart => '[Çĥåŕţ on]';

  @override
  String get menuChooseGroup => '[Çĥööšé å ĝŕöûþ… one t]';

  @override
  String get menuCode => '[Çöðé on]';

  @override
  String get menuCodeBlock => '[Çöðé ƀļöçķ one]';

  @override
  String get menuCommentOnSlide => '[Çöɱɱéñţ öñ šļîðé one t]';

  @override
  String get menuDistribute => '[Ðîšţŕîƀûţé one]';

  @override
  String get menuDownload => '[Ðöŵñļöåð one]';

  @override
  String get menuEditLayout => '[Éðîţ ļåýöûţ one]';

  @override
  String get menuEditMasters => '[Éðîţ ɱåšţéŕš åñð ļåýöûţš one two]';

  @override
  String get menuEffectsEllipsis => '[Éƒƒéçţš… one]';

  @override
  String get menuExtensions => '[Éẋţéñšîöñš one]';

  @override
  String get menuFillEllipsis => '[Ƒîļļ… on]';

  @override
  String get menuFormat => '[Ƒöŕɱåţ one]';

  @override
  String get menuFormatOptions => '[Ƒöŕɱåţ öþţîöñš… one t]';

  @override
  String get menuGroup => '[Ĝŕöûþ on]';

  @override
  String get menuGroupColor => '[Çöļöŕ on]';

  @override
  String get menuGuides => '[Ĝûîðéš one]';

  @override
  String get menuImage => '[Îɱåĝé on]';

  @override
  String get menuInsert => '[Îñšéŕţ one]';

  @override
  String get menuLanguage => '[Ļåñĝûåĝé one]';

  @override
  String get menuLine => '[Ļîñé on]';

  @override
  String get menuLists => '[Ɓûļļéţš & ñûɱƀéŕîñĝ one tw]';

  @override
  String get menuMagicMoveId => '[Ṁåĝîç Ṁöṽé ÎÐ… one t]';

  @override
  String get menuMatchSize => '[Ṁåţçĥ šîžé one]';

  @override
  String get menuMcp => '[ṀÇÞ on]';

  @override
  String get menuMoveSlide => '[Ṁöṽé šļîðé one]';

  @override
  String get menuNewGroup => '[Ñéŵ ĝŕöûþ one]';

  @override
  String get menuNewSlideInGroup => '[Ñéŵ šļîðé îñ ĝŕöûþ one tw]';

  @override
  String get menuNewSlideWithLayout => '[Ñéŵ šļîðé ŵîţĥ ļåýöûţ one two]';

  @override
  String get menuOrder => '[Öŕðéŕ on]';

  @override
  String get menuPanels => '[Þåñéļš one]';

  @override
  String get menuPasteSpecial => '[Þåšţé šþéçîåļ one t]';

  @override
  String get menuPersonalDictionary => '[Þéŕšöñåļ ðîçţîöñåŕý one two]';

  @override
  String get menuPlaceholder => '[Þļåçéĥöļðéŕ one]';

  @override
  String get menuPresent => '[Þŕéšéñţ one]';

  @override
  String get menuPresentFromGroup => '[Þŕéšéñţ ƒŕöɱ ţĥîš ĝŕöûþ one two]';

  @override
  String get menuPresentingSettings => '[Þŕéšéñţîñĝ šéţţîñĝš… one two]';

  @override
  String get menuRehearsePresentation => '[Ŕéĥéåŕšé þŕéšéñţåţîöñ one two]';

  @override
  String get menuRewriteText => '[Ŕéŵŕîţé ţéẋţ one]';

  @override
  String get menuRotate => '[Ŕöţåţé one]';

  @override
  String get menuShape => '[Šĥåþé on]';

  @override
  String get menuShapeGallery => '[Åļļ šĥåþéš… one]';

  @override
  String get menuShow => '[Šĥöŵ on]';

  @override
  String get menuSize => '[Šîžé on]';

  @override
  String get menuSizePosition => '[Šîžé åñð þöšîţîöñ… one tw]';

  @override
  String get menuSlide => '[Šļîðé on]';

  @override
  String get menuSnap => '[Šñåþ on]';

  @override
  String get menuSpacing => '[Ļîñé & þåŕåĝŕåþĥ šþåçîñĝ one two]';

  @override
  String get menuSpelling => '[Šþéļļîñĝ one]';

  @override
  String get menuTable => '[Ţåƀļé on]';

  @override
  String get menuText => '[Ţéẋţ on]';

  @override
  String get menuTextFitting => '[Ţéẋţ ƒîţţîñĝ one]';

  @override
  String get menuTextStyle => '[Ţéẋţ šţýļé one]';

  @override
  String get menuTransition => '[Ţŕåñšîţîöñ… one]';

  @override
  String get menuVersionHistory => '[Ṽéŕšîöñ ĥîšţöŕý one t]';

  @override
  String get menuZoom => '[Žööɱ on]';

  @override
  String get moveToBeginning => '[Ţö ƀéĝîññîñĝ one]';

  @override
  String get moveUp => '[Ûþ o]';

  @override
  String get moveDown => '[Ðöŵñ on]';

  @override
  String get moveToEnd => '[Ţö éñð on]';

  @override
  String get navigatorLabel => '[Šļîðéš one]';

  @override
  String get navigatorEmpty => '[Ñö šļîðéš one]';

  @override
  String get navigatorOpen => '[Šĥöŵ šļîðéš one]';

  @override
  String navigatorGroupSemantics(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count šļîðéš',
      one: '1 šļîðé',
    );
    return '[Ĝŕöûþ $title, $_temp0 one two]';
  }

  @override
  String navigatorSlideSemantics(int number, int total, String title) {
    return '[Šļîðé $number öƒ $total: $title one]';
  }

  @override
  String get notesLabel => '[Šþéåķéŕ ñöţéš one t]';

  @override
  String get notesPlaceholder => '[Çļîçķ ţö åðð šþéåķéŕ ñöţéš one two]';

  @override
  String get orderBringToFront => '[Ɓŕîñĝ ţö ƒŕöñţ one t]';

  @override
  String get orderBringForward => '[Ɓŕîñĝ ƒöŕŵåŕð one t]';

  @override
  String get orderSendBackward => '[Šéñð ƀåçķŵåŕð one t]';

  @override
  String get orderSendToBack => '[Šéñð ţö ƀåçķ one]';

  @override
  String get outlineNoTitle => '[(ñö ţîţļé) one]';

  @override
  String get outlineReadOnlyNote =>
      '[Öûţļîñé ṽîéŵ šĥöŵš éåçĥ šļîðé’š ţîţļé åñð ɱåîñ ţéẋţ. Éðîţîñĝ ĥéŕé çöɱéš šööñ. one two three four five]';

  @override
  String get pasteKeepSource => '[Ķééþ šöûŕçé ƒöŕɱåţţîñĝ one two]';

  @override
  String get pasteUseDestination => '[Ûšé ðéšţîñåţîöñ ţĥéɱé one two]';

  @override
  String get pasteChartUnlinked => '[Þåšţé çĥåŕţ ûñļîñķéð one two]';

  @override
  String get placeholderPicture => '[Þîçţûŕé one]';

  @override
  String get placeholderObject => '[Öƀĵéçţ one]';

  @override
  String get placeholderFooter => '[Ƒööţéŕ one]';

  @override
  String get placeholderSlideNumber => '[Šļîðé ñûɱƀéŕ one]';

  @override
  String get placeholderDate => '[Ðåţé on]';

  @override
  String get presentButton => '[Þŕéšéñţ one]';

  @override
  String get presentOptions => '[Þŕéšéñţîñĝ öþţîöñš one tw]';

  @override
  String get presenterLayoutStandard => '[Çûŕŕéñţ, ñéẋţ åñð ñöţéš one two]';

  @override
  String get presenterLayoutNotes => '[Ļåŕĝé ñöţéš one]';

  @override
  String get presenterLayoutNext => '[Ļåŕĝé ñéẋţ šļîðé one t]';

  @override
  String get reasonNotAvailableYet => '[Ñöţ åṽåîļåƀļé ýéţ one tw]';

  @override
  String get reasonDeckLoading =>
      '[Ţĥé þŕéšéñţåţîöñ îš šţîļļ öþéñîñĝ one two thr]';

  @override
  String get reasonViewAccess => '[Ýöû ĥåṽé ṽîéŵ åççéšš one tw]';

  @override
  String get reasonViewingMode => '[Ýöû’ŕé îñ Ṽîéŵîñĝ ɱöðé one two]';

  @override
  String get reasonFirstSlide => '[Ţĥîš îš ţĥé ƒîŕšţ šļîðé one two]';

  @override
  String get reasonLastSlide => '[Ţĥîš îš ţĥé ļåšţ šļîðé one two]';

  @override
  String get reasonNoSlides => '[Ţĥé þŕéšéñţåţîöñ ĥåš ñö šļîðéš one two th]';

  @override
  String get rewriteShorter => '[Šĥöŕţéŕ one]';

  @override
  String get rewriteLonger => '[Ļöñĝéŕ one]';

  @override
  String get rewriteClearer => '[Çļéåŕéŕ one]';

  @override
  String get rewriteFormal => '[Ṁöŕé ƒöŕɱåļ one]';

  @override
  String get rewriteGrammar => '[Ƒîẋ ĝŕåɱɱåŕ one]';

  @override
  String get rewriteCustom => '[Çûšţöɱ… one]';

  @override
  String get rotateClockwise => '[Ŕöţåţé 90° çļöçķŵîšé one two]';

  @override
  String get rotateCounterClockwise =>
      '[Ŕöţåţé 90° çöûñţéŕ-çļöçķŵîšé one two th]';

  @override
  String get routePresentTitle => '[Þŕéšéñţîñĝ one]';

  @override
  String get routePrintTitle => '[Þŕîñţ åñð ÞÐƑ one]';

  @override
  String get routeHistoryTitle => '[Ṽéŕšîöñ ĥîšţöŕý one t]';

  @override
  String get sectionText => '[Ţéẋţ on]';

  @override
  String get sectionLine => '[Ļîñé on]';

  @override
  String get sectionImage => '[Îɱåĝé on]';

  @override
  String get sectionTable => '[Ţåƀļé on]';

  @override
  String get sectionCell => '[Çéļļ on]';

  @override
  String get sectionIcon => '[Îçöñ on]';

  @override
  String get sectionCode => '[Çöðé on]';

  @override
  String get sectionChart => '[Çĥåŕţ on]';

  @override
  String get sectionFill => '[Ƒîļļ on]';

  @override
  String get sectionBorder => '[Ɓöŕðéŕ one]';

  @override
  String get sectionEffects => '[Éƒƒéçţš one]';

  @override
  String get sectionArrange => '[Åŕŕåñĝé one]';

  @override
  String get sectionLink => '[Ļîñķ on]';

  @override
  String get sectionAccessibility => '[Åççéššîƀîļîţý one t]';

  @override
  String get sectionLayout => '[Ļåýöûţ one]';

  @override
  String get sectionBackground => '[Ɓåçķĝŕöûñð one]';

  @override
  String get sectionTheme => '[Ţĥéɱé on]';

  @override
  String get sectionVisibility => '[Ṽîšîƀîļîţý one]';

  @override
  String get sectionGroup => '[Ĝŕöûþ on]';

  @override
  String get sectionInfo => '[Îñƒö on]';

  @override
  String get settingsSectionPresentations => '[Ñéŵ þŕéšéñţåţîöñš one tw]';

  @override
  String get settingsSectionEditing => '[Éðîţîñĝ one]';

  @override
  String get settingsSectionAnimations => '[Åñîɱåţîöñš & çöðé one tw]';

  @override
  String get settingsSectionPresenting => '[Þŕéšéñţîñĝ one]';

  @override
  String get settingsNewPresentations => '[Ñéŵ þŕéšéñţåţîöñš one tw]';

  @override
  String get settingsNewPresentationsHint =>
      '[Ûšéð ŵĥéñ ýöû çŕéåţé å þŕéšéñţåţîöñ. Éẋîšţîñĝ þŕéšéñţåţîöñš ķééþ ţĥéîŕ öŵñ šéţţîñĝš. one two three four five si]';

  @override
  String get settingsDefaultTheme => '[Ţĥéɱé on]';

  @override
  String get settingsDefaultAppearance => '[Åþþéåŕåñçé one]';

  @override
  String get settingsDefaultSize => '[Šļîðé šîžé one]';

  @override
  String get settingsDefaultLanguage => '[Ļåñĝûåĝé one]';

  @override
  String get settingsCharts => '[Çĥåŕţš one]';

  @override
  String get settingsChartsAutoUpdate =>
      '[Ûþðåţé ļîñķéð çĥåŕţš åûţöɱåţîçåļļý one two thr]';

  @override
  String get settingsChartsAutoUpdateHint =>
      '[Ñéŵ çĥåŕţš ƒŕöɱ Ŵöñķý Šĥééţš ƒöļļöŵ ţĥéîŕ šþŕéåðšĥééţ. one two three fou]';

  @override
  String get settingsEditing => '[Éðîţîñĝ one]';

  @override
  String get settingsUnits => '[Ûñîţš on]';

  @override
  String get settingsScrollChangesSlides => '[Šçŕöļļ ţö çĥåñĝé šļîðéš one two]';

  @override
  String get settingsSmartQuotes => '[Šɱåŕţ ǫûöţéš one]';

  @override
  String get settingsAutoformatLists =>
      '[Åûţöɱåţîçåļļý ƒöŕɱåţ ļîšţš one two t]';

  @override
  String get settingsShowRemoteCursors =>
      '[Šĥöŵ çöļļåƀöŕåţöŕ çûŕšöŕš one two t]';

  @override
  String get settingsSpelling => '[Šþéļļîñĝ one]';

  @override
  String get settingsUnderlineSpelling =>
      '[Ûñðéŕļîñé šþéļļîñĝ éŕŕöŕš one two t]';

  @override
  String get settingsAnimations => '[Åñîɱåţîöñš one]';

  @override
  String get settingsDefaultTransition => '[Ðéƒåûļţ ţŕåñšîţîöñ one tw]';

  @override
  String get settingsTransitionDuration => '[Ţŕåñšîţîöñ ðûŕåţîöñ one two]';

  @override
  String get settingsDefaultBuild => '[Ðéƒåûļţ ƀûîļð one t]';

  @override
  String get settingsPreviewOnHover =>
      '[Þŕéṽîéŵ åñîɱåţîöñš öñ ĥöṽéŕ one two t]';

  @override
  String get settingsReduceEditorMotion =>
      '[Ŕéðûçé ɱöţîöñ îñ ţĥé éðîţöŕ one two t]';

  @override
  String get settingsReduceEditorMotionHint =>
      '[Þŕéṽîéŵš šĥöŵ ţĥé éñð šţåţé îñšţéåð öƒ þļåýîñĝ. one two three]';

  @override
  String get settingsCode => '[Çöðé on]';

  @override
  String get settingsCodeFontSize => '[Çöðé ƒöñţ šîžé one t]';

  @override
  String get settingsCodeLanguage => '[Ðéƒåûļţ çöðé ļåñĝûåĝé one two]';

  @override
  String get settingsTypingSpeed => '[Ţýþé-îñ šþééð one t]';

  @override
  String get settingsTypeInSound => '[Ţýþé-îñ çļîçķ šöûñð one tw]';

  @override
  String get settingsPresenting => '[Þŕéšéñţîñĝ one]';

  @override
  String get settingsPresentingHint =>
      '[Ĥöŵ ýöû þŕéšéñţ. Ţĥé åûðîéñçé ṽîéŵ ƒöļļöŵš ţĥé þŕéšéñţåţîöñ. one two three four]';

  @override
  String get settingsPresenterLayout => '[Þŕéšéñţéŕ ṽîéŵ ļåýöûţ one two]';

  @override
  String get settingsNotesSize => '[Ñöţéš ţéẋţ šîžé one t]';

  @override
  String get settingsTimerMode => '[Ţîɱéŕ on]';

  @override
  String get settingsTimerTarget => '[Çöûñţðöŵñ ļéñĝţĥ one tw]';

  @override
  String get settingsLaserColor => '[Ļåšéŕ þöîñţéŕ çöļöŕ one tw]';

  @override
  String get settingsStartFullscreen =>
      '[Šţåŕţ þŕéšéñţîñĝ îñ ƒûļļ šçŕééñ one two th]';

  @override
  String get settingsStartWithPresenterView =>
      '[Šţåŕţ ŵîţĥ þŕéšéñţéŕ ṽîéŵ one two]';

  @override
  String get settingsShowSkippedInPresenter =>
      '[Šĥöŵ šķîþþéð šļîðéš îñ þŕéšéñţéŕ ṽîéŵ one two thre]';

  @override
  String get sizeWidescreen16x9 => '[Ŵîðéšçŕééñ 16:9 one t]';

  @override
  String get sizeStandard4x3 => '[Šţåñðåŕð 4:3 one]';

  @override
  String get sizeWide16x10 => '[Ŵîðéšçŕééñ 16:10 one tw]';

  @override
  String get sizeSquare => '[Šǫûåŕé 1:1 one]';

  @override
  String get sizePortrait9x16 => '[Þöŕţŕåîţ 9:16 one t]';

  @override
  String get sizeA4 => '[Å4 ļåñðšçåþé one]';

  @override
  String get sizeLetter => '[Ļéţţéŕ ļåñðšçåþé one tw]';

  @override
  String get sizeWidth => '[Ŵîðţĥ on]';

  @override
  String get sizeHeight => '[Ĥéîĝĥţ one]';

  @override
  String get slideUntitled => '[Ûñţîţļéð šļîðé one t]';

  @override
  String get spacingSingle => '[Šîñĝļé one]';

  @override
  String get spacingDouble => '[Ðöûƀļé one]';

  @override
  String get spacingCustom => '[Çûšţöɱ… one]';

  @override
  String get spacingAddBefore => '[Åðð šþåçé ƀéƒöŕé þåŕåĝŕåþĥ one two t]';

  @override
  String get spacingAddAfter => '[Åðð šþåçé åƒţéŕ þåŕåĝŕåþĥ one two]';

  @override
  String get speedSlow => '[Šļöŵ on]';

  @override
  String get speedNormal => '[Ñöŕɱåļ one]';

  @override
  String get speedFast => '[Ƒåšţ on]';

  @override
  String get statusNoSlides => '[Ñö šļîðéš one]';

  @override
  String statusSlideOf(int number, int total) {
    return '[Šļîðé $number öƒ $total one]';
  }

  @override
  String statusSkipped(int count) {
    return '[$count šķîþþéð one]';
  }

  @override
  String get styleTitle => '[Ţîţļé on]';

  @override
  String get styleSubtitle => '[Šûƀţîţļé one]';

  @override
  String get styleHeading => '[Ĥéåðîñĝ one]';

  @override
  String get styleBody => '[Ɓöðý on]';

  @override
  String get styleBody2 => '[Ɓöðý 2 on]';

  @override
  String get styleCaption => '[Çåþţîöñ one]';

  @override
  String get styleQuote => '[Ǫûöţé on]';

  @override
  String get styleAttribution => '[Åţţŕîƀûţîöñ one]';

  @override
  String get styleBigNumber => '[Ɓîĝ ñûɱƀéŕ one]';

  @override
  String get styleLabel => '[Ļåƀéļ on]';

  @override
  String get tableInsertRowAbove => '[Îñšéŕţ ŕöŵ åƀöṽé one t]';

  @override
  String get tableInsertRowBelow => '[Îñšéŕţ ŕöŵ ƀéļöŵ one t]';

  @override
  String get tableInsertColumnLeft => '[Îñšéŕţ çöļûɱñ ļéƒţ one tw]';

  @override
  String get tableInsertColumnRight => '[Îñšéŕţ çöļûɱñ ŕîĝĥţ one tw]';

  @override
  String get textSuperscript => '[Šûþéŕšçŕîþţ one]';

  @override
  String get textSubscript => '[Šûƀšçŕîþţ one]';

  @override
  String get timerElapsed => '[Éļåþšéð ţîɱé one]';

  @override
  String get timerCountdown => '[Çöûñţðöŵñ one]';

  @override
  String get toolbarLabel => '[Šļîðéš ţööļƀåŕ one t]';

  @override
  String get toolbarUndo => '[Ûñðö on]';

  @override
  String get toolbarRedo => '[Ŕéðö on]';

  @override
  String toolbarUndoLabel(String label) {
    return '[Ûñðö $label on]';
  }

  @override
  String toolbarRedoLabel(String label) {
    return '[Ŕéðö $label on]';
  }

  @override
  String get toolbarZoom => '[Žööɱ on]';

  @override
  String get toolbarAddComment => '[Åðð çöɱɱéñţ one]';

  @override
  String get toolbarAlign => '[Åļîĝñ on]';

  @override
  String get toolbarAnimate => '[Åñîɱåţé one]';

  @override
  String get toolbarBackground => '[Ɓåçķĝŕöûñð one]';

  @override
  String get toolbarLayout => '[Ļåýöûţ one]';

  @override
  String get toolbarTheme => '[Ţĥéɱé on]';

  @override
  String get toolbarTransition => '[Ţŕåñšîţîöñ one]';

  @override
  String get transitionNone => '[Ñöñé on]';

  @override
  String get transitionFade => '[Ƒåðé on]';

  @override
  String get transitionPush => '[Þûšĥ on]';

  @override
  String get transitionWipe => '[Ŵîþé on]';

  @override
  String get transitionDissolve => '[Ðîššöļṽé one]';

  @override
  String get unitsSu => '[Šļîðé ûñîţš one]';

  @override
  String get unitsPx => '[Þîẋéļš one]';

  @override
  String get unitsIn => '[Îñçĥéš one]';

  @override
  String get unitsCm => '[Çéñţîɱéţéŕš one]';

  @override
  String get viewNormal => '[Ñöŕɱåļ one]';

  @override
  String get viewGrid => '[Ĝŕîð on]';

  @override
  String get viewOutline => '[Öûţļîñé one]';

  @override
  String get zoomFit => '[Ƒîţ on]';

  @override
  String zoomPercent(int percent) {
    return '[$percent % o]';
  }

  @override
  String get toastUndoPartial =>
      '[Šöɱé çĥåñĝéš ŵéŕéñ’ţ ûñðöñé ƀéçåûšé å çöļļåƀöŕåţöŕ çĥåñĝéð ţĥéɱ šîñçé one two three four fi]';

  @override
  String get cmdSelectElements => '[Šéļéçţ öƀĵéçţš one t]';

  @override
  String get cmdSelectNext => '[Šéļéçţ ñéẋţ öƀĵéçţ one tw]';

  @override
  String get cmdSelectPrevious => '[Šéļéçţ þŕéṽîöûš öƀĵéçţ one two]';

  @override
  String get cmdElementMove => '[Ṁöṽé on]';

  @override
  String get cmdElementResize => '[Ŕéšîžé one]';

  @override
  String get cmdElementNudge => '[Ñûðĝé on]';

  @override
  String get cmdElementAdjust => '[Åðĵûšţ šĥåþé one]';

  @override
  String get cmdElementSetLineEnds => '[Ṁöṽé ļîñé éñð one]';

  @override
  String get cmdElementLock => '[Ļöçķ on]';

  @override
  String get cmdElementUnlock => '[Ûñļöçķ one]';

  @override
  String get cmdGuidesMove => '[Ṁöṽé ĝûîðé one]';

  @override
  String get cmdGuidesDelete => '[Ðéļéţé ĝûîðé one]';

  @override
  String get undoRotate => '[Ŕöţåţé one]';

  @override
  String get undoFlip => '[Ƒļîþ on]';

  @override
  String get reasonSelectObject => '[Šéļéçţ åñ öƀĵéçţ one t]';

  @override
  String get reasonSelectTwoObjects => '[Šéļéçţ åţ ļéåšţ 2 öƀĵéçţš one two]';

  @override
  String get reasonSelectThreeObjects => '[Šéļéçţ åţ ļéåšţ 3 öƀĵéçţš one two]';

  @override
  String get reasonObjectLocked => '[Ûñļöçķ ţĥé öƀĵéçţ ƒîŕšţ one two]';

  @override
  String get reasonInsideGroup =>
      '[Ñöţ åṽåîļåƀļé ƒöŕ öƀĵéçţš îñšîðé å ĝŕöûþ one two thre]';

  @override
  String get reasonSelectGroup => '[Šéļéçţ å ĝŕöûþ one t]';

  @override
  String get reasonNoLockedObjects =>
      '[Ñö ļöçķéð öƀĵéçţš öñ ţĥîš šļîðé one two th]';

  @override
  String get reasonNoGuides => '[Ţĥéŕé åŕé ñö ĝûîðéš one tw]';

  @override
  String get reasonNotOnCanvas => '[Ñöţ åṽåîļåƀļé ƒöŕ ţĥîš öƀĵéçţ one two t]';

  @override
  String get elementKindText => '[Ţéẋţ ƀöẋ one]';

  @override
  String get elementKindShape => '[Šĥåþé on]';

  @override
  String get elementKindLine => '[Ļîñé on]';

  @override
  String get elementKindImage => '[Îɱåĝé on]';

  @override
  String get elementKindTable => '[Ţåƀļé on]';

  @override
  String get elementKindCode => '[Çöðé on]';

  @override
  String get elementKindChart => '[Çĥåŕţ on]';

  @override
  String get elementKindIcon => '[Îçöñ on]';

  @override
  String get elementKindGroup => '[Ĝŕöûþ on]';

  @override
  String get elementKindPlaceholder => '[Þļåçéĥöļðéŕ one]';

  @override
  String canvasAnnounceSelected(String name, int index, int count) {
    return '[$name šéļéçţéð, $index öƒ $count öƀĵéçţš one two]';
  }

  @override
  String canvasAnnounceSelectedMany(int count) {
    return '[$count öƀĵéçţš šéļéçţéð one tw]';
  }

  @override
  String canvasAnnounceMoved(int x, int y) {
    return '[Ṁöṽéð ţö ẋ $x, ý $y one]';
  }

  @override
  String canvasElementSemantics(String name, String state) {
    return '[$name, $state o]';
  }

  @override
  String get canvasStateSelected => '[šéļéçţéð one]';

  @override
  String get canvasStateLocked => '[ļöçķéð one]';

  @override
  String canvasDimensions(int width, int height) {
    return '[$width × $height o]';
  }

  @override
  String canvasPosition(int x, int y) {
    return '[$x, $y o]';
  }

  @override
  String canvasAngle(int degrees) {
    return '[$degrees° o]';
  }

  @override
  String get cmdPrintPrint => '[Þŕîñţ ÞÐƑ one]';

  @override
  String get printPreviewTitle => '[Þŕîñţ þŕéṽîéŵ one t]';

  @override
  String printPreviewTitleWithName(String name) {
    return '[Þŕîñţ þŕéṽîéŵ — $name one t]';
  }

  @override
  String get printBack => '[Ɓåçķ ţö ţĥé þŕéšéñţåţîöñ one two]';

  @override
  String get printDownloadPdf => '[Ðöŵñļöåð ÞÐƑ one]';

  @override
  String get printPrint => '[Þŕîñţ on]';

  @override
  String get printSettings => '[Šéţţîñĝš one]';

  @override
  String get printShowPreview => '[Šĥöŵ þŕéṽîéŵ one]';

  @override
  String printPageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count þåĝéš',
      one: '1 þåĝé',
    );
    return '[$_temp0 one]';
  }

  @override
  String get printUpdatingPreview => '[Ûþðåţîñĝ þŕéṽîéŵ… one tw]';

  @override
  String get printLoadingDeck => '[Ļöåðîñĝ þŕéšéñţåţîöñ… one two]';

  @override
  String get printPreviewFailed =>
      '[Ţĥé þŕéṽîéŵ çöûļð ñöţ ƀé çŕéåţéð one two th]';

  @override
  String get printTryAgain => '[Ţŕý åĝåîñ one]';

  @override
  String get printDownloadsDisabledTitle =>
      '[Ðöŵñļöåðš åŕé ţûŕñéð öƒƒ one two]';

  @override
  String get printDownloadsDisabledBody =>
      '[Ţĥé öŵñéŕ ĥåš ţûŕñéð öƒƒ ðöŵñļöåðîñĝ åñð þŕîñţîñĝ ƒöŕ ṽîéŵéŕš åñð çöɱɱéñţéŕš. one two three four five]';

  @override
  String get printUnavailableTitle =>
      '[Þŕîñţîñĝ îšñ\'ţ åṽåîļåƀļé ĥéŕé one two th]';

  @override
  String get printUnavailableBody =>
      '[Ðöŵñļöåð ţĥé ÞÐƑ åñð þŕîñţ îţ ƒŕöɱ ýöûŕ ÞÐƑ ṽîéŵéŕ. one two three f]';

  @override
  String get printPdfPreviewLabel => '[ÞÐƑ þŕéṽîéŵ one]';

  @override
  String get printPdfReady => '[Ţĥé ÞÐƑ îš ŕéåðý one t]';

  @override
  String printPdfReadyPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ţĥé ÞÐƑ îš ŕéåðý: $count þåĝéš',
      one: 'Ţĥé ÞÐƑ îš ŕéåðý: 1 þåĝé',
    );
    return '[$_temp0 one two three]';
  }

  @override
  String get printPdfDesktopHint =>
      '[Ðöŵñļöåð ţĥé ÞÐƑ ţö ṽîéŵ öŕ þŕîñţ îţ. one two thr]';

  @override
  String get printLayout => '[Ļåýöûţ one]';

  @override
  String get printLayoutSlides => '[Šļîðéš one]';

  @override
  String get printLayoutNotes => '[Ñöţéš þåĝéš one]';

  @override
  String get printLayoutHandouts => '[Ĥåñðöûţš one]';

  @override
  String get printPerPage => '[Šļîðéš þéŕ þåĝé one t]';

  @override
  String get printOrder => '[Öŕðéŕ on]';

  @override
  String get printOrderHorizontal => '[Åçŕöšš, ţĥéñ ðöŵñ one tw]';

  @override
  String get printOrderVertical => '[Ðöŵñ, ţĥéñ åçŕöšš one tw]';

  @override
  String get printRange => '[Šļîðéš ţö þŕîñţ one t]';

  @override
  String get printRangeAll => '[Åļļ šļîðéš one]';

  @override
  String get printRangeCurrent => '[Çûŕŕéñţ šļîðé one t]';

  @override
  String get printRangeSelection => '[Šéļéçţéð šļîðéš one t]';

  @override
  String get printRangeCustom => '[Çûšţöɱ ŕåñĝé one]';

  @override
  String get printRangeHint => '[é.ĝ. 1-3, 7 one]';

  @override
  String get printRangeInvalid =>
      '[Éñţéŕ šļîðé ñûɱƀéŕš ļîķé 1-3, 7 one two th]';

  @override
  String get printPaper => '[Þåþéŕ on]';

  @override
  String get printPaperSlide => '[Šļîðé šîžé one]';

  @override
  String get printPaperLetter => '[Ļéţţéŕ one]';

  @override
  String get printPaperLegal => '[Ļéĝåļ on]';

  @override
  String get printPaperTabloid => '[Ţåƀļöîð one]';

  @override
  String get printOrientation => '[Öŕîéñţåţîöñ one]';

  @override
  String get printOrientationAuto => '[Åûţöɱåţîç one]';

  @override
  String get printOrientationPortrait => '[Þöŕţŕåîţ one]';

  @override
  String get printOrientationLandscape => '[Ļåñðšçåþé one]';

  @override
  String get printMargins => '[Ṁåŕĝîñš one]';

  @override
  String get printMarginsNone => '[Ñöñé on]';

  @override
  String get printMarginsNarrow => '[Ñåŕŕöŵ one]';

  @override
  String get printMarginsNormal => '[Ñöŕɱåļ one]';

  @override
  String get printBuilds => '[Þŕîñţ éåçĥ ƀûîļð šţåĝé one two]';

  @override
  String get printSkipped => '[Îñçļûðé šķîþþéð šļîðéš one two]';

  @override
  String get printFrame => '[Ƒŕåɱé šļîðéš one]';

  @override
  String get printHeaderFooter => '[Ĥéåðéŕ åñð ƒööţéŕ one tw]';

  @override
  String get printSlideNumbers => '[Šļîðé ñûɱƀéŕš one t]';

  @override
  String get printBookmarks =>
      '[Ɓööķɱåŕķš ƒöŕ šéçţîöñš åñð šļîðéš one two thr]';

  @override
  String get printLinks => '[Çļîçķåƀļé ļîñķš one t]';

  @override
  String get printInkSaver => '[Îñķ šåṽéŕ (ñö šļîðé ƀåçķĝŕöûñðš) one two th]';

  @override
  String get printQuality => '[Îɱåĝé ǫûåļîţý one t]';

  @override
  String get printQualityHigh => '[Ĥîĝĥ on]';

  @override
  String get printQualityCompact => '[Çöɱþåçţ (šɱåļļéŕ ƒîļé) one two]';

  @override
  String get printWarnings => '[Åƀöûţ ţĥîš ÞÐƑ one t]';

  @override
  String get printWarningFonts =>
      '[Å ƒöñţ çöûļð ñöţ ƀé éɱƀéððéð; å šţåñðåŕð ƒöñţ ŵåš ûšéð. one two three fo]';

  @override
  String get printWarningGlyphs =>
      '[Šöɱé çĥåŕåçţéŕš ĥåṽé ñö ĝļýþĥ îñ ţĥé éɱƀéððéð ƒöñţš. one two three fo]';

  @override
  String get printWarningIcons => '[Šöɱé îçöñš çöûļð ñöţ ƀé ðŕåŵñ. one two t]';

  @override
  String get printWarningImages =>
      '[Šöɱé îɱåĝéš çöûļð ñöţ ƀé ļöåðéð. one two th]';

  @override
  String get printWarningLinks =>
      '[Ļîñķš ţö šļîðéš ţĥåţ åŕé ñöţ þŕîñţéð ŵéŕé ŕéɱöṽéð. one two three f]';

  @override
  String get printWarningPages =>
      '[Öñļý ţĥé ƒîŕšţ 500 þåĝéš ŵéŕé éẋþöŕţéð. one two thre]';

  @override
  String get printWarningEmpty =>
      '[Ñö šļîðéš ɱåţçĥ ţĥéšé šéţţîñĝš. one two th]';

  @override
  String exportedToast(String name) {
    return '[Éẋþöŕţéð “$name” one]';
  }

  @override
  String get exportFailed => '[Ţĥé éẋþöŕţ ƒåîļéð one tw]';

  @override
  String get exportFormatUnavailable =>
      '[Ţĥîš ƒöŕɱåţ îš ñöţ åṽåîļåƀļé ýéţ one two th]';

  @override
  String pdfSlide(int number) {
    return '[Šļîðé $number on]';
  }

  @override
  String pdfNotesContinued(int number) {
    return '[Ñöţéš (çöñţîñûéð) — Šļîðé $number one two]';
  }

  @override
  String pdfPageOf(int page, int count) {
    return '[Þåĝé $page öƒ $count one]';
  }

  @override
  String get pdfUntitledSection => '[Ûñţîţļéð šéçţîöñ one tw]';

  @override
  String get pdfUntitledPresentation => '[Ûñţîţļéð þŕéšéñţåţîöñ one two]';

  @override
  String get cmdGroupRename => '[Ŕéñåɱé ĝŕöûþ one]';

  @override
  String get cmdGroupMove => '[Ṁöṽé ĝŕöûþ one]';

  @override
  String get cmdGroupToggleCollapsed => '[Çöļļåþšé öŕ éẋþåñð ĝŕöûþ one two]';

  @override
  String get cmdNavSelectAllSlides => '[Šéļéçţ åļļ šļîðéš one tw]';

  @override
  String get cmdNavigatorCopy => '[Çöþý šļîðéš one]';

  @override
  String get cmdNavigatorCut => '[Çûţ šļîðéš one]';

  @override
  String get cmdNavigatorPaste => '[Þåšţé šļîðéš one]';

  @override
  String get cmdNotesZoom => '[Šþéåķéŕ ñöţéš žööɱ one tw]';

  @override
  String cmdSlideDeleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ðéļéţé $count šļîðéš',
      one: 'Ðéļéţé šļîðé',
    );
    return '[$_temp0 one two t]';
  }

  @override
  String cmdSlideDuplicateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ðûþļîçåţé $count šļîðéš',
      one: 'Ðûþļîçåţé šļîðé',
    );
    return '[$_temp0 one two thr]';
  }

  @override
  String get cmdEditNotes => '[Éðîţ šþéåķéŕ ñöţéš one tw]';

  @override
  String get reasonSelectSlides =>
      '[Šéļéçţ šļîðéš îñ ţĥé ñåṽîĝåţöŕ one two th]';

  @override
  String get reasonAlreadyGroup =>
      '[Ţĥéšé šļîðéš åŕé åļŕéåðý å ĝŕöûþ one two th]';

  @override
  String get reasonSkippedWithGroup => '[Šķîþþéð ŵîţĥ ĝŕöûþ one tw]';

  @override
  String get reasonNotInGroup => '[Ţĥé šļîðé îšñ’ţ îñ å ĝŕöûþ one two]';

  @override
  String get reasonNoGroups => '[Ţĥé þŕéšéñţåţîöñ ĥåš ñö ĝŕöûþš one two th]';

  @override
  String get reasonGroupsCantNest => '[Ĝŕöûþš çåñ’ţ ƀé ñéšţéð one two]';

  @override
  String get reasonCantMoveFurther =>
      '[Ţĥé šļîðéš çåñ’ţ ɱöṽé ƒûŕţĥéŕ one two t]';

  @override
  String get reasonClipboardNoSlides =>
      '[Çöþý šļîðéš öŕ ĝŕöûþš ƒîŕšţ one two t]';

  @override
  String get reasonAllCollapsed =>
      '[Ţĥé ĝŕöûþ îš åļŕéåðý çöļļåþšéð one two th]';

  @override
  String get reasonAllExpanded => '[Ţĥé ĝŕöûþ îš åļŕéåðý éẋþåñðéð one two t]';

  @override
  String get navigatorDropHere => '[Ðŕöþ šļîðéš ĥéŕé one t]';

  @override
  String get navigatorNewSlideLayout => '[Ñéŵ šļîðé ŵîţĥ ļåýöûţ one two]';

  @override
  String navigatorDragSlides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count šļîðéš',
      one: '1 šļîðé',
    );
    return '[$_temp0 one t]';
  }

  @override
  String navigatorDragGroup(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count šļîðéš',
      one: '1 šļîðé',
    );
    return '[$title · $_temp0 one t]';
  }

  @override
  String get navigatorGroupExpanded => '[éẋþåñðéð one]';

  @override
  String get navigatorGroupCollapsed => '[çöļļåþšéð one]';

  @override
  String get navigatorSkipped => '[šķîþþéð one]';

  @override
  String navigatorSlideInGroupSemantics(
    int number,
    int total,
    String group,
    String title,
  ) {
    return '[Šļîðé $number öƒ $total, îñ ĝŕöûþ $group: $title one tw]';
  }

  @override
  String get navigatorGroupMenu => '[Ĝŕöûþ åçţîöñš one t]';

  @override
  String get navigatorSlideMenu => '[Šļîðé åçţîöñš one t]';

  @override
  String get navigatorCollapseGroup =>
      '[Çöļļåþšé ĝŕöûþ (Åļţ+çļîçķ: åļļ ĝŕöûþš) one two thre]';

  @override
  String get navigatorExpandGroup =>
      '[Éẋþåñð ĝŕöûþ (Åļţ+çļîçķ: åļļ ĝŕöûþš) one two thre]';

  @override
  String get navigatorGroupColor => '[Ĝŕöûþ çöļöŕ one]';

  @override
  String get navigatorRenameField => '[Ĝŕöûþ ñåɱé one]';

  @override
  String get navigatorSkippedWithGroup => '[Šķîþþéð ŵîţĥ ĝŕöûþ one tw]';

  @override
  String deleteGroupTitle(String title) {
    return '[Ðéļéţé ĝŕöûþ ‘$title’? one t]';
  }

  @override
  String deleteGroupBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ţĥé ĝŕöûþ çöñţåîñš $count šļîðéš.',
      one: 'Ţĥé ĝŕöûþ çöñţåîñš 1 šļîðé.',
    );
    return '[$_temp0 one two three fou]';
  }

  @override
  String deleteGroupsTitle(int count) {
    return '[Ðéļéţé $count ĝŕöûþš? one t]';
  }

  @override
  String get deleteGroupUngroupOnly => '[Ûñĝŕöûþ öñļý one]';

  @override
  String deleteGroupWithSlides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ðéļéţé ĝŕöûþ åñð $count šļîðéš',
      one: 'Ðéļéţé ĝŕöûþ åñð 1 šļîðé',
    );
    return '[$_temp0 one two three]';
  }

  @override
  String get toastGroupDeleted => '[Ĝŕöûþ ðéļéţéð one t]';

  @override
  String get chooseGroupTitle => '[Åðð ţö ĝŕöûþ one]';

  @override
  String get chooseGroupLabel => '[Ĝŕöûþ on]';

  @override
  String get chooseGroupButton => '[Åðð on]';

  @override
  String get gridThumbSize => '[Ţĥûɱƀñåîļ šîžé one t]';

  @override
  String get gridOpenHint => '[Ðöûƀļé-çļîçķ å šļîðé ţö öþéñ îţ one two th]';

  @override
  String get notesBold => '[Ɓöļð on]';

  @override
  String get notesItalic => '[Îţåļîç one]';

  @override
  String get notesUnderline => '[Ûñðéŕļîñé one]';

  @override
  String get notesBulletList => '[Ɓûļļéţéð ļîšţ one t]';

  @override
  String get notesNumberedList => '[Ñûɱƀéŕéð ļîšţ one t]';

  @override
  String get notesLink => '[Ļîñķ on]';

  @override
  String get notesLinkTitle => '[Ļîñķ on]';

  @override
  String get notesLinkUrl => '[ÛŔĻ on]';

  @override
  String get notesLinkApply => '[Åþþļý on]';

  @override
  String get notesLinkRemove => '[Ŕéɱöṽé ļîñķ one]';

  @override
  String get notesLinkInvalid => '[Éñţéŕ åñ ĥţţþ öŕ ĥţţþš åððŕéšš one two t]';

  @override
  String get notesReadOnly => '[Ṽîéŵ öñļý one]';

  @override
  String get notesNoSlide => '[Ñö šļîðé šéļéçţéð one tw]';

  @override
  String get undoTyping => '[Ţýþîñĝ one]';

  @override
  String get dialogApply => '[Åþþļý on]';

  @override
  String get linkDialogTitle => '[Ļîñķ on]';

  @override
  String get linkTargetLabel => '[Ļîñķ ţö one]';

  @override
  String get linkTargetUrl => '[Ŵéƀ åððŕéšš one]';

  @override
  String get linkUrlLabel => '[Åððŕéšš one]';

  @override
  String get linkRemove => '[Ŕéɱöṽé ļîñķ one]';

  @override
  String get linkActionNext => '[Ñéẋţ šļîðé one]';

  @override
  String get linkActionPrevious => '[Þŕéṽîöûš šļîðé one t]';

  @override
  String get linkActionFirst => '[Ƒîŕšţ šļîðé one]';

  @override
  String get linkActionLast => '[Ļåšţ šļîðé one]';

  @override
  String get linkActionEnd => '[Éñð šĥöŵ one]';

  @override
  String get fontLabel => '[Ƒöñţ on]';

  @override
  String get fontSizeLabel => '[Šîžé on]';

  @override
  String get colorLabel =>
      '[Çöļöŕ (#ŔŔĜĜƁƁ öŕ ţĥéɱé:åççéñţ1; éɱþţý = åûţöɱåţîç) one two three fo]';

  @override
  String get lineHeightLabel => '[Ļîñé šþåçîñĝ one]';

  @override
  String get listStyleLabel => '[Šţýļé on]';

  @override
  String get listStartLabel => '[Šţåŕţ ñûɱƀéŕîñĝ åţ one tw]';

  @override
  String get fontThemeHeading => '[Ţĥéɱé ĥéåðîñĝ ƒöñţ one tw]';

  @override
  String get fontThemeBody => '[Ţĥéɱé ƀöðý ƒöñţ one t]';

  @override
  String get fontThemeMono => '[Ţĥéɱé ɱöñöšþåçé ƒöñţ one two]';

  @override
  String get listStyleDisc => '[Ðîšç on]';

  @override
  String get listStyleCircle => '[Çîŕçļé one]';

  @override
  String get listStyleSquare => '[Šǫûåŕé one]';

  @override
  String get listStyleDash => '[Ðåšĥ on]';

  @override
  String get listStyleArrow => '[Åŕŕöŵ on]';

  @override
  String get listStyleCheck => '[Çĥéçķ ɱåŕķ one]';

  @override
  String get listStyleStar => '[Šţåŕ on]';

  @override
  String get listStyleNone => '[Ñö ƀûļļéţ one]';

  @override
  String get cmdFormatLetterSpacing => '[Ļéţţéŕ šþåçîñĝ one t]';

  @override
  String get cmdFormatInsets => '[Ţéẋţ îñšéţš one]';

  @override
  String get cmdTextExitEditing => '[Éẋîţ ţéẋţ éðîţîñĝ one tw]';

  @override
  String get cmdTextRemoveLink => '[Ŕéɱöṽé ļîñķ ƒŕöɱ ţéẋţ one two]';

  @override
  String get reasonNotEditingText => '[Ñö ţéẋţ îš ƀéîñĝ éðîţéð one two]';

  @override
  String get reasonSelectText => '[Šéļéçţ ţéẋţ öŕ å ţéẋţ ƀöẋ one two]';

  @override
  String get reasonSelectTextOrObject => '[Šéļéçţ ţéẋţ öŕ åñ öƀĵéçţ one two]';

  @override
  String get reasonNoLink => '[Ţĥé šéļéçţîöñ ĥåš ñö ļîñķ one two]';

  @override
  String get reasonSelectPlaceholder => '[Šéļéçţ å þļåçéĥöļðéŕ one two]';

  @override
  String toastSkippedLocked(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Šķîþþéð $count ţéẋţ ƀöẋéš öţĥéŕš åŕé éðîţîñĝ',
      one: 'Šķîþþéð 1 ţéẋţ ƀöẋ $name îš éðîţîñĝ',
    );
    return '[$_temp0 one two three four f]';
  }

  @override
  String validationNumberRange(String min, String max) {
    return '[Éñţéŕ å ñûɱƀéŕ ƒŕöɱ $min ţö $max one two]';
  }

  @override
  String slideNumberLabel(int number) {
    return '[Šļîðé $number on]';
  }

  @override
  String get themeColorBg1 => '[Ɓåçķĝŕöûñð 1 one]';

  @override
  String get themeColorBg2 => '[Ɓåçķĝŕöûñð 2 one]';

  @override
  String get themeColorText1 => '[Ţéẋţ 1 on]';

  @override
  String get themeColorText2 => '[Ţéẋţ 2 on]';

  @override
  String themeColorAccent(int n) {
    return '[Åççéñţ $n one]';
  }

  @override
  String get themeColorLink => '[Ļîñķ on]';

  @override
  String shapeName(String geometry) {
    String _temp0 = intl.Intl.selectLogic(geometry, {
      'rect': 'Ŕéçţåñĝļé',
      'roundRect': 'Ŕöûñðéð ŕéçţåñĝļé',
      'ellipse': 'Éļļîþšé',
      'triangle': 'Ţŕîåñĝļé',
      'rightTriangle': 'Ŕîĝĥţ ţŕîåñĝļé',
      'diamond': 'Ðîåɱöñð',
      'pentagon': 'Þéñţåĝöñ',
      'hexagon': 'Ĥéẋåĝöñ',
      'octagon': 'Öçţåĝöñ',
      'parallelogram': 'Þåŕåļļéļöĝŕåɱ',
      'trapezoid': 'Ţŕåþéžöîð',
      'donut': 'Ðöñûţ',
      'arc': 'Åŕç',
      'blockArc': 'Ɓļöçķ åŕç',
      'pie': 'Þîé',
      'chord': 'Çĥöŕð',
      'frame': 'Ƒŕåɱé',
      'halfFrame': 'Ĥåļƒ ƒŕåɱé',
      'plus': 'Þļûš',
      'cross': 'Çŕöšš',
      'cylinder': 'Çýļîñðéŕ',
      'cube': 'Çûƀé',
      'can': 'Çåñ',
      'heart': 'Ĥéåŕţ',
      'cloud': 'Çļöûð',
      'moon': 'Ṁööñ',
      'sun': 'Šûñ',
      'lightning': 'Ļîĝĥţñîñĝ ƀöļţ',
      'arrowRight': 'Ŕîĝĥţ åŕŕöŵ',
      'arrowLeft': 'Ļéƒţ åŕŕöŵ',
      'arrowUp': 'Ûþ åŕŕöŵ',
      'arrowDown': 'Ðöŵñ åŕŕöŵ',
      'arrowLeftRight': 'Ļéƒţ-ŕîĝĥţ åŕŕöŵ',
      'arrowUpDown': 'Ûþ-ðöŵñ åŕŕöŵ',
      'chevron': 'Çĥéṽŕöñ',
      'homePlate': 'Þéñţåĝöñ åŕŕöŵ',
      'notchedArrow': 'Ñöţçĥéð åŕŕöŵ',
      'curvedArrow': 'Çûŕṽéð åŕŕöŵ',
      'circularArrow': 'Çîŕçûļåŕ åŕŕöŵ',
      'uTurn': 'Û-ţûŕñ åŕŕöŵ',
      'star4': '4-þöîñţ šţåŕ',
      'star5': '5-þöîñţ šţåŕ',
      'star6': '6-þöîñţ šţåŕ',
      'star8': '8-þöîñţ šţåŕ',
      'star12': '12-þöîñţ šţåŕ',
      'burst': 'Ɓûŕšţ',
      'ribbon': 'Ŕîƀƀöñ',
      'wave': 'Ŵåṽé',
      'seal': 'Šéåļ',
      'speech': 'Šþééçĥ ƀûƀƀļé',
      'speechRound': 'Ŕöûñð šþééçĥ ƀûƀƀļé',
      'thought': 'Ţĥöûĝĥţ ƀûƀƀļé',
      'calloutRect': 'Ŕéçţåñĝûļåŕ çåļļöûţ',
      'calloutLine': 'Ļîñé çåļļöûţ',
      'banner': 'Ɓåññéŕ',
      'process': 'Þŕöçéšš',
      'decision': 'Ðéçîšîöñ',
      'terminator': 'Ţéŕɱîñåţöŕ',
      'document': 'Ðöçûɱéñţ',
      'data': 'Ðåţå',
      'manualInput': 'Ṁåñûåļ îñþûţ',
      'predefinedProcess': 'Þŕéðéƒîñéð þŕöçéšš',
      'connector': 'Çöññéçţöŕ',
      'offPage': 'Öƒƒ-þåĝé çöññéçţöŕ',
      'delay': 'Ðéļåý',
      'storage': 'Šţöŕéð ðåţå',
      'brace': 'Ɓŕåçé',
      'bracket': 'Ɓŕåçķéţ',
      'doubleBrace': 'Ðöûƀļé ƀŕåçé',
      'custom': 'Çûšţöɱ šĥåþé',
      'other': 'Šĥåþé',
    });
    return '[$_temp0 one two three four five six seven eight nine ten one two three four five six seven eight nine ten one two three four five six seven eight nine ten one two three four five six seven eight nine ten one two three four fiv]';
  }

  @override
  String shapeCategory(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'basic': 'Ɓåšîç šĥåþéš',
      'arrows': 'Åŕŕöŵš',
      'stars': 'Šţåŕš åñð ƀåðĝéš',
      'callouts': 'Çåļļöûţš',
      'flowchart': 'Ƒļöŵçĥåŕţ',
      'brackets': 'Ɓŕåçķéţš',
      'custom': 'Çûšţöɱ',
      'other': 'Šĥåþéš',
    });
    return '[$_temp0 one two three four five]';
  }

  @override
  String iconCategory(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'all': 'Åļļ îçöñš',
      'recent': 'Ŕéçéñţļý ûšéð',
      'arrows': 'Åŕŕöŵš',
      'business': 'Ɓûšîñéšš',
      'charts': 'Çĥåŕţš',
      'communication': 'Çöɱɱûñîçåţîöñ',
      'devices': 'Ðéṽîçéš',
      'development': 'Ðéṽéļöþɱéñţ',
      'files': 'Ƒîļéš',
      'food': 'Ƒööð åñð ðŕîñķ',
      'media': 'Ṁéðîå',
      'nature': 'Ñåţûŕé',
      'people': 'Þéöþļé',
      'security': 'Šéçûŕîţý',
      'shapes': 'Šĥåþéš',
      'text': 'Ţéẋţ',
      'clock': 'Ţîɱé',
      'tools': 'Ţööļš',
      'travel': 'Ţŕåṽéļ',
      'weather': 'Ŵéåţĥéŕ',
      'other': 'Îçöñš',
    });
    return '[$_temp0 one two three four five six seven eight nine ten one]';
  }

  @override
  String arrowStyleName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'none': 'Ñöñé',
      'triangle': 'Åŕŕöŵ',
      'open': 'Öþéñ åŕŕöŵ',
      'stealth': 'Šţéåļţĥ åŕŕöŵ',
      'circle': 'Çîŕçļé',
      'diamond': 'Ðîåɱöñð',
      'bar': 'Ɓåŕ',
      'other': 'Åŕŕöŵ',
    });
    return '[$_temp0 one two three four]';
  }

  @override
  String arrowSizeName(String size) {
    String _temp0 = intl.Intl.selectLogic(size, {
      's': 'Šɱåļļ',
      'm': 'Ṁéðîûɱ',
      'l': 'Ļåŕĝé',
      'other': 'Ṁéðîûɱ',
    });
    return '[$_temp0 one two]';
  }

  @override
  String dashName(String dash) {
    String _temp0 = intl.Intl.selectLogic(dash, {
      'solid': 'Šöļîð',
      'dash': 'Ðåšĥéð',
      'dot': 'Ðöţţéð',
      'dashDot': 'Ðåšĥ-ðöţ',
      'longDash': 'Ļöñĝ ðåšĥ',
      'other': 'Šöļîð',
    });
    return '[$_temp0 one two three]';
  }

  @override
  String capName(String cap) {
    String _temp0 = intl.Intl.selectLogic(cap, {
      'butt': 'Ƒļåţ',
      'round': 'Ŕöûñð',
      'square': 'Šǫûåŕé',
      'other': 'Ƒļåţ',
    });
    return '[$_temp0 one two]';
  }

  @override
  String routingName(String routing) {
    String _temp0 = intl.Intl.selectLogic(routing, {
      'straight': 'Šţŕåîĝĥţ',
      'elbow': 'Éļƀöŵ',
      'curved': 'Çûŕṽéð',
      'other': 'Šţŕåîĝĥţ',
    });
    return '[$_temp0 one two th]';
  }

  @override
  String quickStyleName(String index) {
    String _temp0 = intl.Intl.selectLogic(index, {
      '0': 'Åççéñţ 1',
      '1': 'Åççéñţ 2',
      '2': 'Åççéñţ 3',
      '3': 'Åççéñţ 4',
      '4': 'Åççéñţ 5',
      '5': 'Åççéñţ 6',
      '6': 'Öûţļîñé',
      '7': 'Šöƒţ ţîñţ',
      'other': 'Šţýļé',
    });
    return '[$_temp0 one two three four fiv]';
  }

  @override
  String strokeWidthLabel(String width) {
    return '[$width þţ o]';
  }

  @override
  String get cmdIconReplace => '[Ŕéþļåçé îçöñ… one t]';

  @override
  String get cmdIconSetStrokeWidth => '[Îçöñ šţŕöķé ŵîðţĥ one tw]';

  @override
  String get cmdElementRename => '[Ŕéñåɱé öƀĵéçţ one t]';

  @override
  String get menuChangeShape => '[Çĥåñĝé šĥåþé one]';

  @override
  String get menuQuickStyles => '[Ǫûîçķ šţýļéš one]';

  @override
  String get menuRouting => '[Ŕöûţîñĝ one]';

  @override
  String get menuWeight => '[Ŵéîĝĥţ one]';

  @override
  String get menuDash => '[Ðåšĥ on]';

  @override
  String get menuBorderColor => '[Ɓöŕðéŕ çöļöŕ one]';

  @override
  String get menuLineColor => '[Ļîñé çöļöŕ one]';

  @override
  String get menuFillColor => '[Ƒîļļ çöļöŕ one]';

  @override
  String get menuIconColor => '[Îçöñ çöļöŕ one]';

  @override
  String get colorThemeDefault => '[Ţĥéɱé ðéƒåûļţ one t]';

  @override
  String get styleLabelColor => '[Çöļöŕ on]';

  @override
  String get styleLabelWeight => '[Ŵéîĝĥţ one]';

  @override
  String get styleLabelDash => '[Ðåšĥ on]';

  @override
  String get styleLabelCap => '[Éñðš on]';

  @override
  String get styleLabelArrowSize => '[Åŕŕöŵ šîžé one]';

  @override
  String get styleLabelRouting => '[Ŕöûţîñĝ one]';

  @override
  String get styleLabelShadow => '[Šĥåðöŵ one]';

  @override
  String get styleLabelGlow => '[Ĝļöŵ on]';

  @override
  String get styleLabelOpacity => '[Öþåçîţý one]';

  @override
  String get styleLabelNoFill => '[Ñö ƒîļļ one]';

  @override
  String get styleLabelNoBorder => '[Ñö ƀöŕðéŕ one]';

  @override
  String get styleLabelGeometry => '[Šĥåþé on]';

  @override
  String get styleLabelStrokeWidth => '[Šţŕöķé ŵîðţĥ one]';

  @override
  String get styleLabelIcon => '[Îçöñ on]';

  @override
  String get styleMixed => '[Ṁîẋéð on]';

  @override
  String get arrangeLabelX => '[Ẋ o]';

  @override
  String get arrangeLabelY => '[Ý o]';

  @override
  String get arrangeLabelW => '[Ŵ o]';

  @override
  String get arrangeLabelH => '[Ĥ o]';

  @override
  String get arrangeLabelRotation => '[Ŕöţåţîöñ one]';

  @override
  String get arrangeLabelName => '[Ñåɱé on]';

  @override
  String get arrangeEditInsideGroup => '[Éðîţ îñšîðé ĝŕöûþ one tw]';

  @override
  String get arrangeLocked => '[Ļöçķéð one]';

  @override
  String get accessibilityAltText => '[Åļţ ţéẋţ one]';

  @override
  String get accessibilityAltTextHint =>
      '[Ðéšçŕîƀé ţĥé öƀĵéçţ ƒöŕ þéöþļé ûšîñĝ šçŕééñ ŕéåðéŕš one two three fo]';

  @override
  String get accessibilityDecorative => '[Ðéçöŕåţîṽé one]';

  @override
  String accessibilityReadingOrder(int position, int count) {
    return '[Ŕéåðîñĝ öŕðéŕ: $position öƒ $count one tw]';
  }

  @override
  String get altTextDialogTitle => '[Åļţ ţéẋţ one]';

  @override
  String get altTextDialogDecorative =>
      '[Ṁåŕķ åš ðéçöŕåţîṽé (šçŕééñ ŕéåðéŕš šķîþ îţ) one two three]';

  @override
  String get dialogSave => '[Šåṽé on]';

  @override
  String get iconPickerTitle => '[Îñšéŕţ îçöñ one]';

  @override
  String get iconPickerReplaceTitle => '[Ŕéþļåçé îçöñ one]';

  @override
  String get iconPickerSearch => '[Šéåŕçĥ îçöñš one]';

  @override
  String iconPickerEmpty(String query) {
    return '[Ñö îçöñš ɱåţçĥ “$query” one t]';
  }

  @override
  String iconPickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count îçöñš',
      one: '1 îçöñ',
    );
    return '[$_temp0 one]';
  }

  @override
  String get iconPickerRecentEmpty =>
      '[Îçöñš ýöû îñšéŕţ šĥöŵ ûþ ĥéŕé one two t]';

  @override
  String get iconPickerStroke => '[Šţŕöķé one]';

  @override
  String get iconPickerColor => '[Çöļöŕ on]';

  @override
  String get iconPickerCategory => '[Çåţéĝöŕý one]';

  @override
  String get iconPickerInsert => '[Îñšéŕţ one]';

  @override
  String get iconPickerReplace => '[Ŕéþļåçé one]';

  @override
  String get shapeGalleryTitle => '[Šĥåþéš one]';

  @override
  String get shapeGalleryChoose => '[Çĥööšé one]';

  @override
  String get reasonSelectShape => '[Šéļéçţ å šĥåþé one t]';

  @override
  String get reasonSelectLine => '[Šéļéçţ å ļîñé one]';

  @override
  String get reasonSelectIcon => '[Šéļéçţ åñ îçöñ one t]';

  @override
  String get reasonSelectOneObject => '[Šéļéçţ öñé öƀĵéçţ one tw]';

  @override
  String get reasonNoFill => '[Šéļéçţ å šĥåþé, ţéẋţ ƀöẋ öŕ îçöñ one two th]';

  @override
  String get reasonNoBorder =>
      '[Šéļéçţ å šĥåþé, ļîñé, ţéẋţ ƀöẋ, îɱåĝé öŕ îçöñ one two three]';

  @override
  String get reasonPlaceholdersCantGroup =>
      '[Þļåçéĥöļðéŕš çåñ\'ţ ƀé ĝŕöûþéð one two th]';

  @override
  String get reasonSameLevel => '[Šéļéçţ öƀĵéçţš îñ ţĥé šåɱé ĝŕöûþ one two th]';

  @override
  String get reasonNoStyleCopied => '[Çöþý å šţýļé ƒîŕšţ one tw]';

  @override
  String get painterArmed =>
      '[Çļîçķ åñ öƀĵéçţ ţö åþþļý ţĥé ƒöŕɱåţ one two thr]';

  @override
  String get toolArmedShape =>
      '[Çļîçķ öŕ ðŕåĝ öñ ţĥé šļîðé ţö îñšéŕţ ţĥé šĥåþé one two three]';

  @override
  String get toolArmedLine => '[Ðŕåĝ öñ ţĥé šļîðé ţö ðŕåŵ ţĥé ļîñé one two th]';

  @override
  String get colorAutomatic => '[Åûţöɱåţîç one]';

  @override
  String get inspectorMixed => '[Ṁîẋéð on]';

  @override
  String get spacingBeforeLabel => '[Šþåçé ƀéƒöŕé one]';

  @override
  String get spacingAfterLabel => '[Šþåçé åƒţéŕ one]';

  @override
  String get reasonSelectImage => '[Šéļéçţ åñ îɱåĝé one t]';

  @override
  String get reasonNoDownload =>
      '[Ðöŵñļöåðîñĝ îšñ\'ţ åļļöŵéð ƒöŕ ţĥîš þŕéšéñţåţîöñ one two three f]';

  @override
  String get reasonSelectTable => '[Šéļéçţ å ţåƀļé one t]';

  @override
  String get reasonSelectCells => '[Šéļéçţ ţåƀļé çéļļš one tw]';

  @override
  String get reasonNoMergedCells =>
      '[Ñö ɱéŕĝéð çéļļš îñ ţĥé šéļéçţîöñ one two th]';

  @override
  String get undoCropImage => '[Çŕöþ îɱåĝé one]';

  @override
  String get cmdImageCropApply => '[Åþþļý çŕöþ one]';

  @override
  String get cmdImageCropCancel => '[Çåñçéļ çŕöþ one]';

  @override
  String get cmdImageRetryUpload => '[Ŕéţŕý ûþļöåð one]';

  @override
  String get cmdImageRemoveNotUploaded => '[Ŕéɱöṽé îɱåĝé one]';

  @override
  String get cmdTableResizeAxes => '[Ŕéšîžé ŕöŵš öŕ çöļûɱñš one two]';

  @override
  String get cmdTableSetCellPadding => '[Çéļļ þåððîñĝ one]';

  @override
  String get cmdTableClearCells => '[Çļéåŕ çéļļš one]';

  @override
  String get cmdTableSelectCells => '[Šéļéçţ çéļļš one]';

  @override
  String get cmdTableMoveSelection => '[Ṁöṽé çéļļ šéļéçţîöñ one tw]';

  @override
  String get cmdTableNextCell => '[Ñéẋţ çéļļ one]';

  @override
  String get cmdTablePreviousCell => '[Þŕéṽîöûš çéļļ one t]';

  @override
  String get cmdTableEditCell => '[Éðîţ çéļļ one]';

  @override
  String get cmdTableClearCellSelection => '[Šéļéçţ ţĥé ŵĥöļé ţåƀļé one two]';

  @override
  String get imageNotAvailable =>
      '[Ţĥîš îɱåĝé îšñ\'ţ åṽåîļåƀļé ŕîĝĥţ ñöŵ. one two thre]';

  @override
  String get imagePickTitle => '[Çĥööšé îɱåĝéš one t]';

  @override
  String get imageClipboardEmpty =>
      '[Ţĥéŕé\'š ñö îɱåĝé öñ ţĥé çļîþƀöåŕð. one two thr]';

  @override
  String get imageUrlInvalid => '[Éñţéŕ åñ ĥţţþš:// îɱåĝé åððŕéšš. one two th]';

  @override
  String get imageFetchFailed => '[Çöûļðñ\'ţ ļöåð ţĥîš îɱåĝé. one two]';

  @override
  String get imageOutOfStorage => '[Ýöû\'ŕé öûţ öƒ šţöŕåĝé. one two]';

  @override
  String imageRejectedTooLarge(String name) {
    return '[Çöûļðñ\'ţ îñšéŕţ \'$name\' — îɱåĝéš çåñ ƀé åţ ɱöšţ 50 ṀƁ. one two three]';
  }

  @override
  String imageRejectedFormat(String name) {
    return '[Çöûļðñ\'ţ îñšéŕţ \'$name\' — ţĥîš îɱåĝé ţýþé îšñ\'ţ šûþþöŕţéð. one two three fo]';
  }

  @override
  String get imageInsertDialogTitle => '[Îñšéŕţ îɱåĝé one]';

  @override
  String get imageReplaceDialogTitle => '[Ŕéþļåçé îɱåĝé one t]';

  @override
  String get imageSourceLabel => '[Šöûŕçé one]';

  @override
  String get dialogContinue => '[Çöñţîñûé one]';

  @override
  String get dialogInsert => '[Îñšéŕţ one]';

  @override
  String get dialogCancel => '[Çåñçéļ one]';

  @override
  String get imageUrlDialogTitle => '[Îñšéŕţ îɱåĝé ƀý ÛŔĻ one tw]';

  @override
  String get imageUrlDialogBody =>
      '[Ţĥé îɱåĝé îš ƒéţçĥéð ţĥŕöûĝĥ Ŵöñķý Ŵöŕķ åñð šţöŕéð ŵîţĥ ţĥé þŕéšéñţåţîöñ. one two three four fiv]';

  @override
  String get imageUrlLabel => '[Îɱåĝé åððŕéšš one t]';

  @override
  String get imageMaskDialogTitle => '[Ṁåšķ ŵîţĥ šĥåþé one t]';

  @override
  String get imageMaskShape => '[Šĥåþé on]';

  @override
  String get imageMaskNone => '[Ñö ɱåšķ one]';

  @override
  String get imageDriveDialogTitle =>
      '[Îñšéŕţ îɱåĝé ƒŕöɱ Ŵöñķý Ðŕîṽé one two t]';

  @override
  String get imageDriveSearch => '[Šéåŕçĥ îɱåĝéš one t]';

  @override
  String get imageDriveImage => '[Îɱåĝé on]';

  @override
  String get imageDriveFailed =>
      '[Çöûļðñ\'ţ ļöåð ýöûŕ îɱåĝéš. Çĥéçķ ýöûŕ çöññéçţîöñ. one two three fo]';

  @override
  String get imageDriveEmpty => '[Ñö îɱåĝéš ƒöûñð. one t]';

  @override
  String get cropAspectFree => '[Ƒŕéé on]';

  @override
  String get cropAspectOriginal => '[Öŕîĝîñåļ one]';

  @override
  String get cropFill => '[Ƒîļļ on]';

  @override
  String get cropFit => '[Ƒîţ on]';

  @override
  String get cropDone => '[Ðöñé on]';

  @override
  String get imageNotUploadedOutOfStorage =>
      '[Ñöţ ûþļöåðéð — öûţ öƒ šţöŕåĝé one two t]';

  @override
  String get imageRetry => '[Ŕéţŕý on]';

  @override
  String get imageRemove => '[Ŕéɱöṽé one]';

  @override
  String tableSizeInvalid(int max) {
    return '[Éñţéŕ å ñûɱƀéŕ ƒŕöɱ 1 ţö $max. one two]';
  }

  @override
  String get tableInsertDialogTitle => '[Îñšéŕţ ţåƀļé one]';

  @override
  String get tableRows => '[Ŕöŵš on]';

  @override
  String get tableColumns => '[Çöļûɱñš one]';

  @override
  String get cmdThemeApply => '[Åþþļý ţĥéɱé one]';

  @override
  String get cmdThemeImport =>
      '[Îɱþöŕţ ţĥéɱé ƒŕöɱ å þŕéšéñţåţîöñ… one two thr]';

  @override
  String get cmdThemeRename => '[Ŕéñåɱé ţĥéɱé… one t]';

  @override
  String get cmdThemeDuplicate => '[Ðûþļîçåţé ţĥéɱé one t]';

  @override
  String get cmdThemeSetDefault => '[Šéţ åš ðéƒåûļţ ţĥéɱé one tw]';

  @override
  String get cmdThemeDelete => '[Ŕéɱöṽé ţĥéɱé one]';

  @override
  String get cmdThemeRemoveUnused => '[Ŕéɱöṽé ûñûšéð ţĥéɱéš one two]';

  @override
  String get cmdDeckSetSize => '[Çĥåñĝé šļîðé šîžé one tw]';

  @override
  String get cmdDeckSetNumbering => '[Šéţ šļîðé ñûɱƀéŕš åñð ƒööţéŕ one two t]';

  @override
  String get undoChangeSlideSize => '[Çĥåñĝé šļîðé šîžé one tw]';

  @override
  String get undoNumbering => '[Šļîðé ñûɱƀéŕš åñð ƒööţéŕ one two]';

  @override
  String get reasonThemeInUse =>
      '[Ûšéð ƀý šļîðéš — åþþļý åñöţĥéŕ ţĥéɱé ţö ţĥéɱ ƒîŕšţ one two three f]';

  @override
  String get reasonThemeIsDefault => '[Åļŕéåðý ţĥé ðéƒåûļţ ţĥéɱé one two]';

  @override
  String get reasonNoUnusedThemes => '[Éṽéŕý ţĥéɱé îš îñ ûšé one tw]';

  @override
  String get themesPanelTitle => '[Ţĥéɱéš one]';

  @override
  String get themesApplyTo => '[Åþþļý ţö one]';

  @override
  String get themesApplyAll => '[Åļļ šļîðéš one]';

  @override
  String themesApplySelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Šéļéçţéð šļîðéš ($count)',
      one: 'Šéļéçţéð šļîðé',
    );
    return '[$_temp0 one two thr]';
  }

  @override
  String get themesInPresentation => '[Îñ ţĥîš þŕéšéñţåţîöñ one two]';

  @override
  String get themesBuiltIn => '[Ɓûîļţ-îñ ţĥéɱéš one t]';

  @override
  String get themesImport => '[Îɱþöŕţ ţĥéɱé ƒŕöɱ å þŕéšéñţåţîöñ… one two thr]';

  @override
  String get themesDefault => '[Ðéƒåûļţ one]';

  @override
  String themesUsedBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ûšéð ƀý $count šļîðéš',
      one: 'Ûšéð ƀý 1 šļîðé',
      zero: 'Ñöţ ûšéð',
    );
    return '[$_temp0 one two thr]';
  }

  @override
  String themesMore(String name) {
    return '[Ṁöŕé åçţîöñš ƒöŕ $name one t]';
  }

  @override
  String get themeUntitled => '[Ûñţîţļéð ţĥéɱé one t]';

  @override
  String get themePreviewSubtitle => '[Ţîţļé åñð šûƀţîţļé one tw]';

  @override
  String themeCopyName(String name) {
    return '[$name çöþý on]';
  }

  @override
  String get themeRenameTitle => '[Ŕéñåɱé ţĥéɱé one]';

  @override
  String get themeNameLabel => '[Ñåɱé on]';

  @override
  String get themeNameEmpty => '[Éñţéŕ å ñåɱé one]';

  @override
  String get themeRenameButton => '[Ŕéñåɱé one]';

  @override
  String get themeImportPickTitle =>
      '[Îɱþöŕţ ţĥéɱé ƒŕöɱ å þŕéšéñţåţîöñ one two th]';

  @override
  String get themeImportSearch => '[Šéåŕçĥ þŕéšéñţåţîöñš one two]';

  @override
  String get themeImportPresentation => '[Þŕéšéñţåţîöñ one t]';

  @override
  String get themeImportNoPresentations => '[Ñö öţĥéŕ þŕéšéñţåţîöñš one two]';

  @override
  String get themeImportOffline =>
      '[Çöññéçţ ţö ţĥé îñţéŕñéţ ţö îɱþöŕţ å ţĥéɱé one two thre]';

  @override
  String get themeImportChooseTitle => '[Çĥööšé å ţĥéɱé one t]';

  @override
  String themeImportOption(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count šļîðéš',
      one: '1 šļîðé',
      zero: 'ñöţ ûšéð',
    );
    return '[$name — $_temp0 one two]';
  }

  @override
  String get themeImportButton => '[Îɱþöŕţ one]';

  @override
  String themeImported(String name) {
    return '[Ţĥéɱé “$name” åððéð one t]';
  }

  @override
  String get themeApplyToAll => '[Åþþļý ţö åļļ šļîðéš one tw]';

  @override
  String get backgroundResetToLayout =>
      '[Ŕéšéţ ţö ļåýöûţ ƀåçķĝŕöûñð one two t]';

  @override
  String get pageSetupTitle => '[Þåĝé šéţûþ one]';

  @override
  String get pageSetupPreset => '[Šļîðé šîžé one]';

  @override
  String get pageSetupUnit => '[Ûñîţ on]';

  @override
  String get pageSetupContent => '[Éẋîšţîñĝ çöñţéñţ one tw]';

  @override
  String get pageSetupScale => '[Šçåļé çöñţéñţ ţö ƒîţ one tw]';

  @override
  String get pageSetupDontScale => '[Ðöñ\'ţ šçåļé one]';

  @override
  String get pageSetupPreview => '[Þŕéṽîéŵ one]';

  @override
  String get pageSetupApply => '[Åþþļý on]';

  @override
  String get pageSetupEnterSize => '[Éñţéŕ å ŵîðţĥ åñð å ĥéîĝĥţ. one two]';

  @override
  String get pageSetupSideRange =>
      '[Éåçĥ šîðé ɱûšţ ƀé ƀéţŵééñ 320 åñð 7,680 šû. one two three]';

  @override
  String get pageSetupAspectRange =>
      '[Ţĥé åšþéçţ ŕåţîö ɱûšţ ƀé ƀéţŵééñ 1:4 åñð 4:1. one two three]';

  @override
  String get sizeCustom => '[Çûšţöɱ one]';

  @override
  String get numberingTitle => '[Šļîðé ñûɱƀéŕš åñð ƒööţéŕ one two]';

  @override
  String get numberingShow => '[Šĥöŵ šļîðé ñûɱƀéŕš one tw]';

  @override
  String get numberingFirst => '[Ƒîŕšţ šļîðé ñûɱƀéŕ one tw]';

  @override
  String get numberingFirstInvalid =>
      '[Éñţéŕ å ñûɱƀéŕ ƒŕöɱ 0 ţö 9999 one two t]';

  @override
  String get numberingHideOnTitle => '[Ðöñ\'ţ šĥöŵ öñ ţîţļé šļîðéš one two]';

  @override
  String get numberingFooter => '[Ƒööţéŕ one]';

  @override
  String get numberingFooterHint => '[Éɱþţý = ñö ƒööţéŕ one t]';

  @override
  String get imageUploading => '[Ûþļöåðîñĝ… one]';

  @override
  String get imageAdjustments => '[Åðĵûšţɱéñţš one]';

  @override
  String get imageBrightness => '[Ɓŕîĝĥţñéšš one]';

  @override
  String get imageContrast => '[Çöñţŕåšţ one]';

  @override
  String get imageSaturation => '[Šåţûŕåţîöñ one]';

  @override
  String get imageTemperature => '[Ţéɱþéŕåţûŕé one]';

  @override
  String get imageBlur => '[Ɓļûŕ on]';

  @override
  String get imageGrayscale => '[Ĝŕåýšçåļé one]';

  @override
  String get imageSepia => '[Šéþîå on]';

  @override
  String get imageInvert => '[Îñṽéŕţ one]';

  @override
  String get tableStyle => '[Šţýļé on]';

  @override
  String get tableStyleTheme => '[Ţĥéɱé on]';

  @override
  String get tableStyleNone => '[Ñöñé on]';

  @override
  String get tableHeaderRow => '[Ĥéåðéŕ ŕöŵ one]';

  @override
  String get tableFirstColumn => '[Ƒîŕšţ çöļûɱñ one]';

  @override
  String get tableBandedRows => '[Ɓåñðéð ŕöŵš one]';

  @override
  String get tableBandedColumns => '[Ɓåñðéð çöļûɱñš one t]';

  @override
  String get tableTotalRow => '[Ţöţåļ ŕöŵ one]';

  @override
  String tableCellsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count çéļļš šéļéçţéð',
      one: '1 çéļļ šéļéçţéð',
    );
    return '[$_temp0 one two th]';
  }

  @override
  String get tableCellFill => '[Ƒîļļ on]';

  @override
  String get tableStyleFill => '[Ţåƀļé šţýļé one]';

  @override
  String get tableVerticalAlign => '[Åļîĝñ on]';

  @override
  String get tableCellPadding => '[Þåððîñĝ one]';

  @override
  String get tableStyleDefault => '[Ðéƒåûļţ one]';

  @override
  String get tableBorders => '[Ɓöŕðéŕš one]';

  @override
  String tableBorderEdge(String edge) {
    String _temp0 = intl.Intl.selectLogic(edge, {
      'all': 'Åļļ ƀöŕðéŕš',
      'outer': 'Öûţéŕ ƀöŕðéŕš',
      'inner': 'Îññéŕ ƀöŕðéŕš',
      'horizontal': 'Îññéŕ ĥöŕîžöñţåļ ƀöŕðéŕš',
      'vertical': 'Îññéŕ ṽéŕţîçåļ ƀöŕðéŕš',
      'top': 'Ţöþ ƀöŕðéŕ',
      'bottom': 'Ɓöţţöɱ ƀöŕðéŕ',
      'left': 'Ļéƒţ ƀöŕðéŕ',
      'right': 'Ŕîĝĥţ ƀöŕðéŕ',
      'none': 'Çļéåŕ ƀöŕðéŕš',
      'other': 'Ɓöŕðéŕš',
    });
    return '[$_temp0 one two three four five six seven eight nine ten]';
  }

  @override
  String tableBorderStyle(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'solid': 'Šöļîð',
      'dashed': 'Ðåšĥéð',
      'dotted': 'Ðöţţéð',
      'other': 'Šöļîð',
    });
    return '[$_temp0 one two]';
  }

  @override
  String get cmdPresentEnd => '[Éñð þŕéšéñţåţîöñ one tw]';

  @override
  String get cmdPresentNext => '[Ñéẋţ on]';

  @override
  String get cmdPresentPrevious => '[Þŕéṽîöûš one]';

  @override
  String get cmdPresentNextSlide => '[Ñéẋţ šļîðé one]';

  @override
  String get cmdPresentPreviousSlide => '[Þŕéṽîöûš šļîðé one t]';

  @override
  String get cmdPresentGoTo => '[Ĝö ţö šļîðé one]';

  @override
  String get cmdPresentFirst => '[Ƒîŕšţ šļîðé one]';

  @override
  String get cmdPresentLast => '[Ļåšţ šļîðé one]';

  @override
  String get cmdPresentBlank => '[Ɓļåçķ öŕ ŵĥîţé šçŕééñ one two]';

  @override
  String get cmdPresentPicker => '[Šļîðé þîçķéŕ one]';

  @override
  String get cmdPresentTool => '[Þöîñţéŕ ţööļ one]';

  @override
  String get cmdPresentClearInk => '[Çļéåŕ îñķ öñ ţĥîš šļîðé one two]';

  @override
  String get cmdPresentUndoInk => '[Ûñðö ļåšţ îñķ šţŕöķé one tw]';

  @override
  String get cmdPresentTimer => '[Þŕéšéñţéŕ ţîɱéŕ one t]';

  @override
  String get cmdPresentJoinAsAudience => '[Šĥöŵ åûðîéñçé ṽîéŵ ĥéŕé one two]';

  @override
  String get cmdPresentToggleFullscreen => '[Ƒûļļ šçŕééñ one]';

  @override
  String get cmdPresentToggleSkipped => '[Šĥöŵ šķîþþéð šļîðéš one tw]';

  @override
  String get cmdPresentNotesSize => '[Šþéåķéŕ ñöţéš šîžé one tw]';

  @override
  String get cmdPresentHelp => '[Ķéýƀöåŕð šĥöŕţçûţš one tw]';

  @override
  String get cmdDeckSetPresentSettings => '[Þŕéšéñţåţîöñ šéţţîñĝš one two]';

  @override
  String get reasonNotPresenting => '[Ñöţ þŕéšéñţîñĝ one t]';

  @override
  String get reasonPresenterViewOnly => '[Öñļý îñ ţĥé þŕéšéñţéŕ ṽîéŵ one two]';

  @override
  String get presentUnknownSlide =>
      '[Ţĥåţ šļîðé îšñ’ţ îñ ţĥîš þŕéšéñţåţîöñ one two thre]';

  @override
  String presentSlideLabel(int number, int total) {
    return '[Šļîðé $number öƒ $total one]';
  }

  @override
  String get presentEndScreen =>
      '[Éñð öƒ þŕéšéñţåţîöñ — çļîçķ ţö éẋîţ one two thr]';

  @override
  String get presentCatchingUp => '[Çåţçĥîñĝ ûþ… one]';

  @override
  String get presentToolbarLabel => '[Þŕéšéñţåţîöñ çöñţŕöļš one two]';

  @override
  String presentCounterLabel(int number, int total) {
    return '[Šļîðé $number öƒ $total. Öþéñ ţĥé šļîðé þîçķéŕ one two th]';
  }

  @override
  String get presentToolLaser => '[Ļåšéŕ þöîñţéŕ one t]';

  @override
  String get presentToolPen => '[Þéñ on]';

  @override
  String get presentToolHighlighter => '[Ĥîĝĥļîĝĥţéŕ one]';

  @override
  String get presentToolEraser => '[Éŕåšéŕ one]';

  @override
  String get presentBlackScreen => '[Ɓļåçķ šçŕééñ one]';

  @override
  String get presentWhiteScreen => '[Ŵĥîţé šçŕééñ one]';

  @override
  String get presentEnd => '[Éñð on]';

  @override
  String presentGoToNumber(String number) {
    return '[Ĝö ţö $number on]';
  }

  @override
  String get presentHelpTitle => '[Þŕéšéñţîñĝ šĥöŕţçûţš one two]';

  @override
  String get presentHelpGoToNumber => '[Ĝö ţö šļîðé ñûɱƀéŕ one tw]';

  @override
  String get presentHelpDigits => '[1 2 3 … Éñţéŕ one]';

  @override
  String get presentHelpTemporaryLaser =>
      '[Ļåšéŕ ŵĥîļé ĥéļð (ɱöṽé ţĥé ɱöûšé) one two th]';

  @override
  String get presentTimerPause => '[Þåûšé öŕ ŕéšûɱé ţĥé ţîɱéŕ one two]';

  @override
  String get presentTimerResume => '[Ŕéšûɱé ţĥé ţîɱéŕ one t]';

  @override
  String get presentTimerReset => '[Ŕéšéţ ţĥé ţîɱéŕ one t]';

  @override
  String get presentNotesLarger => '[Ļåŕĝéŕ ñöţéš one]';

  @override
  String get presentNotesSmaller => '[Šɱåļļéŕ ñöţéš one t]';

  @override
  String get presentResume => '[Ŕéšûɱé (çļîçķéŕ Ƒ5) one tw]';

  @override
  String get presentFullscreenHint =>
      '[Þŕéšš Ƒ11 (⌃⌘Ƒ öñ Ṁåç) ƒöŕ ƒûļļ šçŕééñ one two thr]';

  @override
  String get presentFullscreenButton => '[Ƒûļļ šçŕééñ one]';

  @override
  String get presentAudienceTitle => '[Åûðîéñçé ṽîéŵ one t]';

  @override
  String get presentAudienceBody =>
      '[Ţĥîš šçŕééñ šĥöŵš ţĥé šļîðéš öƒ ýöûŕ þŕéšéñţåţîöñ. one two three fo]';

  @override
  String presentAudienceBodyFrom(String device) {
    return '[Ţĥîš šçŕééñ šĥöŵš ţĥé šļîðéš ýöû þŕéšéñţ öñ $device. one two three]';
  }

  @override
  String get presentAudienceKeys =>
      '[Å çļîçķéŕ öŕ ţĥé åŕŕöŵ ķéýš ĥéŕé åļšö ɱöṽé ţĥé þŕéšéñţåţîöñ. one two three four]';

  @override
  String get presentAudienceStay => '[Šţåý îñ ŵîñðöŵ one t]';

  @override
  String get presentGoToSlideMenu => '[Ĝö ţö šļîðé… one]';

  @override
  String get presentPickerTitle => '[Ĝö ţö šļîðé one]';

  @override
  String get presentPickerFilter => '[Ƒîļţéŕ ƀý ţîţļé öŕ ñûɱƀéŕ one two]';

  @override
  String get presentPickerClose => '[Çļöšé on]';

  @override
  String get presentPickerNoMatch => '[Ñö šļîðéš ɱåţçĥ one t]';

  @override
  String presentPickerGroup(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count šļîðéš',
      one: '1 šļîðé',
    );
    return '[$title, $_temp0 one t]';
  }

  @override
  String presentPickerSlide(int number, String title) {
    return '[Šļîðé $number: $title one]';
  }

  @override
  String get presentPickerSkipped => '[Šķîþþéð one]';

  @override
  String get presentOpenOnDeviceTitle => '[Öþéñ öñ åñöţĥéŕ ðéṽîçé one two]';

  @override
  String get presentOpenOnDeviceBody =>
      '[Öþéñ ţĥîš ļîñķ öñ ţĥé çöɱþûţéŕ öŕ ƀŕöŵšéŕ ţĥåţ šĥöŵš ţĥé šļîðéš — ƒöŕ éẋåɱþļé ţĥé öñé çöññéçţéð ţö ţĥé þŕöĵéçţöŕ. Šîĝñ îñ ŵîţĥ ýöûŕ åççöûñţ ţĥéŕé. one two three four five six seven eight ni]';

  @override
  String get presentOpenOnDeviceHint =>
      '[Öŕ öþéñ ţĥîš þŕéšéñţåţîöñ ţĥéŕé åñð çĥööšé “Šĥöŵ åûðîéñçé ṽîéŵ ĥéŕé”. one two three four fi]';

  @override
  String get presentAudienceLink => '[Åûðîéñçé ļîñķ one t]';

  @override
  String get presentCopyLink => '[Çöþý ļîñķ one]';

  @override
  String get presentLinkCopied => '[Çöþîéð one]';

  @override
  String get presentDone => '[Ðöñé on]';

  @override
  String get presentQrLabel => '[ǪŔ çöðé öƒ ţĥé åûðîéñçé ļîñķ one two t]';

  @override
  String get presentOfflineNoDevices =>
      '[Öƒƒļîñé — öţĥéŕ ðéṽîçéš çåñ’ţ ĵöîñ one two thr]';

  @override
  String get presentOfflineNoDevicesBody =>
      '[Ýöû çåñ ķééþ þŕéšéñţîñĝ ĥéŕé. Öţĥéŕ ðéṽîçéš ĵöîñ öñçé ýöû’ŕé ƀåçķ öñļîñé. one two three four fiv]';

  @override
  String get presentConnecting => '[Çöññéçţîñĝ… one]';

  @override
  String get presentSessionEnded =>
      '[Ñöţ çöññéçţéð ţö öţĥéŕ ðéṽîçéš one two th]';

  @override
  String presentAudienceDevices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öţĥéŕ ðéṽîçéš',
      one: '1 öţĥéŕ ðéṽîçé',
      zero: 'Ñö öţĥéŕ ðéṽîçéš ýéţ',
    );
    return '[$_temp0 one two three f]';
  }

  @override
  String get presentPresenterAway => '[Ŵåîţîñĝ ƒöŕ ţĥé þŕéšéñţéŕ… one two t]';

  @override
  String get presentWaitingForPresenter =>
      '[Ŵåîţîñĝ ƒöŕ ţĥé þŕéšéñţéŕ one two]';

  @override
  String get presentAudienceEndedToast => '[Ţĥé þŕéšéñţåţîöñ éñðéð one two]';

  @override
  String get presentAudienceNotFound =>
      '[Ţĥîš þŕéšéñţåţîöñ îšñ’ţ ŕûññîñĝ one two th]';

  @override
  String get presentAudienceNotFoundBody =>
      '[Åšķ ţĥé þŕéšéñţéŕ ƒöŕ å ñéŵ ļîñķ, öŕ öþéñ ţĥé þŕéšéñţåţîöñ åñð çĥööšé “Šĥöŵ åûðîéñçé ṽîéŵ ĥéŕé”. one two three four five six]';

  @override
  String get presentAudienceNoAccess =>
      '[Öñļý ţĥé þŕéšéñţéŕ çåñ šĥöŵ ţĥîš åûðîéñçé ṽîéŵ one two three]';

  @override
  String get presentTakeOverTitle => '[Ţåķé öṽéŕ ţĥé þŕéšéñţåţîöñ? one two t]';

  @override
  String get presentTakeOverBody =>
      '[Ýöû’ŕé þŕéšéñţîñĝ ţĥîš îñ åñöţĥéŕ ŵîñðöŵ. Ţåķé öṽéŕ ţĥé þŕéšéñţåţîöñ ƒŕöɱ ýöûŕ öţĥéŕ ŵîñðöŵ? one two three four five six]';

  @override
  String get presentTakeOver => '[Ţåķé öṽéŕ one]';

  @override
  String get presentTakeOverCancel => '[Þŕéšéñţ ĥéŕé öñļý one tw]';

  @override
  String get presentTakenOverToast =>
      '[Ýöûŕ þŕéšéñţåţîöñ çöñţîñûéš îñ åñöţĥéŕ ŵîñðöŵ one two three]';

  @override
  String get presentExtendedHintTitle =>
      '[Šĥöŵîñĝ ţĥé šļîðéš öñ å þŕöĵéçţöŕ? one two thr]';

  @override
  String get presentExtendedHintBody =>
      '[Öþéñ ţĥîš þŕéšéñţåţîöñ îñ å ŵîñðöŵ ţĥéŕé åñð çĥööšé “Šĥöŵ åûðîéñçé ṽîéŵ ĥéŕé” — öŕ ûšé “Öþéñ öñ åñöţĥéŕ ðéṽîçé…”. one two three four five six seven]';

  @override
  String get presenterViewTitle => '[Þŕéšéñţéŕ ṽîéŵ one t]';

  @override
  String presenterViewTitleWithName(String name) {
    return '[Þŕéšéñţéŕ ṽîéŵ — $name one t]';
  }

  @override
  String get presenterOtherDevice => '[Öţĥéŕ ðéṽîçé… one t]';

  @override
  String get presenterCurrent => '[Çûŕŕéñţ šļîðé one t]';

  @override
  String presenterCurrentStep(int step, int count) {
    return '[Çûŕŕéñţ šļîðé · šţéþ $step öƒ $count one two]';
  }

  @override
  String get presenterAudienceBlack => '[Åûðîéñçé: ƀļåçķ šçŕééñ one two]';

  @override
  String get presenterAudienceWhite => '[Åûðîéñçé: ŵĥîţé šçŕééñ one two]';

  @override
  String get presenterShowSlide => '[Šĥöŵ šļîðé one]';

  @override
  String presenterNextBuild(int step, int count) {
    return '[Ñéẋţ: ƀûîļð $step öƒ $count one t]';
  }

  @override
  String presenterNextSlide(String title) {
    return '[Ñéẋţ šļîðé: $title one]';
  }

  @override
  String get presenterNextSlideUntitled => '[Ñéẋţ šļîðé one]';

  @override
  String get presenterNextEnd => '[Éñð öƒ þŕéšéñţåţîöñ one tw]';

  @override
  String get presenterNextExit => '[Ñéẋţ: éẋîţ one]';

  @override
  String get presenterNotes => '[Šþéåķéŕ ñöţéš one t]';

  @override
  String get presenterNoNotes => '[Ñö šþéåķéŕ ñöţéš ƒöŕ ţĥîš šļîðé one two th]';

  @override
  String presenterElapsed(String time) {
    return '[Éļåþšéð $time one]';
  }

  @override
  String presenterRemaining(String time) {
    return '[Ŕéɱåîñîñĝ $time one]';
  }

  @override
  String presenterSlideOf(int number, int total) {
    return '[Šļîðé $number / $total one]';
  }

  @override
  String presenterAhead(String time) {
    return '[$time åĥéåð on]';
  }

  @override
  String presenterBehind(String time) {
    return '[$time ƀéĥîñð one]';
  }

  @override
  String get presenterStrip => '[Šļîðéš one]';

  @override
  String presentBannerTitle(String device) {
    return '[Ýöû’ŕé þŕéšéñţîñĝ öñ $device one two]';
  }

  @override
  String get presentBannerTitleNoDevice =>
      '[Ýöû’ŕé þŕéšéñţîñĝ ţĥîš þŕéšéñţåţîöñ one two thre]';

  @override
  String get presentBannerDismiss => '[Ðîšɱîšš one]';

  @override
  String get cmdEditCopy => '[Çöþý on]';

  @override
  String get cmdEditCut => '[Çûţ on]';

  @override
  String get cmdEditPaste => '[Þåšţé on]';

  @override
  String get reasonCopyNotAllowed =>
      '[Ţĥé öŵñéŕ ţûŕñéð öƒƒ çöþýîñĝ ƒöŕ ṽîéŵéŕš one two thre]';

  @override
  String get reasonPasteObjectsOnSlide => '[Þåšţé öƀĵéçţš öñ å šļîðé one two]';

  @override
  String get reasonPasteSlidesNotInCells =>
      '[Þåšţé šļîðéš îñ ţĥé šļîðé ñåṽîĝåţöŕ one two thr]';

  @override
  String get toastClipboardEmpty => '[Ţĥéŕé îš ñöţĥîñĝ ţö þåšţé one two]';

  @override
  String get toastPasteClipped =>
      '[Öñļý ţĥé çéļļš ţĥåţ ƒîţ îñ ţĥé ţåƀļé ŵéŕé þåšţéð one two three]';

  @override
  String get toastPasteTruncated =>
      '[Öñļý ţĥé ƒîŕšţ 50 ŕöŵš åñð 20 çöļûɱñš ŵéŕé þåšţéð one two three]';

  @override
  String get pasteChartLinked => '[Ļîñķéð ţö ţĥé šþŕéåðšĥééţ one two]';

  @override
  String get pasteOptionsLabel => '[Þåšţé öþţîöñš one t]';

  @override
  String get cmdFindNext => '[Ƒîñð ñéẋţ one]';

  @override
  String get cmdFindPrevious => '[Ƒîñð þŕéṽîöûš one t]';

  @override
  String get cmdFindReplace => '[Ŕéþļåçé one]';

  @override
  String get cmdFindReplaceAll => '[Ŕéþļåçé åļļ one]';

  @override
  String get undoReplaceAll => '[Ŕéþļåçé åļļ one]';

  @override
  String get findClose => '[Çļöšé ƒîñð one]';

  @override
  String get findPlaceholder => '[Ƒîñð îñ þŕéšéñţåţîöñ one two]';

  @override
  String get findNoResults => '[Ñö ŕéšûļţš one]';

  @override
  String findOfCount(int current, int total) {
    return '[$current öƒ $total o]';
  }

  @override
  String findMatchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ɱåţçĥéš',
      one: '1 ɱåţçĥ',
    );
    return '[$_temp0 one t]';
  }

  @override
  String get findReplaceTitle => '[Ƒîñð åñð ŕéþļåçé one t]';

  @override
  String get findLabel => '[Ƒîñð on]';

  @override
  String get replaceLabel => '[Ŕéþļåçé ŵîţĥ one]';

  @override
  String get findMatchCase => '[Ṁåţçĥ çåšé one]';

  @override
  String get findWholeWords => '[Ŵĥöļé ŵöŕðš one]';

  @override
  String get findUseRegex => '[Ûšé ŕéĝûļåŕ éẋþŕéššîöñš one two]';

  @override
  String get findIncludeNotes => '[Îñçļûðé šþéåķéŕ ñöţéš one two]';

  @override
  String get findIncludeSkipped => '[Îñçļûðé šķîþþéð šļîðéš one two]';

  @override
  String get findScope => '[Šéåŕçĥ îñ one]';

  @override
  String get findScopeAll => '[Åļļ šļîðéš one]';

  @override
  String get findScopeCurrent => '[Çûŕŕéñţ šļîðé one t]';

  @override
  String get findScopeSelected => '[Šéļéçţéð šļîðéš one t]';

  @override
  String get findButtonPrevious => '[Þŕéṽîöûš one]';

  @override
  String get findButtonNext => '[Ñéẋţ on]';

  @override
  String get findInvalidRegex =>
      '[Ţĥîš ŕéĝûļåŕ éẋþŕéššîöñ îš ñöţ ṽåļîð one two thr]';

  @override
  String toastReplacedAll(int count, String find, String replace) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ŕéþļåçéð $count îñšţåñçéš öƒ “$find” ŵîţĥ “$replace”',
      one: 'Ŕéþļåçéð 1 îñšţåñçé öƒ “$find” ŵîţĥ “$replace”',
      zero: 'Ñöţĥîñĝ ŵåš ŕéþļåçéð',
    );
    return '[$_temp0 one two three four five si]';
  }

  @override
  String toastReplaceSkipped(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ɱåţçĥéš îñ ţéẋţ $name îš éðîţîñĝ ŵéŕé šķîþþéð',
      one: '1 ɱåţçĥ îñ ţéẋţ $name îš éðîţîñĝ ŵåš šķîþþéð',
    );
    return '[$_temp0 one two three four five]';
  }

  @override
  String toastFindBodyLocked(String name) {
    return '[$name îš éðîţîñĝ ţĥîš ţéẋţ one tw]';
  }
}
