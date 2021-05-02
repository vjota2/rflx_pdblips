fx_version 'cerulean'
game 'gta5'

author 'Vojtíík#0016'

client_scripts {
    'config.lua',
    'client.lua'
}

server_scripts {
	'@mysql-async/lib/MySQL.lua',
    'config.lua',
    'server.lua'
}

exports {
    'goOnDuty',
    'goOffDuty'
}