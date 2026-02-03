fx_version 'cerulean'
game 'gta5'

name 'offense-defense'
description 'Offense Defense - Runners vs Blockers'
version '0.4.0'

dependency 'oxmysql'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'maps/*.json'
}

shared_scripts {
    'config.lua',
    'shared/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

client_scripts {
    'client/main.lua',
    'client/editor.lua'
}
