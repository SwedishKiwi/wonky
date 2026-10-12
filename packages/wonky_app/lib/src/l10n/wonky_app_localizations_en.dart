// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'wonky_app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class WonkyAppLocalizationsEn extends WonkyAppLocalizations {
  WonkyAppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutAppVersion => 'App version';

  @override
  String get aboutLicenses => 'Open source licenses';

  @override
  String get aboutProtocol => 'Protocol';

  @override
  String get aboutRunMode => 'Server mode';

  @override
  String get aboutServerVersion => 'Server version';

  @override
  String get accountMenu => 'Account';

  @override
  String get actionBack => 'Back';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionClose => 'Close';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionCreate => 'Create';

  @override
  String get actionDone => 'Done';

  @override
  String get actionOk => 'OK';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionReload => 'Reload';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSend => 'Send';

  @override
  String get actionShare => 'Share';

  @override
  String get actionStop => 'Stop';

  @override
  String get actionUndo => 'Undo';

  @override
  String activityCommented(String who) {
    return '$who commented';
  }

  @override
  String activityCreated(String who) {
    return '$who created this';
  }

  @override
  String activityEdited(String who) {
    return '$who edited';
  }

  @override
  String get activityEmpty => 'No activity yet.';

  @override
  String activityExported(String who) {
    return '$who exported';
  }

  @override
  String activityMoved(String who) {
    return '$who moved this';
  }

  @override
  String get activityPeople => 'People';

  @override
  String get activityRecent => 'Recent activity';

  @override
  String activityRenamed(String who) {
    return '$who renamed this';
  }

  @override
  String activityRestored(String who) {
    return '$who restored this from the trash';
  }

  @override
  String activityRestoredVersion(String who) {
    return '$who restored a version';
  }

  @override
  String activityShared(String who) {
    return '$who shared this';
  }

  @override
  String get activitySystem => 'Wonky Work';

  @override
  String activityTitle(String name) {
    return 'Activity on “$name”';
  }

  @override
  String activityTrashed(String who) {
    return '$who moved this to the trash';
  }

  @override
  String activityUnshared(String who) {
    return '$who removed access';
  }

  @override
  String get addShortcutAction => 'Add shortcut';

  @override
  String get addShortcutTitle => 'Add shortcut to My Drive';

  @override
  String agentUndoLabel(String label) {
    return 'AI: $label';
  }

  @override
  String get aiEnable => 'Enable the assistant';

  @override
  String get authBackToSignIn => 'Back to sign in';

  @override
  String get authBackToSignUp => 'Back to sign up';

  @override
  String get authChangeEmail => 'Change email address';

  @override
  String get authCodeResent => 'A new code is on its way.';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authDisplayName => 'Name';

  @override
  String get authEmail => 'Email';

  @override
  String get authErrorCodeLength => 'Enter the 6-digit code.';

  @override
  String get authErrorEmail => 'Enter a valid email address.';

  @override
  String get authErrorExpiredCode =>
      'This code has expired. Request a new one.';

  @override
  String get authErrorInvalidCode =>
      'That code is not right. Check it and try again.';

  @override
  String get authErrorInvalidCredentials => 'Wrong email or password.';

  @override
  String get authErrorNetwork =>
      'Can\'t reach the server. Check your connection and try again.';

  @override
  String get authErrorPasswordMismatch => 'The passwords don\'t match.';

  @override
  String get authErrorPasswordPolicy =>
      'This password doesn\'t meet the requirements. Choose a longer or more varied password.';

  @override
  String get authErrorPasswordShort => 'Use at least 8 characters.';

  @override
  String get authErrorPasswordWeak => 'This password is too easy to guess.';

  @override
  String get authErrorTerms => 'Please accept the terms to continue.';

  @override
  String get authErrorTooManyAttempts =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get authErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authNewPasswordSubtitle =>
      'Choose a new password for your account.';

  @override
  String get authNoAccount => 'New to Wonky Work?';

  @override
  String get authPassword => 'Password';

  @override
  String get authRememberMe => 'Keep me signed in';

  @override
  String get authResendCode => 'Resend code';

  @override
  String authResendIn(int seconds) {
    return 'Resend code in $seconds s';
  }

  @override
  String get authResetSubtitle =>
      'We\'ll email you a code to reset your password.';

  @override
  String get authResetTitle => 'Reset your password';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authSetPassword => 'Set password and sign in';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignInSubtitle =>
      'One account for Wonky Write and Wonky Sheets.';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignUpSubtitle =>
      'Create one account for Wonky Write and Wonky Sheets.';

  @override
  String get authSignUpTitle => 'Create your account';

  @override
  String get authTerms => 'I agree to the terms of service and privacy policy';

  @override
  String get authVerify => 'Verify';

  @override
  String get authVerifyNoDraft => 'Start the sign-up again to get a new code.';

  @override
  String authVerifySubtitle(String email) {
    return 'We sent a 6-digit code to $email.';
  }

  @override
  String get authVerifyTitle => 'Verify your email';

  @override
  String get badgeCommentOnly => 'Comment only';

  @override
  String get badgeOffline => 'Available offline';

  @override
  String get badgeShared => 'Shared';

  @override
  String get badgeViewOnly => 'View only';

  @override
  String get categoryAccount => 'Account';

  @override
  String get categoryComments => 'Comments';

  @override
  String get categoryDrive => 'Drive';

  @override
  String get categoryEdit => 'Edit';

  @override
  String get categoryFile => 'File';

  @override
  String get categoryHelp => 'Help';

  @override
  String get categoryNavigation => 'Navigation';

  @override
  String get categoryOther => 'Other';

  @override
  String get categorySharing => 'Sharing';

  @override
  String get categoryTools => 'Tools';

  @override
  String get categoryVersions => 'Version history';

  @override
  String get categoryView => 'View';

  @override
  String get cmdAbout => 'About';

  @override
  String get cmdActivityDashboard => 'Activity dashboard';

  @override
  String get cmdAddShortcut => 'Add shortcut to Drive';

  @override
  String get cmdAssistant => 'Assistant';

  @override
  String get cmdAssistantNewThread => 'New assistant chat';

  @override
  String get cmdAssistantSend => 'Send to assistant';

  @override
  String get cmdAssistantStop => 'Stop assistant';

  @override
  String get cmdBack => 'Back';

  @override
  String get cmdClosePanel => 'Close panel';

  @override
  String get cmdCommandPalette => 'Command palette';

  @override
  String get cmdComment => 'Comment';

  @override
  String get cmdCommentsPanel => 'Comments';

  @override
  String get cmdCompactMode => 'Compact mode';

  @override
  String get cmdCopy => 'Copy';

  @override
  String get cmdCopyLink => 'Copy link';

  @override
  String get cmdCopyMcpConfig => 'Copy MCP connection settings';

  @override
  String get cmdCut => 'Cut';

  @override
  String get cmdDeleteComment => 'Delete comment';

  @override
  String get cmdDeleteForever => 'Delete forever';

  @override
  String get cmdDetails => 'Details';

  @override
  String get cmdDownload => 'Download';

  @override
  String get cmdEmptyTrash => 'Empty trash';

  @override
  String get cmdFocusSearch => 'Search in Drive';

  @override
  String get cmdForward => 'Forward';

  @override
  String get cmdFullScreen => 'Full screen';

  @override
  String get cmdHelpCenter => 'Help center';

  @override
  String get cmdHome => 'Home';

  @override
  String get cmdImport => 'Import…';

  @override
  String get cmdKeyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get cmdMakeAvailableOffline => 'Make available offline';

  @override
  String get cmdMakeCopy => 'Make a copy';

  @override
  String get cmdMove => 'Move';

  @override
  String get cmdMoveToTrash => 'Move to trash';

  @override
  String get cmdNameCurrentVersion => 'Name current version';

  @override
  String get cmdNewDocument => 'New document';

  @override
  String get cmdNewFile => 'New file';

  @override
  String get cmdNewFolder => 'New folder';

  @override
  String get cmdNewFromTemplate => 'From template…';

  @override
  String get cmdNewSpreadsheet => 'New spreadsheet';

  @override
  String get cmdNextPanel => 'Next panel';

  @override
  String get cmdNextRegion => 'Focus next region';

  @override
  String get cmdOpen => 'Open';

  @override
  String get cmdOpenComment => 'Open comment';

  @override
  String get cmdOpenFile => 'Open…';

  @override
  String get cmdOpenPanel => 'Open panel';

  @override
  String get cmdOpenSheets => 'Open Wonky Sheets';

  @override
  String get cmdOpenWrite => 'Open Wonky Write';

  @override
  String get cmdPaste => 'Paste';

  @override
  String get cmdPastePlain => 'Paste without formatting';

  @override
  String get cmdPreviousPanel => 'Previous panel';

  @override
  String get cmdPreviousRegion => 'Focus previous region';

  @override
  String get cmdPrint => 'Print';

  @override
  String get cmdQuickSwitcher => 'Go to file…';

  @override
  String get cmdRedo => 'Redo';

  @override
  String cmdRedoLabel(String label) {
    return 'Redo $label';
  }

  @override
  String get cmdRename => 'Rename';

  @override
  String get cmdReopen => 'Reopen';

  @override
  String get cmdReply => 'Reply';

  @override
  String get cmdReportProblem => 'Report a problem';

  @override
  String get cmdRequestAccess => 'Request access';

  @override
  String get cmdResolve => 'Resolve';

  @override
  String get cmdRestore => 'Restore';

  @override
  String get cmdRestoreVersion => 'Restore this version';

  @override
  String get cmdSearchMenus => 'Search the menus';

  @override
  String get cmdSeeVersionHistory => 'See version history';

  @override
  String get cmdSelectAll => 'Select all';

  @override
  String get cmdSetTheme => 'App theme';

  @override
  String get cmdSettings => 'Settings';

  @override
  String get cmdShare => 'Share';

  @override
  String get cmdShowMenubar => 'Menu bar';

  @override
  String get cmdShowStatusBar => 'Status bar';

  @override
  String get cmdShowToolbar => 'Toolbar';

  @override
  String get cmdSignOut => 'Sign out';

  @override
  String get cmdStar => 'Star';

  @override
  String get cmdStopAgent => 'Stop agent control';

  @override
  String get cmdTogglePanel => 'Toggle panel';

  @override
  String get cmdToggleUiBridge => 'Allow MCP to control this window';

  @override
  String get cmdUndo => 'Undo';

  @override
  String get cmdUndoHistory => 'Undo history…';

  @override
  String cmdUndoLabel(String label) {
    return 'Undo $label';
  }

  @override
  String get cmdUndoTo => 'Undo to step';

  @override
  String get cmdUnstar => 'Remove star';

  @override
  String get cmdUpload => 'Upload file…';

  @override
  String get cmdVersionsPanel => 'Version history panel';

  @override
  String get cmdWhatsNew => 'What\'s new';

  @override
  String get cmdZoom => 'Zoom';

  @override
  String get collapseFolders => 'Collapse folders';

  @override
  String get columnModified => 'Last modified';

  @override
  String get columnName => 'Name';

  @override
  String get columnOwner => 'Owner';

  @override
  String get columnSize => 'File size';

  @override
  String commandFailed(String title) {
    return '“$title” failed';
  }

  @override
  String get commentAction => 'Comment';

  @override
  String commentAssign(String name) {
    return 'Assign to $name';
  }

  @override
  String get commentDelete => 'Delete';

  @override
  String get commentDeleteThread => 'Delete thread';

  @override
  String get commentDeleted => 'Comment deleted';

  @override
  String get commentEdit => 'Edit';

  @override
  String get commentEdited => 'edited';

  @override
  String get commentEventAssigned => 'assigned the comment';

  @override
  String get commentEventReopened => 'reopened';

  @override
  String get commentEventResolved => 'marked as resolved';

  @override
  String get commentFailed => 'The comment could not be saved';

  @override
  String get commentLink => 'Link to comment';

  @override
  String get commentOrphaned => 'Original content deleted';

  @override
  String get commentPlaceholder => 'Comment or add others with @';

  @override
  String get commentShow => 'Show';

  @override
  String get commentsAll => 'All';

  @override
  String commentsEmptyBody(String shortcut) {
    return 'Select content and press $shortcut to add a comment.';
  }

  @override
  String get commentsEmptyTitle => 'No comments yet';

  @override
  String get commentsForYou => 'For you';

  @override
  String get commentsOpen => 'Open';

  @override
  String get commentsResolved => 'Resolved';

  @override
  String get commentsSearch => 'Search comments';

  @override
  String get commentsSort => 'Sort';

  @override
  String get commentsSortDate => 'Sort by date';

  @override
  String get commentsSortPosition => 'Sort by position';

  @override
  String get copyAction => 'Make a copy';

  @override
  String get copyComments => 'Copy comments';

  @override
  String get copyName => 'Name';

  @override
  String copyOfName(String name) {
    return 'Copy of $name';
  }

  @override
  String get copySharing => 'Share it with the same people';

  @override
  String get copyTitle => 'Make a copy';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get deleteAccountAction => 'Delete account';

  @override
  String deleteAccountBody(String email) {
    return 'This permanently deletes your account $email. This cannot be undone.';
  }

  @override
  String deleteAccountConfirmLabel(String email) {
    return 'Type $email to confirm';
  }

  @override
  String deleteAccountCounts(int documents, int spreadsheets, int folders) {
    return 'You own $documents documents, $spreadsheets spreadsheets and $folders folders.';
  }

  @override
  String get deleteAccountHint => 'Delete your account and the files you own.';

  @override
  String get deleteAccountMismatch => 'That\'s not your email address.';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteForeverAction => 'Delete forever';

  @override
  String get deleteForeverBody =>
      'These items will be deleted permanently. This can\'t be undone.';

  @override
  String deleteForeverTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count items forever?',
      one: 'Delete forever?',
    );
    return '$_temp0';
  }

  @override
  String get densityComfortable => 'Comfortable';

  @override
  String get densityCompact => 'Compact';

  @override
  String get detailsAccess => 'Who has access';

  @override
  String get detailsActivity => 'Activity';

  @override
  String get detailsCreated => 'Created';

  @override
  String get detailsDescription => 'Description';

  @override
  String get detailsDescriptionHint => 'Add a description';

  @override
  String get detailsLocation => 'Location';

  @override
  String get detailsModified => 'Modified';

  @override
  String get detailsNothingSelected => 'Select a file to see its details';

  @override
  String get detailsOpened => 'Opened by me';

  @override
  String get detailsOwner => 'Owner';

  @override
  String get detailsPrivate => 'Private to you';

  @override
  String get detailsRole => 'Your access';

  @override
  String get detailsShared => 'Shared';

  @override
  String get detailsType => 'Type';

  @override
  String get driveListLabel => 'Files';

  @override
  String get driveOfflineBody =>
      'Files you opened recently or made available offline are listed when you\'re offline.';

  @override
  String get driveOfflineTitle => 'You\'re offline';

  @override
  String get dropToUpload => 'Drop files to upload';

  @override
  String get editorOfflineTitle => 'This file isn\'t available offline';

  @override
  String get emptyFolderBody => 'Drop files here or use the New button.';

  @override
  String get emptyFolderTitle => 'This folder is empty';

  @override
  String get emptyHomeBody => 'Create a document or open one shared with you.';

  @override
  String get emptyHomeTitle => 'Welcome to your drive';

  @override
  String get emptyOfflineBody =>
      'Use “Make available offline” on files you need without a connection.';

  @override
  String get emptyOfflineTitle => 'No offline files';

  @override
  String get emptySearchBody => 'Try other words or fewer filters.';

  @override
  String get emptySearchTitle => 'No results';

  @override
  String get emptySharedBody =>
      'Files others share with you will show up here.';

  @override
  String get emptySharedTitle => 'Nothing shared with you yet';

  @override
  String get emptyStarredBody =>
      'Add stars to things you want to find easily later.';

  @override
  String get emptyStarredTitle => 'No starred files yet';

  @override
  String get emptyTrashAction => 'Empty trash';

  @override
  String get emptyTrashBody =>
      'All items in the trash will be deleted forever. This can\'t be undone.';

  @override
  String get emptyTrashTitle => 'Empty trash?';

  @override
  String get emptyTrashViewBody =>
      'Items in the trash are deleted forever after 30 days.';

  @override
  String get emptyTrashViewTitle => 'Trash is empty';

  @override
  String get errorBoundaryBody =>
      'This part of the app hit an unexpected error. Your work is saved.';

  @override
  String get errorBoundaryTitle => 'Something went wrong';

  @override
  String get errorCopyDetails => 'Copy error details';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorNameSlash => 'Names can\'t contain “/”.';

  @override
  String get errorNameTooLong => 'Use at most 255 characters.';

  @override
  String get errorRequired => 'Required';

  @override
  String get expandFolders => 'Expand folders';

  @override
  String get feedbackDescription =>
      'Tell us what happened or what you\'d like to see.';

  @override
  String get feedbackFailed => 'Your report could not be sent';

  @override
  String get feedbackKind => 'Type';

  @override
  String get feedbackKindIdea => 'Idea';

  @override
  String get feedbackKindProblem => 'Problem';

  @override
  String get feedbackMessage => 'Message';

  @override
  String get feedbackThanks => 'Thanks for the feedback!';

  @override
  String get feedbackTitle => 'Report a problem';

  @override
  String get folderTree => 'Folders';

  @override
  String get foldersOnTop => 'Folders on top';

  @override
  String get goHome => 'Go to Home';

  @override
  String get groupEarlier => 'Earlier';

  @override
  String get groupThisWeek => 'Earlier this week';

  @override
  String get groupToday => 'Today';

  @override
  String get groupYesterday => 'Yesterday';

  @override
  String get helpMenu => 'Help';

  @override
  String get helpTopicCommentsBody =>
      'Select text or cells and press Ctrl+Alt+M (⌘⌥M on Mac) to comment. Mention people with @ to notify them. Resolve threads when you\'re done.';

  @override
  String get helpTopicCommentsTitle => 'Comments';

  @override
  String get helpTopicDriveBody =>
      'Your drive holds documents, spreadsheets and folders. Drag files onto folders to move them, star what you use often, and find everything with search.';

  @override
  String get helpTopicDriveTitle => 'Your drive';

  @override
  String get helpTopicHistoryBody =>
      'Versions are saved automatically while you work. Name important versions and restore any of them from File › Version history.';

  @override
  String get helpTopicHistoryTitle => 'Version history';

  @override
  String get helpTopicOfflineBody =>
      'Recently opened files keep working without a connection. Changes sync when you\'re back online.';

  @override
  String get helpTopicOfflineTitle => 'Working offline';

  @override
  String get helpTopicSharingBody =>
      'Use Share to invite people as viewers, commenters or editors, or turn on link sharing for anyone signed in with the link.';

  @override
  String get helpTopicSharingTitle => 'Sharing';

  @override
  String get helpTopicShortcutsBody =>
      'Press Ctrl+/ (⌘/ on Mac) to see every shortcut, and Ctrl+Shift+P (⌘⇧P) to run any command by name.';

  @override
  String get helpTopicShortcutsTitle => 'Keyboard shortcuts';

  @override
  String get historyBack => 'Back to editing';

  @override
  String get historyNoRenderer =>
      'Previews of versions aren\'t available for this file type.';

  @override
  String get historyRestoreThis => 'Restore this version';

  @override
  String get historyShowChanges => 'Show changes';

  @override
  String get importFailed => 'The import failed';

  @override
  String get importUnsupported => 'These files can\'t be imported here';

  @override
  String get inviteInvalid => 'This link is not valid';

  @override
  String get inviteTitle => 'Opening shared file';

  @override
  String get kindDocument => 'Document';

  @override
  String get kindFolder => 'Folder';

  @override
  String get kindSpreadsheet => 'Spreadsheet';

  @override
  String get layoutGrid => 'Grid view';

  @override
  String get layoutList => 'List view';

  @override
  String get mcpAllowControl => 'Allow MCP to control this window';

  @override
  String get mcpControlling => 'An agent is controlling this window';

  @override
  String get mcpHint =>
      'Use this configuration in Claude Desktop or Claude Code with one of your tokens.';

  @override
  String get mcpTitle => 'MCP connection';

  @override
  String get menuAccessibility => 'Accessibility settings';

  @override
  String get menuAppTheme => 'App theme';

  @override
  String get menuDownload => 'Download';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuExplore => 'Explore';

  @override
  String get menuFile => 'File';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuMakeCopy => 'Make a copy';

  @override
  String get menuMode => 'Mode';

  @override
  String get menuNew => 'New';

  @override
  String get menuNewDocument => 'Document';

  @override
  String get menuNewSpreadsheet => 'Spreadsheet';

  @override
  String get menuPanels => 'Panels';

  @override
  String get menuPreferences => 'Preferences';

  @override
  String get menuShare => 'Share';

  @override
  String get menuShow => 'Show';

  @override
  String get menuTools => 'Tools';

  @override
  String get menuVersionHistory => 'Version history';

  @override
  String get menuView => 'View';

  @override
  String get menuZoom => 'Zoom';

  @override
  String get menus => 'Menus';

  @override
  String get moreActions => 'More actions';

  @override
  String get moveHere => 'Move here';

  @override
  String get moveNoFolders => 'No folders here';

  @override
  String get moveNoPermission =>
      'You don\'t have permission to add items to this folder.';

  @override
  String moveTitleMany(int count) {
    return 'Move $count items';
  }

  @override
  String moveTitleOne(String name) {
    return 'Move “$name”';
  }

  @override
  String get nameVersionLabel => 'Version name';

  @override
  String get nameVersionTitle => 'Name this version';

  @override
  String get navHome => 'Home';

  @override
  String get navMyDrive => 'My Drive';

  @override
  String get navOffline => 'Offline';

  @override
  String get navRecent => 'Recent';

  @override
  String get navShared => 'Shared with me';

  @override
  String get navStarred => 'Starred';

  @override
  String get navTrash => 'Trash';

  @override
  String get newButton => 'New';

  @override
  String get newFolderLabel => 'Folder name';

  @override
  String get newFolderTitle => 'New folder';

  @override
  String noAccessBody(String email) {
    return 'You need access to open this file. You\'re signed in as $email.';
  }

  @override
  String get noAccessTitle => 'You need access';

  @override
  String get notAllowed => 'Not allowed';

  @override
  String get notFoundBody => 'The page you\'re looking for doesn\'t exist.';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String notifAccessRequest(String who, String item) {
    return '$who asked for access to $item';
  }

  @override
  String notifAssigned(String who, String item) {
    return '$who assigned you a comment in $item';
  }

  @override
  String notifMention(String who, String item) {
    return '$who mentioned you in $item';
  }

  @override
  String notifOwnership(String who, String item) {
    return '$who wants to make you the owner of $item';
  }

  @override
  String notifReply(String who, String item) {
    return '$who replied in $item';
  }

  @override
  String notifScriptFailure(String item) {
    return 'A script failed in $item';
  }

  @override
  String notifShared(String who, String item) {
    return '$who shared $item with you';
  }

  @override
  String notifSuggestion(String who, String item) {
    return '$who suggested an edit in $item';
  }

  @override
  String notifSuggestionDecided(String who, String item) {
    return '$who reviewed your suggestion in $item';
  }

  @override
  String get notificationsEmpty => 'You\'re all caught up';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String notificationsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
    );
    return '$_temp0';
  }

  @override
  String get notifyEmail => 'In-app and email';

  @override
  String get notifyInApp => 'In-app';

  @override
  String get notifyMentions => 'Mentions';

  @override
  String get notifyOff => 'Off';

  @override
  String get notifyReplies => 'Replies to my comments';

  @override
  String get notifyShares => 'Files shared with me';

  @override
  String get offlineBanner =>
      'You\'re offline. Changes are saved on this device and will sync when you\'re back online.';

  @override
  String get offlineClear => 'Clear local data';

  @override
  String get offlineClearHint =>
      'Removes cached files and pending changes from this device.';

  @override
  String get offlineCleared => 'Local data cleared';

  @override
  String get offlinePending => 'Changes waiting to sync';

  @override
  String get ownerAnyone => 'Owned by anyone';

  @override
  String get ownerMe => 'me';

  @override
  String get ownerMeFilter => 'Owned by me';

  @override
  String get ownerNotMe => 'Not owned by me';

  @override
  String get paletteAllCommands => 'All commands';

  @override
  String get paletteCommands => 'Commands';

  @override
  String get paletteEmpty => 'Nothing found';

  @override
  String get paletteFiles => 'Files';

  @override
  String get paletteGoToFile => 'Open file';

  @override
  String get paletteMenus => 'Menus';

  @override
  String get palettePlaceholder => 'Type a command or search files…';

  @override
  String get paletteRecent => 'Recent';

  @override
  String get paletteSearchMenus => 'Search the menus';

  @override
  String get panelComments => 'Comments';

  @override
  String get panelHistory => 'Version history';

  @override
  String presenceJoined(String name) {
    return '$name joined';
  }

  @override
  String presenceLeft(String name) {
    return '$name left';
  }

  @override
  String get quickSwitcherEmpty => 'No files found';

  @override
  String get quickSwitcherPlaceholder => 'Search documents and spreadsheets…';

  @override
  String get quickSwitcherRecent => 'Recent files';

  @override
  String get quickSwitcherResults => 'Results';

  @override
  String get renameLabel => 'Name';

  @override
  String get renameTitle => 'Rename';

  @override
  String get replyPlaceholder => 'Reply or add others with @';

  @override
  String get requestAccessDescription =>
      'The owner will be notified and can share the file with you.';

  @override
  String get requestAccessFailed => 'The request could not be sent';

  @override
  String get requestAccessMessage => 'Message (optional)';

  @override
  String get requestAccessRole => 'Access';

  @override
  String get requestAccessSend => 'Request access';

  @override
  String get requestAccessTitle => 'Request access';

  @override
  String get restoreVersionAction => 'Restore';

  @override
  String get restoreVersionBody =>
      'The current version is kept in the history, so you can switch back at any time.';

  @override
  String get restoreVersionTitle => 'Restore this version?';

  @override
  String get roleCommenter => 'Commenter';

  @override
  String get roleEditor => 'Editor';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleViewer => 'Viewer';

  @override
  String searchFor(String query) {
    return 'Search for “$query”';
  }

  @override
  String get searchHint => 'Search by name or content';

  @override
  String get searchPlaceholder => 'Search in Drive';

  @override
  String searchResultsFor(String query) {
    return 'Results for “$query”';
  }

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get sessionExpiredBody =>
      'Sign in again to continue. Your work is kept.';

  @override
  String get sessionExpiredTitle => 'Your session expired';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAccent => 'Accent color';

  @override
  String get settingsAccentNeutral => 'Neutral';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAi => 'AI';

  @override
  String get settingsAiHint =>
      'The assistant helps you write and analyze. It only sees files you open with it.';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsDensity => 'Density';

  @override
  String get settingsDeveloper => 'Developer & MCP';

  @override
  String get settingsKeyboard => 'Keyboard shortcuts';

  @override
  String get settingsLanguage => 'Language & region';

  @override
  String get settingsLanguageHint =>
      'Used for dates, numbers and new spreadsheets.';

  @override
  String get settingsLayout => 'Layout';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsOffline => 'Offline & storage';

  @override
  String get settingsOfflineHint =>
      'Files you open recently stay available on this device.';

  @override
  String get settingsPasswordHint =>
      'We\'ll email you a code to set a new password.';

  @override
  String get settingsProfile => 'Profile';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsReduceMotionHint => 'Turns off non-essential animations.';

  @override
  String get settingsSaved => 'Saved';

  @override
  String get settingsSecurity => 'Sign-in & security';

  @override
  String get settingsSheets => 'Wonky Sheets';

  @override
  String get settingsSignOutHint =>
      'Signs you out of Wonky Write and Wonky Sheets on this device.';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsTimeZone => 'Time zone';

  @override
  String get settingsTimeZoneHint =>
      'IANA name, e.g. Europe/Stockholm. Empty follows this device.';

  @override
  String get settingsUiLanguage => 'Language';

  @override
  String get settingsWrite => 'Wonky Write';

  @override
  String get shareAddPeople => 'Add people by name or email';

  @override
  String get shareAnyoneWithLink => 'Anyone with the link';

  @override
  String get shareApprove => 'Approve';

  @override
  String get shareButton => 'Share';

  @override
  String get shareCannotShare =>
      'Only the owner and editors can share this file.';

  @override
  String get shareDeny => 'Deny';

  @override
  String get shareFailed => 'The sharing change could not be saved';

  @override
  String get shareGeneralAccess => 'General access';

  @override
  String shareInherited(String folder) {
    return 'From folder “$folder”';
  }

  @override
  String get shareLinkHint => 'Anyone signed in who has the link can open it';

  @override
  String get shareMessage => 'Message';

  @override
  String get shareNotify => 'Notify people';

  @override
  String get sharePending => 'Pending invite';

  @override
  String get sharePeopleWithAccess => 'People with access';

  @override
  String get shareRemoveAccess => 'Remove access';

  @override
  String shareRemoveBody(String name) {
    return '$name will lose access to this file.';
  }

  @override
  String shareRemoveRecipient(String email) {
    return 'Remove $email';
  }

  @override
  String get shareRemoveTitle => 'Remove access?';

  @override
  String shareRequestTitle(String name, String role) {
    return '$name requests $role access';
  }

  @override
  String get shareRestricted => 'Restricted';

  @override
  String get shareRestrictedHint =>
      'Only people with access can open with the link';

  @override
  String get shareRotateLink => 'Reset link';

  @override
  String shareSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shared with $count people',
      one: 'Shared with 1 person',
    );
    return '$_temp0';
  }

  @override
  String get shareSettingComments => 'Viewers can see comments';

  @override
  String get shareSettingEditors => 'Editors can change permissions and share';

  @override
  String get shareSettingExport =>
      'Viewers and commenters can download, print and copy';

  @override
  String get shareSettingsTitle => 'Sharing settings';

  @override
  String shareTitle(String name) {
    return 'Share “$name”';
  }

  @override
  String shareTransferBody(String name) {
    return '$name becomes the owner once they accept. You\'ll stay an editor.';
  }

  @override
  String get shareTransferOwnership => 'Transfer ownership';

  @override
  String shareTransferSent(String name) {
    return 'Ownership transfer sent to $name';
  }

  @override
  String get shareTransferTitle => 'Transfer ownership?';

  @override
  String shareYou(String name) {
    return '$name (you)';
  }

  @override
  String get sheetsAutocomplete => 'Formula suggestions';

  @override
  String get sheetsFormulaHelp => 'Show formula help';

  @override
  String get sheetsScripts => 'Allow scripts';

  @override
  String shortcutConflictBody(String keys, String commands) {
    return '$keys is already used by $commands. Replace it?';
  }

  @override
  String get shortcutConflictTitle => 'Shortcut in use';

  @override
  String get shortcutReplace => 'Replace';

  @override
  String get shortcutReserved => 'The browser reserves this shortcut.';

  @override
  String get shortcutReset => 'Reset to default';

  @override
  String get shortcutResetAll => 'Reset all';

  @override
  String get shortcutsSearch => 'Search shortcuts';

  @override
  String get shortcutsTitle => 'Keyboard shortcuts';

  @override
  String get showMenus => 'Show menus';

  @override
  String get someone => 'Someone';

  @override
  String sortBy(String field) {
    return 'Sort: $field';
  }

  @override
  String get sortCreated => 'Created';

  @override
  String get sortDescending => 'Descending';

  @override
  String get sortModified => 'Last modified';

  @override
  String get sortModifiedByMe => 'Last modified by me';

  @override
  String get sortName => 'Name';

  @override
  String get sortOpenedByMe => 'Last opened by me';

  @override
  String get sortSize => 'File size';

  @override
  String storageUsed(String size) {
    return '$size used';
  }

  @override
  String get strengthEmpty => 'Enter a password';

  @override
  String get strengthFair => 'Fair';

  @override
  String get strengthGood => 'Good';

  @override
  String strengthLabel(String label) {
    return 'Password strength: $label';
  }

  @override
  String get strengthStrong => 'Strong';

  @override
  String get strengthWeak => 'Weak';

  @override
  String get switchAccount => 'Switch account';

  @override
  String get templateBlank => 'Blank';

  @override
  String get templateEducation => 'Education';

  @override
  String get templateFinance => 'Finance';

  @override
  String get templateGallery => 'Template gallery';

  @override
  String get templatePersonal => 'Personal';

  @override
  String get templateProjectManagement => 'Project management';

  @override
  String templateStripTitle(String kind) {
    return 'Start a new $kind';
  }

  @override
  String get templateWork => 'Work';

  @override
  String get templatesHide => 'Hide templates';

  @override
  String get templatesShow => 'Show templates';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String themeToggleTooltip(String mode) {
    return 'Theme: $mode';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours h ago';
  }

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String get toastAccessRequested => 'Request sent';

  @override
  String toastCopyCreated(String name) {
    return 'Created “$name”';
  }

  @override
  String get toastLinkCopied => 'Link copied';

  @override
  String get toastMcpConfigCopied => 'MCP settings copied';

  @override
  String toastMovedToTrash(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items moved to trash',
      one: 'Moved to trash',
    );
    return '$_temp0';
  }

  @override
  String get toastOfflineOpFailed =>
      'A change made offline could not be applied';

  @override
  String get toastShortcutAdded => 'Shortcut added';

  @override
  String get toastUndoPartial =>
      'Some changes couldn\'t be undone because they were edited by someone else.';

  @override
  String toastVersionNamed(String name) {
    return 'Saved version “$name”';
  }

  @override
  String get toastVersionRestored => 'Version restored';

  @override
  String get toggleSidebar => 'Main menu';

  @override
  String get tokenCopyOnce => 'Copy this token now. You won\'t see it again.';

  @override
  String get tokenCreate => 'Create token';

  @override
  String get tokenName => 'Token name';

  @override
  String get tokenRevoke => 'Revoke';

  @override
  String get tokenRevoked => 'revoked';

  @override
  String get tokensEmpty => 'No tokens yet.';

  @override
  String get tokensHint => 'Personal access tokens let MCP clients act as you.';

  @override
  String get tokensTitle => 'Personal access tokens';

  @override
  String get trashedBanner => 'This file is in the trash.';

  @override
  String get typeAll => 'All types';

  @override
  String get typeDocuments => 'Documents';

  @override
  String get typeFolders => 'Folders';

  @override
  String get typeSpreadsheets => 'Spreadsheets';

  @override
  String get undoHistoryEmpty => 'Nothing to undo';

  @override
  String get undoHistoryTitle => 'Undo history';

  @override
  String get untitledFolder => 'Untitled folder';

  @override
  String get versionNewAvailable => 'A new version is available';

  @override
  String get versionsEmpty => 'No versions yet';

  @override
  String get versionsName => 'Name this version';

  @override
  String get versionsNamedOnly => 'Only named versions';

  @override
  String get versionsOpenFull => 'Open full history';

  @override
  String get versionsRename => 'Rename version';

  @override
  String get versionsRestorePoint => 'Before restore';

  @override
  String get whatsNew1 =>
      'One account for Wonky Write and Wonky Sheets — sign in once, use both.';

  @override
  String get whatsNew2 =>
      'Every action is a command: press Ctrl+Shift+P (⌘⇧P) to run anything.';

  @override
  String get whatsNew3 =>
      'Undo covers drive changes too — rename, move, star and trash.';

  @override
  String get whatsNew4 =>
      'Comments, mentions and version history in every file.';

  @override
  String get whatsNewTitle => 'What\'s new';

  @override
  String get wonkyWork => 'Wonky Work';

  @override
  String get writeAutoPair => 'Auto-pair brackets and quotes';

  @override
  String get writeExportFormat => 'Default download format';

  @override
  String get writeMarkdownShortcuts => 'Markdown shortcuts';

  @override
  String get writePageless => 'Pageless by default';

  @override
  String get writeSmartQuotes => 'Smart quotes';

  @override
  String get writeSpellcheck => 'Spellcheck';

  @override
  String get youHaveCommentAccess => 'You have comment access';

  @override
  String get youHaveViewAccess => 'You have view access';
}
