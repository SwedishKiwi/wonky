# Wonky Work

**A collaborative office suite, built in the open with Flutter and Serverpod.**

Wonky Work is documents, spreadsheets, presentations and file storage in one place, with real-time
collaboration, comments, version history and a built-in AI assistant. It runs in the browser
at **[wonky.work](https://wonky.work)**.

| App | What it is |
|-----|------------|
| **Wonky Drive** | Every file in one place: folders, sharing, uploads and previews. |
| **Wonky Write** | A Markdown-first word processor, like Google Docs. Real-time editing, comments, suggestions and themes. |
| **Wonky Sheets** | An offline-first spreadsheet, like Google Sheets. Formulas, charts, pivots and conditional formatting. |
| **Wonky Slides** | Presentations with themes, transitions, live Sheets charts and a presenter view. |

One account signs you in to all of them, and they share one design and one way of working: every
action is a command, and every change can be undone.

## We're looking for contributors

Wonky Work is young, and there is a lot left to build. If you write Flutter or Dart, or you want
to learn by shipping real features, we'd love your help.

Contributing works a little differently here:

1. **Users tell us what to build.** Bugs and ideas are posted and voted on in the app, on the
   [Bugs & improvements](https://wonky.work/improvements) board.
2. **We turn the best ones into tasks.** Each task comes with a reviewed prompt, written for an AI
   coding agent such as [Claude Code](https://claude.com/claude-code).
3. **You claim a task and build it.** Pick one from
   [Up for grabs](https://wonky.work/improvements/tasks), claim it, and build it together with
   your agent. Then review and test the result, and open a pull request.
4. **It ships.** When your PR is merged and deployed, everyone who voted for the improvement gets
   a notification.

You don't need to know the whole codebase to start: the task, the prompt and the specs give you
and your agent the context. **[Read the contributing guide →](CONTRIBUTING.md)**

Found a bug or have an idea? Post it on the [board](https://wonky.work/improvements), where others
can vote on it.

## How it's built

- **Flutter** for all four apps, running on the web (compiled to WebAssembly).
- **[Serverpod](https://serverpod.dev)** for the backend: one Dart server for authentication,
  real-time sync, storage and AI.
- **Specs first.** The [`specs/`](specs/README.md) folder is the source of truth for how
  everything works, and it's kept up to date with the code. It's a good place to start reading.

```
wonky_server/    The Serverpod server, which also serves the web apps
wonky_drive/     Wonky Drive
wonky_write/     Wonky Write
wonky_sheets/    Wonky Sheets
wonky_slides/    Wonky Slides
packages/        Shared packages: UI, app shell, sync, charts, formulas and more
specs/           The specifications
```

To run it locally, follow [CONTRIBUTING.md](CONTRIBUTING.md): it takes you from a fresh machine to
a running server and apps.

## License and security

Wonky Work is open source under the [BSD 3-Clause License](LICENSE). Contributors sign the
[Contributor License Agreement](CLA.md); a bot asks you to on your first pull request.

Please report security issues privately to **security@serverpod.dev**, not on the board or in
GitHub issues. See [SECURITY.md](SECURITY.md).

---

Made by the [Serverpod](https://serverpod.dev) team and contributors.
