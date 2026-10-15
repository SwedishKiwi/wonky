BEGIN;

--
-- ACTION ALTER TABLE
--
ALTER TABLE "drive_item" ADD COLUMN "attachmentBytes" bigint NOT NULL DEFAULT 0;
ALTER TABLE "drive_item" ADD COLUMN "kindMask" bigint NOT NULL DEFAULT 0;
ALTER TABLE "drive_item" ADD COLUMN "mimeType" text;
ALTER TABLE "drive_item" ADD COLUMN "fileCategory" text;
ALTER TABLE "drive_item" ADD COLUMN "uploadState" text;
ALTER TABLE "drive_item" ADD COLUMN "fileMetaJson" text;
ALTER TABLE "drive_item" ADD COLUMN "previewFileId" uuid;
CREATE INDEX "drive_item_upload_idx" ON "drive_item" USING btree ("uploadState", "createdAt");
--
-- ACTION ALTER TABLE
--
ALTER TABLE "space_reservation" ADD COLUMN "kind" text NOT NULL DEFAULT 'spreadsheet'::text;
--
-- ACTION ALTER TABLE
--
ALTER TABLE "space_subscription" ADD COLUMN "kind" text NOT NULL DEFAULT 'spreadsheet'::text;
--
-- ACTION CREATE TABLE
--
CREATE TABLE "storage_reservation" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "fileUuid" uuid NOT NULL,
    "itemId" bigint,
    "bytes" bigint NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "expiresAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "storage_reservation_file_idx" ON "storage_reservation" USING btree ("fileUuid");
CREATE INDEX "storage_reservation_user_idx" ON "storage_reservation" USING btree ("userId");
CREATE INDEX "storage_reservation_expiry_idx" ON "storage_reservation" USING btree ("expiresAt");

--
-- ACTION ALTER TABLE
--
ALTER TABLE "user_preferences" ADD COLUMN "slidesDefaults" text NOT NULL DEFAULT '{}'::text;
ALTER TABLE "user_preferences" ADD COLUMN "slidesPresenter" text NOT NULL DEFAULT '{}'::text;
ALTER TABLE "user_preferences" ADD COLUMN "driveDefaults" text NOT NULL DEFAULT '{}'::text;
--
-- ACTION CREATE TABLE
--
CREATE TABLE "user_storage" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "usedBytes" bigint NOT NULL DEFAULT 0,
    "reservedBytes" bigint NOT NULL DEFAULT 0,
    "documentsBytes" bigint NOT NULL DEFAULT 0,
    "spreadsheetsBytes" bigint NOT NULL DEFAULT 0,
    "presentationsBytes" bigint NOT NULL DEFAULT 0,
    "filesBytes" bigint NOT NULL DEFAULT 0,
    "trashBytes" bigint NOT NULL DEFAULT 0,
    "quotaBytesOverride" bigint,
    "overQuotaSince" timestamp without time zone,
    "reconciledAt" timestamp without time zone,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "user_storage_user_idx" ON "user_storage" USING btree ("userId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "storage_reservation"
    ADD CONSTRAINT "storage_reservation_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "storage_reservation"
    ADD CONSTRAINT "storage_reservation_fk_1"
    FOREIGN KEY("itemId")
    REFERENCES "drive_item"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "user_storage"
    ADD CONSTRAINT "user_storage_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261014223419475-m8-drive-contracts', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014223419475-m8-drive-contracts', "timestamp" = now();

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
