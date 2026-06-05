-- ============================================================================
-- client/job.lua
-- Job-duty management, clothing, and the global isOnHoboJob() check.
-- Loaded FIRST so all other client scripts can call isOnHoboJob().
-- ============================================================================

local onDuty = false   -- local mirror updated via events / duty toggle

-- ============================================================================
-- PUBLIC: used by every other client script as the job gate
-- ============================================================================

function isOnHoboJob()
    if not Config.RequireJob then return true end
    return onDuty
end

-- ============================================================================
-- Internal: sync duty state from framework
-- ============================================================================

local function applyDutyState(newState)
    if newState == onDuty then return end   -- no change, nothing to do
    onDuty = newState
    SendNUIMessage({ action = 'setDuty', onDuty = newState })
    if newState then
        TriggerEvent('um_hobos:onDuty')
    else
        TriggerEvent('um_hobos:offDuty')
    end
end

local function fetchDutyFromFramework()
    if not Config.RequireJob then
        applyDutyState(true)
        return
    end
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    if ok and data and data.job then
        applyDutyState(data.job.name == Config.JobName)
    else
        applyDutyState(false)
    end
end

-- ============================================================================
-- Clothing
-- ============================================================================

local function applyHoboOutfit(outfitIndex)
    local outfit = Config.HoboOutfits[outfitIndex or 1]
    if not outfit then return end
    local ped = PlayerPedId()
    for _, comp in ipairs(outfit.components) do
        SetPedComponentVariation(ped, comp.comp, comp.drawable, comp.texture, 2)
    end
end

local function restoreDefaultOutfit()
    -- Requests the default character outfit from qbx_core
    local ok, player = pcall(function() return exports.qbx_core:GetPlayerData() end)
    if not ok or not player then return end
    -- Trigger the standard appearance refresh if available
    if GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:setPlayerAppearance')
    elseif GetResourceState('fivem-appearance') == 'started' then
        TriggerEvent('fivem-appearance:setPlayerAppearance')
    end
end

-- ============================================================================
-- Duty toggle
-- ============================================================================

local function setDuty(newState)
    if newState == onDuty then return end
    onDuty = newState

    -- Tell the framework
    TriggerServerEvent('um_hobos:setDuty', newState)

    if newState then
        lib.notify({ type = 'success', description = Lang.duty_on,  duration = 5000 })
        applyHoboOutfit(1)
        TriggerEvent('um_hobos:onDuty')
    else
        lib.notify({ type = 'inform', description = Lang.duty_off, duration = 5000 })
        restoreDefaultOutfit()
        TriggerEvent('um_hobos:offDuty')
    end

    -- Tell HUD
    SendNUIMessage({ action = 'setDuty', onDuty = newState })
end

-- ============================================================================
-- Duty-location interaction zones  (ox_lib spheres with [E] prompt)
-- ============================================================================

CreateThread(function()
    Wait(2000)   -- let ox_lib finish initialising

    for _, loc in ipairs(Config.HoboCamps) do
        -- Blip — settings come from loc.blip in config, with sensible defaults
        if Config.ShowDutyBlips then
            local b    = loc.blip or {}
            local blip = AddBlipForCoord(loc.coords.x, loc.coords.y, loc.coords.z)
            SetBlipSprite(blip,      b.sprite     or 88)
            SetBlipColour(blip,      b.color      or 2)
            SetBlipScale(blip,       b.scale      or 0.8)
            SetBlipAsShortRange(blip, b.shortRange ~= false)  -- defaults to true if not set
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(loc.label or Lang.duty_location)
            EndTextCommandSetBlipName(blip)
        end

        -- Interaction zone
        local zone = lib.zones.sphere({
            coords  = vec3(loc.coords.x, loc.coords.y, loc.coords.z),
            radius  = loc.radius,
            debug   = false,

            onEnter = function()
                if onDuty then
                    lib.showTextUI('[E] Clock Off')
                else
                    lib.showTextUI('[E] Start Hobo Life — ' .. loc.label)
                end
            end,
            onExit  = function() lib.hideTextUI() end,
            inside  = function()
                if not IsControlJustPressed(0, 38) then return end
                lib.hideTextUI()
                setDuty(not onDuty)
            end,
        })
    end
end)

-- ============================================================================
-- Framework events — keep onDuty in sync when job changes elsewhere
-- ============================================================================

AddEventHandler('QBCore:Client:OnJobUpdate', function(jobData)
    if not Config.RequireJob then return end
    applyDutyState(jobData.name == Config.JobName)
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(1500)
    fetchDutyFromFramework()
end)

-- Also sync on spawn
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    fetchDutyFromFramework()
end)

-- ============================================================================
-- Net events from server
-- ============================================================================

RegisterNetEvent('um_hobos:client:setDuty', function(state)
    applyDutyState(state)
end)
