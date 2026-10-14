BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sheets_import_job" (
    "id" bigserial PRIMARY KEY,
    "uuid" uuid NOT NULL,
    "userId" bigint NOT NULL,
    "authUserId" uuid NOT NULL,
    "spreadsheetUuid" uuid NOT NULL,
    "uploadFileId" uuid NOT NULL,
    "fileName" text NOT NULL,
    "format" text NOT NULL,
    "optionsJson" text NOT NULL,
    "activeSheetId" text,
    "status" text NOT NULL,
    "progressDone" bigint NOT NULL,
    "progressTotal" bigint NOT NULL,
    "reportJson" text,
    "sheetIdsJson" text,
    "changeId" uuid,
    "errorCode" text,
    "error" text,
    "cancelRequested" boolean NOT NULL DEFAULT false,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "leaseOwner" text,
    "leaseUntil" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "sheets_import_job_uuid_idx" ON "sheets_import_job" USING btree ("uuid");
CREATE INDEX "sheets_import_job_user_idx" ON "sheets_import_job" USING btree ("userId", "status");


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261014152733788-sheets-import-jobs', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014152733788-sheets-import-jobs', "timestamp" = now();

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
