BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "script_job" (
    "id" bigserial PRIMARY KEY,
    "kind" text NOT NULL,
    "spreadsheetUuid" uuid NOT NULL,
    "itemUuid" uuid NOT NULL,
    "triggerId" uuid,
    "runAsUserId" bigint NOT NULL,
    "functionName" text NOT NULL,
    "payloadJson" text NOT NULL,
    "status" text NOT NULL,
    "enqueuedAt" timestamp without time zone NOT NULL,
    "leaseOwner" text,
    "leaseUntil" timestamp without time zone,
    "attempts" bigint NOT NULL DEFAULT 0,
    "coalesced" bigint NOT NULL DEFAULT 0,
    "resultJson" text,
    "finishedAt" timestamp without time zone
);

-- Indexes
CREATE INDEX "script_job_status_idx" ON "script_job" USING btree ("status", "enqueuedAt");
CREATE INDEX "script_job_trigger_idx" ON "script_job" USING btree ("triggerId", "status");
CREATE INDEX "script_job_user_idx" ON "script_job" USING btree ("runAsUserId", "status");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "script_trigger_state" ADD COLUMN "lastNotifiedAt" timestamp without time zone;

--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261014170811542-script-jobs', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014170811542-script-jobs', "timestamp" = now();

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
