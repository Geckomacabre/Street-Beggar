-- ============================================================================
-- um_hobos — database setup
-- Run this once, OR let server/database.lua auto-create the table on start.
-- ============================================================================

-- Hobo progression table
CREATE TABLE IF NOT EXISTS `hobo_progression` (
    `citizenid`        VARCHAR(50)   NOT NULL,
    `xp`               INT           NOT NULL DEFAULT 0,
    `rank`             INT           NOT NULL DEFAULT 1,
    `skill_begging`    INT           NOT NULL DEFAULT 0,
    `skill_scavenging` INT           NOT NULL DEFAULT 0,
    `skill_charisma`   INT           NOT NULL DEFAULT 0,
    `skill_survival`   INT           NOT NULL DEFAULT 0,
    `hunger`           FLOAT         NOT NULL DEFAULT 100.0,
    `thirst`           FLOAT         NOT NULL DEFAULT 100.0,
    `hygiene`          FLOAT         NOT NULL DEFAULT 100.0,
    `energy`           FLOAT         NOT NULL DEFAULT 100.0,
    `morale`           FLOAT         NOT NULL DEFAULT 100.0,
    `shelter_data`     LONGTEXT          NULL DEFAULT NULL,
    `updated_at`       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================================
-- Add the hobo job to QBX jobs table (run this in your qbx_core SQL or via
-- the in-game admin panel — whichever your server uses).
-- ============================================================================

INSERT IGNORE INTO `jobs` (`name`, `label`) VALUES ('hobo', 'Hobo');
INSERT IGNORE INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`)
VALUES
    ('hobo', 0, 'street_rat',     'Street Rat',         0,  '{}', '{}'),
    ('hobo', 1, 'drifter',        'Drifter',            0,  '{}', '{}'),
    ('hobo', 2, 'king',           'King of the Streets',0,  '{}', '{}');

-- ============================================================================
-- ox_inventory items (add to ox_inventory/data/items.lua instead, but listed
-- here for reference)
-- ============================================================================
-- ['junk_metal']     = { label='Scrap Metal',    weight=200, stack=true,  close=true }
-- ['junk_cloth']     = { label='Torn Cloth',     weight=100, stack=true,  close=true }
-- ['junk_wood']      = { label='Wood Scrap',     weight=250, stack=true,  close=true }
-- ['junk_glass']     = { label='Broken Glass',   weight=100, stack=true,  close=true }
-- ['junk_food']      = { label='Food Scraps',    weight=100, stack=true,  close=true,
--                          client = { event = 'um_hobos:useNeedItem:junk_food' } }
-- ['junk_water']     = { label='Dirty Water',    weight=150, stack=true,  close=true,
--                          client = { event = 'um_hobos:useNeedItem:junk_water' } }
-- ['shelter_frame']  = { label='Shelter Frame',  weight=800, stack=false, close=true }
-- ['tarp']           = { label='Tarp',           weight=500, stack=true,  close=true }
-- ['soap']           = { label='Bar of Soap',    weight= 50, stack=true,  close=true,
--                          client = { event = 'um_hobos:useNeedItem:soap' } }
-- ['hobo_knife']     = { label='Shiv',           weight=300, stack=false, close=true }
