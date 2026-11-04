fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
description "Red River HUD"
version '2.1.5'

shared_scripts {
    '@w_lib/init.lua',      -- our unified library: w (== lib) / cache / w.callback / w.framework / exports.w_lib
    'shared/config.lua',
    'shared/needs.lua',       -- after config.lua: buffs, voice, horse care, thresholds, display
    'shared/consumables.lua', -- after needs.lua: the curated table of catalog food, drink, medicine, and horse care
    'shared/use_profiles.lua',
    'shared/use_rules.lua',
    'shared/animal_profiles.lua',
    'shared/satchels.lua',    -- after config.lua: satchel tiers and their carry bonus
    'shared/wheel.lua',       -- after config.lua: the weapon wheel (its strings come from the dictionary)
    'shared/settings_schema.lua', -- LAST: the live settings (w_admin) land on the final Config
}

-- The admin console (w_admin) finds the live settings by this line; w_lib's w.settings module
-- registers WSettingsSchema / WSettingsValues / WSettingsApply (shared/settings_schema.lua).
w_settings 'yes'

-- Modules loaded at start: the dictionary (locales/{ar,en}.json, the language the library
-- decides) and the callback wire both sides use immediately.
w_lib { 'locale', 'callback' }

client_scripts {
    'client/*.lua',
}

server_scripts {
    -- ⚠️ oxmysql first, not last. It used to sit below the glob, so MySQL simply did
    --    not exist while our own files were being read -- and any file touching it at
    --    load time died on the spot. metabolism.lua survived only because its table
    --    creation happens inside a CreateThread, which runs after everything is loaded.
    --    That is a trap, not a pattern: the order below removes it.
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

dependencies {
    'w_lib',
    'oxmysql',
}

-- React UI in the original design + the w_crafting theme (red/white/black + RDR fonts + RTL).
-- Any change here needs: refresh, then restart w_hud.
ui_page 'web/build/index.html'

files {
    -- the two languages the server runs in; the library loads them
    'locales/*.json',
    -- the built React UI (a broad, reliable pattern -- same as w_crafting)
    'web/build/index.html',
    'web/build/**/*',
}

lua54 'yes'
