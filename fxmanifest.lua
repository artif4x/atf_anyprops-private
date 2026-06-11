fx_version 'cerulean'
game 'gta5'

author 'Artif4x'
description 'Hold and Place any props for Qbox'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/server.lua'
}

dependencies {
    'qbx_core',
    'ox_inventory',
    'ox_lib'
}