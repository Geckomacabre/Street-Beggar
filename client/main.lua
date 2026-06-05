-- ============================================================================
-- client/main.lua
-- Commands, ox_lib menus, and general initialisation.
-- All heavy mechanics live in their own files; this is just the entry layer.
-- ============================================================================

-- ============================================================================
-- /hobo — main menu
-- ============================================================================

local function openHoboMenu()
    if not isOnHoboJob() then
        lib.notify({ type = 'error', description = Lang.not_on_duty, duration = 3000 })
        return
    end

    local prog = GetProgData()
    local rank = GetRank()

    lib.registerContext({
        id    = 'hobo_main_menu',
        title = Lang.menu_title,
        options = {
            {
                title       = Lang.menu_status,
                description = string.format(Lang.menu_rank, GetRankName(rank), rank)
                              .. '\n' .. string.format(Lang.menu_xp, GetXP(), GetXPForNextRank(rank)),
                icon        = 'fas fa-id-card',
                disabled    = true,
            },
            {
                title    = 'Skills',
                icon     = 'fas fa-chart-bar',
                onSelect = function()
                    local skillLines = {}
                    for _, skill in ipairs(Config.Skills) do
                        local level = GetSkill(skill)
                        table.insert(skillLines, {
                            title       = skill:gsub('^%l', string.upper),
                            description = ('Level %d / %d'):format(level, Config.MaxSkillLevel),
                            disabled    = true,
                        })
                    end
                    lib.registerContext({ id = 'hobo_skills', title = 'Skills', options = skillLines, menu = 'hobo_main_menu' })
                    lib.showContext('hobo_skills')
                end,
            },
            {
                title    = 'Build / Manage Shelter',
                icon     = 'fas fa-home',
                onSelect = OpenShelterMenu,
            },
            {
                title    = Lang.menu_craft,
                icon     = 'fas fa-hammer',
                onSelect = openCraftMenu,
            },
            {
                title    = Lang.menu_clothing,
                icon     = 'fas fa-tshirt',
                onSelect = openClothingMenu,
            },
            {
                title    = Lang.menu_duty,
                icon     = 'fas fa-sign-out-alt',
                onSelect = function()
                    TriggerEvent('um_hobos:offDuty')
                    TriggerServerEvent('um_hobos:setDuty', false)
                end,
            },
        },
    })
    lib.showContext('hobo_main_menu')
end

RegisterCommand('hobo', openHoboMenu, false)
TriggerEvent('chat:addSuggestion', '/hobo', 'Open the Hobo Life menu (requires hobo job)')

-- ============================================================================
-- /hobostatus
-- ============================================================================

RegisterCommand('hobostatus', function()
    if not isOnHoboJob() then
        lib.notify({ type = 'error', description = Lang.not_on_duty, duration = 3000 })
        return
    end
    local rank = GetRank()
    local xp   = GetXP()
    local next = GetXPForNextRank(rank)
    local lines = {
        ('~y~Rank:~s~ %d — %s'):format(rank, GetRankName(rank)),
        ('~y~XP:~s~ %d / %d'):format(xp, next),
    }
    for _, skill in ipairs(Config.Skills) do
        table.insert(lines, ('~y~%s:~s~ %d'):format(skill:gsub('^%l', string.upper), GetSkill(skill)))
    end
    for _, line in ipairs(lines) do
        BeginTextCommandPrint('STRING')
        AddTextComponentSubstringPlayerName(line)
        EndTextCommandPrint(5000, false)
    end
end, false)
TriggerEvent('chat:addSuggestion', '/hobostatus', 'Show your hobo rank, XP, and skills')

-- ============================================================================
-- /hoboduty  — toggle from anywhere (as a fallback to the location zones)
-- ============================================================================

RegisterCommand('hoboduty', function()
    TriggerEvent('um_hobos:dutyToggleRequest')
end, false)
TriggerEvent('chat:addSuggestion', '/hoboduty', 'Toggle on/off duty at a hobo camp')

-- ============================================================================
-- Hobo crafting menu
-- ============================================================================

function openCraftMenu()
    if not isOnHoboJob() then
        lib.notify({ type = 'error', description = Lang.not_on_duty, duration = 3000 })
        return
    end

    local options = {}
    for _, recipe in ipairs(Config.HoboCrafting) do
        local reqs = {}
        for _, r in ipairs(recipe.requires) do
            table.insert(reqs, r.count .. 'x ' .. r.item)
        end
        local reqStr = #reqs > 0 and table.concat(reqs, ', ') or 'Free'
        table.insert(options, {
            title       = recipe.label,
            description = 'Needs: ' .. reqStr .. '  |  +' .. recipe.xp .. ' XP',
            onSelect    = function()
                TriggerServerEvent('um_hobos:craftHoboItem', recipe.label)
            end,
        })
    end

    lib.registerContext({ id = 'hobo_craft_menu', title = Lang.craft_title, options = options, menu = 'hobo_main_menu' })
    lib.showContext('hobo_craft_menu')
end

RegisterCommand('crafthobo', openCraftMenu, false)
TriggerEvent('chat:addSuggestion', '/crafthobo', 'Open the hobo crafting menu')

-- Craft result notification
RegisterNetEvent('um_hobos:client:craftResult', function(success, msg, xp)
    if success then
        lib.notify({ type = 'success', description = msg, duration = 4000 })
        if xp and xp > 0 then GainXP(xp, 'craft') end
    else
        lib.notify({ type = 'error', description = msg, duration = 4000 })
    end
end)

-- ============================================================================
-- Clothing menu
-- ============================================================================

function openClothingMenu()
    if not isOnHoboJob() then return end
    local options = {}
    for i, outfit in ipairs(Config.HoboOutfits) do
        local idx = i
        table.insert(options, {
            title    = outfit.name,
            onSelect = function()
                -- Apply outfit components
                local ped = PlayerPedId()
                for _, comp in ipairs(outfit.components) do
                    SetPedComponentVariation(ped, comp.comp, comp.drawable, comp.texture, 2)
                end
                lib.notify({ type = 'success', description = 'Outfit changed.', duration = 3000 })
            end,
        })
    end
    lib.registerContext({ id = 'hobo_clothing_menu', title = 'Change Outfit', options = options, menu = 'hobo_main_menu' })
    lib.showContext('hobo_clothing_menu')
end

-- ============================================================================
-- Guard the existing /beg command with a job check
-- (client.lua registers it; we just intercept if the player isn't on duty)
-- ============================================================================

-- The check is done inside client.lua's command/event handlers by calling
-- isOnHoboJob() which is defined in job.lua (loaded first).
