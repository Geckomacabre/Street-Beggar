-- ============================================================================
-- um_beg config
-- ============================================================================

Config = {}

-- ----------------------------------------------------------------------------
-- BEG EMOTE VARIANTS
-- /beg picks one at random each toggle. To add more, copy an entry.
-- Each variant can override the prop or skip it entirely (prop = nil).
-- ----------------------------------------------------------------------------
Config.BegVariants = {
    {
        name      = 'beg2',
        dict      = 'amb@world_human_bum_freeway@male@base',
        clip      = 'base',
        flag      = 49,
        prop      = 'prop_beggers_sign_01',
        propBone  = 28422,
        propOffset   = vector3(0.0, 0.0, 0.0),
        propRotation = vector3(0.0, 0.0, 0.0),
    },
}

-- ----------------------------------------------------------------------------
-- SCAN PARAMS
-- ----------------------------------------------------------------------------
Config.RollIntervalMinMs   = 4000
Config.RollIntervalMaxMs   = 9000
Config.PerDriverCooldownMs = 300000
Config.PerPedCooldownMs    = 300000
Config.ScanRange           = 10.0   -- tight radius so only cars already beside the player are targeted
Config.MaxVehicleSpeedToTarget = 0.5  -- m/s; only target cars that are essentially stopped (traffic light / stop sign)
Config.ConeAngleDegrees    = 120.0
Config.MaxZDifference      = 5.0   -- ignore cars/peds whose Z differs by more than this (stops bridge picks)

-- Also scan pedestrians (walking, standing) within the cone? They roll the
-- same as drivers: give / yell / ignore. If yelling, ped reacts angrily; if
-- giving, they wave you over and you auto-walk to them like with cars.
Config.ScanPedestrians     = true

-- Visual: cone on minimap for the offer (uses SetBlipShowCone like GTA Online missions)
Config.ShowOfferCone       = true

-- ----------------------------------------------------------------------------
-- OUTCOME ROLLS (must total <=100)
-- ----------------------------------------------------------------------------
Config.Outcomes = {
    give    = 25,
    yell    = 20,
    ignore  = 50,
    cop     = 5,    -- chance an LSPD officer notices and comes over
}

Config.AreaModifiers = {
    nice   = { give = 25, yell = -10, cop = 5  },   -- richer areas = more generous + more police presence
    normal = { give = 0,  yell = 0,   cop = 0  },
    bad    = { give = -15, yell = 15, cop = -3 },
}

Config.PersonalityModifiers = {
    timid      = { give = 25, yell = -20 },
    aggressive = { give = -20, yell = 30 },
    curious    = { give = 10, yell = -5  },
    criminal   = { give = -25, yell = -5 },
}

-- ----------------------------------------------------------------------------
-- OFFER VEHICLE
-- ----------------------------------------------------------------------------
Config.Offer = {
    parkDurationMs    = 12000,
    timeoutMs         = 20000,
    claimRadius       = 3.5,
    blipSprite        = 478,
    blipColor         = 5,        -- yellow
    autoWalkSpeed     = 2.0,      -- 1=walk 2=jog 3=run
    autoWalkTimeoutMs = 25000,
}

-- ----------------------------------------------------------------------------
-- COP ENCOUNTER
-- ----------------------------------------------------------------------------
Config.CopEncounter = {
    niceCopChance      = 50,
    niceCopPayout      = 100,
    meanCopWantedLevel = 2,
    jailMinutes        = 5,
    bustedDurationMs   = 4000,
    pedModels          = { 's_m_y_cop_01', 's_f_y_cop_01', 's_m_y_sheriff_01' },
    vehicleModels      = { 'police', 'police2', 'police3' },
    spawnDistanceMin   = 30.0,
    spawnDistanceMax   = 50.0,
    driveSpeed         = 22.0,
    despawnAfterMs     = 45000,
}

-- ----------------------------------------------------------------------------
-- LIMO ENCOUNTER
-- Always generous. Only triggers after the player has been begging a while.
-- ----------------------------------------------------------------------------
Config.LimoEncounter = {
    payoutMin        = 75,
    payoutMax        = 250,
    offerTimeoutMs   = 22000,
    minBegTimeMs     = 120000, -- must beg for 2 minutes before eligible
    triggerChance    = 4,      -- % per roll interval once eligible
    cooldownMs       = 300000, -- 5 min minimum between limo spawns
    pedModels        = { 'a_m_m_business_01', 'u_m_m_filmdirector', 'a_f_y_business_02', 'u_m_o_filmnoir' },
    vehicleModels    = { 'stretch', 'stretch2' },
    spawnDistanceMin = 35.0,
    spawnDistanceMax = 55.0,
    driveSpeed       = 18.0,
    despawnAfterMs   = 30000,

    -- Optional bonus items given alongside the cash payout.
    -- Each entry is rolled independently — a player can receive multiple.
    -- chance = % (1-100).  count can be a fixed number or { min, max } for a range.
    bonusItems = {
        { item = 'water',      count = 1,          chance = 40 },
        { item = 'sandwich',   count = 1,          chance = 30 },
        { item = 'bandage',    count = { 1, 3 },   chance = 20 },
    },
}

-- ----------------------------------------------------------------------------
-- PAYOUT
-- ----------------------------------------------------------------------------
Config.Payout = {
    min = 1,
    max = 15,
    generousChance = 5,
    generousMin    = 25,
    generousMax    = 75,
}

-- ----------------------------------------------------------------------------
-- COIN SYSTEM
-- Shared coin pool used by begging gives, payphone searches, and drive-by tosses.
-- weight = relative probability (higher = more common).
-- ----------------------------------------------------------------------------
Config.CoinPool = {
    { item = 'penny',   weight = 50 },
    { item = 'nickel',  weight = 25 },
    { item = 'dime',    weight = 15 },
    { item = 'quarter', weight = 10 },
}

-- Chance that a normal begging give pays in coins instead of paper money.
-- Coin gives return 1–coinMax coins from Config.CoinPool.
Config.CoinGive = {
    chance   = 20,   -- % of give outcomes that become coin-only payouts
    countMin = 1,
    countMax = 4,
}

-- ----------------------------------------------------------------------------
-- DIALOG / SUBTITLE TEXT
-- Shown at bottom of screen using GTA's native subtitle ("BeginTextCommandPrint")
-- ----------------------------------------------------------------------------
Config.Subtitles = {
    enabled        = true,
    durationMs     = 3000,
    showStart      = true,
}

-- Subtitle lines have moved to locales/en.json
-- Edit that file to change in-game text without touching config.

-- ----------------------------------------------------------------------------
-- DRIVE-BY TOSS
-- Moving cars passing close have a small chance to toss coins without stopping.
-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- MUGGING EVENT
-- When a ped rolls "give", there's a Mug.chance % it's a mugger in disguise.
-- They wave, walk over, then steal cash and flee.
-- ----------------------------------------------------------------------------
Config.Mug = {
    chance            = 15,     -- % of ped-give rolls that turn into a mug
    stealMin          = 10,
    stealMax          = 40,
    approachTimeoutMs = 15000,  -- how long mugger has to reach the player
    fleeAfterMs       = 8000,   -- despawn delay after fleeing
}

Config.DriveByToss = {
    enabled    = false,
    maxRange   = 18.0,   -- metres — how close the car needs to be
    chance     = 4,      -- percent chance per roll interval
    min        = 1,
    max        = 5,
    cooldownMs = 60000,  -- 1 minute minimum between tosses
}

Config.NotifyDuration   = 4000
Config.RewardCooldownMs = 6000
Config.MaxBegPerSession = 0

-- ----------------------------------------------------------------------------
-- ITEM REQUIREMENT
-- RequireItem = true  → player must have Config.BegItem in ox_inventory to beg.
-- RequireItem = false → standalone mode, no item check (command always works).
-- ----------------------------------------------------------------------------
Config.RequireItem = true
Config.BegItem     = 'cardboard_sign'

-- ----------------------------------------------------------------------------
-- CRAFTING
-- /craftbegbox consumes boxItem + markerItem and produces one BegItem.
-- Requires ox_inventory (Config.UseOxInventory = true).
-- ----------------------------------------------------------------------------
Config.Craft = {
    enabled    = true,
    boxItem    = 'cardboard_box',
    markerItem = 'marker',
    duration   = 5000,   -- ms to hold E at a crafting spot
}

-- ----------------------------------------------------------------------------
-- CRAFTING LOCATIONS
-- Physical spots in the world where a cardboard sign can be made.
-- Walk to any one, press E when prompted, wait for the progress bar.
-- Add as many as you like — coords can be fine-tuned in-game.
-- ----------------------------------------------------------------------------
Config.CraftingBenches = {
    {
        label  = 'Skid Row (near Mission Row)',
        -- Behind the row of tents south of the LSPD building
        coords = vec3(363.0, -1390.0, 32.5),
        radius = 2.5,
    },
    {
        label  = 'Olympic Freeway Underpass',
        -- Homeless camp under the big overpass south of downtown
        coords = vec3(123.0, -1693.0, 29.3),
        radius = 2.5,
    },
    {
        label  = 'Vespucci Beach (under the bridge)',
        -- Canal-side camp beneath the Route 1 bridge
        coords = vec3(-713.0, -1320.0, 5.0),
        radius = 2.5,
    },
}

-- ----------------------------------------------------------------------------
-- ZONE AREA TYPES
-- Keys are GetNameOfZone() short codes (uppercase). Any zone not listed is
-- treated as 'normal'. Valid types: 'nice' | 'normal' | 'bad'
-- ----------------------------------------------------------------------------
-- ----------------------------------------------------------------------------
-- PAYOUT TIERS
-- Active tier is chosen each payout based on what the player has equipped/placed.
-- sign_only falls back to Config.Payout above.
-- ----------------------------------------------------------------------------
Config.PayoutTiers = {
    box_only = {                             -- box placed, no sign, no guitar
        min = 1,  max = 6,
        generousChance = 2, generousMin = 8,   generousMax = 18,
    },
    sign_and_box = {                         -- sign begging + box nearby
        min = 8,  max = 28,
        generousChance = 8, generousMin = 40,  generousMax = 100,
    },
    box_and_guitar = {                       -- busking (guitar + box) — single payout on completion
        min = 30, max = 90,
        generousChance = 15, generousMin = 80, generousMax = 200,
    },
}

-- ----------------------------------------------------------------------------
-- BEGGING BOX
-- Placed prop that earns passively (audience mechanic) or upgrades the tier
-- when combined with the sign or guitar.
-- ----------------------------------------------------------------------------
Config.BeggingBox = {
    item               = 'begging_box',
    model              = 'v_ind_cs_box01',
    placeOffset        = 1.2,     -- metres in front of player when placed
    nearRange          = 8.0,     -- box must be within this to affect tier
    audienceIntervalMs = 20000,   -- how often an NPC walks over in box-only mode
}

-- ----------------------------------------------------------------------------
-- GUITAR / BUSKING
-- Uses a progress bar up to durationMs. Requires box placed nearby.
-- ----------------------------------------------------------------------------
Config.Guitar = {
    item         = 'begging_guitar',
    model        = 'prop_acc_guitar_01',
    bone         = 24818,
    boneOffset   = vector3(-0.05,  0.31, 0.1),
    boneRotation = vector3(  0.0, 20.0, 150.0),
    animDict     = 'switch@trevor@guitar_beatdown',
    animClip     = '001370_02_trvs_8_guitar_beatdown_idle_busker',
    durationMs   = 120000,   -- 2-minute max progress bar
    requireBox   = true,
    boxRange     = 10.0,     -- how close box must be to start busking
}

Config.ZoneAreas = {
    -- Wealthy / nice areas (more generous drivers, more police presence)
    ROCKF   = 'nice',
    RICHM   = 'nice',
    RGLEN   = 'nice',
    GOLF    = 'nice',
    WVINE   = 'nice',
    PBLUFF  = 'nice',
    MORN    = 'nice',
    HAWICK  = 'nice',
    VINEW   = 'nice',
    CHIL    = 'nice',
    -- Rough / bad areas (less giving, more yelling, fewer cops)
    DAVIS   = 'bad',
    CHAMH   = 'bad',
    STRAW   = 'bad',
    RANCHO  = 'bad',
    CYPRE   = 'bad',
    EBURO   = 'bad',
    LMESA   = 'bad',
    SKID    = 'bad',
    BANNING = 'bad',
    ELYSIAN = 'bad',
}

-- ----------------------------------------------------------------------------
-- ox_inventory hook
-- When true, payouts are added via exports.ox_inventory:AddItem (preferred for
-- ox_inventory accounts) instead of qbx_core's Player.Functions.AddMoney.
-- ----------------------------------------------------------------------------
Config.UseOxInventory = true
Config.OxMoneyItem    = 'money'   -- item name in ox_inventory (usually 'money' or 'cash')

-- ----------------------------------------------------------------------------
-- Ambient speech keys
-- ----------------------------------------------------------------------------
Config.YellSpeeches = {
    'GENERIC_INSULT_HIGH',
    'GENERIC_INSULT_MED',
    'GENERIC_CURSE_MED',
    'GENERIC_CURSE_HIGH',
    'CHAT_RESP_NEG',
    'BLOCKED_GENERIC',
}

Config.GiveSpeeches = {
    'GENERIC_HOWS_IT_GOING',
    'GENERIC_HI',
    'CHAT_RESP_POS',
    'GENERIC_THANKS',
}

-- ============================================================================
-- HOBO TOUGH LIFE — JOB SYSTEM
-- All settings below only apply to the new job-locked hobo expansion.
-- The begging / busking / limo system above still uses Config.RequireItem and
-- works independently; the job layer simply gates it behind duty status.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- FRAMEWORK & JOB
-- ----------------------------------------------------------------------------
Config.Framework  = 'qb'            -- 'qb' (QBX / qb-core) or 'esx'
Config.JobName    = 'hobo'          -- job name as it appears in the DB
Config.RequireJob = true            -- false = skip job check (dev / standalone)

-- Hobo camp locations shown on the map.
-- Each camp is a zone players walk into to access the hobo job features.
-- blip: sprite/color/scale/shortRange are all optional — defaults shown below.
--   sprite     → blip icon  (see https://docs.fivem.net/docs/game-references/blips/)
--   color      → blip color (see https://docs.fivem.net/docs/game-references/blips/)
--   scale      → blip size on the map
--   shortRange → true = only visible on minimap when nearby; false = always on full map
Config.HoboCamps = {
    {
        label  = 'Skid Row Camp',
        coords = vec4(363.0, -1390.0, 32.5, 200.0),
        radius = 4.0,
        blip   = { sprite = 88, color = 2, scale = 0.8, shortRange = true },
    },
    {
        label  = 'Vespucci Beach Camp',
        coords = vec4(-713.0, -1320.0, 5.0, 90.0),
        radius = 4.0,
        blip   = { sprite = 88, color = 2, scale = 0.8, shortRange = true },
    },
    {
        label  = 'Olympic Underpass',
        coords = vec4(16.0264, -1206.6689, 30.8959, 15.0639),
        radius = 4.0,
        blip   = { sprite = 88, color = 2, scale = 0.8, shortRange = true },
    },
}

-- ----------------------------------------------------------------------------
-- PROGRESSION
-- ----------------------------------------------------------------------------
Config.MaxRank = 20

-- XP required to REACH each rank (index = rank, value = cumulative XP from rank 1)
Config.RankXP = {
    [1]  = 0,      [2]  = 200,    [3]  = 500,    [4]  = 900,
    [5]  = 1400,   [6]  = 2000,   [7]  = 2700,   [8]  = 3600,
    [9]  = 4600,   [10] = 5800,   [11] = 7200,   [12] = 8800,
    [13] = 10600,  [14] = 12600,  [15] = 14800,  [16] = 17200,
    [17] = 19800,  [18] = 22600,  [19] = 25600,  [20] = 29000,
}

Config.RankNames = {
    [1]  = 'Street Rat',       [2]  = 'Drifter',
    [3]  = 'Wanderer',         [4]  = 'Vagrant',
    [5]  = 'Scavenger',        [6]  = 'Scrounger',
    [7]  = 'Panhandler',       [8]  = 'Grifter',
    [9]  = 'Road Dog',         [10] = 'Hobo',
    [11] = 'Tramp',            [12] = 'Box Knight',
    [13] = 'Cart Pusher',      [14] = 'Curb King',
    [15] = 'Sidewalk Saint',   [16] = 'Alley Boss',
    [17] = 'Undercity Lord',   [18] = 'Shadow Sovereign',
    [19] = 'Street Legend',    [20] = 'King of the Streets',
}

-- XP rewards for various actions
Config.XPRewards = {
    beg_success      = 10,
    beg_generous     = 25,
    scavenge         = 15,
    scavenge_rare    = 40,
    craft            = 20,
    shelter_sleep    = 30,
    rank_up          = 0,    -- rank-up notification only; no extra XP
}

-- Skill names (used as DB keys and display labels)
Config.Skills = { 'begging', 'scavenging', 'charisma', 'survival' }
Config.MaxSkillLevel = 10   -- each skill: 0 – 10

-- Skill XP per gain event
Config.SkillXP = {
    begging    = { beg_success = 1 },
    scavenging = { scavenge = 2 },
    charisma   = { beg_generous = 1, limo = 3, pickpocket_success = 2 },
    survival   = { craft = 1, shelter_sleep = 2 },
}

-- ----------------------------------------------------------------------------
-- SURVIVAL NEEDS  (only active when Config.NeedsEnabled = true)
-- ----------------------------------------------------------------------------
Config.NeedsEnabled = false   -- set true to enable hunger/thirst/hygiene/energy/morale

Config.Needs = {
    hunger  = { label = 'Hunger',  icon = '🍞', drainPerMin = 1.2, warnAt = 20, critAt = 5  },
    thirst  = { label = 'Thirst',  icon = '💧', drainPerMin = 1.8, warnAt = 20, critAt = 5  },
    hygiene = { label = 'Hygiene', icon = '🧼', drainPerMin = 0.2, warnAt = 15, critAt = 5  },
    energy  = { label = 'Energy',  icon = '⚡', drainPerMin = 0.8, warnAt = 25, critAt = 10 },
    morale  = { label = 'Morale',  icon = '😊', drainPerMin = 0.3, warnAt = 20, critAt = 5  },
}

-- How needs affect begging payout multiplier (if enabled)
-- e.g. low hygiene → drivers roll ignore more often
Config.NeedsBeggingPenalty = {
    hygiene = { threshold = 30, givePenalty = -10, yellBonus = 10 },
    morale  = { threshold = 20, givePenalty = -5  },
}

-- Items that restore needs (item name → { need, amount })
Config.NeedRestoreItems = {
    sandwich      = { need = 'hunger',  amount = 40 },
    water         = { need = 'thirst',  amount = 50 },
    junk_food     = { need = 'hunger',  amount = 20 },
    junk_water    = { need = 'thirst',  amount = 25 },
    soap          = { need = 'hygiene', amount = 60 },
    energy_drink  = { need = 'energy',  amount = 40 },
}

-- Needs tick interval (milliseconds)
Config.NeedsTickMs = 60000   -- drain happens every 60 seconds

-- ----------------------------------------------------------------------------
-- SCAVENGING
-- ----------------------------------------------------------------------------
Config.ScavengeBlip = {
    sprite = 78,   -- trash bag
    color  = 5,    -- yellow
    scale  = 0.7,
    label  = 'Scavenge',
}

Config.ScavengeCooldownMs  = 300000   -- 5 min per location
Config.ScavengeProgressMs  = 6000    -- how long the dig progress bar takes
Config.ScavengeMaxPerHour  = 20      -- server-side sanity cap

-- Prop models that become scavenge targets via ox_target.
-- Dumpsters/bins trigger the dumpster-diving outcome system (food/bottles/cash/hobo/items).
-- Tent models trigger the same system — homeless camp looting.
Config.ScavengeProps = {
    -- Dumpsters / bins
    'prop_dumpster_01a', 'prop_dumpster_02a', 'prop_dumpster_02b',
    'prop_dumpster_3a',  'prop_dumpster_4a',  'prop_dumpster_4b',
    'prop_bin_05a',      'prop_bin_07a',      'prop_cs_bin_01',
    'prop_trashbag_01a', 'prop_trashbag_03a',
    -- Tent / camp props (hobo camp scavenging)
    'prop_skid_tent_01',  'prop_skid_tent_01b', 'prop_skid_tent_03',
    'prop_skid_tent_cloth', 'm23_2_prop_m32_tent_01a',
}

-- Fixed scavenge locations (in addition to model-based targeting)
Config.ScavengeLocations = {
    { label = 'Dumpster (Mission Row)',    coords = vec3(368.0,  -1397.0, 32.5),  radius = 2.0 },
    { label = 'Trash Pile (Davis)',        coords = vec3(106.0,  -1710.0, 29.0),  radius = 2.5 },
    { label = 'Abandoned Car (Strawberry)',coords = vec3(-198.0, -1485.0, 33.5),  radius = 2.5 },
    { label = 'Dumpster (Vespucci)',       coords = vec3(-704.0, -1340.0, 5.0),   radius = 2.0 },
    { label = 'Trash Pile (LSIA)',         coords = vec3(-1079.0, -2865.0, 13.8), radius = 2.5 },
    { label = 'Dumpster (Rockford Hills)', coords = vec3(-673.0, 576.0,  168.8),  radius = 2.0 },
    { label = 'Trash Heap (Rancho)',       coords = vec3(714.0,  -1399.0, 25.2),  radius = 2.5 },
    { label = 'Skip (La Mesa)',            coords = vec3(987.0,  -1373.0, 29.3),  radius = 2.0 },
}

-- ----------------------------------------------------------------------------
-- SHELTER
-- ----------------------------------------------------------------------------
Config.MaxShelterRange     = 20.0    -- must be this close to placed shelter to sleep/access
Config.ShelterSleepMs      = 8000    -- progress bar duration for sleeping
Config.ShelterEnergyRestore = 60     -- energy restored per sleep (if needs enabled)
Config.ShelterMoraleRestore = 30
Config.ShelterStorageSlots = 15      -- inventory slots in the shelter stash

-- Placement preview colour (DrawMarker)
Config.ShelterMarker = { r = 100, g = 200, b = 255, a = 160 }

-- ----------------------------------------------------------------------------
-- CRAFTING  (junk-item recipes, separate from cardboard sign)
-- ----------------------------------------------------------------------------
Config.HoboCrafting = {
    {
        label    = 'Brew Dirty Water',
        result   = { item = 'junk_water', count = 1 },
        requires = { { item = 'junk_glass', count = 1 } },
        xp       = 5,
    },
    {
        label    = 'Wrap Food Scraps',
        result   = { item = 'junk_food', count = 1 },
        requires = { { item = 'junk_cloth', count = 1 } },
        xp       = 5,
    },
    {
        label    = 'Make Shelter Frame',
        result   = { item = 'shelter_frame', count = 1 },
        requires = { { item = 'junk_metal', count = 3 }, { item = 'junk_wood', count = 2 } },
        xp       = 20,
    },
    {
        label    = 'Stitch a Tarp',
        result   = { item = 'tarp', count = 1 },
        requires = { { item = 'junk_cloth', count = 3 } },
        xp       = 15,
    },
    {
        label    = 'Fashion a Knife',
        result   = { item = 'weapon_knife', count = 1 },   -- given with low durability (breaks quickly)
        requires = { { item = 'junk_metal', count = 2 }, { item = 'junk_wood', count = 1 } },
        xp       = 25,
    },
}

-- ----------------------------------------------------------------------------
-- CLOTHING  (component-based outfits applied on duty start)
-- Each entry is a list of { component, drawable, texture } applied to the ped.
-- Component IDs: 1=mask 3=torso 4=legs 6=feet 7=accessory 8=undershirt 11=top
-- ----------------------------------------------------------------------------
Config.HoboOutfits = {
    {   -- "Classic Hobo"
        name = 'Classic Hobo',
        components = {
            { comp = 11, drawable = 6,  texture = 0 },   -- torn jacket
            { comp = 4,  drawable = 26, texture = 0 },   -- dirty trousers
            { comp = 6,  drawable = 25, texture = 0 },   -- worn boots
            { comp = 8,  drawable = 15, texture = 0 },   -- stained shirt
        },
    },
    {   -- "Vagrant"
        name = 'Vagrant',
        components = {
            { comp = 11, drawable = 0,  texture = 0 },
            { comp = 4,  drawable = 4,  texture = 0 },
            { comp = 6,  drawable = 2,  texture = 0 },
        },
    },
}

-- ----------------------------------------------------------------------------
-- BLIPS  (only shown while on hobo job)
-- ----------------------------------------------------------------------------
Config.ShowDutyBlips     = true    -- duty-toggle locations
Config.ShowScavengeBlips = false   -- scavenge-location blips (can be noisy)

-- ----------------------------------------------------------------------------
-- PICKPOCKET
-- ----------------------------------------------------------------------------
Config.Pickpocket = {
    -- Grid layout
    totalSlots = 5,       -- total slots shown
    filledMin  = 2,       -- filled slots at charisma < 6
    filledMax  = 3,       -- filled slots at charisma >= 6

    -- Slider speed: ms for the cursor to travel across all slots once (left→right).
    -- Lower = faster = harder. Scales with charisma level.
    sliderSpeeds = {
        [0] = 1200,   -- charisma 0-2  (fast / hard)
        [3] = 1800,   -- charisma 3-5
        [6] = 2400,   -- charisma 6-8
        [9] = 3200,   -- charisma 9-10 (slow / easy)
    },

    -- Loot pool (weighted). type = 'cash' pays money; type = 'item' gives the item.
    -- Adjust item names to match your server's ox_inventory items.
    loot = {
        { label = '$5',        icon = '💵', type = 'cash', value = 5,   weight = 30 },
        { label = '$15',       icon = '💵', type = 'cash', value = 15,  weight = 20 },
        { label = '$30',       icon = '💵', type = 'cash', value = 30,  weight = 12 },
        { label = '$60',       icon = '💵', type = 'cash', value = 60,  weight = 5  },
        { label = 'Phone',     icon = '📱', type = 'item', item = 'phone',      weight = 10 },
        { label = 'Sandwich',  icon = '🥪', type = 'item', item = 'sandwich',   weight = 10 },
        { label = 'Lockpick',  icon = '🔑', type = 'item', item = 'lockpick',   weight = 8  },
        { label = 'Watch',     icon = '⌚', type = 'item', item = 'cheap_watch',weight = 5  },
    },

    -- Chance (%) the NPC calls cops on a FAILED attempt (reduced by charisma)
    copCallChanceBase = 40,    -- at charisma 0
    copCallChanceMin  = 5,     -- floor regardless of charisma

    -- Wanted level on cop call
    wantedLevel = 1,

    -- Per-ped cooldown so the same NPC can't be hit twice quickly
    pedCooldownMs = 300000,    -- 5 minutes

    -- XP rewards
    xpSuccess = 20,
    xpFail    = 2,

    -- Approach animation played before the minigame appears
    animDict = 'anim@gangster@gangster_watch_01',
    animClip = 'idle_d',

    -- Ped models that can NEVER be pickpocketed.
    -- IMPORTANT: only list models that are EXCLUSIVELY script/static peds.
    -- DO NOT add ambient pedestrian models (a_m_*, a_f_*) — those walk around
    -- the world and would be incorrectly blocked for all players.
    -- Our own script peds (fence, etc.) are already blocked by the non-networked
    -- entity check above, so they don't need to be listed here.
    blockedModels = {
        'mp_m_shopkeep_01',    -- loaf_storerobbery shop clerk (script-only model)
    },
}

-- ============================================================================
-- PAYPHONE SEARCHING
-- All 7 phonebox model variants confirmed from worldPublicPhones.json (516 in world)
-- ============================================================================
Config.Payphone = {
    findChance  = 40,      -- % chance anything is in the payphone at all
    coinMin     = 1,       -- minimum number of coins found (drawn from Config.CoinPool)
    coinMax     = 5,       -- maximum number of coins found
    cooldownMs  = 600000,  -- 10 min per payphone before it can be searched again
    xpReward    = 3,
    models      = {
        'prop_phonebox_01a',
        'prop_phonebox_01b',
        'prop_phonebox_01c',
        'prop_phonebox_02',
        'prop_phonebox_03',
        'prop_phonebox_04',
        'p_phonebox_02_s',
    },
}

-- ============================================================================
-- WINDSHIELD WASHING
-- /wash to toggle. Walk up to stopped cars and press [E].
-- ============================================================================
Config.Washing = {
    payoutMin      = 3,
    payoutMax      = 12,
    generousChance = 20,     -- % chance driver tips extra
    generousMin    = 15,
    generousMax    = 35,
    refuseChance   = 25,     -- % driver waves you off (no cooldown penalty)
    yellChance     = 15,     -- % driver yells and honks
    durationMs     = 4000,   -- progress bar length
    carCooldownMs  = 180000, -- 3 min before same car can be washed again
    scanRange      = 5.0,
    xpReward       = 8,
    -- Confirmed from um_emotes AnimationList ("clean" emote)
    animDict       = 'timetable@floyd@clean_kitchen@base',
    animClip       = 'base',
    animProp       = 'prop_sponge_01',
    animPropBone   = 28422,
    animPropOffset = vector3(0.0, 0.0, -0.01),
    animPropRot    = vector3(90.0, 0.0, 0.0),
}

-- ============================================================================
-- CAN / BOTTLE COLLECTING
-- Walk near props to auto-pocket them. Sell at the recycling center.
-- ============================================================================
Config.Collecting = {
    -- Items that can be collected (and their sell price at the recycling center)
    items = {
        { item = 'can',    label = 'Aluminum Can',  price = 1,  weight = 60 },
        { item = 'bottle', label = 'Glass Bottle',  price = 2,  weight = 40 },
    },
    pickupRadius  = 2.5,     -- metres — auto-collect when this close
    respawnMs     = 300000,  -- 5 min before a spot refills
    xpPerItem     = 3,
    maxPerSell    = 60,      -- server-side cap on items per sell transaction

    -- Dynamic anchor detection: scans for dumpster/bin props from Config.ScavengeProps
    -- and spawns collectibles randomly near them — no hardcoded coords needed.
    scanRadius      = 400.0,   -- how far from the player to scan for anchor props on duty start
    maxSpawns       = 30,      -- max number of collectible slot entries created
    spawnOffsetMin  = 1.5,     -- min metres away from anchor prop
    spawnOffsetMax  = 5.0,     -- max metres away from anchor prop

    -- Streaming — props are only physically present when the player is nearby.
    -- Beyond despawnDist they are deleted from memory; re-created on approach.
    streamSpawnDist   = 80.0,   -- spawn prop when player is within this distance
    streamDespawnDist = 120.0,  -- delete prop when player moves further than this

    recycleCenter = {
        coords    = vec3(88.0, -1740.0, 29.3),
        radius    = 4.0,
        blipLabel = 'Recycling Center',
    },
}

-- ============================================================================
-- ODD JOBS BOARD
-- A corkboard at the hobo camp. 3 rotating jobs, refresh every hour.
-- ============================================================================
Config.OddJobs = {
    refreshMs  = 3600000,  -- rotate available jobs every hour
    maxSlots   = 3,        -- jobs shown on the board at once

    board = {
        coords  = vec3(23.4194, -1200.5555, 31.4526),
        heading = 96.4223,
        model   = 'ch2_02b_infoboard',  -- confirmed in ObjectList.ini
        radius  = 1.8,
        label   = 'Job Board',
    },

    -- All possible jobs — 3 are picked at random each refresh
    jobPool = {
        {
            id          = 'trash_overpass',
            label       = 'Clean the Overpass',
            description = 'Pick up trash under the Olympic Freeway overpass. 5 piles.',
            type        = 'collect',
            count       = 5,
            zone        = vec3(123.0, -1693.0, 29.3),
            zoneRadius  = 22.0,
            payout      = 35,
            timeMs      = 300000,
            xp          = 20,
        },
        {
            id          = 'trash_vespucci',
            label       = 'Tidy Up the Beach',
            description = 'Clean up trash along Vespucci Beach. 5 piles.',
            type        = 'collect',
            count       = 5,
            zone        = vec3(-712.0, -1325.0, 5.0),
            zoneRadius  = 25.0,
            payout      = 30,
            timeMs      = 300000,
            xp          = 18,
        },
        {
            id          = 'trash_davis',
            label       = 'Davis Cleanup Crew',
            description = 'Someone needs to deal with the trash in Davis. 6 piles.',
            type        = 'collect',
            count       = 6,
            zone        = vec3(106.0, -1710.0, 29.0),
            zoneRadius  = 28.0,
            payout      = 40,
            timeMs      = 360000,
            xp          = 22,
        },
        {
            id          = 'delivery_package',
            label       = 'Discreet Package Delivery',
            description = 'Pick up a package near the dumpster and deliver it. No questions.',
            type        = 'delivery',
            pickup      = vec3(370.0, -1397.0, 32.5),
            dropoff     = vec3(-184.0, -1414.0, 31.0),
            payout      = 55,
            timeMs      = 420000,
            xp          = 30,
        },
        {
            id          = 'delivery_food',
            label       = 'Food Run',
            description = 'Grab the bag from the corner and bring it around the block.',
            type        = 'delivery',
            pickup      = vec3(100.0, -1705.0, 29.2),
            dropoff     = vec3(50.0,  -1760.0, 29.0),
            payout      = 45,
            timeMs      = 360000,
            xp          = 25,
        },
        {
            id          = 'delivery_rancho',
            label       = 'Rancho Drop',
            description = 'Take the bag to an address in Rancho. Fast.',
            type        = 'delivery',
            pickup      = vec3(718.0, -1397.0, 25.2),
            dropoff     = vec3(800.0, -1280.0, 26.3),
            payout      = 60,
            timeMs      = 480000,
            xp          = 32,
        },
    },
}

-- ============================================================================
-- CAMPFIRES
-- Two types: hobo stove (tin can, short-lived, durable/reusable) and beach fire
-- (requires wood, lasts longer). Both support extinguish and relight.
-- Extinguish stops the particle — prop stays. Relight requires fuel + lighter.
-- Hobo stove has a durability counter; once used up the can is destroyed.
-- ============================================================================

-- Shared cooking recipes (available on both fire types when lit)
Config.CampfireCooking = {
    { input = 'junk_food',    output = 'sandwich',    duration = 8000,  label = 'Cook Scraps'  },
    { input = 'half_eaten_food', output = 'sandwich', duration = 6000,  label = 'Reheat Food'  },
    { input = 'food_scraps',  output = 'junk_food',   duration = 5000,  label = 'Sort Scraps'  },
    { input = 'raw_meat',     output = 'cooked_meat', duration = 12000, label = 'Cook Meat'    },
}

Config.Campfires = {
    -- Hobo stove — tin can + paper. Short burn, but can be re-lit up to maxDurability times.
    hobo_stove = {
        item          = 'hobo_stove',      -- item that triggers placement
        prop          = 'prop_hobo_stove_01',
        ptfxDict      = 'core',
        ptfxName      = 'ent_amb_barrel_fire',
        ptfxScale     = 0.35,
        fuelItem      = 'paper',           -- item required to relight
        fuelPerLight  = 2,                 -- paper needed to light / relight
        burnMs        = 600000,            -- 10 min per lighting
        maxDurability = 5,                 -- times it can be lit before the can wears out
        warmRadius    = 6.0,
        warmTickMs    = 30000,
        energyBonus   = 3,
        moraleBonus   = 2,
    },
    -- Beach fire — logs + wood. Lasts longer, one item per placement.
    beach_fire = {
        item          = 'campfire_kit',    -- existing item
        prop          = 'prop_beach_fire',
        ptfxDict      = 'core',
        ptfxName      = 'ent_amb_barrel_fire',
        ptfxScale     = 0.75,
        fuelItem      = 'junk_wood',       -- item required to relight
        fuelPerLight  = 3,                 -- wood needed to light / relight
        burnMs        = 1800000,           -- 30 min per lighting
        maxDurability = nil,               -- no durability limit
        warmRadius    = 10.0,
        warmTickMs    = 30000,
        energyBonus   = 5,
        moraleBonus   = 4,
    },
}

-- ============================================================================
-- DUMPSTER DIVING
-- Outcome-based search (nothing / food / bottles / cash / hobo encounter).
-- Ported and merged from um_scavenge.
-- ============================================================================
Config.DumpsterDiving = {
    -- Base outcome weights (these are additive — area modifiers adjust them)
    outcomes = {
        nothing = 30,
        items   = 25,   -- rolls from LootTables.dumpster server-side
        food    = 15,   -- gives half_eaten_food or rotten_food
        bottles = 12,   -- gives 1-3 bottle / can
        cash    = 8,    -- gives $1-10 directly
        hobo    = 5,    -- spawns a hostile hobo NPC
    },
    -- Cash bounds for the 'cash' outcome
    cashMin = 1,
    cashMax = 10,
    -- Per-player global cooldown between any two searches (ms)
    playerCooldownMs = 8000,

    -- Area modifier overrides
    areaModifiers = {
        nice   = { hobo = -5, cash = 5,  items = 5  },
        bad    = { hobo = 10, cash = -3, nothing = 5 },
        normal = {},
    },
}

-- Hostile hobo encounter config (used by dumpster diving)
Config.HostileHobo = {
    pedModels = {
        'a_m_m_tramp_01', 'a_m_o_tramp_01', 'a_f_m_tramp_01',
        'a_m_m_acult_01', 'a_m_y_hippy_01',
    },
    weaponPool     = { 'weapon_unarmed', 'weapon_unarmed', 'weapon_knife', 'weapon_bottle' },
    health         = 130,
    despawnAfterMs = 60000,
    yellSpeeches   = { 'GENERIC_INSULT_HIGH', 'GENERIC_CURSE_HIGH', 'CHAT_RESP_NEG' },
}

-- ============================================================================
-- RECYCLING CENTER
-- Open to ALL players (not hobo-job-gated). Sells cans, bottles, and scrap metals.
-- ============================================================================
Config.RecyclingCenter = {
    coords    = vec3(88.0, -1740.0, 29.3),
    radius    = 4.0,
    blipLabel = 'Recycling Center',
    -- Items accepted and their cash value per unit
    prices = {
        can    = 1,
        bottle = 2,
        iron         = 8,
        aluminum     = 9,
        copper       = 10,
        steel        = 9,
        rubber       = 7,
        plastic      = 7,
        metalscrap   = 8,
        junk_metal   = 5,
    },
    maxPerSell = 100,   -- server-side cap on total items per transaction
}

-- ============================================================================
-- COOPERATIVE CAR WASH
-- /offercarwash → washer announces availability.
-- /carwashaccept → nearby car owner accepts; washer can then wash the parked car.
-- Payout comes from the owner's wallet; washer receives Config.Washing amounts.
-- ============================================================================
Config.CoopWash = {
    offerRadius   = 40.0,   -- how far to broadcast the offer
    vehicleRadius = 15.0,   -- max distance owner can be from their vehicle when accepting
    payoutMin     = Config and Config.Washing and Config.Washing.payoutMin or 5,
    payoutMax     = Config and Config.Washing and Config.Washing.payoutMax or 20,
    durationMs    = 5000,   -- progress bar for empty-car wash
    acceptTtlMs   = 120000, -- offer expires after 2 min if nobody accepts
}

-- ============================================================================
-- ONBOARDING MISSION
-- One-time intro chain: Pete (homeless guy) → Sister Agnes → starter kit.
-- Triggers the first time a player goes on duty.
-- ============================================================================
Config.Onboarding = {
    -- Pete — the homeless guy who starts the chain
    pete = {
        location  = vec3(23.4, -1201.5, 31.4),   -- Olympic Underpass hobo camp
        heading   = 200.0,
        pedModel  = 'a_m_m_tramp_01',
        animation = 'WORLD_HUMAN_DRINKING',
    },

    -- Items given to the player when the chain completes (via Sister Agnes)
    starterKit = {
        { item = 'cardboard_box', count = 1 },
        { item = 'marker',        count = 1 },
        { item = 'junk_wood',     count = 3 },
        { item = 'paper',         count = 4 },
    },
}

-- ============================================================================
-- CHURCH SISTER
-- Sister Agnes outside All Saints Community Church, Strawberry.
-- Offers slightly better rotating jobs and one free meal every 12 hours.
-- Open to all players.
-- ============================================================================
Config.ChurchSister = {
    location  = vec4(-2.4612, -1496.4523, 30.8502, 106.6994),   -- All Saints Church, Strawberry
    pedModel  = 'cs_mrs_thornhill',
    heading   = 106.6994,
    -- animation: string = GTA scenario name | table = { dict, clip } from um_emotes
    -- Examples:
    --   animation = 'WORLD_HUMAN_PRAY'
    --   animation = 'WORLD_HUMAN_CLIPBOARD'
    --   animation = { dict = 'missheist_jewelleadinout', clip = 'jh_int_outro_loop_a' }  -- think 2
    animation = { dict = 'anim@amb@casino@hangout@ped_male@stand@02b@idles', clip = 'idle_a' },  -- think4 (standing)

    -- Free food
    foodItem       = 'sandwich',
    foodCooldownMs = 43200000,  -- 12 hours

    -- Job rotation
    refreshMs = 1800000,   -- refresh available jobs every 30 minutes
    maxJobs   = 2,         -- jobs shown at once (fewer but better than the board's 3)

    -- Job pool — 25–30% better payout than equivalent board jobs
    jobPool = {
        {
            id          = 'church_steps',
            label       = 'Clean the Church Steps',
            description = 'Sweep up litter around the front of the church. 4 piles.',
            type        = 'collect',
            count       = 4,
            zone        = vec3(-346.0, -1556.0, 28.0),
            zoneRadius  = 22.0,
            payout      = 50,
            timeMs      = 240000,
            xp          = 25,
        },
        {
            id          = 'church_food_run',
            label       = 'Food Parcel Delivery',
            description = 'Take a bag of groceries to a family on the block.',
            type        = 'delivery',
            pickup      = vec3(-350.0, -1548.0, 28.0),
            dropoff     = vec3(-282.0, -1530.0, 30.5),
            payout      = 65,
            timeMs      = 360000,
            xp          = 30,
        },
        {
            id          = 'church_davis_run',
            label       = 'Deliver Supplies to Davis',
            description = 'Bring a care package to someone in Davis.',
            type        = 'delivery',
            pickup      = vec3(-350.0, -1548.0, 28.0),
            dropoff     = vec3(99.0, -1715.0, 29.3),
            payout      = 80,
            timeMs      = 480000,
            xp          = 38,
        },
        {
            id          = 'church_yard_clean',
            label       = 'Tidy the Churchyard',
            description = 'Clear rubbish from the churchyard. 5 piles.',
            type        = 'collect',
            count       = 5,
            zone        = vec3(-360.0, -1560.0, 28.0),
            zoneRadius  = 25.0,
            payout      = 55,
            timeMs      = 300000,
            xp          = 28,
        },
        {
            id          = 'church_shelter_run',
            label       = 'Shelter Supply Drop',
            description = 'Drop off blankets at the Olympic Underpass camp.',
            type        = 'delivery',
            pickup      = vec3(-350.0, -1548.0, 28.0),
            dropoff     = vec3(16.0, -1206.0, 31.0),
            payout      = 75,
            timeMs      = 420000,
            xp          = 35,
        },
    },
}

-- ============================================================================
-- WORLD INTERACTIONS  (ported from um_WorldInteractions)
-- All features are open to every player unless noted.
-- ============================================================================

-- Porta Potties — enter for privacy (camera-above view, G to exit)
Config.PortaPotty = {
    enabled  = true,
    camFOV   = 120.0,
    exitKey  = 47,   -- G
    models   = { 'prop_portaloo_01a' },
}

-- Dumpster Hiding — climb inside a dumpster (separate from scavenging search)
Config.DumpsterHide = {
    enabled  = true,
    camFOV   = 120.0,
    exitKey  = 47,   -- G
    -- Uses Config.ScavengeProps dumpster models (registered in scavenging.lua)
    -- Only large dumpsters make sense for hiding:
    models   = {
        'prop_dumpster_01a', 'prop_dumpster_02a', 'prop_dumpster_02b',
        'prop_dumpster_3a',  'prop_dumpster_4a',  'prop_dumpster_4b',
    },
}

-- Chairs — sit in world chair props (G to stand up)
Config.Chairs = {
    enabled  = true,
    exitKey  = 47,   -- G
    models   = {
        { model = 'prop_skid_chair_01',   offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_skid_chair_02',   offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_skid_chair_03',   offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_01a',       offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_01b',       offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_02',        offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_03',        offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_04a',       offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_04b',       offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_05',        offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_06',        offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_07',        offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_08',        offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_09',        offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_chair_10',        offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_off_chair_01',    offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_off_chair_03',    offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_off_chair_04',    offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_off_chair_05',    offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_old_wood_chair',  offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_rub_couch03',     offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_couch_sm_05',     offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_rock_chair_01',   offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_sol_chair',       offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_cs_office_chair', offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_gc_chair02',      offset = vec3(0.0, -0.5, 0.0) },
        { model = 'bkr_prop_weed_chair_01a', offset = vec3(0.0, -0.5, 0.0) },
        { model = 'prop_torture_ch_01',   offset = vec3(0.0, -0.5, 0.0) },
    },
}

-- Toilets — use restroom fixtures (G to leave)
Config.Toilets = {
    enabled  = true,
    exitKey  = 47,   -- G
    models   = {
        { model = 'prop_toilet_01', offset = vec3(0.0, -0.6, 0.0) },
        { model = 'prop_toilet_02', offset = vec3(0.0, -0.6, 0.0) },
    },
}

-- Vending Machines — buy snacks and drinks with cash
Config.VendingMachines = {
    enabled  = true,
    -- Per machine type: label, models, items for sale
    machines = {
        {
            label       = 'Snack Machine',
            icon        = 'fas fa-cookie-bite',
            models      = { 'prop_vend_snak_01', 'prop_vend_snak_02' },
            items       = {
                { name = 'twerks_candy',   label = 'Twerks Bar',   price = 2,  stock = 25 },
                { name = 'snikkel_candy',  label = 'Snikkel Bar',  price = 2,  stock = 25 },
            },
        },
        {
            label       = 'Soda Machine',
            icon        = 'fas fa-whiskey-glass',
            models      = { 'prop_vend_soda_01', 'prop_vend_soda_02' },
            items       = {
                { name = 'kurkakola', label = 'Cola', price = 2, stock = 50 },
            },
        },
        {
            label       = 'Coffee Machine',
            icon        = 'fas fa-mug-hot',
            models      = { 'prop_vend_coffe_01' },
            items       = {
                { name = 'coffee', label = 'Coffee', price = 5, stock = 50 },
            },
        },
        {
            label       = 'Water Machine',
            icon        = 'fas fa-bottle-droplet',
            models      = { 'prop_vend_water_01' },
            items       = {
                { name = 'water_bottle', label = 'Water Bottle', price = 1, stock = 50 },
            },
        },
    },
}

-- Parking Meters — pay, inspect (police/parking jobs), or rob (requires lockpick)
Config.ParkingMeters = {
    enabled        = true,
    pricePerMinute = 0.5,
    checkMeterSecs = 7,        -- progress bar duration for inspection
    jobsCanCheck   = { ['police'] = true, ['parking_enforcement'] = true },
    models         = { 'prop_parknmeter_01', 'prop_parknmeter_02' },

    robbery = {
        enabled       = true,
        requiredItem  = 'lockpick',
        payoutMinCents = 10,    -- minimum payout in cents ($0.10)
        payoutMaxCents = 75,    -- maximum payout in cents ($0.75)
        cooldownMins  = 10,
        skillCheck    = { checks = 4, difficulty = 'easy', keys = { 'w', 'a', 's', 'd' } },
        dispatchBlip  = { sprite = 108, color = 1, scale = 1.2 },
    },
}

-- ============================================================================
-- STOLEN GOODS FENCE
-- A shady NPC in a back alley who buys pickpocketed items.
-- Higher charisma = better prices. Chance of police attention.
-- ============================================================================
Config.Fence = {
    location  = vec3(-527.0859, -1503.7495, 9.4286),
    heading   = 123.2228,
    pedModel  = 'a_m_m_skidrow_01',
    -- animation: string = GTA scenario name | table = { dict, clip } from um_emotes
    -- Examples:
    --   animation = 'WORLD_HUMAN_STAND_IMPATIENT'
    --   animation = 'WORLD_HUMAN_SMOKING'
    --   animation = { dict = 'missheist_jewelleadinout', clip = 'jh_int_outro_loop_a' }  -- think 2
    animation = 'WORLD_HUMAN_STAND_IMPATIENT',

    nearRadius   = 30.0,  -- only show blip within this distance
    bustedChance = 8,     -- % chance of 1-star wanted after a sale
    wantedLevel  = 1,
    cooldownMs   = 60000, -- 1 min between sales

    charismaBonus = 0.05, -- +5% price per charisma level (up to +50% at level 10)

    -- Items this fence will buy (price = base cash paid)
    -- Adjust items to match your server's ox_inventory item names
    items = {
        { item = 'phone',       label = 'Stolen Phone',  price = 40 },
        { item = 'cheap_watch', label = 'Hot Watch',     price = 25 },
        { item = 'lockpick',    label = 'Lockpick',      price = 15 },
    },
}

-- ----------------------------------------------------------------------------
-- COMMANDS
-- ----------------------------------------------------------------------------
-- /hobo        → open hobo menu
-- /hoboduty    → toggle on/off duty at a duty location
-- /hobostatus  → print your rank / XP / skills to chat
-- /beg         → existing (guarded by isOnHoboJob when Config.RequireJob = true)
-- /crafthobo   → open hobo crafting menu
-- /wash        → toggle windshield washing mode

