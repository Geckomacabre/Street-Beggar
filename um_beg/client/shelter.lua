-- ============================================================================
-- client/shelter.lua
-- Personal shelter — placement, sleep, stash access.
-- One shelter per player; data persisted in DB.
-- ============================================================================

local activeShelter  = nil   -- { prop, coords, pieceId } or nil
local shelterZone    = nil
local placingShelter = false

-- ============================================================================
-- Asset loader (shared with begging.lua pattern)
-- ============================================================================

local function loadModel(model, timeoutMs)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    RequestModel(hash)
    local until_ = GetGameTimer() + (timeoutMs or 3000)
    while not HasModelLoaded(hash) and GetGameTimer() < until_ do Wait(15) end
    return HasModelLoaded(hash) and hash or nil
end

-- ============================================================================
-- Shelter zone — [E] Sleep / Stash / Remove
-- ============================================================================

local function createShelterZone()
    if not activeShelter or not DoesEntityExist(activeShelter.prop) then return end
    if shelterZone then shelterZone:remove(); shelterZone = nil end

    shelterZone = lib.zones.sphere({
        coords  = GetEntityCoords(activeShelter.prop),
        radius  = 3.5,
        debug   = false,
        onEnter = function()
            if not isOnHoboJob() then return end
            lib.showTextUI(
                '[E] Sleep  |  [G] Stash  |  [H] Remove Shelter'
            )
        end,
        onExit  = function() lib.hideTextUI() end,
        inside  = function()
            if not isOnHoboJob() then return end

            -- [E] Sleep
            if IsControlJustPressed(0, 38) then
                lib.hideTextUI()
                local done = lib.progressBar({
                    duration     = Config.ShelterSleepMs,
                    label        = Lang.shelter_sleep,
                    useWhileDead = false,
                    canCancel    = true,
                    disable      = { move = true, car = true, combat = true },
                    anim         = { dict = 'switch@trevor@sitting_couch', clip = 'trevor_base_idle_var_1', flag = 49 },
                })
                if done then
                    lib.notify({ type = 'success', description = Lang.shelter_woke, duration = 4000 })
                    GainXP(Config.XPRewards.shelter_sleep, 'shelter_sleep')
                    GainSkillXP('shelter_sleep')
                    if Config.NeedsEnabled then
                        TriggerEvent('um_hobos:shelterSleep')
                    end
                end

            -- [G] Stash
            elseif IsControlJustPressed(0, 47) then
                lib.hideTextUI()
                TriggerServerEvent('um_hobos:openShelterStash')

            -- [H] Remove
            elseif IsControlJustPressed(0, 74) then
                lib.hideTextUI()
                local confirm = lib.alertDialog({
                    header  = 'Remove Shelter',
                    content = 'Pack up your shelter?',
                    centered = true, cancel = true,
                    labels  = { confirm = 'Remove', cancel = 'Cancel' },
                })
                if confirm == 'confirm' then
                    removeShelter()
                end
            end
        end,
    })
end

-- ============================================================================
-- Remove shelter
-- ============================================================================

function removeShelter()
    if shelterZone then shelterZone:remove(); shelterZone = nil end
    if activeShelter and DoesEntityExist(activeShelter.prop) then
        SetEntityAsMissionEntity(activeShelter.prop, true, true)
        DeleteObject(activeShelter.prop)
    end
    activeShelter = nil
    TriggerServerEvent('um_hobos:removeShelter')
    lib.notify({ type = 'inform', description = Lang.shelter_removed, duration = 3000 })
end

-- ============================================================================
-- 3-D placement preview (same pattern as begging box)
-- ============================================================================

local function startShelterPlacement(piece)
    if placingShelter then return end
    if activeShelter then
        lib.notify({ type = 'error', description = Lang.shelter_already, duration = 4000 })
        return
    end

    placingShelter = true
    local hash = loadModel(piece.model, 3000)
    if not hash then placingShelter = false; return end

    local ghost = CreateObject(hash, 0, 0, 0, false, false, false)
    SetEntityAlpha(ghost, 160, false)
    SetEntityCollision(ghost, false, false)
    SetEntityAsMissionEntity(ghost, true, true)

    lib.showTextUI('[E] Place Shelter   [BACKSPACE] Cancel')

    while placingShelter do
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local fwd    = GetEntityForwardVector(ped)
        local px, py = coords.x + fwd.x * 2.0, coords.y + fwd.y * 2.0
        local _, gz  = GetGroundZFor_3dCoord(px, py, coords.z + 3.0, false)
        local pz     = gz or coords.z

        SetEntityCoords(ghost, px, py, pz, false, false, false, false)
        PlaceObjectOnGroundProperly(ghost)

        local c = Config.ShelterMarker
        DrawMarker(25, px, py, pz + 0.02, 0, 0, 0, 0, 0, 0,
            1.5, 1.5, 0.12, c.r, c.g, c.b, c.a, false, false, 2, false, nil, nil, false)

        if IsControlJustPressed(0, 38) then          -- E — confirm
            lib.hideTextUI()
            SetEntityAsMissionEntity(ghost, true, true); DeleteObject(ghost)
            SetModelAsNoLongerNeeded(hash)
            local cx, cy, cz = px, py, pz
            placingShelter = false

            local done = lib.progressBar({
                duration  = 4000, label = 'Setting up shelter...',
                canCancel = true,
                disable   = { move = true, car = true, combat = true },
                anim      = { dict = 'random@domestic', clip = 'pickup_low', flag = 49 },
            })
            if done then
                local bm = loadModel(piece.model, 3000)
                if bm then
                    local prop = CreateObject(bm, cx, cy, cz, true, true, false)
                    PlaceObjectOnGroundProperly(prop)
                    Wait(200)
                    FreezeEntityPosition(prop, true)
                    SetEntityAsMissionEntity(prop, true, true)
                    SetModelAsNoLongerNeeded(bm)
                    activeShelter = { prop = prop, coords = GetEntityCoords(prop), pieceId = piece.id }
                    createShelterZone()
                    TriggerServerEvent('um_hobos:saveShelter', {
                        pieceId = piece.id,
                        coords  = { x = cx, y = cy, z = cz },
                    })
                    lib.notify({ type = 'success', description = Lang.shelter_placed, duration = 4000 })
                end
            end
            return
        elseif IsControlJustPressed(0, 177) then     -- Backspace — cancel
            lib.hideTextUI()
            SetEntityAsMissionEntity(ghost, true, true); DeleteObject(ghost)
            SetModelAsNoLongerNeeded(hash)
            placingShelter = false
            return
        end
        Wait(0)
    end
end

-- ============================================================================
-- Build shelter menu — choose which piece to place
-- ============================================================================

function OpenShelterMenu()
    if not isOnHoboJob() then
        lib.notify({ type = 'error', description = Lang.not_on_duty, duration = 3000 })
        return
    end

    local options = {}
    for _, piece in ipairs(ShelterPieces) do
        local reqs = {}
        for _, r in ipairs(piece.requires) do
            table.insert(reqs, r.count .. 'x ' .. r.item)
        end
        local reqStr = #reqs > 0 and table.concat(reqs, ', ') or 'No materials needed'
        table.insert(options, {
            title       = piece.label,
            description = piece.desc .. '\nRequires: ' .. reqStr,
            onSelect    = function()
                startShelterPlacement(piece)
            end,
        })
    end

    lib.registerContext({
        id      = 'hobo_shelter_menu',
        title   = 'Build Shelter',
        options = options,
    })
    lib.showContext('hobo_shelter_menu')
end

-- ============================================================================
-- Needs: sleep restores energy and morale
-- ============================================================================

AddEventHandler('um_hobos:shelterSleep', function()
    -- Handled in needs.lua via direct need modification
    local energyRestore = Config.ShelterEnergyRestore
        + (GetSkill('survival') >= 6 and 40 or 0)   -- Survival 6 = full restore
    TriggerServerEvent('um_hobos:shelterSleepNeeds', energyRestore, Config.ShelterMoraleRestore)
end)

RegisterNetEvent('um_hobos:client:restoreNeeds', function(energy, morale)
    if not Config.NeedsEnabled then return end
    -- needs.lua has no direct setter exposed; send via global event
    TriggerEvent('um_hobos:restoreNeed', 'energy', energy)
    TriggerEvent('um_hobos:restoreNeed', 'morale', morale)
end)

-- ============================================================================
-- Restore shelter on duty start (server sends saved data)
-- ============================================================================

RegisterNetEvent('um_hobos:client:loadShelter', function(data)
    if not data then return end
    local piece = nil
    for _, p in ipairs(ShelterPieces) do
        if p.id == data.pieceId then piece = p; break end
    end
    if not piece then return end

    local hash = loadModel(piece.model, 3000)
    if not hash then return end
    local prop = CreateObject(hash, data.coords.x, data.coords.y, data.coords.z, true, true, false)
    PlaceObjectOnGroundProperly(prop)
    Wait(200)
    FreezeEntityPosition(prop, true)
    SetEntityAsMissionEntity(prop, true, true)
    SetModelAsNoLongerNeeded(hash)
    activeShelter = { prop = prop, coords = GetEntityCoords(prop), pieceId = data.pieceId }
    createShelterZone()
end)

AddEventHandler('um_hobos:onDuty', function()
    TriggerServerEvent('um_hobos:requestShelter')
end)

AddEventHandler('um_hobos:offDuty', function()
    -- Remove the local prop; server keeps the DB entry
    if shelterZone then shelterZone:remove(); shelterZone = nil end
    if activeShelter and DoesEntityExist(activeShelter.prop) then
        SetEntityAsMissionEntity(activeShelter.prop, true, true)
        DeleteObject(activeShelter.prop)
    end
    activeShelter = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if shelterZone then shelterZone:remove() end
    if activeShelter and DoesEntityExist(activeShelter.prop) then
        DeleteObject(activeShelter.prop)
    end
end)
