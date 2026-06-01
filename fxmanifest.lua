fx_version 'cerulean'
game 'gta5'

name 'um_beg'
description 'Beg at car windows for spare change'
author 'Upstate Mafia'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
}
