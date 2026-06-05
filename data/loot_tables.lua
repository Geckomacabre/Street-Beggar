-- ============================================================================
-- Scavenging loot tables
-- Each tier is unlocked by scavenging skill level.
-- weight = relative chance within the tier (higher = more common).
-- ============================================================================

LootTables = {}

-- Tier 1 — available from skill 0
LootTables[1] = {
    { item = 'junk_cloth',   count = { 1, 2 }, weight = 30 },
    { item = 'junk_wood',    count = { 1, 3 }, weight = 25 },
    { item = 'junk_glass',   count = 1,        weight = 20 },
    { item = 'junk_food',    count = 1,        weight = 15 },
    { item = 'junk_water',   count = 1,        weight = 10 },
    { item = 'food_scraps',  count = { 1, 2 }, weight = 12 },
    { item = 'rotten_food',  count = 1,        weight = 10 },
    -- nothing (empty roll)
    { item = nil,            count = 0,        weight = 25 },
}

-- Tier 2 — skill >= 3
LootTables[2] = {
    { item = 'junk_metal',     count = { 1, 3 }, weight = 28 },
    { item = 'junk_cloth',     count = { 2, 4 }, weight = 20 },
    { item = 'junk_wood',      count = { 2, 4 }, weight = 18 },
    { item = 'bandage',        count = 1,        weight = 10 },
    { item = 'junk_food',      count = { 1, 2 }, weight = 10 },
    { item = 'lighter',        count = 1,        weight = 5  },
    { item = 'half_eaten_food',count = 1,        weight = 12 },
    { item = 'metalscrap',     count = { 1, 2 }, weight = 8  },
    { item = nil,              count = 0,        weight = 12 },
}

-- Tier 3 — skill >= 6
LootTables[3] = {
    { item = 'junk_metal',     count = { 2, 4 }, weight = 22 },
    { item = 'junk_cloth',     count = { 2, 5 }, weight = 18 },
    { item = 'shelter_frame',  count = 1,        weight = 8  },
    { item = 'tarp',           count = 1,        weight = 8  },
    { item = 'water',          count = { 1, 2 }, weight = 12 },
    { item = 'sandwich',       count = 1,        weight = 10 },
    { item = 'soap',           count = 1,        weight = 7  },
    { item = 'energy_drink',   count = 1,        weight = 5  },
    { item = 'iron',           count = { 1, 3 }, weight = 10 },
    { item = 'copper',         count = { 1, 2 }, weight = 7  },
    { item = nil,              count = 0,        weight = 8  },
}

-- Tier 4 — skill >= 9 (max, rare tier)
LootTables[4] = {
    { item = 'junk_metal',     count = { 3, 6 }, weight = 18 },
    { item = 'money',          count = { 5, 25 },weight = 15 },
    { item = 'shelter_frame',  count = { 1, 2 }, weight = 10 },
    { item = 'tarp',           count = { 1, 2 }, weight = 10 },
    { item = 'lockpick',       count = 1,        weight = 5  },
    { item = 'bandage',        count = { 1, 3 }, weight = 12 },
    { item = 'water',          count = { 2, 3 }, weight = 10 },
    { item = 'sandwich',       count = { 1, 2 }, weight = 8  },
    { item = 'iron',           count = { 2, 4 }, weight = 10 },
    { item = 'aluminum',       count = { 1, 3 }, weight = 8  },
    { item = 'steel',          count = { 1, 2 }, weight = 6  },
    { item = nil,              count = 0,        weight = 6  },
}

-- Dumpster-specific table (flat, no skill tiers — lots of filler so good loot is rare)
-- Used when outcome = 'items' from the dumpster diving roll
LootTables.dumpster = {
    { item = 'food_scraps',    count = { 1, 3 }, weight = 28 },
    { item = 'rotten_food',    count = 1,        weight = 22 },
    { item = 'half_eaten_food',count = 1,        weight = 12 },
    { item = 'junk_cloth',     count = { 1, 2 }, weight = 18 },
    { item = 'junk_glass',     count = 1,        weight = 15 },
    { item = 'can',      count = { 1, 3 }, weight = 20 },
    { item = 'bottle',   count = { 1, 2 }, weight = 16 },
    { item = 'junk_wood',      count = { 1, 2 }, weight = 12 },
    { item = 'plastic',        count = { 1, 2 }, weight = 10 },
    { item = 'rubber',         count = 1,        weight = 8  },
    { item = 'metalscrap',     count = { 1, 2 }, weight = 7  },
    { item = 'iron',           count = { 1, 2 }, weight = 6  },
    { item = 'junk_metal',     count = { 1, 2 }, weight = 6  },
    { item = 'money',          count = { 1, 5 }, weight = 3  },
    { item = nil,              count = 0,        weight = 35 },
}

-- Returns the correct tier index based on scavenging skill level
function GetLootTier(scavengeSkill)
    if scavengeSkill >= 9 then return 4
    elseif scavengeSkill >= 6 then return 3
    elseif scavengeSkill >= 3 then return 2
    else return 1 end
end

-- Weighted random pick from a tier (pass LootTables[n] or LootTables.dumpster)
function RollLoot(tier)
    local tbl   = type(tier) == 'number' and (LootTables[tier] or LootTables[1]) or tier
    local total = 0
    for _, entry in ipairs(tbl) do total = total + entry.weight end
    local roll  = math.random(total)
    local accum = 0
    for _, entry in ipairs(tbl) do
        accum = accum + entry.weight
        if roll <= accum then
            if not entry.item then return nil end
            local count = type(entry.count) == 'table'
                and math.random(entry.count[1], entry.count[2])
                or  entry.count
            return { item = entry.item, count = count }
        end
    end
    return nil
end
