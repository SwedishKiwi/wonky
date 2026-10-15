BEGIN;

--
-- Function: gen_random_uuid_v7()
-- Source: https://gist.github.com/kjmph/5bd772b2c2df145aa645b837da7eca74
-- License: MIT (copyright notice included on the generator source code).
--
create or replace function gen_random_uuid_v7()
returns uuid
as $$
begin
  -- use random v4 uuid as starting point (which has the same variant we need)
  -- then overlay timestamp
  -- then set version 7 by flipping the 2 and 1 bit in the version 4 string
  return encode(
    set_bit(
      set_bit(
        overlay(uuid_send(gen_random_uuid())
                placing substring(int8send(floor(extract(epoch from clock_timestamp()) * 1000)::bigint) from 3)
                from 1 for 6
        ),
        52, 1
      ),
      53, 1
    ),
    'hex')::uuid;
end
$$
language plpgsql
volatile;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "chart_link" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "elementId" uuid NOT NULL,
    "spreadsheetItemUuid" uuid NOT NULL,
    "chartObjectId" uuid NOT NULL,
    "sheetId" text,
    "sourceSpecJson" text NOT NULL,
    "dataSnapshotJson" text NOT NULL,
    "sourceVersion" text NOT NULL,
    "updatedAt" timestamp without time zone NOT NULL,
    "updatedBy" uuid NOT NULL,
    "autoUpdate" boolean NOT NULL DEFAULT false,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "chart_link_element_idx" ON "chart_link" USING btree ("elementId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "code_state" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "elementId" uuid NOT NULL,
    "sortKey" text NOT NULL,
    "label" text,
    "code" text NOT NULL,
    "language" text,
    "title" text,
    "highlight" text,
    "annotationsJson" text,
    "transitionJson" text,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "code_state_element_idx" ON "code_state" USING btree ("elementId", "sortKey");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "deck" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "title" text NOT NULL,
    "width" double precision NOT NULL DEFAULT 1920.0,
    "height" double precision NOT NULL DEFAULT 1080.0,
    "sizePreset" text NOT NULL DEFAULT 'widescreen16x9'::text,
    "themeId" uuid,
    "appearance" text NOT NULL DEFAULT 'light'::text,
    "language" text,
    "showSlideNumbers" boolean NOT NULL DEFAULT false,
    "hideNumberOnTitle" boolean NOT NULL DEFAULT true,
    "firstSlideNumber" bigint NOT NULL DEFAULT 1,
    "footerText" text,
    "defaultsJson" text,
    "guidesJson" text,
    "presentJson" text,
    "createdBy" uuid NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

--
-- ACTION CREATE TABLE
--
CREATE TABLE "deck_change_log" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "deckId" uuid NOT NULL,
    "userId" uuid NOT NULL,
    "actorKind" text NOT NULL,
    "sessionId" text NOT NULL,
    "label" text NOT NULL,
    "summaryJson" text NOT NULL,
    "detailJson" text,
    "at" timestamp without time zone NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "deck_change_log_at_idx" ON "deck_change_log" USING btree ("deckId", "at");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "deck_theme" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "deckId" uuid NOT NULL,
    "name" text NOT NULL,
    "sourceKey" text,
    "colorsJson" text NOT NULL,
    "fontsJson" text NOT NULL,
    "textStylesJson" text NOT NULL,
    "backgroundJson" text NOT NULL,
    "shapeStyleJson" text,
    "tableStyleJson" text,
    "codeStyleJson" text,
    "chartStyleJson" text,
    "sortKey" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "deck_theme_deck_idx" ON "deck_theme" USING btree ("deckId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "slide" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "deckId" uuid NOT NULL,
    "sortKey" text NOT NULL,
    "groupId" uuid,
    "layoutId" uuid,
    "backgroundJson" text,
    "skipped" boolean NOT NULL DEFAULT false,
    "notes" text,
    "transitionJson" text,
    "hideMasterElements" boolean,
    "timingsJson" text,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "slide_order_idx" ON "slide" USING btree ("deckId", "sortKey");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "slide_build" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "slideId" uuid NOT NULL,
    "elementId" uuid NOT NULL,
    "kind" text NOT NULL,
    "effect" text NOT NULL,
    "sortKey" text NOT NULL,
    "trigger" text NOT NULL,
    "delayMs" bigint NOT NULL DEFAULT 0,
    "durationMs" bigint NOT NULL,
    "easing" text NOT NULL,
    "optionsJson" text,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "slide_build_slide_idx" ON "slide_build" USING btree ("slideId", "sortKey");
CREATE INDEX "slide_build_element_idx" ON "slide_build" USING btree ("elementId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "slide_element" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "slideId" uuid,
    "layoutId" uuid,
    "masterId" uuid,
    "parentId" uuid,
    "kind" text NOT NULL,
    "name" text,
    "x" double precision,
    "y" double precision,
    "width" double precision,
    "height" double precision,
    "rotation" double precision,
    "flipH" boolean NOT NULL DEFAULT false,
    "flipV" boolean NOT NULL DEFAULT false,
    "zKey" text NOT NULL,
    "readingKey" text,
    "locked" boolean NOT NULL DEFAULT false,
    "hidden" boolean NOT NULL DEFAULT false,
    "placeholderType" text,
    "placeholderOf" uuid,
    "matchKey" text NOT NULL,
    "text" text,
    "textStyleJson" text,
    "fillJson" text,
    "strokeJson" text,
    "effectsJson" text,
    "opacity" double precision,
    "dataJson" text,
    "linkJson" text,
    "altText" text,
    "decorative" boolean NOT NULL DEFAULT false,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "slide_element_slide_idx" ON "slide_element" USING btree ("slideId", "zKey");
CREATE INDEX "slide_element_layout_idx" ON "slide_element" USING btree ("layoutId");
CREATE INDEX "slide_element_master_idx" ON "slide_element" USING btree ("masterId");
CREATE INDEX "slide_element_parent_idx" ON "slide_element" USING btree ("parentId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "slide_group" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "deckId" uuid NOT NULL,
    "title" text NOT NULL,
    "sortKey" text NOT NULL,
    "parentId" uuid,
    "color" text,
    "skipped" boolean NOT NULL DEFAULT false,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "slide_group_order_idx" ON "slide_group" USING btree ("deckId", "sortKey");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "slide_layout" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "masterId" uuid NOT NULL,
    "name" text NOT NULL,
    "key" text,
    "sortKey" text NOT NULL,
    "backgroundJson" text,
    "hideMasterElements" boolean NOT NULL DEFAULT false,
    "hidden" boolean NOT NULL DEFAULT false,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "slide_layout_master_idx" ON "slide_layout" USING btree ("masterId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "slide_master" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "themeId" uuid NOT NULL,
    "name" text NOT NULL,
    "sortKey" text NOT NULL,
    "backgroundJson" text,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "slide_master_theme_idx" ON "slide_master" USING btree ("themeId");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "slide_table_axis" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "elementId" uuid NOT NULL,
    "dimension" text NOT NULL,
    "sortKey" text NOT NULL,
    "size" double precision,
    "header" boolean NOT NULL DEFAULT false,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "slide_table_axis_element_idx" ON "slide_table_axis" USING btree ("elementId", "sortKey");

--
-- ACTION CREATE TABLE
--
CREATE TABLE "slide_table_cell" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid_v7(),
    "spaceId" bigint,
    "elementId" uuid NOT NULL,
    "rowId" uuid NOT NULL,
    "columnId" uuid NOT NULL,
    "text" text,
    "fill" text,
    "borderTop" text,
    "borderRight" text,
    "borderBottom" text,
    "borderLeft" text,
    "vAlign" text,
    "padding" text,
    "rowSpan" bigint,
    "colSpan" bigint,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "slide_table_cell_element_idx" ON "slide_table_cell" USING btree ("elementId");

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "chart_link"
    ADD CONSTRAINT "chart_link_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "chart_link"
    ADD CONSTRAINT "chart_link_fk_1"
    FOREIGN KEY("elementId")
    REFERENCES "slide_element"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "code_state"
    ADD CONSTRAINT "code_state_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "code_state"
    ADD CONSTRAINT "code_state_fk_1"
    FOREIGN KEY("elementId")
    REFERENCES "slide_element"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "deck"
    ADD CONSTRAINT "deck_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "deck_change_log"
    ADD CONSTRAINT "deck_change_log_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "deck_change_log"
    ADD CONSTRAINT "deck_change_log_fk_1"
    FOREIGN KEY("deckId")
    REFERENCES "deck"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "deck_theme"
    ADD CONSTRAINT "deck_theme_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "deck_theme"
    ADD CONSTRAINT "deck_theme_fk_1"
    FOREIGN KEY("deckId")
    REFERENCES "deck"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "slide"
    ADD CONSTRAINT "slide_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "slide"
    ADD CONSTRAINT "slide_fk_1"
    FOREIGN KEY("deckId")
    REFERENCES "deck"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "slide_build"
    ADD CONSTRAINT "slide_build_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "slide_build"
    ADD CONSTRAINT "slide_build_fk_1"
    FOREIGN KEY("slideId")
    REFERENCES "slide"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE ONLY "slide_build"
    ADD CONSTRAINT "slide_build_fk_2"
    FOREIGN KEY("elementId")
    REFERENCES "slide_element"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "slide_element"
    ADD CONSTRAINT "slide_element_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "slide_element"
    ADD CONSTRAINT "slide_element_fk_1"
    FOREIGN KEY("slideId")
    REFERENCES "slide"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE ONLY "slide_element"
    ADD CONSTRAINT "slide_element_fk_2"
    FOREIGN KEY("layoutId")
    REFERENCES "slide_layout"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE ONLY "slide_element"
    ADD CONSTRAINT "slide_element_fk_3"
    FOREIGN KEY("masterId")
    REFERENCES "slide_master"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE ONLY "slide_element"
    ADD CONSTRAINT "slide_element_fk_4"
    FOREIGN KEY("parentId")
    REFERENCES "slide_element"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "slide_group"
    ADD CONSTRAINT "slide_group_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "slide_group"
    ADD CONSTRAINT "slide_group_fk_1"
    FOREIGN KEY("deckId")
    REFERENCES "deck"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "slide_layout"
    ADD CONSTRAINT "slide_layout_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "slide_layout"
    ADD CONSTRAINT "slide_layout_fk_1"
    FOREIGN KEY("masterId")
    REFERENCES "slide_master"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "slide_master"
    ADD CONSTRAINT "slide_master_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "slide_master"
    ADD CONSTRAINT "slide_master_fk_1"
    FOREIGN KEY("themeId")
    REFERENCES "deck_theme"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "slide_table_axis"
    ADD CONSTRAINT "slide_table_axis_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "slide_table_axis"
    ADD CONSTRAINT "slide_table_axis_fk_1"
    FOREIGN KEY("elementId")
    REFERENCES "slide_element"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;

--
-- ACTION CREATE FOREIGN KEY
--
ALTER TABLE ONLY "slide_table_cell"
    ADD CONSTRAINT "slide_table_cell_fk_0"
    FOREIGN KEY("spaceId")
    REFERENCES "offline_sync_spaces"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION;
ALTER TABLE ONLY "slide_table_cell"
    ADD CONSTRAINT "slide_table_cell_fk_1"
    FOREIGN KEY("elementId")
    REFERENCES "slide_element"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE ONLY "slide_table_cell"
    ADD CONSTRAINT "slide_table_cell_fk_2"
    FOREIGN KEY("rowId")
    REFERENCES "slide_table_axis"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE ONLY "slide_table_cell"
    ADD CONSTRAINT "slide_table_cell_fk_3"
    FOREIGN KEY("columnId")
    REFERENCES "slide_table_axis"("id")
    ON DELETE CASCADE
    ON UPDATE NO ACTION
    DEFERRABLE INITIALLY DEFERRED;


--
-- MIGRATION VERSION FOR wonky
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('wonky', '20261014234831373-slides-s1', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261014234831373-slides-s1', "timestamp" = now();

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
