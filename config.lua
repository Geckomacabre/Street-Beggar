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
-- DIALOG / SUBTITLE TEXT
-- Shown at bottom of screen using GTA's native subtitle ("BeginTextCommandPrint")
-- ----------------------------------------------------------------------------
Config.Subtitles = {
    enabled        = true,
    durationMs     = 3000,
    showStart      = true,
}

Config.SubtitleLines = {
    start = {
        "You start panhandling. Maybe someone will notice you...",
        "Time to make some change.",
        "Hold up the sign and hope for the best.",
        "You take your spot on the sidewalk. Time to hustle.",
        "Another day, another street corner.",
        "You plant yourself on the curb and wait.",
        "Sign up. Dignity down. Let's go.",
        "Eyes on the road, hand out. Classic.",
    },
    give = {
        "~g~A generous soul slipped you some cash.",
        "~g~Bless 'em. They actually noticed.",
        "~g~Cash in hand. Tonight's not so bad.",
        "~g~Score! A few bucks toward dinner.",
        "~g~Someone actually stopped. You'll take it.",
        "~g~A quiet hand reaches out the window.",
        "~g~Small bills, big heart.",
        "~g~Not much, but it's honest money.",
        "~g~They saw you. That alone means something.",
    },
    give_generous = {
        "~g~Holy hell, look at this stack!",
        "~g~Somebody's feeling REAL generous tonight.",
        "~g~A nice big bill. Don't spend it all in one place.",
        "~g~That's more than you expected. Way more.",
        "~g~You nearly drop the sign in shock.",
        "~g~Jackpot. You could eat for a week.",
        "~g~Must be their lucky day — and yours.",
        "~g~That's... actually a lot. Thank you, stranger.",
    },
    yell = {
        "~r~\"Get a job, you bum!\"",
        "~r~\"Get away from my car!\"",
        "~r~\"Beat it before I call the cops!\"",
        "~r~\"Disgusting. Leave me alone!\"",
        "~r~\"I work for a living, so should you!\"",
        "~r~\"Keep moving, loser!\"",
        "~r~\"Nobody wants you here!\"",
        "~r~\"Don't touch my car!\"",
        "~r~\"Go beg somewhere else!\"",
        "~r~\"I'll call the cops, I swear!\"",
    },
    ignore = {
        "They didn't even look at you.",
        "Driver kept staring straight ahead.",
        "Maybe they didn't see you.",
        "Pretended you weren't there.",
        "Eyes forward. You don't exist to them.",
        "Not even a glance.",
        "Invisible. As usual.",
        "They turned up the radio instead.",
        "Sunglasses on. Problem solved.",
        "That one hurt a little.",
        "Window rolled up tight.",
        "Stared at the light until it changed.",
    },
    drive_off = {
        "~r~They pulled away before you could get there.",
        "~r~Off they went. The light changed.",
        "~r~Gone. Opportunity missed.",
        "~r~They didn't have time to wait.",
        "~r~You were too slow. They drove off.",
        "~r~So close. The moment passed.",
        "~r~Didn't even look back.",
        "~r~They peeled off in disgust.",
    },
    limo_approach = {
        "A very nice car is making its way over here...",
        "That's a limo. An actual limo.",
        "Somebody rich just noticed you.",
        "A luxury vehicle is slowing down nearby.",
    },
    limo_nice = {
        "~g~The window rolls down. They wave you over.",
        "~g~Someone important wants to talk to you.",
        "~g~The tinted window drops. A hand gestures your way.",
        "~g~A well-dressed arm extends from the window.",
    },
    limo_collect = {
        "~g~They press a thick envelope into your hands.",
        "~g~More money than you've seen all week. Just like that.",
        "~g~\"Keep it.\" The window rolls back up.",
        "~g~A generous soul. You won't forget this one.",
        "~g~Enough to last you a while. Unbelievable.",
    },
    limo_mean = {
        "~r~The window cracks open just enough to sneer at you.",
        "~r~\"Pathetic.\" The limo drives off without a second glance.",
        "~r~A dismissive wave. They don't even look at you.",
        "~r~Rich enough to help. Chose not to.",
    },
    ped_yell = {
        "~r~\"Bug off!\"",
        "~r~\"I don't have anything!\"",
        "~r~\"Move along!\"",
        "~r~\"Stop harassing people!\"",
        "~r~\"Get out of my face!\"",
        "~r~\"I'm calling someone if you don't leave!\"",
        "~r~\"You're blocking the sidewalk!\"",
    },
    ped_give = {
        "~g~The passerby slips you a few bucks.",
        "~g~\"Here you go, friend.\"",
        "~g~A kind stranger helped you out.",
        "~g~They didn't have much, but they shared anyway.",
        "~g~\"Take care of yourself, okay?\"",
        "~g~Quietly dropped some cash in your hand.",
        "~g~A nod and a few bills. No words needed.",
        "~g~\"I've been there. Keep going.\"",
    },
    toss = {
        "~g~A driver tossed some change as they passed!",
        "~g~Coins scattered from the window — you scooped them up.",
        "~g~Someone threw a crumpled bill from a moving car.",
        "~g~Lucky catch. Something flew out a window.",
        "~g~A quick honk and loose change raining down.",
        "~g~They didn't stop, but they didn't ignore you either.",
    },
    mug_approach = {
        "Someone's walking over...",
        "A stranger catches your eye and heads your way.",
        "Looks like someone noticed you.",
        "A passerby seems to be coming towards you.",
    },
    mug_reveal = {
        "~r~It was a setup — they grab your cash and bolt!",
        "~r~You've been robbed! They snatched what you earned!",
        "~r~A decoy. They take everything and run.",
        "~r~Sucker play. Robbed clean.",
        "~r~The friendly face was a lie. Your money's gone.",
    },
}

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
    enabled    = true,
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
Config = {
    Core = 'qb-core',
    Target = 'qb-target',
    Menu = 'qb-menu',
    Input = 'qb-input',
    BeggingBossModel = "a_m_o_acult_02",
    BeggingBossLoc = vector4(-57.14, -1229.02, 27.8, 42.63),
    BeggingBoxModel = 'v_ind_cs_box01',
    BoxPrice = 100,
    GuitarPrice = 150,
    RewardMin = 30,
    RewardMax = 50,
}
