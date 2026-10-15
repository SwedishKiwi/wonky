BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "slides_snapshot_index" (
    "id" bigserial PRIMARY KEY,
    "itemVersionId" bigint NOT NULL,
    "slidesJson" text NOT NULL,
    "changesJson" text NOT NULL,
    "authorIds" json NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "slides_snapshot_index_version_idx" ON "slides_snapshot_index" USING btree ("itemVersionId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "slides_snapshot_index"
    ADD CONSTRAINT "slides_snapshot_index_fk_0"
    FOREIGN KEY("itemVersionId")
    REFERENCES "item_version"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261015115837413-slides-versions', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261015115837413-slides-versions', "timestamp" = now();

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
