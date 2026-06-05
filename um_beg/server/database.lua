-- ============================================================================
-- server/database.lua
-- oxmysql helpers for hobo progression, needs, and shelter data.
-- ============================================================================

-- ============================================================================
-- Schema bootstrap (runs once on resource start)
-- ============================================================================

MySQL.ready(function()
    MySQL.query([[
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
            `onboarding_done`  TINYINT(1)    NOT NULL DEFAULT 0,
            `updated_at`       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

-- ============================================================================
-- Load / upsert player row
-- ============================================================================

function DB_LoadProgression(citizenid, cb)
    MySQL.single(
        'SELECT * FROM hobo_progression WHERE citizenid = ?',
        { citizenid },
        function(row)
            if not row then
                -- First time — insert defaults and return them
                MySQL.insert(
                    'INSERT IGNORE INTO hobo_progression (citizenid) VALUES (?)',
                    { citizenid }
                )
                cb({
                    xp             = 0, rank = 1,
                    skills         = { begging = 0, scavenging = 0, charisma = 0, survival = 0 },
                    shelter        = nil,
                    onboarding_done = false,
                })
                return
            end
            cb({
                xp     = row.xp,
                rank   = row.rank,
                skills = {
                    begging    = row.skill_begging,
                    scavenging = row.skill_scavenging,
                    charisma   = row.skill_charisma,
                    survival   = row.skill_survival,
                },
                shelter         = row.shelter_data and json.decode(row.shelter_data) or nil,
                onboarding_done = row.onboarding_done == 1,
            })
        end
    )
end

function DB_SaveProgression(citizenid, data)
    MySQL.update([[
        INSERT INTO hobo_progression
            (citizenid, xp, rank, skill_begging, skill_scavenging, skill_charisma, skill_survival)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            xp = VALUES(xp), rank = VALUES(rank),
            skill_begging = VALUES(skill_begging),
            skill_scavenging = VALUES(skill_scavenging),
            skill_charisma = VALUES(skill_charisma),
            skill_survival = VALUES(skill_survival)
    ]], {
        citizenid,
        data.xp, data.rank,
        data.skills.begging, data.skills.scavenging,
        data.skills.charisma, data.skills.survival,
    })
end

function DB_SaveNeeds(citizenid, needs)
    MySQL.update([[
        INSERT INTO hobo_progression (citizenid, hunger, thirst, hygiene, energy, morale)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            hunger = VALUES(hunger), thirst = VALUES(thirst),
            hygiene = VALUES(hygiene), energy = VALUES(energy), morale = VALUES(morale)
    ]], { citizenid, needs.hunger, needs.thirst, needs.hygiene, needs.energy, needs.morale })
end

function DB_SaveOnboarding(citizenid)
    MySQL.update([[
        INSERT INTO hobo_progression (citizenid, onboarding_done)
        VALUES (?, 1)
        ON DUPLICATE KEY UPDATE onboarding_done = 1
    ]], { citizenid })
end

function DB_SaveShelter(citizenid, shelterData)
    local encoded = shelterData and json.encode(shelterData) or nil
    MySQL.update([[
        INSERT INTO hobo_progression (citizenid, shelter_data)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE shelter_data = VALUES(shelter_data)
    ]], { citizenid, encoded })
end
