BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "deck_change_log_receipt" (
    "id" bigserial PRIMARY KEY,
    "changeLogId" uuid NOT NULL,
    "deckUuid" uuid NOT NULL,
    "processedAt" timestamp without time zone NOT NULL,
    "completedAt" timestamp without time zone,
    "doneConsumers" json NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "deck_change_log_receipt_idx" ON "deck_change_log_receipt" USING btree ("changeLogId");
CREATE INDEX "deck_change_log_receipt_deck_idx" ON "deck_change_log_receipt" USING btree ("deckUuid", "processedAt");


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261015005729394-slides-receipts', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261015005729394-slides-receipts', "timestamp" = now();

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
