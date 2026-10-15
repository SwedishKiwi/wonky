BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_ai_usage" (
    "id" bigserial PRIMARY KEY,
    "day" text NOT NULL,
    "provider" text NOT NULL,
    "model" text NOT NULL,
    "feature" text NOT NULL,
    "requests" bigint NOT NULL,
    "inputTokens" bigint NOT NULL,
    "outputTokens" bigint NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "board_ai_usage_idx" ON "board_ai_usage" USING btree ("day", "provider", "model", "feature");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_bundle_suggestion" (
    "id" bigserial PRIMARY KEY,
    "title" text NOT NULL,
    "rationale" text NOT NULL,
    "area" text,
    "postIds" json NOT NULL,
    "state" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_comment" (
    "id" bigserial PRIMARY KEY,
    "uuid" uuid NOT NULL,
    "postId" bigint,
    "taskId" bigint,
    "authorId" bigint,
    "body" text NOT NULL,
    "systemEvent" text,
    "moderation" text NOT NULL,
    "moderationReason" text,
    "needsCheck" boolean NOT NULL DEFAULT false,
    "createdAt" timestamp without time zone NOT NULL,
    "editedAt" timestamp without time zone,
    "deletedAt" timestamp without time zone,
    "removedAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "board_comment_uuid_idx" ON "board_comment" USING btree ("uuid");
CREATE INDEX "board_comment_post_idx" ON "board_comment" USING btree ("postId", "createdAt");
CREATE INDEX "board_comment_task_idx" ON "board_comment" USING btree ("taskId", "createdAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_flag" (
    "id" bigserial PRIMARY KEY,
    "postId" bigint,
    "commentId" bigint,
    "userId" bigint NOT NULL,
    "reason" text NOT NULL,
    "note" text,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "board_flag_post_idx" ON "board_flag" USING btree ("postId", "userId");
CREATE INDEX "board_flag_comment_idx" ON "board_flag" USING btree ("commentId", "userId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_github_delivery" (
    "id" bigserial PRIMARY KEY,
    "deliveryId" text NOT NULL,
    "event" text NOT NULL,
    "receivedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "board_github_delivery_idx" ON "board_github_delivery" USING btree ("deliveryId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_moderation_log" (
    "id" bigserial PRIMARY KEY,
    "adminId" bigint NOT NULL,
    "action" text NOT NULL,
    "targetKind" text NOT NULL,
    "targetId" bigint NOT NULL,
    "beforeJson" text,
    "afterJson" text,
    "reason" text,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "board_moderation_log_target_idx" ON "board_moderation_log" USING btree ("targetKind", "targetId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_post" (
    "id" bigserial PRIMARY KEY,
    "authorId" bigint,
    "kind" text NOT NULL,
    "reportedKind" text NOT NULL,
    "area" text,
    "size" text,
    "aiLabels" boolean NOT NULL DEFAULT true,
    "title" text NOT NULL,
    "body" text NOT NULL,
    "contextJson" text,
    "appHint" text NOT NULL,
    "screenshotFileId" bigint,
    "status" text NOT NULL,
    "moderation" text NOT NULL,
    "moderationReason" text,
    "needsCheck" boolean NOT NULL DEFAULT false,
    "editedByModerator" boolean NOT NULL DEFAULT false,
    "triageState" text NOT NULL,
    "triageJson" text,
    "triageAttempts" bigint NOT NULL DEFAULT 0,
    "suggestedTitle" text,
    "summary" text,
    "duplicateOfId" bigint,
    "possibleDuplicateOfId" bigint,
    "duplicateHintDismissed" boolean NOT NULL DEFAULT false,
    "declineReason" text,
    "taskId" bigint,
    "score" bigint NOT NULL DEFAULT 0,
    "voteCount" bigint NOT NULL DEFAULT 0,
    "commentCount" bigint NOT NULL DEFAULT 0,
    "flagCount" bigint NOT NULL DEFAULT 0,
    "createdAt" timestamp without time zone NOT NULL,
    "editedAt" timestamp without time zone,
    "deletedAt" timestamp without time zone,
    "removedAt" timestamp without time zone
);

-- Indexes
CREATE INDEX "board_post_list_idx" ON "board_post" USING btree ("moderation", "kind", "status", "score");
CREATE INDEX "board_post_author_idx" ON "board_post" USING btree ("authorId");
CREATE INDEX "board_post_task_idx" ON "board_post" USING btree ("taskId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_pull_request" (
    "id" bigserial PRIMARY KEY,
    "prNumber" bigint NOT NULL,
    "taskId" bigint,
    "authorLogin" text NOT NULL,
    "headSha" text NOT NULL,
    "state" text NOT NULL,
    "gateState" text NOT NULL,
    "gateReason" text,
    "gateFirstFailedAt" timestamp without time zone,
    "gateCommentId" bigint,
    "reviewCommentId" bigint,
    "lastReviewSha" text,
    "lastReviewJson" text,
    "lastReviewAt" timestamp without time zone,
    "reviewDay" text,
    "reviewCount" bigint NOT NULL DEFAULT 0,
    "mergeCommitSha" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "board_pull_request_number_idx" ON "board_pull_request" USING btree ("prNumber");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_task" (
    "id" bigserial PRIMARY KEY,
    "title" text NOT NULL,
    "area" text NOT NULL,
    "size" text NOT NULL,
    "status" text NOT NULL,
    "promptBody" text NOT NULL,
    "promptGeneratedAt" timestamp without time zone,
    "promptEditedById" bigint,
    "promptEditedAt" timestamp without time zone,
    "createdById" bigint NOT NULL,
    "publishedAt" timestamp without time zone,
    "claimedById" bigint,
    "claimedAt" timestamp without time zone,
    "claimExpiresAt" timestamp without time zone,
    "claimWarnedAt" timestamp without time zone,
    "claimCode" text,
    "pullRequestUrl" text,
    "prNumber" bigint,
    "prAuthorLogin" text,
    "mergeCommitSha" text,
    "doneAt" timestamp without time zone,
    "shippedDeploySha" text,
    "shippedAt" timestamp without time zone,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "board_task_status_idx" ON "board_task" USING btree ("status");
CREATE INDEX "board_task_claim_idx" ON "board_task" USING btree ("claimedById");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_user_profile" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "githubLogin" text,
    "blockedAt" timestamp without time zone,
    "blockedUntil" timestamp without time zone,
    "blockedReason" text,
    "blockedById" bigint
);

-- Indexes
CREATE UNIQUE INDEX "board_user_profile_user_idx" ON "board_user_profile" USING btree ("userId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "board_vote" (
    "id" bigserial PRIMARY KEY,
    "postId" bigint NOT NULL,
    "userId" bigint NOT NULL,
    "value" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "board_vote_unique_idx" ON "board_vote" USING btree ("postId", "userId");
CREATE INDEX "board_vote_recent_idx" ON "board_vote" USING btree ("postId", "createdAt");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "board_comment"
    ADD CONSTRAINT "board_comment_fk_0"
    FOREIGN KEY("postId")
    REFERENCES "board_post"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "board_comment"
    ADD CONSTRAINT "board_comment_fk_1"
    FOREIGN KEY("taskId")
    REFERENCES "board_task"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "board_comment"
    ADD CONSTRAINT "board_comment_fk_2"
    FOREIGN KEY("authorId")
    REFERENCES "user_profile"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "board_flag"
    ADD CONSTRAINT "board_flag_fk_0"
    FOREIGN KEY("postId")
    REFERENCES "board_post"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "board_flag"
    ADD CONSTRAINT "board_flag_fk_1"
    FOREIGN KEY("commentId")
    REFERENCES "board_comment"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "board_flag"
    ADD CONSTRAINT "board_flag_fk_2"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "board_post"
    ADD CONSTRAINT "board_post_fk_0"
    FOREIGN KEY("authorId")
    REFERENCES "user_profile"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "board_post"
    ADD CONSTRAINT "board_post_fk_1"
    FOREIGN KEY("screenshotFileId")
    REFERENCES "stored_file"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "board_post"
    ADD CONSTRAINT "board_post_fk_2"
    FOREIGN KEY("taskId")
    REFERENCES "board_task"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "board_pull_request"
    ADD CONSTRAINT "board_pull_request_fk_0"
    FOREIGN KEY("taskId")
    REFERENCES "board_task"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "board_task"
    ADD CONSTRAINT "board_task_fk_0"
    FOREIGN KEY("claimedById")
    REFERENCES "user_profile"("id")
    ON DELETE SET NULL
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "board_user_profile"
    ADD CONSTRAINT "board_user_profile_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "board_vote"
    ADD CONSTRAINT "board_vote_fk_0"
    FOREIGN KEY("postId")
    REFERENCES "board_post"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "board_vote"
    ADD CONSTRAINT "board_vote_fk_1"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261015192946787-board', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261015192946787-board', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260924105404509', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105404509', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_offline_sync
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_offline_sync', '20260914143806119', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260914143806119', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();


COMMIT;
