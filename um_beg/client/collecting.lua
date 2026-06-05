-- ============================================================================
-- client/collecting.lua
-- Can / bottle collecting — dynamically spawns props near dumpsters and bins
-- found in the world. No hardcoded coordinates needed.
-- Walk within pickup radius to auto-pocket. Sell at the recycling center.
-- ============================================================================

local spawns        = {}   -- array of { prop = entity, item = string, respawnAt = ms, anchorCoords = vec3 }
local recycleProp   = nil
local recycleBlip   = nil
local scanning      = false

-- ============================================================================
-- Prop model helpers
-- ============================================================================

local propModel = 'prop_beer_can_01'   -- confirmed in ObjectList.ini

local function weightedItem()
    local pool  = Config.Collecting.items
    local total = 0
    for _, e in ipairs(pool) do total = total + e.weight end
    local roll = math.random(total)
    local cum  = 0
    for _, e in ipairs(pool) do
        cum = cum + e.weight
        if roll <= cum then return e.item, e.label end
    end
    return pool[1].item, pool[1].label
end

local function spawnCanAt(coords)
    local hash = GetHashKey(propModel)
    RequestModel(hash)
    local deadline = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
    if not HasModelLoaded(hash) then return nil end

    local prop = CreateObject(hash, coords.x, coords.y, coords.z + 0.5, false, false, false)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    SetEntityAsMissionEntity(prop, true, true)
    SetModelAsNoLongerNeeded(hash)
    return prop
end

local function deleteSpawnProp(idx)
    local s = spawns[idx]
    if s and s.prop and DoesEntityExist(s.prop) then
        SetEntityAsMissionEntity(s.prop, true, true)
        DeleteObject(s.prop)
    end
    if s then s.prop = nil end
end

-- ============================================================================
-- Dynamic anchor detection
-- Finds dumpsters/bins from Config.ScavengeProps in the world and returns
-- random offset positions near each one.
-- ============================================================================

local function buildAnchorHashes()
    local t = {}
    for _, name in ipairs(Config.ScavengeProps) do
        t[GetHashKey(name)] = true
    end
    return t
end

local function scanForAnchors()
    if scanning then return end
    scanning = true

    local anchorHashes = buildAnchorHashes()
    local ped          = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local cfg          = Config.Collecting
    local positions    = {}

    for _, obj in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(obj) and anchorHashes[GetEntityModel(obj)] then
            local oc   = GetEntityCoords(obj)
            local dist = #(oc - playerCoords)
            if dist <= cfg.scanRadius and #positions < cfg.maxSpawns then
                -- Random scatter point near this anchor
                local angle  = math.random() * 2 * math.pi
                local offset = cfg.spawnOffsetMin + math.random() * (cfg.spawnOffsetMax - cfg.spawnOffsetMin)
                local sx     = oc.x + math.cos(angle) * offset
                local sy     = oc.y + math.sin(angle) * offset
                local found, sz = GetGroundZFor_3dCoord(sx, sy, oc.z + 3.0, false)
                local pz    = found and sz or oc.z
                positions[#positions + 1] = { coords = vec3(sx, sy, pz), anchor = oc }
            end
        end
        Wait(0)   -- yield each iteration so we don't freeze the game
    end

    -- Build spawns table from positions
    local now = GetGameTimer()
    for _, pos in ipairs(positions) do
        local item, _ = weightedItem()
        local prop    = spawnCanAt(pos.coords)
        if prop then
            spawns[#spawns + 1] = {
                prop         = prop,
                item         = item,
                respawnAt    = nil,
                anchorCoords = pos.anchor,
            }
        end
    end

    scanning = false
end

-- ============================================================================
-- Recycling center target — open to all players, not job-gated
-- ============================================================================

local function buildRecycleTarget()
    -- Use the dedicated RecyclingCenter config; fall back to legacy Collecting coords
    local rc = Config.RecyclingCenter or Config.Collecting.recycleCenter
    if recycleBlip and DoesBlipExist(recycleBlip) then RemoveBlip(recycleBlip) end

    local hash = GetHashKey('prop_cs_bin_01')
    RequestModel(hash)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end

    if HasModelLoaded(hash) then
        recycleProp = CreateObject(hash, rc.coords.x, rc.coords.y, rc.coords.z, false, false, false)
        PlaceObjectOnGroundProperly(recycleProp)
        FreezeEntityPosition(recycleProp, true)
        SetEntityAsMissionEntity(recycleProp, true, true)
        SetModelAsNoLongerNeeded(hash)

        -- No canInteract restriction — available to everyone
        exports.ox_target:addLocalEntity(recycleProp, {
            {
                name     = 'um_hobos_recycle',
                label    = 'Sell Recyclables',
                icon     = 'fas fa-recycle',
                distance = rc.radius,
                onSelect = function()
                    TriggerServerEvent('um_hobos:sellCollectibles')
                end,
            }
        })
    end

    recycleBlip = AddBlipForCoord(rc.coords.x, rc.coords.y, rc.coords.z)
    SetBlipSprite(recycleBlip, 78)
    SetBlipColour(recycleBlip, 2)
    SetBlipScale(recycleBlip, 0.8)
    SetBlipAsShortRange(recycleBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(rc.blipLabel or 'Recycling Center')
    EndTextCommandSetBlipName(recycleBlip)
end

-- Recycling center is always visible — spawned on resource start regardless of duty
CreateThread(function()
    Wait(3000)   -- give ox_target time to start
    buildRecycleTarget()
end)

-- ============================================================================
-- Init / cleanup  (duty-dependent collectibles only)
-- ============================================================================

local function initCollectibles()
    Wait(500)
    CreateThread(function() scanForAnchors() end)
end

local function cleanupCollectibles()
    for i = 1, #spawns do deleteSpawnProp(i) end
    spawns = {}
    -- NOTE: recycleBlip and recycleProp are NOT destroyed on off-duty
    -- because the recycling center is open to all players.
end

-- ============================================================================
-- Main proximity + respawn thread
-- ============================================================================

CreateThread(function()
    while true do
        if isOnHoboJob() and #spawns > 0 then
            local ped    = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local now    = GetGameTimer()
            local radius = Config.Collecting.pickupRadius

            for i, s in ipairs(spawns) do
                -- Respawn check
                if s.respawnAt and now > s.respawnAt and not s.prop then
                    local prop = spawnCanAt(s.anchorCoords and vec3(
                        s.anchorCoords.x + (math.random() - 0.5) * 4,
                        s.anchorCoords.y + (math.random() - 0.5) * 4,
                        s.anchorCoords.z
                    ) or coords)
                    if prop then
                        local item, _ = weightedItem()
                        s.prop      = prop
                        s.item      = item
                        s.respawnAt = nil
                    end
                end

                -- Pickup check
                if s.prop and DoesEntityExist(s.prop) then
                    if #(GetEntityCoords(s.prop) - coords) <= radius then
                        local item  = s.item
                        deleteSpawnProp(i)
                        s.respawnAt = now + Config.Collecting.respawnMs

                        TriggerServerEvent('um_hobos:collectItem', item)
                        GainXP(Config.Collecting.xpPerItem, 'collect')
                        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)

                        local label = item
                        for _, e in ipairs(Config.Collecting.items) do
                            if e.item == item then label = e.label; break end
                        end
                        lib.notify({ type = 'inform', description = ('Picked up a %s.'):format(label), duration = 2000 })
                    end
                end
            end

            Wait(400)
        else
            Wait(2000)
        end
    end
end)

-- ============================================================================
-- Server callback: sell result
-- ============================================================================

RegisterNetEvent('um_hobos:client:sellResult')
AddEventHandler('um_hobos:client:sellResult', function(earned, count)
    if earned and earned > 0 then
        lib.notify({
            type        = 'success',
            description = ('Recycled %d item(s) for $%d.'):format(count, earned),
            duration    = 4000,
        })
    else
        lib.notify({ type = 'error', description = "You don't have anything to recycle.", duration = 3000 })
    end
end)

AddEventHandler('um_hobos:onDuty',  initCollectibles)
AddEventHandler('um_hobos:offDuty', cleanupCollectibles)

-- Also register the recycle sell result without the old success wording mismatch
RegisterNetEvent('um_hobos:client:recycleResult')
AddEventHandler('um_hobos:client:recycleResult', function(earned, count)
    if earned and earned > 0 then
        lib.notify({
            type        = 'success',
            description = ('Recycled %d item(s) for $%d.'):format(count, earned),
            duration    = 4000,
        })
    else
        lib.notify({ type = 'error', description = "You don't have anything to recycle.", duration = 3000 })
    end
end)
