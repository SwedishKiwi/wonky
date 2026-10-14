BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "ai_function_cache" (
    "id" bigserial PRIMARY KEY,
    "key" text NOT NULL,
    "spreadsheetUuid" uuid NOT NULL,
    "model" text NOT NULL,
    "value" text NOT NULL,
    "error" text,
    "createdAt" timestamp without time zone NOT NULL,
    "hits" bigint NOT NULL DEFAULT 0
);

-- Indexes
CREATE UNIQUE INDEX "ai_function_cache_key_idx" ON "ai_function_cache" USING btree ("key");
CREATE INDEX "ai_function_cache_sheet_idx" ON "ai_function_cache" USING btree ("spreadsheetUuid");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "sheets_ai_preview_record" (
    "id" bigserial PRIMARY KEY,
    "previewId" text NOT NULL,
    "userId" bigint NOT NULL,
    "spreadsheetUuid" uuid NOT NULL,
    "previewJson" text NOT NULL,
    "changesJson" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "expiresAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "sheets_ai_preview_id_idx" ON "sheets_ai_preview_record" USING btree ("previewId");
CREATE INDEX "sheets_ai_preview_expires_idx" ON "sheets_ai_preview_record" USING btree ("expiresAt");


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261014155607023-sheets-ai-previews-ai-cache', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014155607023-sheets-ai-previews-ai-cache', "timestamp" = now();

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
