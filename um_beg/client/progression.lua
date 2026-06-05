-- ============================================================================
-- client/progression.lua
-- Local XP / rank / skill state + helpers used by all other systems.
-- ============================================================================

-- Local mirror of server-stored data (loaded on duty start)
local progData = {
    xp       = 0,
    rank     = 1,
    skills   = { begging = 0, scavenging = 0, charisma = 0, survival = 0 },
}

-- ============================================================================
-- Getters (used by begging.lua, scavenging.lua, needs.lua, etc.)
-- ============================================================================

function GetProgData()   return progData end
function GetRank()       return progData.rank end
function GetXP()         return progData.xp end
function GetSkill(name)  return progData.skills[name] or 0 end

function GetRankName(rank)
    return Config.RankNames[rank] or ('Rank ' .. tostring(rank))
end

function GetXPForNextRank(rank)
    return Config.RankXP[rank + 1] or Config.RankXP[Config.MaxRank]
end

-- ============================================================================
-- XP gain (called by other systems; syncs to server)
-- ============================================================================

function GainXP(amount, sourceTag)
    if not isOnHoboJob() then return end
    if amount <= 0 then return end
    TriggerServerEvent('um_hobos:gainXP', amount, sourceTag)
end

-- Skill XP gain — sourceTag maps to Config.SkillXP entries
function GainSkillXP(sourceTag)
    if not isOnHoboJob() then return end
    TriggerServerEvent('um_hobos:gainSkillXP', sourceTag)
end

-- ============================================================================
-- Receive updated progression from server
-- ============================================================================

RegisterNetEvent('um_hobos:client:updateProgression', function(data)
    local oldRank = progData.rank
    progData = data

    -- Rank-up notification
    if data.rank > oldRank then
        local name = GetRankName(data.rank)
        lib.notify({
            type        = 'success',
            title       = '🏆 Rank Up!',
            description = string.format(Lang.rank_up, name, data.rank),
            duration    = 8000,
        })
        -- Flash the HUD
        SendNUIMessage({ action = 'rankUp', rank = data.rank, rankName = name })
    end

    -- Push fresh data to HUD
    SendNUIMessage({
        action   = 'updateProgression',
        xp       = data.xp,
        rank     = data.rank,
        rankName = GetRankName(data.rank),
        xpNext   = GetXPForNextRank(data.rank),
        skills   = data.skills,
    })
end)

RegisterNetEvent('um_hobos:client:skillUp', function(skillName, newLevel)
    progData.skills[skillName] = newLevel
    local reward = SkillRewards[skillName] and SkillRewards[skillName][newLevel]
    local desc   = reward or string.format(Lang.skill_up, skillName, newLevel)
    lib.notify({ type = 'success', title = '⭐ Skill Up!', description = desc, duration = 6000 })
    SendNUIMessage({ action = 'updateSkills', skills = progData.skills })
end)

-- ============================================================================
-- Load progression when player goes on duty
-- ============================================================================

AddEventHandler('um_hobos:onDuty', function()
    TriggerServerEvent('um_hobos:requestProgression')
end)

RegisterNetEvent('um_hobos:client:loadProgression', function(data)
    progData = data
    SendNUIMessage({
        action   = 'updateProgression',
        xp       = data.xp,
        rank     = data.rank,
        rankName = GetRankName(data.rank),
        xpNext   = GetXPForNextRank(data.rank),
        skills   = data.skills,
    })
end)
