import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/dialogs.dart';
import '../../shell/shell_services.dart';
import '../board_hub.dart';
import 'board_widgets.dart';

/// The repository the board's PRs go to (`BoardMe.repository`).
String boardRepository(ShellServices s) =>
    BoardHub.of(s).me.value?.repository ?? 'serverpod/wonky';

/// The Serverpod CLI version of `CONTRIBUTING.md` step 2 (the `VERSION` in
/// `.github/workflows/tests.yml`).
const boardServerpodCliVersion = '4.1.0-beta.3';

/// The setup commands of `CONTRIBUTING.md` steps 2–5 (specs/16 §10.3), one
/// per copy button: install the CLI, clone your fork of [repository] and get
/// the packages, configure the server, run it.
List<String> boardSetupCommands(String repository) {
  final name = repository.split('/').last;
  return [
    'dart install serverpod_cli@$boardServerpodCliVersion',
    'git clone https://github.com/<you>/$name.git',
    'cd $name && flutter pub get',
    'cd wonky_server',
    'cp config/passwords.example.yaml config/passwords.yaml',
    'docker compose up -d',
    'serverpod start',
  ];
}

/// `/improvements/contribute` (specs/16 §10.3): the short version of
/// `CONTRIBUTING.md` (steps 1–7) as app strings, so it works without
/// GitHub, with copy buttons and a link to the full guide.
class BoardContributePage extends StatefulWidget {
  const BoardContributePage({super.key, required this.services});

  final ShellServices services;

  @override
  State<BoardContributePage> createState() => _BoardContributePageState();
}

class _BoardContributePageState extends State<BoardContributePage> {
  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    BoardHub.of(s).me.addListener(_onMe);
    unawaited(BoardHub.of(s).loadMe());
  }

  @override
  void dispose() {
    BoardHub.of(s).me.removeListener(_onMe);
    super.dispose();
  }

  void _onMe() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final repo = boardRepository(s);
    final cmds = boardSetupCommands(repo);
    final security =
        BoardHub.of(s).me.value?.securityContact ?? 'security@serverpod.dev';
    Widget step(
      int n,
      String title,
      String text, [
      List<Widget> more = const [],
    ]) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.muted,
              shape: BoxShape.circle,
            ),
            child: Text('$n', style: theme.textTheme.small),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.p.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(text, style: theme.textTheme.muted),
                ...more,
              ],
            ),
          ),
        ],
      ),
    );
    return BoardFrame(
      services: s,
      title: l.boardContributeTitle,
      child: ListView(
        key: const ValueKey<String>('board.contribute'),
        padding: EdgeInsets.fromLTRB(
          narrow ? 16 : 24,
          24,
          narrow ? 16 : 24,
          48,
        ),
        children: [
          BoardContent(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.boardContributeIntro, style: theme.textTheme.p),
                const SizedBox(height: 20),
                step(1, l.boardContribStep1Title, l.boardContribStep1),
                step(2, l.boardContribStep2Title, l.boardContribStep2, [
                  BoardCopyLine(
                    text: cmds[0],
                    copyKey: 'board.contribute.copy.0',
                  ),
                ]),
                step(3, l.boardContribStep3Title, l.boardContribStep3, [
                  for (final i in const [1, 2])
                    BoardCopyLine(
                      text: cmds[i],
                      copyKey: 'board.contribute.copy.$i',
                    ),
                ]),
                step(4, l.boardContribStep4Title, l.boardContribStep4, [
                  for (final i in const [3, 4, 5])
                    BoardCopyLine(
                      text: cmds[i],
                      copyKey: 'board.contribute.copy.$i',
                    ),
                ]),
                step(5, l.boardContribStep5Title, l.boardContribStep5, [
                  BoardCopyLine(
                    text: cmds[6],
                    copyKey: 'board.contribute.copy.6',
                  ),
                ]),
                step(6, l.boardContribStep6Title, l.boardContribStep6, [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ShadButton.outline(
                      key: const ValueKey<String>('board.contribute.tasks'),
                      size: ShadButtonSize.sm,
                      onPressed: () => s.router.go('/improvements/tasks'),
                      child: Text(l.boardTabTasks),
                    ),
                  ),
                ]),
                step(7, l.boardContribStep7Title, l.boardContribStep7, [
                  const BoardCopyLine(
                    text: 'Wonky-Task: T-12\nWonky-Claim: XXXX-XXXX',
                    copyKey: 'board.contribute.copy.prLines',
                  ),
                ]),
                Text(l.boardContribLicense, style: theme.textTheme.muted),
                const SizedBox(height: 8),
                Text(
                  l.boardContribSecurity(security),
                  style: theme.textTheme.muted,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ShadButton(
                    key: const ValueKey<String>('board.contribute.guide'),
                    leading: const Icon(LucideIcons.bookOpen, size: 16),
                    onPressed: () => confirmExternalLink(
                      context,
                      s,
                      url: 'https://github.com/$repo/blob/main/CONTRIBUTING.md',
                    ),
                    child: Text(l.boardContributeGuide),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
