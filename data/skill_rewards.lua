-- ============================================================================
-- Skill unlock rewards
-- Checked in progression.lua when a skill level increases.
-- ============================================================================

SkillRewards = {}

-- Each entry: skill name → level → reward description shown to the player.
-- Actual mechanical effects are applied in the relevant system (begging.lua, etc.)
-- via the helpers GetSkillMultiplier / GetSkillBonus in progression.lua.

SkillRewards['begging'] = {
    [1]  = 'Begging: Slightly better payout (x1.05)',
    [2]  = 'Begging: +2% give chance',
    [3]  = 'Begging: Payout x1.10',
    [4]  = 'Begging: +4% give chance',
    [5]  = 'Begging: Payout x1.20  |  Unlocks silver-tongue dialogue',
    [6]  = 'Begging: +6% give chance',
    [7]  = 'Begging: Payout x1.30',
    [8]  = 'Begging: +8% give chance  |  Reduced cop encounters',
    [9]  = 'Begging: Payout x1.40',
    [10] = 'Begging: Payout x1.50  |  Max silver-tongue',
}

SkillRewards['scavenging'] = {
    [1]  = 'Scavenging: Slightly faster searches',
    [2]  = 'Scavenging: Chance of double loot',
    [3]  = 'Scavenging: Unlocks Tier 2 loot table',
    [4]  = 'Scavenging: Shorter cooldown (-15%)',
    [5]  = 'Scavenging: Double loot chance increased',
    [6]  = 'Scavenging: Unlocks Tier 3 loot table',
    [7]  = 'Scavenging: Shorter cooldown (-30%)',
    [8]  = 'Scavenging: Triple loot chance',
    [9]  = 'Scavenging: Unlocks Tier 4 loot table',
    [10] = 'Scavenging: Max efficiency — rare items doubled',
}

SkillRewards['charisma'] = {
    [1]  = 'Charisma: NPCs warm up to you faster',
    [2]  = 'Charisma: +3% limo encounter chance',
    [3]  = 'Charisma: Mugging chance reduced',
    [4]  = 'Charisma: NPCs yell less at you',
    [5]  = 'Charisma: +6% limo encounter chance  |  Cop nice-chance +10%',
    [6]  = 'Charisma: Unlocks smooth-talk on player begging',
    [7]  = 'Charisma: Generous payout range expanded',
    [8]  = 'Charisma: Mugging virtually eliminated',
    [9]  = 'Charisma: Cop encounter almost always nice',
    [10] = 'Charisma: Legendary street charm',
}

SkillRewards['survival'] = {
    [1]  = 'Survival: Needs drain 5% slower',
    [2]  = 'Survival: Shelter sleep restores +10 energy',
    [3]  = 'Survival: Needs drain 15% slower',
    [4]  = 'Survival: Crafting ingredient cost -1 (min 1)',
    [5]  = 'Survival: Needs drain 25% slower  |  Extra shelter slot',
    [6]  = 'Survival: Sleep fully restores energy',
    [7]  = 'Survival: Needs drain 35% slower',
    [8]  = 'Survival: Crafting yields bonus item (5% chance)',
    [9]  = 'Survival: Needs drain 45% slower',
    [10] = 'Survival: Iron constitution — needs drain halved',
}

-- ============================================================================
-- Mechanical getters used by other systems
-- ============================================================================

-- Payout multiplier from begging skill (1.0 = no bonus)
function GetBeggingMultiplier(skillLevel)
    local mul = { 1.0, 1.05, 1.08, 1.10, 1.15, 1.20, 1.25, 1.30, 1.35, 1.40, 1.50 }
    return mul[math.min(skillLevel + 1, #mul)]
end

-- Extra give-chance bonus (percentage points) from begging skill
function GetBeggingGiveBonus(skillLevel)
    return math.floor(skillLevel * 0.8)
end

-- Scavenge cooldown multiplier (lower = faster)
function GetScavengeCooldownMultiplier(skillLevel)
    local reductions = { 1.0, 0.97, 0.94, 0.90, 0.85, 0.80, 0.75, 0.70, 0.65, 0.60, 0.50 }
    return reductions[math.min(skillLevel + 1, #reductions)]
end

-- Needs drain multiplier from survival skill
function GetNeedsDrainMultiplier(skillLevel)
    local muls = { 1.0, 0.95, 0.90, 0.85, 0.80, 0.75, 0.70, 0.65, 0.60, 0.55, 0.50 }
    return muls[math.min(skillLevel + 1, #muls)]
end
