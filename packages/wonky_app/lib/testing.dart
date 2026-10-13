/// Test helpers for the shell and the apps (suite 15 §2, §5): in-memory
/// repositories and a [CommandTestHarness] that runs commands through the
/// real dispatcher and undo service. Never import from `lib/` code.
library;

export 'src/assistant/fake_assistant_api.dart';
export 'src/testing/command_test_harness.dart';
export 'src/testing/fake_repositories.dart'
    hide
        UnfakedCommentRepository,
        UnfakedFileRepository,
        UnfakedMetaRepository,
        UnfakedNotificationRepository,
        UnfakedPresenceRepository,
        UnfakedSharingRepository,
        UnfakedVersionRepository;
