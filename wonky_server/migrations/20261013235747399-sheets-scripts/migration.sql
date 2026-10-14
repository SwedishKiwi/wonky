BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "script_authorization" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "spreadsheetUuid" uuid NOT NULL,
    "scopes" json NOT NULL,
    "grantedAt" timestamp without time zone NOT NULL,
    "revokedAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "script_auth_user_sheet_idx" ON "script_authorization" USING btree ("userId", "spreadsheetUuid");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "script_execution" (
    "id" bigserial PRIMARY KEY,
    "uuid" uuid NOT NULL,
    "spreadsheetUuid" uuid NOT NULL,
    "projectId" uuid,
    "functionName" text NOT NULL,
    "kind" text NOT NULL,
    "triggerId" uuid,
    "userId" bigint NOT NULL,
    "runAsUserId" bigint NOT NULL,
    "runtime" text NOT NULL,
    "status" text NOT NULL,
    "buildSourceHash" text NOT NULL,
    "startedAt" timestamp without time zone NOT NULL,
    "durationMs" bigint NOT NULL,
    "logs" text NOT NULL,
    "errorMessage" text,
    "errorStackJson" text,
    "changeId" uuid,
    "cellsRead" bigint NOT NULL,
    "cellsWritten" bigint NOT NULL,
    "fetchCalls" bigint NOT NULL,
    "callCount" bigint NOT NULL DEFAULT 1
);

-- Indexes
CREATE UNIQUE INDEX "script_exec_uuid_idx" ON "script_execution" USING btree ("uuid");
CREATE INDEX "script_exec_sheet_idx" ON "script_execution" USING btree ("spreadsheetUuid", "startedAt");
CREATE INDEX "script_exec_user_idx" ON "script_execution" USING btree ("userId", "startedAt");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "script_quota_usage" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "day" timestamp without time zone NOT NULL,
    "serverRuntimeMs" bigint NOT NULL DEFAULT 0,
    "clientRuntimeMs" bigint NOT NULL DEFAULT 0,
    "urlFetchCalls" bigint NOT NULL DEFAULT 0,
    "urlFetchBytes" bigint NOT NULL DEFAULT 0,
    "triggerRuns" bigint NOT NULL DEFAULT 0
);

-- Indexes
CREATE UNIQUE INDEX "script_quota_user_day_idx" ON "script_quota_usage" USING btree ("userId", "day");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "script_trigger_state" (
    "id" bigserial PRIMARY KEY,
    "triggerId" uuid NOT NULL,
    "spreadsheetUuid" uuid NOT NULL,
    "scheduleJson" text,
    "nextRunAt" timestamp without time zone,
    "lastRunAt" timestamp without time zone,
    "lastStatus" text,
    "consecutiveFailures" bigint NOT NULL DEFAULT 0,
    "disabledReason" text,
    "runningSince" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "script_trigger_state_id_idx" ON "script_trigger_state" USING btree ("triggerId");
CREATE INDEX "script_trigger_state_due_idx" ON "script_trigger_state" USING btree ("nextRunAt");


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261013235747399-sheets-scripts', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261013235747399-sheets-scripts', "timestamp" = now();

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
