-- ============================================================================
-- client/worldinteractions.lua
-- Ported from um_WorldInteractions. All SDC/QBCore abstractions replaced with
-- ox_target, ox_lib, and qbx_core patterns matching the rest of um_beg.
-- Systems: Porta Potty, Dumpster Hiding, Chairs, Toilets, Vending, Parking Meters
-- ============================================================================

-- ============================================================================
-- Shared helpers
-- ============================================================================

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(10) end
end

local function entityKey(entity)
    local c = GetEntityCoords(entity)
    return ('%d_%d_%d'):format(math.ceil(c.x), math.ceil(c.y), math.ceil(c.z))
end

local function faceEntity(ped, target)
    local p1, p2 = GetEntityCoords(ped), GetEntityCoords(target)
    SetEntityHeading(ped, GetHeadingFromVector_2d(p2.x - p1.x, p2.y - p1.y))
end

local function faceCoords(ped, coords)
    local p1 = GetEntityCoords(ped)
    SetEntityHeading(ped, GetHeadingFromVector_2d(coords.x - p1.x, coords.y - p1.y))
end

-- ============================================================================
-- PORTA POTTY
-- ============================================================================

local portaState = { inside = false, entity = nil, cam = nil, savedCoords = nil, offsetRot = { x=0, y=0, z=0 } }

local function startPortaCam(entity)
    ClearFocus()
    local c = GetEntityCoords(entity)
    portaState.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', vec3(c.x, c.y, c.z + 3.0), 0, 0, 0, Config.PortaPotty.camFOV)
    SetCamActive(portaState.cam, true)
    RenderScriptCams(true, false, 0, true, false)
end

local function endPortaCam()
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    if portaState.cam then DestroyCam(portaState.cam, false) end
    portaState.cam = nil
    portaState.offsetRot = { x=0, y=0, z=0 }
end

local function processPortaCam()
    DisableFirstPersonCamThisFrame()
    DisableControlAction(1, 1, true)
    DisableControlAction(1, 2, true)
    local c = GetEntityCoords(portaState.entity)
    portaState.offsetRot.x = math.max(-90, math.min(90,  portaState.offsetRot.x - GetDisabledControlNormal(1, 2) * 8.0))
    portaState.offsetRot.z = portaState.offsetRot.z - GetDisabledControlNormal(1, 1) * 8.0
    if portaState.offsetRot.z >  360 then portaState.offsetRot.z = portaState.offsetRot.z - 360 end
    if portaState.offsetRot.z < -360 then portaState.offsetRot.z = portaState.offsetRot.z + 360 end
    SetFocusArea(c.x, c.y, c.z + 3.0, 0, 0, 0)
    SetCamRot(portaState.cam, portaState.offsetRot.x, portaState.offsetRot.y, portaState.offsetRot.z, 2)
end

RegisterNetEvent('um_worldint:client:startPorta')
AddEventHandler('um_worldint:client:startPorta', function()
    if not portaState.entity then return end
    local ped  = PlayerPedId()
    local ec   = GetEntityCoords(portaState.entity)

    portaState.savedCoords = GetEntityCoords(ped)
    portaState.inside = true

    DoScreenFadeOut(500) Wait(500)
    SetEntityCoords(ped, ec.x, ec.y, ec.z - 5.0, false, false, false, false) Wait(10)
    FreezeEntityPosition(ped, true)
    startPortaCam(portaState.entity)
    DoScreenFadeIn(500)

    while portaState.inside do
        Wait(1)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('~INPUT_DETONATE~ Exit')
        EndTextCommandDisplayHelp(false, false, false, -1)
        processPortaCam()

        if IsControlJustReleased(0, Config.PortaPotty.exitKey) then
            TriggerServerEvent('um_worldint:server:exitPorta', entityKey(portaState.entity))
            DoScreenFadeOut(500) Wait(500)
            FreezeEntityPosition(ped, false)
            SetEntityCoords(ped, portaState.savedCoords.x, portaState.savedCoords.y, portaState.savedCoords.z, false, false, false, false)
            endPortaCam()
            portaState = { inside = false, entity = nil, cam = nil, savedCoords = nil, offsetRot = { x=0,y=0,z=0 } }
            DoScreenFadeIn(500)
        end
    end
end)

RegisterNetEvent('um_worldint:client:portaInUse')
AddEventHandler('um_worldint:client:portaInUse', function()
    portaState.entity = nil
    lib.notify({ type = 'error', description = 'Someone is already in there.', duration = 3000 })
end)

-- ============================================================================
-- DUMPSTER HIDING
-- ============================================================================

local dumpState = { inside = false, entity = nil, cam = nil, savedCoords = nil, offsetRot = { x=0, y=0, z=0 } }

local function startDumpCam(entity)
    ClearFocus()
    local c = GetEntityCoords(entity)
    dumpState.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', vec3(c.x, c.y, c.z + 2.0), 0, 0, 0, Config.DumpsterHide.camFOV)
    SetCamActive(dumpState.cam, true)
    RenderScriptCams(true, false, 0, true, false)
end

local function endDumpCam()
    ClearFocus()
    RenderScriptCams(false, false, 0, true, false)
    if dumpState.cam then DestroyCam(dumpState.cam, false) end
    dumpState.cam = nil
    dumpState.offsetRot = { x=0, y=0, z=0 }
end

local function processDumpCam()
    DisableFirstPersonCamThisFrame()
    DisableControlAction(1, 1, true)
    DisableControlAction(1, 2, true)
    local c = GetEntityCoords(dumpState.entity)
    dumpState.offsetRot.x = math.max(-90, math.min(90, dumpState.offsetRot.x - GetDisabledControlNormal(1, 2) * 8.0))
    dumpState.offsetRot.z = dumpState.offsetRot.z - GetDisabledControlNormal(1, 1) * 8.0
    if dumpState.offsetRot.z >  360 then dumpState.offsetRot.z = dumpState.offsetRot.z - 360 end
    if dumpState.offsetRot.z < -360 then dumpState.offsetRot.z = dumpState.offsetRot.z + 360 end
    SetFocusArea(c.x, c.y, c.z + 2.0, 0, 0, 0)
    SetCamRot(dumpState.cam, dumpState.offsetRot.x, dumpState.offsetRot.y, dumpState.offsetRot.z, 2)
end

RegisterNetEvent('um_worldint:client:startDumpHide')
AddEventHandler('um_worldint:client:startDumpHide', function()
    if not dumpState.entity then return end
    local ped = PlayerPedId()
    local ec  = GetEntityCoords(dumpState.entity)

    dumpState.savedCoords = GetEntityCoords(ped)
    dumpState.inside = true

    DoScreenFadeOut(500) Wait(500)
    SetEntityCoords(ped, ec.x, ec.y, ec.z - 5.0, false, false, false, false) Wait(10)
    FreezeEntityPosition(ped, true)
    startDumpCam(dumpState.entity)
    DoScreenFadeIn(500)

    while dumpState.inside do
        Wait(1)
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('~INPUT_DETONATE~ Climb Out')
        EndTextCommandDisplayHelp(false, false, false, -1)
        processDumpCam()

        if IsControlJustReleased(0, Config.DumpsterHide.exitKey) then
            TriggerServerEvent('um_worldint:server:exitDump', entityKey(dumpState.entity))
            DoScreenFadeOut(500) Wait(500)
            FreezeEntityPosition(ped, false)
            SetEntityCoords(ped, dumpState.savedCoords.x, dumpState.savedCoords.y, dumpState.savedCoords.z, false, false, false, false)
            endDumpCam()
            dumpState = { inside = false, entity = nil, cam = nil, savedCoords = nil, offsetRot = { x=0,y=0,z=0 } }
            DoScreenFadeIn(500)
        end
    end
end)

RegisterNetEvent('um_worldint:client:dumpInUse')
AddEventHandler('um_worldint:client:dumpInUse', function()
    dumpState.entity = nil
    lib.notify({ type = 'error', description = 'Someone is already hiding in there.', duration = 3000 })
end)

-- ============================================================================
-- CHAIRS
-- ============================================================================

local chairState  = { using = false, entity = nil, savedCoords = nil }
local chairOffsets = {}  -- [modelHash string] = vec3 offset

CreateThread(function()
    if not Config.Chairs.enabled then return end
    Wait(2000)
    if GetResourceState('ox_target') ~= 'started' then return end

    local models = {}
    for _, entry in ipairs(Config.Chairs.models) do
        models[#models + 1] = entry.model
        chairOffsets[tostring(GetHashKey(entry.model))] = entry.offset
    end

    exports.ox_target:addModel(models, {
        {
            name     = 'um_worldint_sit',
            label    = 'Sit Down',
            icon     = 'fas fa-chair',
            distance = 1.5,
            onSelect = function(data)
                if chairState.using then
                    lib.notify({ type = 'error', description = 'You are already sitting.', duration = 2000 })
                    return
                end
                local entity = data.entity
                local key    = entityKey(entity)
                chairState.entity = entity
                TriggerServerEvent('um_worldint:server:useChair', key, tostring(GetEntityModel(entity)))
            end,
        }
    })
end)

RegisterNetEvent('um_worldint:client:startChair')
AddEventHandler('um_worldint:client:startChair', function(modelHash)
    if not chairState.entity then return end
    local ped    = PlayerPedId()
    local offset = chairOffsets[modelHash] or vec3(0, -0.5, 0)
    local pos    = GetOffsetFromEntityInWorldCoords(chairState.entity, offset.x, offset.y, offset.z)
    local pos2   = GetOffsetFromEntityInWorldCoords(chairState.entity, offset.x, offset.y * 2, offset.z)

    DoScreenFadeOut(500) Wait(500)
    chairState.savedCoords = GetEntityCoords(ped)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    PlaceObjectOnGroundProperly(ped)
    faceCoords(ped, pos2)
    loadAnimDict('timetable@ron@ig_3_couch')
    TaskPlayAnim(ped, 'timetable@ron@ig_3_couch', 'base', 8.0, 8.0, -1, 1, 1, 0, 0, 0)
    FreezeEntityPosition(ped, true)
    DoScreenFadeIn(500)
    chairState.using = true

    while chairState.using do
        Wait(1)
        if not IsEntityPlayingAnim(ped, 'timetable@ron@ig_3_couch', 'base', 1) then
            loadAnimDict('timetable@ron@ig_3_couch')
            TaskPlayAnim(ped, 'timetable@ron@ig_3_couch', 'base', 8.0, 8.0, -1, 1, 1, 0, 0, 0)
        end
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('~INPUT_DETONATE~ Stand Up')
        EndTextCommandDisplayHelp(false, false, false, -1)

        if IsControlJustReleased(0, Config.Chairs.exitKey) then
            TriggerServerEvent('um_worldint:server:leaveChair', entityKey(chairState.entity))
            DoScreenFadeOut(500) Wait(500)
            ClearPedTasksImmediately(ped)
            FreezeEntityPosition(ped, false)
            SetEntityCoords(ped, chairState.savedCoords.x, chairState.savedCoords.y, chairState.savedCoords.z, false, false, false, false)
            PlaceObjectOnGroundProperly(ped)
            chairState = { using = false, entity = nil, savedCoords = nil }
            Wait(400)
            DoScreenFadeIn(500)
        end
    end
    ClearPedTasksImmediately(ped)
end)

RegisterNetEvent('um_worldint:client:chairInUse')
AddEventHandler('um_worldint:client:chairInUse', function()
    chairState.entity = nil
    lib.notify({ type = 'error', description = 'Someone is already sitting there.', duration = 2500 })
end)

-- ============================================================================
-- TOILETS
-- ============================================================================

local toiletState   = { using = false, entity = nil, anim = nil, savedCoords = nil }
local toiletOffsets = {}

CreateThread(function()
    if not Config.Toilets.enabled then return end
    Wait(2000)
    if GetResourceState('ox_target') ~= 'started' then return end

    local models = {}
    for _, entry in ipairs(Config.Toilets.models) do
        models[#models + 1] = entry.model
        toiletOffsets[tostring(GetHashKey(entry.model))] = entry.offset
    end

    exports.ox_target:addModel(models, {
        {
            name     = 'um_worldint_toilet_stand',
            label    = 'Use (Standing)',
            icon     = 'fas fa-restroom',
            distance = 1.5,
            onSelect = function(data)
                if toiletState.using then return end
                toiletState.entity = data.entity
                TriggerServerEvent('um_worldint:server:useToilet', entityKey(data.entity), true, tostring(GetEntityModel(data.entity)))
            end,
        },
        {
            name     = 'um_worldint_toilet_sit',
            label    = 'Use (Sitting)',
            icon     = 'fas fa-toilet',
            distance = 1.5,
            onSelect = function(data)
                if toiletState.using then return end
                toiletState.entity = data.entity
                TriggerServerEvent('um_worldint:server:useToilet', entityKey(data.entity), false, tostring(GetEntityModel(data.entity)))
            end,
        },
    })
end)

RegisterNetEvent('um_worldint:client:startToilet')
AddEventHandler('um_worldint:client:startToilet', function(standing, modelHash)
    if not toiletState.entity then return end
    local ped    = PlayerPedId()
    local offset = toiletOffsets[modelHash] or vec3(0, -0.6, 0)
    local pos    = GetOffsetFromEntityInWorldCoords(toiletState.entity, offset.x, offset.y, offset.z)
    local pos2   = GetOffsetFromEntityInWorldCoords(toiletState.entity, offset.x, offset.y * 2, offset.z)

    local animDict, animClip
    if standing then
        animDict = 'misscarsteal2peeing'
        animClip = 'peeing_loop'
    else
        animDict = 'timetable@ron@ig_3_couch'
        animClip = 'base'
    end
    toiletState.anim = { dict = animDict, clip = animClip }

    DoScreenFadeOut(500) Wait(500)
    toiletState.savedCoords = GetEntityCoords(ped)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    PlaceObjectOnGroundProperly(ped)
    if standing then
        faceEntity(ped, toiletState.entity)
    else
        faceCoords(ped, pos2)
    end
    loadAnimDict(animDict)
    TaskPlayAnim(ped, animDict, animClip, 8.0, 8.0, -1, 1, 1, 0, 0, 0)
    FreezeEntityPosition(ped, true)
    DoScreenFadeIn(500)
    toiletState.using = true

    while toiletState.using do
        Wait(1)
        if not IsEntityPlayingAnim(ped, animDict, animClip, 1) then
            loadAnimDict(animDict)
            TaskPlayAnim(ped, animDict, animClip, 8.0, 8.0, -1, 1, 1, 0, 0, 0)
        end
        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('~INPUT_DETONATE~ Leave')
        EndTextCommandDisplayHelp(false, false, false, -1)

        if IsControlJustReleased(0, Config.Toilets.exitKey) then
            TriggerServerEvent('um_worldint:server:leaveToilet', entityKey(toiletState.entity))
            DoScreenFadeOut(500) Wait(500)
            ClearPedTasksImmediately(ped)
            FreezeEntityPosition(ped, false)
            SetEntityCoords(ped, toiletState.savedCoords.x, toiletState.savedCoords.y, toiletState.savedCoords.z, false, false, false, false)
            PlaceObjectOnGroundProperly(ped)
            toiletState = { using = false, entity = nil, anim = nil, savedCoords = nil }
            Wait(400)
            DoScreenFadeIn(500)
        end
    end
    ClearPedTasksImmediately(ped)
end)

RegisterNetEvent('um_worldint:client:toiletInUse')
AddEventHandler('um_worldint:client:toiletInUse', function()
    toiletState.entity = nil
    lib.notify({ type = 'error', description = 'This one is occupied.', duration = 2500 })
end)

-- ============================================================================
-- VENDING MACHINES
-- ============================================================================

local vendModelMap = {}   -- [modelHash string] = machineIndex

CreateThread(function()
    if not Config.VendingMachines.enabled then return end
    Wait(2000)
    if GetResourceState('ox_target') ~= 'started' then return end

    local allModels = {}
    for i, machine in ipairs(Config.VendingMachines.machines) do
        for _, model in ipairs(machine.models) do
            allModels[#allModels + 1] = model
            vendModelMap[tostring(GetHashKey(model))] = i
        end
    end

    exports.ox_target:addModel(allModels, {
        {
            name     = 'um_worldint_vend',
            label    = 'Use Machine',
            icon     = 'fas fa-candy-cane',
            distance = 1.5,
            onSelect = function(data)
                local machineIdx = vendModelMap[tostring(GetEntityModel(data.entity))]
                if not machineIdx then return end
                local key = entityKey(data.entity)
                TriggerServerEvent('um_worldint:server:openVend', key, machineIdx)
            end,
        }
    })
end)

RegisterNetEvent('um_worldint:client:openVend')
AddEventHandler('um_worldint:client:openVend', function(id, machineIdx, stockData)
    local machine = Config.VendingMachines.machines[machineIdx]
    if not machine then return end

    local opts = {}
    for itemName, itemData in pairs(stockData) do
        local inStock = itemData.stock > 0
        opts[#opts + 1] = {
            title       = itemData.label,
            description = ('$%d  |  Stock: %d'):format(itemData.price, itemData.stock),
            icon        = inStock and machine.icon or 'fas fa-ban',
            disabled    = not inStock,
            onSelect    = function()
                TriggerServerEvent('um_worldint:server:buyVend', id, machineIdx, itemName)
            end,
        }
    end

    lib.registerContext({ id = 'um_vend_menu', title = machine.label, options = opts })
    lib.showContext('um_vend_menu')
end)

-- ============================================================================
-- PARKING METERS
-- ============================================================================

local function getCurrentJob()
    local ok, player = pcall(function() return exports.qbx_core:GetPlayerData() end)
    if ok and player then return player.job and player.job.name end
    return nil
end

local meterAlerts = {}

CreateThread(function()
    if not Config.ParkingMeters.enabled then return end
    Wait(2000)
    if GetResourceState('ox_target') ~= 'started' then return end

    local opts = {
        {
            name     = 'um_worldint_meter_pay',
            label    = 'Pay Meter',
            icon     = 'fas fa-coins',
            distance = 1.0,
            onSelect = function(data)
                local input = lib.inputDialog('Parking Meter', {
                    { type = 'number', label = 'Hours',   icon = 'hourglass-start', required = false, default = 0, min = 0 },
                    { type = 'number', label = 'Minutes', icon = 'hourglass-end',   required = false, default = 0, min = 0 },
                })
                if not input then return end
                local hrs  = tonumber(input[1]) or 0
                local mins = tonumber(input[2]) or 0
                if hrs <= 0 and mins <= 0 then
                    lib.notify({ type = 'error', description = 'Enter a time amount.', duration = 2500 })
                    return
                end
                TriggerServerEvent('um_worldint:server:payMeter', entityKey(data.entity), hrs, mins)
            end,
        },
        {
            name        = 'um_worldint_meter_check',
            label       = 'Inspect Meter',
            icon        = 'fas fa-magnifying-glass',
            distance    = 1.0,
            canInteract = function()
                local job = getCurrentJob()
                return job and Config.ParkingMeters.jobsCanCheck[job] or false
            end,
            onSelect    = function(data)
                TriggerServerEvent('um_worldint:server:checkMeter', entityKey(data.entity))
            end,
        },
    }

    if Config.ParkingMeters.robbery.enabled then
        opts[#opts + 1] = {
            name     = 'um_worldint_meter_rob',
            label    = 'Rob Meter',
            icon     = 'fas fa-sack-dollar',
            distance = 1.0,
            onSelect = function(data)
                local key = entityKey(data.entity)
                -- skill check first
                local sc = Config.ParkingMeters.robbery.skillCheck
                local zones, keys = {}, {}
                for i = 1, sc.checks do
                    zones[i] = sc.difficulty
                    keys[i]  = sc.keys[math.random(#sc.keys)]
                end
                if not lib.skillCheck(zones, keys) then
                    lib.notify({ type = 'error', description = 'Your hands slipped.', duration = 3000 })
                    return
                end
                TriggerServerEvent('um_worldint:server:robMeter', key, GetEntityCoords(data.entity))
            end,
        }
    end

    exports.ox_target:addModel(Config.ParkingMeters.models, opts)
end)

-- Server tells client to play inspect animation
RegisterNetEvent('um_worldint:client:doMeterCheck')
AddEventHandler('um_worldint:client:doMeterCheck', function(isPaid)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_PARKING_METER', 0, true)
    lib.progressBar({
        duration  = Config.ParkingMeters.checkMeterSecs * 1000,
        label     = 'Checking meter...',
        canCancel = false,
        disable   = { move = true, combat = true },
    })
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    lib.notify({
        type        = isPaid and 'success' or 'error',
        description = isPaid and 'Meter is paid.' or 'Meter is expired.',
        duration    = 4000,
    })
end)

-- Server tells client to play rob animation
RegisterNetEvent('um_worldint:client:doMeterRob')
AddEventHandler('um_worldint:client:doMeterRob', function()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_PARKING_METER', 0, true)
    lib.progressBar({
        duration  = 8000,
        label     = 'Breaking into meter...',
        canCancel = false,
        disable   = { move = true, combat = true },
    })
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    TriggerServerEvent('um_worldint:server:meterRobComplete')
end)

-- Police dispatch blip for meter robbery
RegisterNetEvent('um_worldint:client:meterAlert')
AddEventHandler('um_worldint:client:meterAlert', function(coords)
    local job = getCurrentJob()
    if not (job and Config.ParkingMeters.jobsCanCheck[job]) then return end

    local key = ('%d_%d_%d'):format(math.ceil(coords.x), math.ceil(coords.y), math.ceil(coords.z))
    if meterAlerts[key] then return end

    lib.notify({ type = 'error', description = 'Parking meter robbery in progress!', duration = 5000 })
    local blp = Config.ParkingMeters.robbery.dispatchBlip
    local b   = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, blp.sprite)
    SetBlipScale(b, blp.scale)
    SetBlipColour(b, blp.color)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Meter Robbery')
    EndTextCommandSetBlipName(b)
    meterAlerts[key] = b

    CreateThread(function()
        Wait(45000)
        if meterAlerts[key] and DoesBlipExist(meterAlerts[key]) then
            RemoveBlip(meterAlerts[key])
        end
        meterAlerts[key] = nil
    end)
end)

-- ============================================================================
-- Loose Change — use from inventory to count it up and convert to cash
-- ============================================================================

RegisterNetEvent('um_beg:cashInChange')
AddEventHandler('um_beg:cashInChange', function()
    TriggerServerEvent('um_worldint:server:cashInChange')
end)

-- ============================================================================
-- ox_target setup — Porta Potty + Dumpster Hide (registered after ox_target starts)
-- ============================================================================

CreateThread(function()
    Wait(2000)
    if GetResourceState('ox_target') ~= 'started' then return end

    -- Porta potties
    if Config.PortaPotty.enabled then
        exports.ox_target:addModel(Config.PortaPotty.models, {
            {
                name     = 'um_worldint_porta',
                label    = 'Use Porta Potty',
                icon     = 'fas fa-toilet-portable',
                distance = 1.5,
                onSelect = function(data)
                    if portaState.inside then
                        lib.notify({ type = 'error', description = 'You are already inside one.', duration = 2000 })
                        return
                    end
                    portaState.entity = data.entity
                    TriggerServerEvent('um_worldint:server:usePorta', entityKey(data.entity))
                end,
            }
        })
    end

    -- Dumpster hiding
    if Config.DumpsterHide.enabled then
        exports.ox_target:addModel(Config.DumpsterHide.models, {
            {
                name     = 'um_worldint_dumpster_hide',
                label    = 'Hide in Dumpster',
                icon     = 'fas fa-person-shelter',
                distance = 1.5,
                onSelect = function(data)
                    if dumpState.inside then
                        lib.notify({ type = 'error', description = 'You are already hiding.', duration = 2000 })
                        return
                    end
                    dumpState.entity = data.entity
                    TriggerServerEvent('um_worldint:server:useDump', entityKey(data.entity))
                end,
            }
        })
    end
end)
