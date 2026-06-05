-- ============================================================================
-- client/pickpocket.lua
-- Hobo pickpocket — NUI slot-grid minigame.
-- 5 slots shown, 2-3 filled with lootable items.  Cursor sweeps left↔right;
-- press [SPACE] when it's over a filled slot to succeed.
-- Only available while on hobo job (isOnHoboJob() from job.lua).
-- ============================================================================

local pedCooldowns   = {}   -- [entity handle] = expireMs
local busy           = false
local pickpocketDone = false
local pickpocketResult = nil

-- ============================================================================
-- NUI callback — receives which slot was active when space was pressed
-- ============================================================================

RegisterNUICallback('pickpocketResult', function(data, cb)
    pickpocketResult = data
    pickpocketDone   = true
    cb('ok')
end)

-- ============================================================================
-- Helpers
-- ============================================================================

-- Build a hash set of blocked models once on load for O(1) lookups
local blockedModelHashes = {}
CreateThread(function()
    -- Wait a tick so Config is definitely populated
    Wait(0)
    for _, modelName in ipairs(Config.Pickpocket.blockedModels or {}) do
        blockedModelHashes[GetHashKey(modelName)] = true
    end
end)

-- Returns true if this ped can be pickpocketed
local function isValidTarget(ped)
    -- Block non-networked (client-side-only) entities — these are always script peds
    if not NetworkGetEntityIsNetworked(ped) then return false end
    -- Block model blacklist
    if blockedModelHashes[GetEntityModel(ped)] then return false end
    return true
end

-- Cop-call chance on failure (reduced by charisma)
local function copCallChance()
    local charisma  = GetSkill('charisma')
    local reduction = charisma * 3
    return math.max(
        Config.Pickpocket.copCallChanceMin,
        Config.Pickpocket.copCallChanceBase - reduction
    )
end

-- Slider speed in ms per pass, scaled by charisma
local function getSliderSpeed()
    local charisma = GetSkill('charisma')
    local speeds   = Config.Pickpocket.sliderSpeeds
    local chosen   = speeds[0]
    for threshold, spd in pairs(speeds) do
        if charisma >= threshold then chosen = spd end
    end
    return chosen
end

-- Build slot array: totalSlots entries, 2-3 filled with weighted loot
local function buildSlots()
    local charisma   = GetSkill('charisma')
    local total      = Config.Pickpocket.totalSlots
    local numFilled  = (charisma >= 6) and Config.Pickpocket.filledMax or Config.Pickpocket.filledMin

    -- All empty to start
    local slots = {}
    for i = 1, total do
        slots[i] = { empty = true }
    end

    -- Pick unique positions for loot
    local positions = {}
    local safety    = 0
    while #positions < numFilled and safety < 200 do
        safety = safety + 1
        local pos = math.random(1, total)
        local dup = false
        for _, p in ipairs(positions) do
            if p == pos then dup = true; break end
        end
        if not dup then positions[#positions + 1] = pos end
    end

    -- Weighted random pick from loot pool for each position
    local pool      = Config.Pickpocket.loot
    local poolTotal = 0
    for _, e in ipairs(pool) do poolTotal = poolTotal + e.weight end

    for _, pos in ipairs(positions) do
        local roll = math.random(poolTotal)
        local cum  = 0
        for _, e in ipairs(pool) do
            cum = cum + e.weight
            if roll <= cum then
                slots[pos] = {
                    empty = false,
                    label = e.label,
                    icon  = e.icon,
                    type  = e.type,
                    value = e.value,   -- cash only
                    item  = e.item,    -- item only
                }
                break
            end
        end
    end

    return slots
end

-- Load anim dict with short timeout
local function loadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(15) end
    return HasAnimDictLoaded(dict)
end

-- ============================================================================
-- Core pickpocket action
-- ============================================================================

local function attemptPickpocket(targetPed)
    if busy then return end
    if not isOnHoboJob() then
        lib.notify({ type = 'error', description = Lang.not_on_duty, duration = 3000 })
        return
    end

    -- Block script/static peds
    if not isValidTarget(targetPed) then return end

    -- Per-ped cooldown
    local now = GetGameTimer()
    if pedCooldowns[targetPed] and now < pedCooldowns[targetPed] then
        lib.notify({ type = 'error', description = "They'd notice if you tried again so soon.", duration = 3000 })
        return
    end

    busy = true

    -- Safety: ensure busy is always cleared even if something errors below
    local ped = PlayerPedId()
    local ok, err = pcall(function()

    -- Build grid and show NUI immediately
    local slots = buildSlots()
    local speed = getSliderSpeed()

    pickpocketDone   = false
    pickpocketResult = nil

    SendNUIMessage({
        action = 'startPickpocket',
        slots  = slots,
        speed  = speed,
    })

    -- Give NUI direct keyboard focus so it detects [SPACE] with zero roundtrip delay.
    -- hasCursor = false keeps the game camera usable.
    SetNuiFocus(true, false)

    -- Play approach animation (NUI already visible)
    if loadDict(Config.Pickpocket.animDict) then
        TaskPlayAnim(ped, Config.Pickpocket.animDict, Config.Pickpocket.animClip,
            4.0, -4.0, 1200, 49, 0, false, false, false)
    end

    -- Wait for NUI keydown result — space is handled entirely inside NUI now
    local deadline = GetGameTimer() + 12000
    while not pickpocketDone and GetGameTimer() < deadline do
        Wait(100)
    end

    -- Always release NUI focus first
    SetNuiFocus(false, false)

    -- Timed out
    if not pickpocketDone then
        SendNUIMessage({ action = 'hidePickpocket' })
        ClearPedTasks(ped)
        lib.notify({ type = 'error', description = 'You hesitated too long.', duration = 3000 })
        busy = false
        return
    end

    -- Short pause so the result flash is visible
    Wait(900)
    ClearPedTasks(ped)

    local result = pickpocketResult
    local slot   = result and result.slot

    if slot and not slot.empty then
        -- ---- SUCCESS — ped never looks at the player ----
        pedCooldowns[targetPed] = GetGameTimer() + Config.Pickpocket.pedCooldownMs

        local msg
        if slot.type == 'cash' then
            msg = ('You lifted $%d without them noticing.'):format(slot.value or 0)
        else
            msg = ('You lifted a %s without them noticing.'):format(slot.label or slot.item or 'item')
        end
        lib.notify({ type = 'success', description = msg, duration = 4000 })

        TriggerServerEvent('um_hobos:pickpocketReward', slot.type, slot.value or 0, slot.item or '')

        GainXP(Config.Pickpocket.xpSuccess, 'pickpocket')
        GainSkillXP('pickpocket_success')
        if Config.NeedsEnabled then TriggerEvent('um_hobos:moraleBump', 8) end

        -- Ped either stays put or wanders off naturally — never faces the player
        Citizen.SetTimeout(800, function()
            if not DoesEntityExist(targetPed) then return end
            if math.random(100) <= 50 then
                TaskWanderStandard(targetPed, 10.0, 10)   -- walks away normally
            else
                ClearPedTasks(targetPed)                   -- resumes ambient AI
            end
        end)

    else
        -- ---- FAILURE — ped reacts based on rolled outcome ----
        GainXP(Config.Pickpocket.xpFail, 'pickpocket_fail')

        local roll = math.random(100)

        if roll <= 40 then
            -- Outcome 1: ped panics and flees
            PlayAmbientSpeech1(targetPed, 'GENERIC_CURSE_HIGH', 'SPEECH_PARAMS_FORCE_SHOUTED_CRITICAL')
            TaskReactAndFleePed(targetPed, ped)
            lib.notify({ type = 'error', description = 'They felt it and bolted!', duration = 4000 })

        elseif roll <= 70 then
            -- Outcome 2: ped gets angry and fights back (punches — most have no weapon)
            PlayAmbientSpeech1(targetPed, 'GENERIC_INSULT_HIGH', 'SPEECH_PARAMS_FORCE_SHOUTED_CRITICAL')
            TaskTurnPedToFaceEntity(targetPed, ped, 800)
            Citizen.SetTimeout(900, function()
                if DoesEntityExist(targetPed) then
                    TaskCombatPed(targetPed, ped, 0, 16)
                end
            end)
            -- Release after 10 s so they don't chase forever
            Citizen.SetTimeout(10000, function()
                if DoesEntityExist(targetPed) then
                    ClearPedTasks(targetPed)
                    TaskWanderStandard(targetPed, 10.0, 10)
                end
            end)
            lib.notify({ type = 'error', description = 'They caught you — they\'re swinging!', duration = 4000 })

        else
            -- Outcome 3: ped shouts, looks around nervously, then moves on
            PlayAmbientSpeech1(targetPed, 'GENERIC_CURSE_MED', 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR')
            TaskTurnPedToFaceEntity(targetPed, ped, 1000)
            Citizen.SetTimeout(2000, function()
                if DoesEntityExist(targetPed) then
                    TaskWanderStandard(targetPed, 10.0, 10)
                end
            end)
            lib.notify({ type = 'error', description = 'They felt something — your hand slipped!', duration = 4000 })
        end

        -- Independent roll: chance the ped calls cops regardless of above reaction
        if math.random(100) <= copCallChance() then
            Citizen.SetTimeout(3000, function()
                if not isOnHoboJob() then return end
                SetPlayerWantedLevel(PlayerId(), Config.Pickpocket.wantedLevel, false)
                SetPlayerWantedLevelNow(PlayerId(), false)
                lib.notify({ type = 'error', description = 'They called the cops!', duration = 5000 })
            end)
        end
    end

    end)  -- end pcall

    if not ok then
        print('[um_hobos] pickpocket error: ' .. tostring(err))
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'hidePickpocket' })
        ClearPedTasks(ped)
    end

    busy = false
end

-- ============================================================================
-- ox_target — "Pickpocket" option on all pedestrians
-- ============================================================================

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do
        Wait(1000)
    end

    -- NOTE: canInteract is intentionally omitted — ox_target calls it from its
    -- own Lua state where um_beg globals (Config, isOnHoboJob) don't exist.
    -- The job check is done inside onSelect/attemptPickpocket instead.
    exports.ox_target:addGlobalPed({
        {
            name     = 'um_hobos_pickpocket',
            label    = 'Pickpocket',
            icon     = 'fas fa-hand-paper',
            distance = 2.0,
            onSelect = function(data)
                local targetPed = data.entity
                if not targetPed or not DoesEntityExist(targetPed) then return end
                if IsPedAPlayer(targetPed) then return end
                if IsEntityDead(targetPed) then return end
                CreateThread(function()
                    attemptPickpocket(targetPed)
                end)
            end,
        }
    })
end)
