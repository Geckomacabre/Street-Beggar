-- ============================================================================
-- um_beg client (Phase 1)
-- /beg toggles begging. While begging, scans cars + peds in forward cone for
-- random outcomes (give / yell / ignore / cop). On give, an offer is created
-- with a minimap cone (GTA-Online-style SetBlipShowCone), player auto-walks
-- over, claims cash, then auto-walks back to begOrigin.
-- ============================================================================

local begging        = false
local activeVariant  = nil   -- which Config.BegVariants entry is active
local heldProp       = nil
local driverCooldown = {}    -- entity handle -> expireMs
local pedCooldown    = {}    -- entity handle -> expireMs
local activeOffer    = nil   -- { veh|nil, driver, blip, expiresAt, claimed, kind = 'car' | 'ped' }
local activeCop      = nil   -- cop encounter state
local activeLimo     = nil   -- limo encounter state
local activeMugger   = nil   -- mugger encounter state
local begOrigin      = nil
local begHeading     = 0     -- ped heading when /beg was started
local begStartTime   = 0     -- when current beg session started (ms)
local lastTossMs     = 0     -- last drive-by toss timestamp
local lastLimoMs     = 0     -- last limo spawn timestamp
-- Box & busking state
local activeBox      = nil   -- { prop, coords } when begging box is placed
local boxPickupZone  = nil   -- ox_lib zone for picking up the box
local buskingActive  = false -- guitar progress bar is running
local buskingProp    = nil   -- guitar prop entity handle
local placingBox     = false -- currently in 3D placement preview mode

-- ---- Subtitle helper ------------------------------------------------------

local function pick(t) return t[math.random(#t)] end

local function subtitle(category, override)
    if not Config.Subtitles.enabled then return end
    local line = override or pick(Config.SubtitleLines[category] or { '' })
    if not line or line == '' then return end
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(line)
    EndTextCommandPrint(Config.Subtitles.durationMs, true)
end

-- ---- Asset loading --------------------------------------------------------

local function loadDict(dict, timeoutMs)
    RequestAnimDict(dict)
    local until_ = GetGameTimer() + (timeoutMs or 2000)
    while not HasAnimDictLoaded(dict) and GetGameTimer() < until_ do Wait(15) end
    return HasAnimDictLoaded(dict)
end

local function loadModel(model, timeoutMs)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    RequestModel(hash)
    local until_ = GetGameTimer() + (timeoutMs or 2000)
    while not HasModelLoaded(hash) and GetGameTimer() < until_ do Wait(15) end
    return HasModelLoaded(hash) and hash or nil
end

-- ---- Begging prop & anim --------------------------------------------------

local function attachVariantProp(variant)
    if heldProp and DoesEntityExist(heldProp) then return end
    if not variant.prop then return end  -- variants without a prop (e.g. on-knees)
    local ped = PlayerPedId()
    local hash = loadModel(variant.prop, 2000)
    if not hash then return end
    local coords = GetEntityCoords(ped)
    heldProp = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    AttachEntityToEntity(
        heldProp, ped, GetPedBoneIndex(ped, variant.propBone),
        variant.propOffset.x, variant.propOffset.y, variant.propOffset.z,
        variant.propRotation.x, variant.propRotation.y, variant.propRotation.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(hash)
end

local function clearProp()
    if heldProp and DoesEntityExist(heldProp) then
        DetachEntity(heldProp, false, false)
        DeleteObject(heldProp)
    end
    heldProp = nil
end

local function isVariantPlaying(variant)
    return IsEntityPlayingAnim(PlayerPedId(), variant.dict, variant.clip, 3)
end

local function playVariant(variant)
    if not loadDict(variant.dict, 2000) then return false end
    TaskPlayAnim(PlayerPedId(), variant.dict, variant.clip, 8.0, -8.0, -1, variant.flag, 0, false, false, false)
    return true
end

local function resetCurrentAnim(heading)
    if not activeVariant then return end
    local ped = PlayerPedId()
    -- Kill any active movement task (walk-back nav task can still be running
    -- and wins the rotation battle against SetEntityHeading on the same tick)
    ClearPedTasks(ped)
    StopAnimTask(ped, activeVariant.dict, activeVariant.clip, 3.0)
    if heading then
        -- Freeze the ped so physics/idle can't rotate them while we re-orient
        FreezeEntityPosition(ped, true)
        SetEntityHeading(ped, heading)
    end
    Wait(120)
    if heading then SetEntityHeading(ped, heading) end  -- re-stamp after settle
    playVariant(activeVariant)
    if heading then
        -- Unfreeze now that the animation has locked the rotation
        Wait(100)
        SetEntityHeading(ped, heading)
        FreezeEntityPosition(ped, false)
    end
end

-- ---- Lifecycle ------------------------------------------------------------

local function startBeg()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        lib.notify({ type = 'error', description = "Can't beg from inside a vehicle.", duration = Config.NotifyDuration })
        return
    end
    -- Item check (ox_inventory path)
    if Config.RequireItem and Config.UseOxInventory then
        local ok, count = pcall(function() return exports.ox_inventory:Search('count', Config.BegItem) end)
        if not ok or not count or count < 1 then
            lib.notify({ type = 'error', description = 'You need a cardboard sign to beg.', duration = Config.NotifyDuration })
            return
        end
    end
    activeVariant = Config.BegVariants[math.random(#Config.BegVariants)]
    if not playVariant(activeVariant) then
        lib.notify({ type = 'error', description = 'Animation failed to load.', duration = Config.NotifyDuration })
        return
    end
    attachVariantProp(activeVariant)
    begging      = true
    begOrigin    = GetEntityCoords(ped)
    begHeading   = GetEntityHeading(ped)
    begStartTime = GetGameTimer()
    if Config.Subtitles.showStart then subtitle('start') end
end

local function clearActiveOffer(success)
    if not activeOffer then return end
    if activeOffer.blip and DoesBlipExist(activeOffer.blip) then RemoveBlip(activeOffer.blip) end
    -- Unfreeze and resume driver / wander ped
    if activeOffer.kind == 'car' and activeOffer.veh and DoesEntityExist(activeOffer.veh) then
        FreezeEntityPosition(activeOffer.veh, false)
        if activeOffer.driver and DoesEntityExist(activeOffer.driver) then
            ClearPedTasks(activeOffer.driver)
            TaskVehicleDriveWander(activeOffer.driver, activeOffer.veh, 18.0, 786603)
        end
    elseif activeOffer.driver and DoesEntityExist(activeOffer.driver) then
        ClearPedTasks(activeOffer.driver)
        TaskWanderStandard(activeOffer.driver, 10.0, 10)
    end
    if not success then
        ClearPedTasks(PlayerPedId())
        if activeOffer.expiresAt and GetGameTimer() >= activeOffer.expiresAt then
            subtitle('drive_off')
        end
    end
    activeOffer = nil
end

local function clearActiveCop()
    if not activeCop then return end
    if activeCop.blip and DoesBlipExist(activeCop.blip) then RemoveBlip(activeCop.blip) end
    if activeCop.veh and DoesEntityExist(activeCop.veh) then
        SetVehicleSiren(activeCop.veh, false)
    end
    if activeCop.cleanupAt then
        local capVeh = activeCop.veh
        local capDriver = activeCop.driver
        Citizen.SetTimeout(math.max(0, activeCop.cleanupAt - GetGameTimer()), function()
            for _, ent in ipairs({ capDriver, activeCop and activeCop.passenger, capVeh }) do
                if ent and DoesEntityExist(ent) then
                    SetEntityAsMissionEntity(ent, true, true)
                    DeleteEntity(ent)
                end
            end
        end)
    end
    activeCop = nil
end

local function clearActiveMugger()
    if not activeMugger then return end
    if activeMugger.blip and DoesBlipExist(activeMugger.blip) then RemoveBlip(activeMugger.blip) end
    if activeMugger.ped and DoesEntityExist(activeMugger.ped) then
        ClearPedTasks(activeMugger.ped)
        TaskWanderStandard(activeMugger.ped, 10.0, 10)
    end
    activeMugger = nil
end

local function stopBeg()
    if not begging then return end
    begging = false
    begOrigin = nil
    if activeVariant then
        StopAnimTask(PlayerPedId(), activeVariant.dict, activeVariant.clip, 3.0)
    end
    clearProp()
    clearActiveOffer(false)
    clearActiveCop()
    clearActiveLimo()
    clearActiveMugger()
    activeVariant = nil
    begHeading    = 0
    begStartTime  = 0
    if buskingActive then lib.cancelProgress() end
end

local function walkBackToOrigin()
    if not begging or not begOrigin then return end
    TaskFollowNavMeshToCoord(PlayerPedId(), begOrigin.x, begOrigin.y, begOrigin.z, 1.5, 30000, 1.5, false, 0)
end

-- ---- Tier helpers -----------------------------------------------------------

local function boxIsNearby()
    if not activeBox or not DoesEntityExist(activeBox.prop) then return false end
    return #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(activeBox.prop)) <= Config.BeggingBox.nearRange
end

--- Returns the active payout tier name for the current setup.
local function getActiveTier()
    local hasBox = boxIsNearby()
    if buskingActive and hasBox then return 'box_and_guitar' end
    if begging       and hasBox then return 'sign_and_box'   end
    if begging                  then return 'sign_only'      end
    if hasBox                   then return 'box_only'       end
    return 'sign_only'
end

-- ---- Forward cone check ---------------------------------------------------

local function inForwardCone(plyCoords, plyForward, targetCoords, halfConeCos)
    local dx = targetCoords.x - plyCoords.x
    local dy = targetCoords.y - plyCoords.y
    local magSq = dx*dx + dy*dy
    if magSq < 0.01 then return true end
    local invMag = 1.0 / math.sqrt(magSq)
    local nx = dx * invMag
    local ny = dy * invMag
    local dot = plyForward.x * nx + plyForward.y * ny
    return dot >= halfConeCos
end

-- ---- Candidate scanning (vehicles AND peds) ------------------------------

--- Returns { kind, veh|nil, ped, dist }  or nil
local function findCandidate()
    local self = PlayerPedId()
    local plyCoords = GetEntityCoords(self)
    local plyForward = GetEntityForwardVector(self)
    local halfConeCos = math.cos(math.rad(Config.ConeAngleDegrees * 0.5))
    local maxZ = Config.MaxZDifference
    local now = GetGameTimer()

    local best  -- { kind, veh, ped, dist }

    -- Cars
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and not IsEntityDead(veh)
           and (not activeOffer or veh ~= activeOffer.veh) then
            local driver = GetPedInVehicleSeat(veh, -1)
            if driver ~= 0 and DoesEntityExist(driver) and not IsPedAPlayer(driver) and not IsEntityDead(driver) then
                local cd = driverCooldown[driver]
                if not cd or now > cd then
                    if GetEntitySpeed(veh) <= Config.MaxVehicleSpeedToTarget then
                        local vc = GetEntityCoords(veh)
                        if math.abs(vc.z - plyCoords.z) <= maxZ then
                            local dist = #(vc - plyCoords)
                            if dist <= Config.ScanRange then
                                if inForwardCone(plyCoords, plyForward, vc, halfConeCos) then
                                    if not best or dist < best.dist then
                                        best = { kind = 'car', veh = veh, ped = driver, dist = dist }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Pedestrians (optional)
    if Config.ScanPedestrians then
        for _, p in ipairs(GetGamePool('CPed')) do
            if DoesEntityExist(p) and not IsPedAPlayer(p) and not IsEntityDead(p)
               and not IsPedInAnyVehicle(p, false)
               and not (activeOffer and p == activeOffer.driver) then
                local cd = pedCooldown[p]
                if not cd or now > cd then
                    local pc = GetEntityCoords(p)
                    if math.abs(pc.z - plyCoords.z) <= maxZ then
                        local dist = #(pc - plyCoords)
                        if dist <= Config.ScanRange then
                            if inForwardCone(plyCoords, plyForward, pc, halfConeCos) then
                                if not best or dist < best.dist then
                                    best = { kind = 'ped', veh = nil, ped = p, dist = dist }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

-- ---- Outcome rolls -------------------------------------------------------

local function getModifiers(targetPed)
    local mods = { give = 0, ignore = 0, yell = 0, cop = 0 }
    local coords   = GetEntityCoords(targetPed)
    local zone     = GetNameOfZone(coords.x, coords.y, coords.z)
    local areaType = Config.ZoneAreas[zone] or 'normal'
    for k, v in pairs(Config.AreaModifiers[areaType] or {}) do mods[k] = (mods[k] or 0) + v end
    local personality = Entity(targetPed).state and Entity(targetPed).state.umw_personality
    if personality and Config.PersonalityModifiers[personality] then
        for k, v in pairs(Config.PersonalityModifiers[personality]) do mods[k] = (mods[k] or 0) + v end
    end
    return mods
end

local function rollOutcome(targetPed)
    local mods = getModifiers(targetPed)
    local w = {
        give   = math.max(0, Config.Outcomes.give   + (mods.give   or 0)),
        ignore = math.max(0, Config.Outcomes.ignore + (mods.ignore or 0)),
        yell   = math.max(0, Config.Outcomes.yell   + (mods.yell   or 0)),
        cop    = math.max(0, Config.Outcomes.cop    + (mods.cop    or 0)),
    }
    local total = w.give + w.ignore + w.yell + w.cop
    if total <= 0 then return 'ignore' end
    local roll = math.random(total)
    local accum = 0
    for _, k in ipairs({ 'give', 'ignore', 'yell', 'cop' }) do
        accum = accum + w[k]
        if roll <= accum then return k end
    end
    return 'ignore'
end

-- ---- Outcome handlers ----------------------------------------------------

local function payoutAmount()
    local tier = getActiveTier()
    local cfg  = (tier ~= 'sign_only') and (Config.PayoutTiers and Config.PayoutTiers[tier]) or nil
    if not cfg then cfg = Config.Payout end  -- sign_only uses existing Config.Payout
    local generous = math.random(100) <= (cfg.generousChance or Config.Payout.generousChance)
    local amount   = generous
        and math.random(cfg.generousMin or Config.Payout.generousMin, cfg.generousMax or Config.Payout.generousMax)
        or  math.random(cfg.min         or Config.Payout.min,         cfg.max         or Config.Payout.max)
    return amount, generous, tier
end

local function setupOfferBlip(entity, label)
    local blip = AddBlipForEntity(entity)
    SetBlipSprite(blip, Config.Offer.blipSprite)
    SetBlipColour(blip, Config.Offer.blipColor)
    SetBlipScale(blip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Generous')
    EndTextCommandSetBlipName(blip)
    if Config.ShowOfferCone then
        SetBlipShowCone(blip, true)
    end
    return blip
end

-- Honking driver waits at the light to give
local function outcomeGiveCar(veh, driverPed, driverNet)
    StartVehicleHorn(veh, 250, GetHashKey('NORMAL'), false)
    Citizen.SetTimeout(450, function()
        if DoesEntityExist(veh) then StartVehicleHorn(veh, 250, GetHashKey('NORMAL'), false) end
    end)
    FreezeEntityPosition(veh, true)
    PlayAmbientSpeech1(driverPed, pick(Config.GiveSpeeches), 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR')

    local blip = setupOfferBlip(veh, 'Generous Driver')
    activeOffer = {
        kind = 'car', veh = veh, driver = driverPed, driverNet = driverNet, blip = blip,
        expiresAt = GetGameTimer() + Config.Offer.timeoutMs,
        claimed = false,
    }
    -- Stop beg anim so the player can walk
    if activeVariant then StopAnimTask(PlayerPedId(), activeVariant.dict, activeVariant.clip, 2.0) end
    TaskGoToEntity(PlayerPedId(), veh, Config.Offer.autoWalkTimeoutMs, Config.Offer.claimRadius - 1.0, Config.Offer.autoWalkSpeed, 1073741824, 0)
end

-- Generous pedestrian waves you over
local function outcomeGivePed(targetPed, netId)
    PlayAmbientSpeech1(targetPed, pick(Config.GiveSpeeches), 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR')
    -- Wave gesture
    if loadDict('gestures@m@standing@casual', 1200) then
        TaskPlayAnim(targetPed, 'gestures@m@standing@casual', 'gesture_come_here_soft', 8.0, -8.0, 2000, 49, 0, false, false, false)
    end
    -- Hold position
    ClearPedTasks(targetPed)
    TaskStandStill(targetPed, Config.Offer.timeoutMs)

    local blip = setupOfferBlip(targetPed, 'Kind Stranger')
    activeOffer = {
        kind = 'ped', veh = nil, driver = targetPed, driverNet = netId, blip = blip,
        expiresAt = GetGameTimer() + Config.Offer.timeoutMs,
        claimed = false,
    }
    if activeVariant then StopAnimTask(PlayerPedId(), activeVariant.dict, activeVariant.clip, 2.0) end
    TaskGoToEntity(PlayerPedId(), targetPed, Config.Offer.autoWalkTimeoutMs, Config.Offer.claimRadius - 1.0, Config.Offer.autoWalkSpeed, 1073741824, 0)
end

-- Mugger pretends to give then robs the player
local function outcomeMug(targetPed)
    PlayAmbientSpeech1(targetPed, pick(Config.GiveSpeeches), 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR')
    if loadDict('gestures@m@standing@casual', 1500) then
        TaskPlayAnim(targetPed, 'gestures@m@standing@casual', 'gesture_come_here_soft', 8.0, -8.0, 2500, 49, 0, false, false, false)
    end
    -- Wait for wave to finish before advancing
    Citizen.SetTimeout(2500, function()
        if DoesEntityExist(targetPed) then
            TaskGoToEntity(targetPed, PlayerPedId(), Config.Mug.approachTimeoutMs, 0.5, 2.5, 1073741824, 0)
        end
    end)
    local blip = setupOfferBlip(targetPed, 'Kind Stranger')
    activeMugger = {
        ped      = targetPed,
        blip     = blip,
        expiresAt = GetGameTimer() + Config.Mug.approachTimeoutMs + 2500,
        triggered = false,
    }
    subtitle('mug_approach')
end

local function outcomeYellCar(veh, driverPed)
    StartVehicleHorn(veh, 1200, GetHashKey('NORMAL'), false)
    PlayAmbientSpeech1(driverPed, pick(Config.YellSpeeches), 'SPEECH_PARAMS_FORCE_SHOUTED_CRITICAL')
    subtitle('yell')
end

local function outcomeYellPed(targetPed)
    PlayAmbientSpeech1(targetPed, pick(Config.YellSpeeches), 'SPEECH_PARAMS_FORCE_SHOUTED_CRITICAL')
    -- Push-off animation
    if loadDict('gestures@m@standing@casual', 1200) then
        TaskPlayAnim(targetPed, 'gestures@m@standing@casual', 'gesture_no_way', 8.0, -8.0, 2000, 49, 0, false, false, false)
    end
    subtitle('ped_yell')
end

-- ---- Cop encounter ----------------------------------------------------------

local function drawBustedScreen(durationMs)
    AnimpostfxStop('DeathFailMPDark')
    AnimpostfxPlay('DeathFailMPDark', 0, true)
    local until_ = GetGameTimer() + durationMs
    while GetGameTimer() < until_ do
        DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 200)
        SetTextScale(2.4, 2.4); SetTextFont(7); SetTextColour(220, 30, 30, 255)
        SetTextOutline(); SetTextCentre(true)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName('BUSTED')
        EndTextCommandDisplayText(0.5, 0.36)
        SetTextScale(0.55, 0.55); SetTextFont(4); SetTextColour(255, 255, 255, 220)
        SetTextCentre(true)
        BeginTextCommandDisplayText('STRING')
        AddTextComponentSubstringPlayerName('Loitering and panhandling. Off to county you go.')
        EndTextCommandDisplayText(0.5, 0.52)
        Wait(0)
    end
    AnimpostfxStop('DeathFailMPDark')
end

local function handleArrestChoice(copPed)
    stopBeg()
    local choice = lib.alertDialog({
        header   = "You're being approached by an officer",
        content  = "They don't look happy. Put your hands up and surrender, or make a run for it.",
        centered = true, cancel = true,
        labels   = { confirm = 'Run!', cancel = 'Surrender' },
    })
    if choice == 'confirm' then
        SetPlayerWantedLevel(PlayerId(), Config.CopEncounter.meanCopWantedLevel, false)
        SetPlayerWantedLevelNow(PlayerId(), false)
        if DoesEntityExist(copPed) then
            PlayAmbientSpeech1(copPed, 'GENERIC_INSULT_HIGH', 'SPEECH_PARAMS_FORCE_SHOUTED_CRITICAL')
        end
        lib.notify({ type = 'inform', description = 'You bolt down the street!', duration = Config.NotifyDuration })
    else
        TaskHandsUp(PlayerPedId(), 8000, 0, -1, true)
        Wait(2200)
        drawBustedScreen(Config.CopEncounter.bustedDurationMs)
        TriggerServerEvent('um_beg:requestJail', Config.CopEncounter.jailMinutes)
    end
end

local function spawnCopEncounter()
    local cfg = Config.CopEncounter
    local plyCoords = GetEntityCoords(PlayerPedId())
    local angle = math.rad(math.random(360))
    local dist  = math.random(cfg.spawnDistanceMin, cfg.spawnDistanceMax)
    local found, nodePos, nodeHeading = GetClosestVehicleNodeWithHeading(
        plyCoords.x + math.cos(angle) * dist,
        plyCoords.y + math.sin(angle) * dist,
        plyCoords.z, 1, 3.0, 0)
    if not found then return end

    local pedHash = loadModel(cfg.pedModels[math.random(#cfg.pedModels)], 3000)
    if not pedHash then return end

    local vehHash = loadModel(cfg.vehicleModels[math.random(#cfg.vehicleModels)], 3000)
    if not vehHash then SetModelAsNoLongerNeeded(pedHash); return end

    local veh = CreateVehicle(vehHash, nodePos.x, nodePos.y, nodePos.z + 0.5, nodeHeading, true, false)
    SetModelAsNoLongerNeeded(vehHash)
    if not veh or not DoesEntityExist(veh) then SetModelAsNoLongerNeeded(pedHash); return end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleSiren(veh, true)
    SetVehicleEngineOn(veh, true, true, false)

    local copPed = CreatePedInsideVehicle(veh, 4, pedHash, -1, true, false)
    SetModelAsNoLongerNeeded(pedHash)
    if not copPed then SetEntityAsMissionEntity(veh, true, true); DeleteEntity(veh); return end

    SetEntityAsMissionEntity(copPed, true, true)
    SetPedAsCop(copPed, true)
    TaskVehicleDriveToCoordLongrange(copPed, veh, plyCoords.x, plyCoords.y, plyCoords.z, cfg.driveSpeed, 786603, 8.0)

    local nice = math.random(100) <= cfg.niceCopChance
    activeCop = {
        veh = veh, driver = copPed, nice = nice,
        exited = false, approaching = false,
        cleanupAt = GetGameTimer() + cfg.despawnAfterMs,
        resolved = false,
    }

    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 60); SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Police')
    EndTextCommandSetBlipName(blip)
    if Config.ShowOfferCone then SetBlipShowCone(blip, true) end
    activeCop.blip = blip

    subtitle(nice and 'cop_nice' or 'cop_mean')
end

-- Cop interaction tick — vehicle stops nearby, cop gets out and walks up
CreateThread(function()
    while true do
        if activeCop and not activeCop.resolved then
            if not DoesEntityExist(activeCop.driver) or IsEntityDead(activeCop.driver) then
                clearActiveCop()
            else
                local plyCoords = GetEntityCoords(PlayerPedId())

                if not activeCop.exited then
                    if activeCop.veh and DoesEntityExist(activeCop.veh) then
                        if #(plyCoords - GetEntityCoords(activeCop.veh)) <= 10.0 then
                            SetVehicleSiren(activeCop.veh, false)
                            FreezeEntityPosition(activeCop.veh, true)
                            TaskLeaveVehicle(activeCop.driver, activeCop.veh, 0)
                            activeCop.exited = true
                        end
                    end
                elseif not IsPedInAnyVehicle(activeCop.driver, false) then
                    if not activeCop.approaching then
                        activeCop.approaching = true
                        TaskGoToEntity(activeCop.driver, PlayerPedId(), 30000, 1.5, 2.0, 1073741824, 0)
                    end
                    if #(plyCoords - GetEntityCoords(activeCop.driver)) <= 3.0 then
                        activeCop.resolved = true
                        if activeCop.nice then
                            if loadDict('mp_common', 1200) then
                                TaskPlayAnim(activeCop.driver, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 49, 0, false, false, false)
                            end
                            TriggerServerEvent('umw:beg:reward', Config.CopEncounter.niceCopPayout, true, 'cop_nice')
                            Wait(1500)
                            clearActiveCop()
                        else
                            local copRef = activeCop.driver
                            clearActiveCop()
                            handleArrestChoice(copRef)
                        end
                    end
                end
                Wait(200)
            end
        else
            Wait(1000)
        end
    end
end)

-- ---- Limo encounter (rare, always generous) ---------------------------------

local function clearActiveLimo()
    if not activeLimo then return end
    if activeLimo.blip and DoesBlipExist(activeLimo.blip) then RemoveBlip(activeLimo.blip) end
    if activeLimo.veh and DoesEntityExist(activeLimo.veh) then
        FreezeEntityPosition(activeLimo.veh, false)
    end
    if activeLimo.cleanupAt then
        local capVeh    = activeLimo.veh
        local capDriver = activeLimo.driver
        Citizen.SetTimeout(math.max(0, activeLimo.cleanupAt - GetGameTimer()), function()
            for _, ent in ipairs({ capDriver, capVeh }) do
                if ent and DoesEntityExist(ent) then
                    SetEntityAsMissionEntity(ent, true, true); DeleteEntity(ent)
                end
            end
        end)
    end
    activeLimo = nil
end

local function spawnLimoEncounter()
    local cfg = Config.LimoEncounter
    local plyCoords = GetEntityCoords(PlayerPedId())
    local angle = math.rad(math.random(360))
    local spawnDist = math.random(cfg.spawnDistanceMin, cfg.spawnDistanceMax)
    local found, nodePos, nodeHeading = GetClosestVehicleNodeWithHeading(
        plyCoords.x + math.cos(angle) * spawnDist,
        plyCoords.y + math.sin(angle) * spawnDist,
        plyCoords.z, 1, 3.0, 0)
    if not found then return end

    local pedHash = loadModel(cfg.pedModels[math.random(#cfg.pedModels)], 3000)
    if not pedHash then return end

    local vehHash = loadModel(cfg.vehicleModels[math.random(#cfg.vehicleModels)], 3000)
    if not vehHash then SetModelAsNoLongerNeeded(pedHash); return end

    local veh = CreateVehicle(vehHash, nodePos.x, nodePos.y, nodePos.z + 0.5, nodeHeading, true, false)
    SetModelAsNoLongerNeeded(vehHash)
    if not veh or not DoesEntityExist(veh) then SetModelAsNoLongerNeeded(pedHash); return end

    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleEngineOn(veh, true, true, false)

    local driverPed = CreatePedInsideVehicle(veh, 4, pedHash, -1, true, false)
    SetModelAsNoLongerNeeded(pedHash)
    if not driverPed then SetEntityAsMissionEntity(veh, true, true); DeleteEntity(veh); return end

    SetEntityAsMissionEntity(driverPed, true, true)
    TaskVehicleDriveToCoordLongrange(driverPed, veh, plyCoords.x, plyCoords.y, plyCoords.z, cfg.driveSpeed, 786603, 5.0)

    activeLimo = {
        veh = veh, driver = driverPed,
        cleanupAt = GetGameTimer() + cfg.despawnAfterMs,
        resolved = false,
    }

    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 225); SetBlipColour(blip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Luxury Vehicle')
    EndTextCommandSetBlipName(blip)
    if Config.ShowOfferCone then SetBlipShowCone(blip, true) end
    activeLimo.blip = blip

    subtitle('limo_approach')
end

-- Limo interaction tick — always generous, becomes an activeOffer on arrival
CreateThread(function()
    while true do
        if activeLimo and not activeLimo.resolved then
            if not DoesEntityExist(activeLimo.driver) or IsEntityDead(activeLimo.driver)
               or not DoesEntityExist(activeLimo.veh) then
                clearActiveLimo()
            else
                if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(activeLimo.veh)) <= 7.0 then
                    activeLimo.resolved = true
                    local capVeh    = activeLimo.veh
                    local capDriver = activeLimo.driver
                    FreezeEntityPosition(capVeh, true)
                    StartVehicleHorn(capVeh, 300, GetHashKey('NORMAL'), false)
                    Citizen.SetTimeout(500, function()
                        if DoesEntityExist(capVeh) then StartVehicleHorn(capVeh, 300, GetHashKey('NORMAL'), false) end
                    end)
                    PlayAmbientSpeech1(capDriver, pick(Config.GiveSpeeches), 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR')
                    subtitle('limo_nice')
                    if activeLimo and activeLimo.blip and DoesBlipExist(activeLimo.blip) then RemoveBlip(activeLimo.blip) end
                    local offerBlip = setupOfferBlip(capVeh, 'Generous Stranger')
                    activeLimo = nil
                    activeOffer = {
                        kind = 'car', veh = capVeh, driver = capDriver,
                        driverNet = capDriver, blip = offerBlip,
                        expiresAt = GetGameTimer() + Config.LimoEncounter.offerTimeoutMs,
                        claimed = false,
                        payoutOverride = math.random(Config.LimoEncounter.payoutMin, Config.LimoEncounter.payoutMax),
                    }
                    if activeVariant then StopAnimTask(PlayerPedId(), activeVariant.dict, activeVariant.clip, 2.0) end
                    TaskGoToEntity(PlayerPedId(), capVeh, Config.LimoEncounter.offerTimeoutMs, Config.Offer.claimRadius - 1.0, Config.Offer.autoWalkSpeed, 1073741824, 0)
                end
                Wait(300)
            end
        else
            Wait(1000)
        end
    end
end)

-- ---- Mugger monitor thread -----------------------------------------------

CreateThread(function()
    while true do
        if activeMugger and not activeMugger.triggered then
            if not DoesEntityExist(activeMugger.ped) or IsEntityDead(activeMugger.ped) then
                clearActiveMugger()
            elseif GetGameTimer() >= activeMugger.expiresAt then
                clearActiveMugger()
            else
                local playerPed = PlayerPedId()
                local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(activeMugger.ped))
                if dist <= 1.8 then
                    activeMugger.triggered = true
                    local muggerRef = activeMugger.ped
                    if activeMugger.blip and DoesBlipExist(activeMugger.blip) then RemoveBlip(activeMugger.blip) end
                    activeMugger = nil

                    subtitle('mug_reveal')
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.25)

                    ClearPedTasks(muggerRef)
                    TaskCombatPed(muggerRef, playerPed, 0, 16)
                    Wait(2000)

                    TriggerServerEvent('umw:beg:mugged')

                    ClearPedTasks(muggerRef)
                    TaskFleeEntity(muggerRef, playerPed, false, false, 50.0, false, false)
                    stopBeg()

                    Citizen.SetTimeout(Config.Mug.fleeAfterMs, function()
                        if DoesEntityExist(muggerRef) then
                            SetEntityAsMissionEntity(muggerRef, true, true)
                            DeleteEntity(muggerRef)
                        end
                    end)
                end
                Wait(150)
            end
        else
            Wait(1000)
        end
    end
end)

-- ---- Roll scheduler ------------------------------------------------------

CreateThread(function()
    while true do
        if begging and not activeOffer and not (activeCop and not activeCop.resolved) then
            Wait(math.random(Config.RollIntervalMinMs, Config.RollIntervalMaxMs))
            if begging and not activeOffer then
                local cand = findCandidate()
                if cand then
                    local outcome = rollOutcome(cand.ped)
                    if cand.kind == 'car' then
                        driverCooldown[cand.ped] = GetGameTimer() + Config.PerDriverCooldownMs
                        if outcome == 'give' then outcomeGiveCar(cand.veh, cand.ped, cand.ped)
                        elseif outcome == 'yell' then outcomeYellCar(cand.veh, cand.ped)
                        elseif outcome == 'cop' then spawnCopEncounter()
                        else subtitle('ignore') end
                    else  -- ped
                        pedCooldown[cand.ped] = GetGameTimer() + Config.PerPedCooldownMs
                        if outcome == 'give' then
                            if math.random(100) <= Config.Mug.chance then
                                outcomeMug(cand.ped)
                            else
                                outcomeGivePed(cand.ped, cand.ped)
                            end
                        elseif outcome == 'yell' then outcomeYellPed(cand.ped)
                        elseif outcome == 'cop' then spawnCopEncounter()
                        else subtitle('ignore') end
                    end
                end

                -- Limo: rare bonus event, only after begging for a while
                local lcfg = Config.LimoEncounter
                if not activeOffer and not activeCop and not activeLimo
                   and begStartTime > 0
                   and (GetGameTimer() - begStartTime)  >= lcfg.minBegTimeMs
                   and (GetGameTimer() - lastLimoMs)    >= lcfg.cooldownMs
                   and math.random(100) <= lcfg.triggerChance then
                    lastLimoMs = GetGameTimer()
                    spawnLimoEncounter()
                end

                -- Drive-by toss: moving car passing close tosses change without stopping
                local cfg = Config.DriveByToss
                if cfg.enabled and (GetGameTimer() - lastTossMs) > cfg.cooldownMs then
                    local self2  = PlayerPedId()
                    local pc2    = GetEntityCoords(self2)
                    local fwd2   = GetEntityForwardVector(self2)
                    local hcc    = math.cos(math.rad(Config.ConeAngleDegrees * 0.5))
                    for _, mv in ipairs(GetGamePool('CVehicle')) do
                        if DoesEntityExist(mv) and GetEntitySpeed(mv) > Config.MaxVehicleSpeedToTarget then
                            local vc2 = GetEntityCoords(mv)
                            if math.abs(vc2.z - pc2.z) <= Config.MaxZDifference then
                                local d2 = #(vc2 - pc2)
                                if d2 <= cfg.maxRange and inForwardCone(pc2, fwd2, vc2, hcc) then
                                    if math.random(100) <= cfg.chance then
                                        local drv = GetPedInVehicleSeat(mv, -1)
                                        if drv ~= 0 and DoesEntityExist(drv) and not IsPedAPlayer(drv) then
                                            lastTossMs = GetGameTimer()
                                            StartVehicleHorn(mv, 350, GetHashKey('NORMAL'), false)
                                            TriggerServerEvent('umw:beg:reward', math.random(cfg.min, cfg.max), false, 'driver')
                                            subtitle('toss')
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        else
            Wait(800)
        end
    end
end)

-- ---- Claim tick ----------------------------------------------------------

CreateThread(function()
    while true do
        if activeOffer then
            if not DoesEntityExist(activeOffer.driver) then
                clearActiveOffer(false); Wait(500)
            elseif GetGameTimer() >= activeOffer.expiresAt then
                clearActiveOffer(false); Wait(500)
            else
                local self = PlayerPedId()
                local pCoords = GetEntityCoords(self)
                local targetEnt = (activeOffer.kind == 'car' and activeOffer.veh and DoesEntityExist(activeOffer.veh)) and activeOffer.veh or activeOffer.driver
                local dist = #(pCoords - GetEntityCoords(targetEnt))

                if dist <= Config.Offer.claimRadius and not activeOffer.claimed then
                    activeOffer.claimed = true
                    if loadDict('mp_common', 1200) then
                        TaskPlayAnim(activeOffer.driver, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 49, 0, false, false, false)
                    end
                    PlayAmbientSpeech1(activeOffer.driver, pick(Config.GiveSpeeches), 'SPEECH_PARAMS_FORCE_NORMAL_CLEAR')

                    local amount, generous, sourceTag
                    if activeOffer.payoutOverride then
                        amount    = activeOffer.payoutOverride
                        generous  = true
                        sourceTag = 'limo_nice'
                    else
                        local tierName
                        amount, generous, tierName = payoutAmount()
                        if     tierName == 'sign_and_box' then sourceTag = 'sign_box'
                        elseif tierName == 'box_only'     then sourceTag = 'box_only'
                        else   sourceTag = activeOffer.kind == 'ped' and 'ped' or 'driver'
                        end
                    end
                    TriggerServerEvent('umw:beg:reward', amount, generous, sourceTag)
                    subtitle(activeOffer.payoutOverride and 'limo_collect' or (generous and 'give_generous' or (activeOffer.kind == 'ped' and 'ped_give' or 'give')))

                    Wait(1500)
                    clearActiveOffer(true)

                    if begging then
                        if begOrigin then
                            walkBackToOrigin()
                            -- Poll until back at spot (max 35s)
                            local arriveBy = GetGameTimer() + 35000
                            while begging and not activeOffer and GetGameTimer() < arriveBy do
                                if #(GetEntityCoords(PlayerPedId()) - begOrigin) <= 2.0 then break end
                                Wait(400)
                            end
                            if begging then
                                resetCurrentAnim(begHeading)
                            end
                        else
                            resetCurrentAnim()
                        end
                    end
                end

                if dist <= 8.0 then Wait(100) else Wait(500) end
            end
        else
            Wait(1000)
        end
    end
end)

-- ---- Animation guard -----------------------------------------------------

CreateThread(function()
    while true do
        if begging and activeVariant and not activeOffer and not buskingActive then
            if not IsPedInAnyVehicle(PlayerPedId(), false) and not isVariantPlaying(activeVariant) then
                playVariant(activeVariant)
            end
            Wait(3000)
        else
            Wait(5000)
        end
    end
end)

-- ---- X press = stop begging (don't let game cancel the anim silently) ----

CreateThread(function()
    while true do
        if begging then
            -- 73 = INPUT_VEH_DUCK / X on foot also context-cancel
            if IsControlJustPressed(0, 73) then
                stopBeg()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ============================================================================
-- Begging Box — 3-D placement preview, pickup zone, passive audience thread
-- ============================================================================

local function createBoxPickupZone()
    if not activeBox or not DoesEntityExist(activeBox.prop) then return end
    if boxPickupZone then boxPickupZone:remove(); boxPickupZone = nil end
    boxPickupZone = lib.zones.sphere({
        coords  = GetEntityCoords(activeBox.prop),
        radius  = 2.0,
        debug   = false,
        onEnter = function() lib.showTextUI('[E] Pick Up Box') end,
        onExit  = function() lib.hideTextUI() end,
        inside  = function()
            if not IsControlJustPressed(0, 38) then return end
            if buskingActive then
                lib.notify({ type = 'error', description = "Can't pick up the box while busking.", duration = 3000 })
                return
            end
            lib.hideTextUI()
            if boxPickupZone then boxPickupZone:remove(); boxPickupZone = nil end
            if activeBox and DoesEntityExist(activeBox.prop) then
                SetEntityAsMissionEntity(activeBox.prop, true, true)
                DeleteObject(activeBox.prop)
            end
            activeBox = nil
            lib.notify({ type = 'inform', description = 'You packed up the box.', duration = 3000 })
        end,
    })
end

--- Per-frame placement preview. Runs as its own coroutine from the item-use handler.
local function startBoxPlacement()
    if placingBox then return end
    if activeBox and DoesEntityExist(activeBox.prop) then
        lib.notify({ type = 'error', description = 'You already have a box placed. Pick it up first.', duration = 4000 })
        return
    end

    placingBox = true
    local boxHash = loadModel(Config.BeggingBox.model, 3000)
    if not boxHash then placingBox = false; return end

    -- Transparent ghost prop
    local ghost = CreateObject(boxHash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(ghost, 150, false)
    SetEntityCollision(ghost, false, false)
    SetEntityAsMissionEntity(ghost, true, true)

    lib.showTextUI('[E] Place   [BACKSPACE] Cancel')

    while placingBox do
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local fwd    = GetEntityForwardVector(ped)
        local px     = coords.x + fwd.x * Config.BeggingBox.placeOffset
        local py     = coords.y + fwd.y * Config.BeggingBox.placeOffset
        local _, gz  = GetGroundZFor_3dCoord(px, py, coords.z + 3.0, false)
        local pz     = gz or coords.z

        SetEntityCoords(ghost, px, py, pz, false, false, false, false)
        PlaceObjectOnGroundProperly(ghost)

        -- Green circle marker on the ground
        DrawMarker(25, px, py, pz + 0.04, 0,0,0, 0,0,0, 0.8, 0.8, 0.12,
            0, 200, 100, 160, false, false, 2, false, nil, nil, false)

        if IsControlJustPressed(0, 38) then        -- E — confirm
            lib.hideTextUI()
            SetEntityAsMissionEntity(ghost, true, true)
            DeleteObject(ghost)
            SetModelAsNoLongerNeeded(boxHash)
            local cx, cy, cz = px, py, pz
            placingBox = false

            local done = lib.progressBar({
                duration     = 2000,
                label        = 'Placing the box...',
                canCancel    = true,
                disable      = { move = true, car = true, combat = true },
                anim         = { dict = 'random@domestic', clip = 'pickup_low', flag = 49 },
            })

            if done then
                local bm = loadModel(Config.BeggingBox.model, 3000)
                if bm then
                    local prop = CreateObject(bm, cx, cy, cz, true, true, false)
                    PlaceObjectOnGroundProperly(prop)
                    Wait(200)
                    FreezeEntityPosition(prop, true)
                    SetEntityAsMissionEntity(prop, true, true)
                    SetModelAsNoLongerNeeded(bm)
                    activeBox = { prop = prop, coords = GetEntityCoords(prop) }
                    createBoxPickupZone()
                    lib.notify({ type = 'success', description = 'Box placed! Beg or busk nearby for a boost.', duration = 4000 })
                end
            end
            return

        elseif IsControlJustPressed(0, 177) then   -- Backspace — cancel
            lib.hideTextUI()
            SetEntityAsMissionEntity(ghost, true, true)
            DeleteObject(ghost)
            SetModelAsNoLongerNeeded(boxHash)
            placingBox = false
            return
        end

        Wait(0)
    end
end

-- Passive audience thread — fires only in box-only mode (no sign, no guitar)
CreateThread(function()
    while true do
        if activeBox and DoesEntityExist(activeBox.prop) and not begging and not buskingActive then
            local boxCoords = GetEntityCoords(activeBox.prop)
            -- Nearest pedestrian within 15 m
            local closestPed, closestDist = nil, 15.0
            for _, p in ipairs(GetGamePool('CPed')) do
                if DoesEntityExist(p) and not IsPedAPlayer(p) and not IsEntityDead(p)
                   and not IsPedInAnyVehicle(p, false) then
                    local d = #(GetEntityCoords(p) - boxCoords)
                    if d < closestDist then closestPed = p; closestDist = d end
                end
            end

            if closestPed then
                SetEntityAsMissionEntity(closestPed, true, true)
                SetBlockingOfNonTemporaryEvents(closestPed, true)
                TaskGoToCoordAnyMeans(closestPed, boxCoords.x, boxCoords.y, boxCoords.z, 1.2, 0, false, 1, 0.0)
                local deadline = GetGameTimer() + 10000
                while GetGameTimer() < deadline and activeBox and DoesEntityExist(activeBox.prop) and not begging and not buskingActive do
                    if #(GetEntityCoords(closestPed) - boxCoords) < 2.0 then break end
                    Wait(400)
                end
                if activeBox and DoesEntityExist(closestPed) and not begging and not buskingActive then
                    ClearPedTasks(closestPed)
                    Wait(1200)
                    local tcfg = Config.PayoutTiers.box_only
                    local generous = math.random(100) <= tcfg.generousChance
                    local amount   = generous
                        and math.random(tcfg.generousMin, tcfg.generousMax)
                        or  math.random(tcfg.min, tcfg.max)
                    if activeBox then
                        TriggerServerEvent('umw:beg:reward', amount, generous, 'box_only')
                        subtitle(generous and 'give_generous' or 'give')
                    end
                end
                SetEntityAsNoLongerNeeded(closestPed)
                SetBlockingOfNonTemporaryEvents(closestPed, false)
            end
            Wait(Config.BeggingBox.audienceIntervalMs)
        else
            Wait(5000)
        end
    end
end)

-- ============================================================================
-- Busking — guitar progress bar (up to 2 min), requires box nearby
-- ============================================================================

RegisterNetEvent('um_beg:startBusking')
AddEventHandler('um_beg:startBusking', function()
    if buskingActive then return end
    local gcfg = Config.Guitar

    -- Box proximity check
    if gcfg.requireBox then
        if not activeBox or not DoesEntityExist(activeBox.prop) then
            lib.notify({ type = 'error', description = 'Place your begging box nearby first.', duration = 4000 })
            return
        end
        if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(activeBox.prop)) > gcfg.boxRange then
            lib.notify({ type = 'error', description = 'Get closer to your box to start busking.', duration = 4000 })
            return
        end
    end

    if IsPedInAnyVehicle(PlayerPedId(), false) then
        lib.notify({ type = 'error', description = "Can't busk from a vehicle.", duration = 4000 })
        return
    end

    local ped = PlayerPedId()

    -- Attach guitar prop
    local gh = loadModel(gcfg.model, 3000)
    if not gh then return end
    local gc = GetEntityCoords(ped)
    buskingProp = CreateObject(gh, gc.x, gc.y, gc.z, true, true, false)
    AttachEntityToEntity(
        buskingProp, ped, GetPedBoneIndex(ped, gcfg.bone),
        gcfg.boneOffset.x, gcfg.boneOffset.y, gcfg.boneOffset.z,
        gcfg.boneRotation.x, gcfg.boneRotation.y, gcfg.boneRotation.z,
        true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(gh)

    -- Start guitar animation
    if loadDict(gcfg.animDict, 2000) then
        TaskPlayAnim(ped, gcfg.animDict, gcfg.animClip, 5.0, -1, -1, 51, 0, false, false, false)
    end

    buskingActive = true

    -- 2-minute progress bar
    local done = lib.progressBar({
        duration     = gcfg.durationMs,
        label        = 'Busking...',
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true, sprint = true },
    })

    -- Clean up regardless of whether cancelled
    buskingActive = false
    StopAnimTask(ped, gcfg.animDict, gcfg.animClip, 3.0)
    if buskingProp and DoesEntityExist(buskingProp) then
        DetachEntity(buskingProp, false, false)
        DeleteObject(buskingProp)
        buskingProp = nil
    end

    if done then
        local tcfg    = Config.PayoutTiers.box_and_guitar
        local generous = math.random(100) <= tcfg.generousChance
        local amount   = generous
            and math.random(tcfg.generousMin, tcfg.generousMax)
            or  math.random(tcfg.min, tcfg.max)
        TriggerServerEvent('umw:beg:reward', amount, generous, 'busking')
        subtitle(generous and 'give_generous' or 'give')
    else
        lib.notify({ type = 'inform', description = 'You stopped busking.', duration = 3000 })
    end
end)

-- Item use → start 3D placement preview
RegisterNetEvent('um_beg:placeBox')
AddEventHandler('um_beg:placeBox', function()
    Wait(200)   -- let inventory close first
    startBoxPlacement()
end)

-- ---- Commands & cleanup --------------------------------------------------

-- /beg command (works with or without ox_inventory)
RegisterCommand('beg', function()
    if begging then stopBeg() else startBeg() end
end, false)
TriggerEvent('chat:addSuggestion', '/beg', 'Toggle begging at the side of the road')

-- ox_inventory item use → same as /beg
-- AddEventHandler catches both local (client.event) and network triggers.
-- We Wait a tick so the inventory NUI finishes closing before startBeg() runs —
-- GTA suppresses native subtitle rendering while NUI has focus.
RegisterNetEvent('um_beg:useSign')
AddEventHandler('um_beg:useSign', function()
    if begging then
        stopBeg()
    else
        Wait(200)
        startBeg()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearProp(); clearActiveOffer(false); clearActiveCop(); clearActiveLimo(); clearActiveMugger()
    if buskingActive then lib.cancelProgress() end
    if buskingProp and DoesEntityExist(buskingProp) then DeleteObject(buskingProp) end
    if activeBox   and DoesEntityExist(activeBox.prop) then
        SetEntityAsMissionEntity(activeBox.prop, true, true)
        DeleteObject(activeBox.prop)
    end
    if boxPickupZone then boxPickupZone:remove() end
end)

AddEventHandler('baseevents:onPlayerDying', function() stopBeg() end)
AddEventHandler('baseevents:onPlayerKilled', function() stopBeg() end)

-- ============================================================================
-- Crafting zones
-- Reads Config.CraftingBenches. Walk to any spot, press E, wait for the bar.
-- ============================================================================

local craftingBusy = false

-- Result callback from server
RegisterNetEvent('um_beg:craftResult', function(success, msg)
    lib.notify({ type = success and 'success' or 'error', description = msg, duration = 4000 })
end)

CreateThread(function()
    -- Only set up zones when ox_inventory crafting is enabled
    if not Config.UseOxInventory then return end
    if not (Config.Craft and Config.Craft.enabled) then return end
    if not (Config.CraftingBenches and #Config.CraftingBenches > 0) then return end

    -- Small delay to ensure ox_lib zones are ready
    Wait(1500)

    for _, bench in ipairs(Config.CraftingBenches) do
        lib.zones.sphere({
            coords  = bench.coords,
            radius  = bench.radius or 2.5,
            debug   = false,

            onEnter = function()
                lib.showTextUI('[E] Craft Cardboard Sign\n~s~' .. (bench.label or ''))
            end,

            onExit  = function()
                lib.hideTextUI()
                -- Cancel any in-progress craft if player walks out mid-bar
                craftingBusy = false
            end,

            inside  = function()
                if craftingBusy then return end
                if not IsControlJustPressed(0, 38) then return end  -- E key

                craftingBusy = true

                -- Fast client-side ingredient check so we give instant feedback
                local okB, boxes   = pcall(function() return exports.ox_inventory:Search('count', Config.Craft.boxItem)    end)
                local okM, markers = pcall(function() return exports.ox_inventory:Search('count', Config.Craft.markerItem) end)

                if not okB or (boxes or 0) < 1 then
                    lib.notify({ type = 'error', description = ('You need a %s.'):format(Config.Craft.boxItem), duration = 4000 })
                    craftingBusy = false
                    return
                end
                if not okM or (markers or 0) < 1 then
                    lib.notify({ type = 'error', description = ('You need a %s.'):format(Config.Craft.markerItem), duration = 4000 })
                    craftingBusy = false
                    return
                end

                -- Progress bar — looks and feels like a crafting bench
                local done = lib.progressBar({
                    duration     = Config.Craft.duration or 5000,
                    label        = 'Scrawling on cardboard...',
                    useWhileDead = false,
                    canCancel    = true,
                    disable      = { move = true, car = true, combat = true, sprint = true },
                    anim         = { dict = 'anim@heists@ornate_bank@hack', clip = 'hack_loop', flag = 49 },
                })

                if done then
                    TriggerServerEvent('um_beg:craftSign')
                    -- Result arrives via 'um_beg:craftResult' net event above
                end

                craftingBusy = false
            end,
        })
    end
end)
