import 'package:flutter/widgets.dart';

import '../l10n/wonky_app_localizations.dart';

/// The shell's strings of [context], or the English ones when no
/// `WonkyAppLocalizations` delegate is installed (shared widgets pumped by
/// app or package tests without the shell's delegates).
WonkyAppLocalizations wonkyAppL10nOrEnglish(BuildContext context) =>
    Localizations.of<WonkyAppLocalizations>(context, WonkyAppLocalizations) ??
    lookupWonkyAppLocalizations(const Locale('en'));
