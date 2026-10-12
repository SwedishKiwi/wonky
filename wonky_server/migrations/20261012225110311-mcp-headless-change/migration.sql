BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "headless_change" (
    "id" bigserial PRIMARY KEY,
    "changeId" uuid NOT NULL,
    "kind" text NOT NULL,
    "itemId" bigint NOT NULL,
    "documentId" bigint,
    "revision" bigint,
    "inverseJson" text,
    "metaField" text,
    "metaBeforeJson" text,
    "metaAfterJson" text,
    "userId" bigint NOT NULL,
    "actorKind" text NOT NULL,
    "label" text,
    "toolName" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "revertedAt" timestamp without time zone
);

-- Indexes
CREATE UNIQUE INDEX "headless_change_id_idx" ON "headless_change" USING btree ("changeId");
CREATE INDEX "headless_change_created_idx" ON "headless_change" USING btree ("createdAt");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "headless_change"
    ADD CONSTRAINT "headless_change_fk_0"
    FOREIGN KEY("itemId")
    REFERENCES "drive_item"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261012225110311-mcp-headless-change', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261012225110311-mcp-headless-change', "timestamp" = now();

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
