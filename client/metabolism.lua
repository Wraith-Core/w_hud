-- ════════════════════════════════════════════════════════════════════════════
-- w_hud -- player lifecycle + language handover to the UI (client) -- via w_lib
--   * Sets LocalPlayer.state.isLoggedIn on every framework (rsg-core used to be the
--     only one setting it), so the HUD gates in thread.lua work on VORP/RSG/QBR.
--   * Asks the server to load the metabolism values when the character loads.
--   * Hands the React UI its strings and text direction, and again on every switch.
-- NOTE: hunger/thirst values arrive through the existing HUD events (UpdateNeeds)
--   broadcast by server/metabolism.lua -- so hunger/thirst update exactly as before.
-- ════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════
-- Language
--
-- The library owns the key (w.getLocaleKey: the player's choice or the server convar).
-- The page never carries a string of its own: it renders from the `ui.*` section of
-- locales/{ar,en}.json, sent here with the direction, on init and on every switch.
-- ════════════════════════════════════════════════════════════════════════════

--- The `ui.*` entries of the loaded dictionary, without the prefix.
---@return table<string, string>
local function uiStrings()
    local out = {}

    for key, value in pairs(w.getLocales() or {}) do
        if key:sub(1, 3) == 'ui.' then out[key:sub(4)] = value end
    end

    return out
end

local function sendLocale()
    local key = WHudLocale.key()

    SendNUIMessage({
        action  = 'setLocale',
        locale  = key,
        dir     = WHudLocale.rtl() and 'rtl' or 'ltr',
        strings = uiStrings(),
    })
end

-- Top-right info: server name (sv_projectName) + player id + location (optional)
local function sendServerInfo()
    SendNUIMessage({
        action = 'setServerInfo',
        name = GetConvar('w_hud_name', GetConvar('sv_projectName', 'REDM RP')),
        id = GetPlayerServerId(PlayerId()),
    })
    local loc = GetConvar('w_hud_location', '')
    if loc ~= '' then SendNUIMessage({ action = 'setLocation', location = loc }) end
end

-- The page announces itself once React has mounted: answer with the language and the
-- server identity so the first frame is already in the right language.
RegisterNUICallback('w_hud:ready', function(_, cb)
    cb({ ok = true })
    sendLocale()
    sendServerInfo()
    TriggerEvent('w_hud:client:pageReady') -- framework.lua pushes the level (w_level's state bag)
end)

-- A live switch from /w_lib: reload our dictionary first (the library's own handler may
-- run after ours), then re-send every text that was built from it.
AddEventHandler('w_lib:setLocale', function(key)
    w.locale(WHudLocale.normalise(key)) -- ar or en; anything else the library reports is en
    sendLocale()
    TriggerEvent('w_hud:client:refreshDisplay') -- buff labels (client/needs.lua)
end)

local charLoaded = false
local function onLoaded()
    if charLoaded then return end   -- guard against a double call (event + server probe)
    charLoaded = true
    LocalPlayer.state:set('isLoggedIn', true, true)
    TriggerServerEvent('w_hud:server:load')
    -- Re-announce language/direction + server info to the UI after character selection
    sendLocale()
    sendServerInfo()
end

local function onLogout()
    charLoaded = false
    LocalPlayer.state:set('isLoggedIn', false, true)
end

-- Character-load events for every framework
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', onLoaded)      -- RSG
RegisterNetEvent('qbr-core:client:OnPlayerLoaded', onLoaded)     -- QBR
RegisterNetEvent('vorp:SelectedCharacter', onLoaded)            -- VORP
RegisterNetEvent('vorp:selectedCharacter', onLoaded)           -- VORP (alternate spelling)
-- The server pushes this after a live resource restart (no selection event is replayed)
RegisterNetEvent('w_hud:client:forceLoaded', onLoaded)

-- Logout events
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', onLogout)
RegisterNetEvent('qbr-core:client:OnPlayerUnload', onLogout)
RegisterNetEvent('vorp:playerUnloaded', onLogout)

-- w_lib's framework bridge -- covers whatever framework the library supports
w.ready(function()
    pcall(function() w.framework:onCharacterSelected(onLoaded) end)
end)

-- Fallback for a live resource restart: ask the server (the authority) whether a
-- character really is selected. It will not light the HUD on the character-selection
-- screen, because the server has no character loaded yet either.
CreateThread(function()
    -- One attempt is not enough: after a restart the w_lib callback machinery may not
    -- be ready on the client 1500ms in, so the probe fails silently and the HUD stays
    -- dead until the player relogs. Retry within a bounded window.
    local deadline = GetGameTimer() + 30000

    while not charLoaded and GetGameTimer() < deadline do
        Wait(1000)

        local ok, loaded = pcall(function()
            return w.callback.await('w_hud:server:isCharLoaded', false)
        end)

        if ok and loaded then
            onLoaded()
            return
        end
    end
end)

-- ★ The top-right panel and PVP state moved to client/framework.lua, where their
--   RSG counterparts (SetPlayerData and PvpHasToggled) sit right beside them.
--   This file is for the character lifecycle alone.

-- A safety re-send for a page that mounted before this script registered the callback
CreateThread(function()
    Wait(600)
    sendLocale()
end)
