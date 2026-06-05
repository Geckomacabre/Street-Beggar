fx_version 'cerulean'
game      'gta5'

name        'um_hobos'
author      'Upstate Mafia'
description 'Hobo Tough Life — job-locked street survival & begging resource for Qbox/QBX'
version     '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'data/loot_tables.lua',
    'data/skill_rewards.lua',
    'data/shelter_pieces.lua',
}

client_scripts {
    'client/job.lua',           -- job check, duty toggle, clothing
    'client/progression.lua',   -- XP, ranks, skill helpers
    'client/hud.lua',           -- NUI bridge
    'client/needs.lua',         -- hunger/thirst/hygiene/energy/morale
    'client/scavenging.lua',    -- dumpster/trash-pile loot
    'client/shelter.lua',       -- shelter placement, sleep, storage
    'client/main.lua',          -- commands, ox_lib menus, init
    'client/pickpocket.lua',    -- pickpocket minigame
    'client/washing.lua',       -- windshield washing
    'client/payphone.lua',      -- payphone loose change
    'client/collecting.lua',    -- can / bottle collecting
    'client/oddjobs.lua',       -- odd jobs board
    'client/campfire.lua',      -- campfire placement & cooking
    'client/fence.lua',         -- stolen goods fence
    'client/worldinteractions.lua', -- porta potty, dumpster hide, chairs, toilets, vending, meters
    'client/church.lua',            -- Sister Agnes — better jobs + free meal
    'client/onboarding.lua',        -- intro mission chain (Pete → Agnes)
    'client/client.lua',        -- begging / busking / limo / cop
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',      -- oxmysql helpers
    'server/main.lua',          -- hobo-job server events
    'server/server.lua',        -- existing begging reward / crafting events
    'server/worldinteractions.lua', -- porta potty, dumpster hide, chairs, toilets, vending, meters
    'server/church.lua',            -- Sister Agnes — better jobs + free meal
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'locales/en.json',
}

lua54 'yes'
