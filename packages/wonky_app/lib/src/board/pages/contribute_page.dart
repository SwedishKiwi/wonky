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

/// The setup commands of `CONTRIBUTING.md` steps 2–5 (specs/16 §10.3), one
/// per copy button.
List<String> boardSetupCommands(String repository) => [
  'dart pub global activate serverpod_cli',
  'git clone https://github.com/$repository.git',
  'cd ${repository.split('/').last}/wonky_server && docker compose up -d',
  'cp config/passwords.example.yaml config/passwords.yaml',
  'serverpod start',
];

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
                  BoardCopyLine(
                    text: cmds[1],
                    copyKey: 'board.contribute.copy.1',
                  ),
                  BoardCopyLine(
                    text: cmds[2],
                    copyKey: 'board.contribute.copy.2',
                  ),
                ]),
                step(4, l.boardContribStep4Title, l.boardContribStep4, [
                  BoardCopyLine(
                    text: cmds[3],
                    copyKey: 'board.contribute.copy.3',
                  ),
                ]),
                step(5, l.boardContribStep5Title, l.boardContribStep5, [
                  BoardCopyLine(
                    text: cmds[4],
                    copyKey: 'board.contribute.copy.4',
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
