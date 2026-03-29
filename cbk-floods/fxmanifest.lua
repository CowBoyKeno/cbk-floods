fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'cbk-floods'
author 'CowBoyKeno'
description 'A flood event resource for FiveM RP servers'
version '1.0.0'

ui_page 'ui/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config/*.lua',
    'shared/*.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/*.lua'
}

files {
    'ui/index.html',
    'ui/app.js',
    'ui/style.css',
    'water.xml'
}

dependencies {
    '/onesync',
    'ox_lib'
}
