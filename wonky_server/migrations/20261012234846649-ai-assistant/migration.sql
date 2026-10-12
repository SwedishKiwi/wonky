BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "ai_usage" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "model" text NOT NULL,
    "feature" text NOT NULL,
    "inputTokens" bigint NOT NULL,
    "outputTokens" bigint NOT NULL,
    "cacheReadTokens" bigint NOT NULL,
    "cacheWriteTokens" bigint NOT NULL,
    "at" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "ai_usage_user_at_idx" ON "ai_usage" USING btree ("userId", "at");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "ai_user_setting" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "quality" text NOT NULL DEFAULT 'best'::text,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "ai_user_setting_user_idx" ON "ai_user_setting" USING btree ("userId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "assistant_message" (
    "id" bigserial PRIMARY KEY,
    "threadId" bigint NOT NULL,
    "role" text NOT NULL,
    "contentJson" text,
    "displayText" text NOT NULL,
    "toolCallsJson" text,
    "visible" boolean NOT NULL DEFAULT true,
    "replay" boolean NOT NULL DEFAULT true,
    "runId" text,
    "stopReason" text,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "assistant_message_thread_idx" ON "assistant_message" USING btree ("threadId", "id");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "assistant_thread" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "itemId" bigint,
    "title" text NOT NULL,
    "contextRevision" bigint,
    "contextMarkdown" text,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "assistant_thread_user_item_idx" ON "assistant_thread" USING btree ("userId", "itemId", "updatedAt");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "ai_usage"
    ADD CONSTRAINT "ai_usage_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "ai_user_setting"
    ADD CONSTRAINT "ai_user_setting_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "assistant_message"
    ADD CONSTRAINT "assistant_message_fk_0"
    FOREIGN KEY("threadId")
    REFERENCES "assistant_thread"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "assistant_thread"
    ADD CONSTRAINT "assistant_thread_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "assistant_thread"
    ADD CONSTRAINT "assistant_thread_fk_1"
    FOREIGN KEY("itemId")
    REFERENCES "drive_item"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261012234846649-ai-assistant', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261012234846649-ai-assistant', "timestamp" = now();

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
