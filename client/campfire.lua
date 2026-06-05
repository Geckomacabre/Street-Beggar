-- ============================================================================
-- client/campfire.lua
-- Two campfire types: hobo_stove (tin can + paper, durable/reusable) and
-- beach_fire (junk_wood, longer burn). Both support extinguish and relight.
-- Extinguishing stops particles but leaves the prop in place (dark).
-- Hobo stove tracks durability; at 0 uses the prop is deleted.
-- ============================================================================

-- Per-type fire state (one active fire allowed per type)
local fires = {
    hobo_stove = { prop = nil, ptfx = nil, lit = false, burnExpiry = 0, durability = 0 },
    beach_fire  = { prop = nil, ptfx = nil, lit = false, burnExpiry = 0 },
}
local placing = false

-- ============================================================================
-- Particle helpers
-- ============================================================================

local function startPtfx(cfg, coords)
    RequestNamedPtfxAsset(cfg.ptfxDict)
    local deadline = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded(cfg.ptfxDict) and GetGameTimer() < deadline do Wait(15) end
    UseParticleFxAssetNextCall(cfg.ptfxDict)
    return StartParticleFxLoopedAtCoord(
        cfg.ptfxName,
        coords.x, coords.y, coords.z + 0.15,
        0.0, 0.0, 0.0,
        cfg.ptfxScale or 0.5,
        false, false, false, false)
end

local function stopPtfx(ptfxHandle)
    if ptfxHandle then StopParticleFxLooped(ptfxHandle, false) end
end

-- ============================================================================
-- Warm tick
-- ============================================================================

local function startWarmTick(fireType)
    local cfg = Config.Campfires[fireType]
    CreateThread(function()
        local state = fires[fireType]
        while state.prop and DoesEntityExist(state.prop) and state.lit do
            Wait(cfg.warmTickMs)
            if not state.lit then break end
            if GetGameTimer() >= state.burnExpiry then
                -- Burn-out
                state.lit = false
                stopPtfx(state.ptfx)
                state.ptfx = nil
                lib.notify({ type = 'inform', description = 'The fire burned out.', duration = 4000 })
                -- Hobo stove: decrement durability on burn-out
                if fireType == 'hobo_stove' then
                    state.durability = state.durability - 1
                    if state.durability <= 0 then
                        -- Can is worn out — destroy prop
                        exports.ox_target:removeLocalEntity(state.prop)
                        SetEntityAsMissionEntity(state.prop, true, true)
                        DeleteObject(state.prop)
                        state.prop = nil
                        state.durability = 0
                        lib.notify({ type = 'error', description = 'The stove is worn out and falls apart.', duration = 4000 })
                    end
                end
                return
            end
            if Config.NeedsEnabled then
                TriggerEvent('um_hobos:moraleBump',  cfg.moraleBonus)
                TriggerEvent('um_hobos:energyBump',  cfg.energyBonus)
            end
        end
    end)
end

-- ============================================================================
-- Extinguish fire (stops flame, keeps prop)
-- ============================================================================

local function extinguish(fireType)
    local state = fires[fireType]
    if not state.lit then return end
    state.lit = false
    stopPtfx(state.ptfx)
    state.ptfx = nil
    lib.notify({ type = 'inform', description = 'Fire extinguished.', duration = 3000 })
end

-- ============================================================================
-- Build / update ox_target on the fire prop
-- ============================================================================

local function rebuildTarget(fireType)
    local state = fires[fireType]
    if not state.prop or not DoesEntityExist(state.prop) then return end
    local cfg = Config.Campfires[fireType]

    -- Remove old, re-add with current canInteract state
    exports.ox_target:removeLocalEntity(state.prop)
    exports.ox_target:addLocalEntity(state.prop, {
        {
            name        = 'um_campfire_cook',
            label       = 'Cook / Add Fuel',
            icon        = 'fas fa-fire',
            distance    = 2.5,
            canInteract = function() return fires[fireType].lit end,
            onSelect    = function()
                CreateThread(function()
                    local options = {}
                    for _, recipe in ipairs(Config.CampfireCooking) do
                        local hasItem = false
                        if Config.UseOxInventory then
                            local ok, cnt = pcall(function()
                                return exports.ox_inventory:Search('count', recipe.input)
                            end)
                            hasItem = ok and (cnt or 0) >= 1
                        else
                            hasItem = true
                        end
                        options[#options + 1] = {
                            title       = recipe.label,
                            description = ('%s → %s%s'):format(
                                recipe.input, recipe.output,
                                hasItem and '' or '  ~r~(missing)'),
                            disabled    = not hasItem,
                            onSelect    = function()
                                local done = lib.progressBar({
                                    duration  = recipe.duration,
                                    label     = ('Cooking %s...'):format(recipe.input),
                                    canCancel = true,
                                    disable   = { move = false, car = true, combat = true },
                                })
                                if done then
                                    TriggerServerEvent('um_hobos:campfireCook', recipe.input, recipe.output)
                                end
                            end,
                        }
                    end
                    options[#options + 1] = {
                        title       = 'Add Fuel',
                        description = ('Add %dx %s (+%d min burn time).'):format(
                            cfg.fuelPerLight, cfg.fuelItem, math.floor(cfg.burnMs / 60000)),
                        onSelect    = function()
                            TriggerServerEvent('um_hobos:campfireAddFuel', fireType)
                        end,
                    }
                    lib.registerContext({ id = 'um_cook_menu', title = 'Campfire', options = options })
                    lib.showContext('um_cook_menu')
                end)
            end,
        },
        {
            name        = 'um_campfire_extinguish',
            label       = 'Extinguish Fire',
            icon        = 'fas fa-wind',
            distance    = 2.5,
            canInteract = function() return fires[fireType].lit end,
            onSelect    = function() extinguish(fireType) end,
        },
        {
            name        = 'um_campfire_relight',
            label       = ('Relight (%s + lighter)'):format(cfg.fuelItem),
            icon        = 'fas fa-fire-flame-simple',
            distance    = 2.5,
            canInteract = function() return not fires[fireType].lit end,
            onSelect    = function()
                TriggerServerEvent('um_hobos:campfireRelight', fireType)
            end,
        },
    })
end

-- ============================================================================
-- Light / place fire at coords
-- ============================================================================

local function lightFire(fireType, coords, durabilityIn)
    local cfg   = Config.Campfires[fireType]
    local state = fires[fireType]

    local hash = GetHashKey(cfg.prop)
    RequestModel(hash)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
    if not HasModelLoaded(hash) then
        lib.notify({ type = 'error', description = 'Could not spawn fire prop.', duration = 3000 })
        return
    end

    state.prop = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    PlaceObjectOnGroundProperly(state.prop)
    FreezeEntityPosition(state.prop, true)
    SetEntityAsMissionEntity(state.prop, true, true)
    SetModelAsNoLongerNeeded(hash)

    state.lit        = true
    state.burnExpiry = GetGameTimer() + cfg.burnMs
    state.ptfx       = startPtfx(cfg, GetEntityCoords(state.prop))
    if fireType == 'hobo_stove' then
        state.durability = durabilityIn or cfg.maxDurability
    end

    rebuildTarget(fireType)
    startWarmTick(fireType)

    local msg = fireType == 'hobo_stove'
        and ('Stove lit! Burns for %d min. (%d uses left.)'):format(
                math.floor(cfg.burnMs / 60000), state.durability)
        or  ('Campfire lit! Burns for %d min.'):format(math.floor(cfg.burnMs / 60000))
    lib.notify({ type = 'success', description = msg, duration = 4000 })
end

-- ============================================================================
-- Placement mode
-- ============================================================================

local function startPlacement(fireType)
    if placing then return end
    local state = fires[fireType]
    local cfg   = Config.Campfires[fireType]

    if state.prop and DoesEntityExist(state.prop) then
        lib.notify({ type = 'error', description = 'You already have that fire going.', duration = 3000 })
        return
    end

    placing = true

    -- Ghost preview
    local hash = GetHashKey(cfg.prop)
    RequestModel(hash)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
    if not HasModelLoaded(hash) then placing = false; return end

    local ghost = CreateObject(hash, 0, 0, 0, false, false, false)
    SetEntityAlpha(ghost, 150, false)
    SetEntityCollision(ghost, false, false)
    SetEntityAsMissionEntity(ghost, true, true)

    lib.showTextUI('[E] Place   [BACKSPACE] Cancel')

    while placing do
        local ped   = PlayerPedId()
        local coord = GetEntityCoords(ped)
        local fwd   = GetEntityForwardVector(ped)
        local px    = coord.x + fwd.x * 1.5
        local py    = coord.y + fwd.y * 1.5
        local _, gz = GetGroundZFor_3dCoord(px, py, coord.z + 3.0, false)
        SetEntityCoords(ghost, px, py, gz or coord.z, false, false, false, false)
        PlaceObjectOnGroundProperly(ghost)

        if IsControlJustPressed(0, 38) then      -- E: confirm
            lib.hideTextUI()
            local finalCoords = GetEntityCoords(ghost)
            SetEntityAsMissionEntity(ghost, true, true)
            DeleteObject(ghost)
            SetModelAsNoLongerNeeded(hash)
            placing = false
            TriggerServerEvent('um_hobos:campfireLight', fireType)
            Wait(200)
            lightFire(fireType, finalCoords, cfg.maxDurability)
            return
        elseif IsControlJustPressed(0, 177) then -- Backspace: cancel
            lib.hideTextUI()
            SetEntityAsMissionEntity(ghost, true, true)
            DeleteObject(ghost)
            SetModelAsNoLongerNeeded(hash)
            placing = false
            return
        end
        Wait(0)
    end
end

-- ============================================================================
-- Cleanup helper (used on off-duty and resource stop)
-- ============================================================================

local function cleanupAllFires()
    for ft, state in pairs(fires) do
        stopPtfx(state.ptfx)
        state.ptfx = nil
        state.lit  = false
        if state.prop and DoesEntityExist(state.prop) then
            exports.ox_target:removeLocalEntity(state.prop)
            SetEntityAsMissionEntity(state.prop, true, true)
            DeleteObject(state.prop)
        end
        state.prop = nil
    end
end

-- ============================================================================
-- Item use events — triggered by ox_inventory item use hooks
-- ============================================================================

RegisterNetEvent('um_beg:useHoboStove')
AddEventHandler('um_beg:useHoboStove', function()
    Wait(200)
    startPlacement('hobo_stove')
end)

RegisterNetEvent('um_beg:useCampfireKit')
AddEventHandler('um_beg:useCampfireKit', function()
    Wait(200)
    startPlacement('beach_fire')
end)

-- ============================================================================
-- Server feedback events
-- ============================================================================

RegisterNetEvent('um_hobos:client:campfireFuelAdded')
AddEventHandler('um_hobos:client:campfireFuelAdded', function(fireType)
    local state = fires[fireType or 'beach_fire']
    local cfg   = Config.Campfires[fireType or 'beach_fire']
    if state then
        state.burnExpiry = state.burnExpiry + cfg.burnMs
        lib.notify({ type = 'success', description = ('Fuel added — +%d min.'):format(
            math.floor(cfg.burnMs / 60000)), duration = 3000 })
    end
end)

RegisterNetEvent('um_hobos:client:campfireRelit')
AddEventHandler('um_hobos:client:campfireRelit', function(fireType)
    local state = fires[fireType]
    local cfg   = Config.Campfires[fireType]
    if not state or not state.prop or not DoesEntityExist(state.prop) then return end
    if state.lit then return end

    state.lit        = true
    state.burnExpiry = GetGameTimer() + cfg.burnMs
    if fireType == 'hobo_stove' then
        state.durability = state.durability - 1
        if state.durability <= 0 then
            lib.notify({ type = 'error', description = 'The stove is worn out.', duration = 4000 })
            -- Will clean up on next burn-out in startWarmTick
            state.durability = 1   -- let this last light finish
        end
    end
    state.ptfx = startPtfx(cfg, GetEntityCoords(state.prop))
    rebuildTarget(fireType)
    startWarmTick(fireType)
    lib.notify({ type = 'success', description = 'Fire relit!', duration = 3000 })
end)

RegisterNetEvent('um_hobos:client:cookResult')
AddEventHandler('um_hobos:client:cookResult', function(success, output)
    if success then
        lib.notify({ type = 'success', description = ('Cooked! Got 1x %s.'):format(output), duration = 4000 })
    else
        lib.notify({ type = 'error', description = 'Cooking failed — missing ingredients?', duration = 3000 })
    end
end)

AddEventHandler('um_hobos:offDuty', cleanupAllFires)
