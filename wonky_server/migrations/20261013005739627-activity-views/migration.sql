BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "item_view_day" (
    "id" bigserial PRIMARY KEY,
    "itemId" bigint NOT NULL,
    "userId" bigint NOT NULL,
    "day" timestamp without time zone NOT NULL,
    "views" bigint NOT NULL DEFAULT 1,
    "lastViewedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "item_view_day_idx" ON "item_view_day" USING btree ("itemId", "userId", "day");
CREATE INDEX "item_view_day_item_idx" ON "item_view_day" USING btree ("itemId", "day");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "user_activity_settings" (
    "id" bigserial PRIMARY KEY,
    "userId" bigint NOT NULL,
    "showViewHistory" boolean NOT NULL DEFAULT true,
    "updatedAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "user_activity_settings_user_idx" ON "user_activity_settings" USING btree ("userId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "item_view_day"
    ADD CONSTRAINT "item_view_day_fk_0"
    FOREIGN KEY("itemId")
    REFERENCES "drive_item"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "item_view_day"
    ADD CONSTRAINT "item_view_day_fk_1"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "user_activity_settings"
    ADD CONSTRAINT "user_activity_settings_fk_0"
    FOREIGN KEY("userId")
    REFERENCES "user_profile"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261013005739627-activity-views', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261013005739627-activity-views', "timestamp" = now();

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
