fx_version 'cerulean'
game 'gta5'

name 'offense-defense'
description 'Offense Defense - Runners vs Blockers'
version '0.3.0'

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
    'server/*.lua'
}

client_scripts {
    'client/main.lua',
    'client/editor.lua'
}
