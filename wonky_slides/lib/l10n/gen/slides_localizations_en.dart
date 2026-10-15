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
}
