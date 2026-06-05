-- ============================================================================
-- client/onboarding.lua
-- One-time intro mission chain:
--   1. Pete (homeless NPC at the camp) — triggered on first duty start
--   2. Waypoint to Sister Agnes at the church
--   3. Agnes welcomes the player, fires server event, gives starter kit
-- ============================================================================

local petePed         = nil
local onboardingDone  = false   -- set true once server confirms completion
local chainStep       = 0       -- 0 = not started, 1 = pete done, 2 = at church
local churchZone      = nil     -- lib.zones sphere watching for church arrival

-- ============================================================================
-- Helpers
-- ============================================================================

local function spawnPete()
    if petePed and DoesEntityExist(petePed) then return end
    local cfg  = Config.Onboarding.pete
    local hash = GetHashKey(cfg.pedModel)
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(15) end
    if not HasModelLoaded(hash) then return end

    petePed = CreatePed(4, hash, cfg.location.x, cfg.location.y, cfg.location.z, cfg.heading, false, false)
    SetEntityAsMissionEntity(petePed, true, true)
    SetBlockingOfNonTemporaryEvents(petePed, true)
    SetPedCanRagdoll(petePed, false)
    FreezeEntityPosition(petePed, true)

    local anim = cfg.animation
    if type(anim) == 'table' then
        RequestAnimDict(anim.dict)
        local ad = GetGameTimer() + 3000
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < ad do Wait(10) end
        TaskPlayAnim(petePed, anim.dict, anim.clip, 8.0, 8.0, -1, 1, 0, false, false, false)
    else
        TaskStartScenarioInPlace(petePed, anim or 'WORLD_HUMAN_DRINKING', 0, true)
    end
    SetModelAsNoLongerNeeded(hash)

    exports.ox_target:addLocalEntity(petePed, {
        {
            name     = 'um_hobos_pete',
            label    = onboardingDone and 'Talk to Pete' or 'Talk to Pete',
            icon     = 'fas fa-person',
            distance = 2.5,
            onSelect = function()
                if onboardingDone then
                    -- Post-onboarding casual dialog
                    lib.notify({ type = 'inform', description = '"Stay warm out there." — Pete', duration = 4000 })
                    return
                end
                if chainStep == 0 then
                    startPeteDialog()
                elseif chainStep == 1 then
                    lib.notify({ type = 'inform', description = '"Go find Sister Agnes at the church. She\'ll sort you out." — Pete', duration = 5000 })
                end
            end,
        }
    })
end

-- ============================================================================
-- Pete's dialog — step 1 of the chain
-- ============================================================================

local function startPeteDialog()
    -- Freeze player briefly, face Pete
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    if petePed and DoesEntityExist(petePed) then
        TaskTurnPedToFaceEntity(ped, petePed, 1000)
    end
    Wait(800)
    FreezeEntityPosition(ped, false)

    lib.alertDialog({
        header   = 'Pete',
        content  = '*A weathered man looks up from the ground.*\n\n"Hey. New face. You look lost."\n\n"Streets aren\'t easy — trust me, I know. But there\'s ways to get by. Begging, scavenging, odd jobs... you learn the rhythm."\n\n"There\'s a woman at the church on Elgin. Sister Agnes. Good people. She helped me when I first ended up out here. Go find her — she\'ll set you straight."',
        centered = true,
        cancel   = false,
        labels   = { confirm = 'Thanks, Pete' },
    }, function()
        chainStep = 1
        -- Waypoint to church
        local churchCoords = Config.ChurchSister.location
        SetNewWaypoint(churchCoords.x, churchCoords.y)
        lib.notify({
            type        = 'inform',
            description = 'Head to Sister Agnes at the church on Elgin Ave.',
            duration    = 6000,
        })
        startChurchWatch()
    end)
end

-- ============================================================================
-- Watch for player arriving at the church — step 2
-- ============================================================================

function startChurchWatch()
    if churchZone then return end
    local churchCoords = Config.ChurchSister.location

    churchZone = lib.zones.sphere({
        coords  = vec3(churchCoords.x, churchCoords.y, churchCoords.z),
        radius  = 8.0,
        debug   = false,
        onEnter = function()
            if chainStep ~= 1 then return end
            chainStep = 2
            Wait(500)
            startAgnesDialog()
        end,
    })
end

-- ============================================================================
-- Sister Agnes onboarding dialog — step 3
-- ============================================================================

function startAgnesDialog()
    -- Remove waypoint
    RemoveWaypoint()

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    Wait(600)
    FreezeEntityPosition(ped, false)

    lib.alertDialog({
        header   = 'Sister Agnes',
        content  = '*She turns and smiles warmly.*\n\n"Ah — Pete sent you. Good. Come in out of the cold."\n\n"This isn\'t much, but we do what we can. There are things you can do to get back on your feet — odd jobs, collecting, making the most of what the city throws away."\n\n"We post work on the board at the camp. Come find me here if you need a meal or something to keep you busy. I\'ll always have something."\n\n*She presses a small bundle into your hands.*\n\n"Start with this. And — get yourself a sign. People respond to honesty."',
        centered = true,
        cancel   = false,
        labels   = { confirm = 'Thank you, Sister' },
    }, function()
        -- Tell server — marks DB, gives starter kit
        TriggerServerEvent('um_hobos:onboardingComplete')

        if churchZone then
            churchZone:remove()
            churchZone = nil
        end
    end)
end

-- ============================================================================
-- Server response — mark complete locally
-- ============================================================================

RegisterNetEvent('um_hobos:client:onboardingComplete')
AddEventHandler('um_hobos:client:onboardingComplete', function()
    onboardingDone = true
    chainStep      = 0
    lib.notify({
        type        = 'success',
        description = 'Sister Agnes gave you a starter kit. Type /hoboduty near a camp to get started.',
        duration    = 8000,
    })
end)

-- ============================================================================
-- Hook into progression load — know whether onboarding is done before Pete spawns
-- ============================================================================

RegisterNetEvent('um_hobos:client:loadProgression')
AddEventHandler('um_hobos:client:loadProgression', function(data)
    if data.onboarding_done then
        onboardingDone = true
    end
end)

-- ============================================================================
-- Trigger on first duty start — spawn Pete and begin chain if needed
-- ============================================================================

AddEventHandler('um_hobos:onDuty', function()
    CreateThread(function()
        Wait(2000)
        spawnPete()

        -- If not done yet, prompt them toward Pete
        if not onboardingDone and chainStep == 0 then
            Wait(2000)
            lib.notify({
                type        = 'inform',
                description = 'Someone near the camp wants to talk to you.',
                duration    = 6000,
            })
        end
    end)
end)

-- Pete is cleaned up on off-duty but re-spawns next on-duty
AddEventHandler('um_hobos:offDuty', function()
    if churchZone then churchZone:remove(); churchZone = nil end
    -- Pete stays persistent as long as the resource runs; just remove target
    if petePed and DoesEntityExist(petePed) then
        exports.ox_target:removeLocalEntity(petePed)
        SetEntityAsMissionEntity(petePed, true, true)
        DeleteEntity(petePed)
        petePed = nil
    end
end)
