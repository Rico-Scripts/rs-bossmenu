fx_version 'cerulean'
game 'gta5'

author 'Rico Scripts'
description 'RS Boss Menu - ESX Legacy company management'
version '1.0.1'

lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@rs_discordlogs/server/intercept.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/app.js',
    'html/style.css'
}

dependencies {
    'es_extended',
    'ox_lib',
    'oxmysql',
    'rs_discordlogs'
}
