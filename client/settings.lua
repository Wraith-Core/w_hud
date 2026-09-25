-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · client/settings.lua
-- The player's own HUD -- where every piece sits, how large it is and what colour.
--
-- ═══ What this file is, and what it is not ═══
--
--   It is a courier and a keyring. The layout itself lives in the UI (web/src/settings),
--   because that is where the pixels are and moving a circle with the mouse is not a
--   thing Lua can do well or at all. What Lua owns is the two things the browser cannot:
--   the key that opens the panel, and making the result survive a disconnect.
--
-- ═══ Two stores, deliberately ═══
--
--   · SetResourceKvp -- on this machine, read the instant the character loads.
--   · the database   -- against the character identifier, read a moment later.
--
--   The KVP is not a cache for the database's sake, it is for the player's: a round trip
--   to the server takes a second or two on a full server, and a HUD that assembles itself
--   in front of you every time you log in looks broken even though it is working. The
--   local copy paints the right layout on the first frame, and the server's answer
--   replaces it -- which is what makes the layout follow you to another machine.
--
--   ⚠️ The server wins on conflict, always. The KVP is the faster answer, not the truer
--      one: a player who rearranged their HUD on a friend's PC must find it rearranged
--      when they come home, not reverted by whatever their own machine remembered.
-- ════════════════════════════════════════════════════════════════════════════

local KVP = 'w_hud:layout'

-- ════════════════════════════════════════════════════════════════════════════
-- The server's half of the settings
--
-- ★ Two owners, one panel. What a player may change is their own layout and colours;
--   what the server decides -- the name in the corner, the logo, how fast hunger falls,
--   which parts of the HUD exist at all -- arrives from server/admin.lua and is the
--   same for everyone.
--
-- ⚠️ WHudSrv is read by client/thread.lua's damage loop on every tick, so it is a global
--   rather than a local: that file loads after this one and needs the live table, not a
--   copy taken at load time.
-- ════════════════════════════════════════════════════════════════════════════

WHudSrv = nil        -- the server's settings, once they have arrived
WHudIsAdmin = false  -- whether *this* player may edit them

--- The settings as the UI last saw them. nil = never loaded (the UI keeps its defaults).
local Settings = nil
local menuOpen = false

-- ════════════════════════════════════════════════════════════════════════════
-- Helpers
-- ════════════════════════════════════════════════════════════════════════════

--- ⚠️ Everything that comes back from a store goes through here. json.decode raises on
--- malformed input, and a settings blob truncated by a disk full or an old build would
--- otherwise take the whole file down at login -- with no HUD as the visible symptom.
---@param raw any
---@return table|nil
local function decode(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end

    local ok, data = pcall(json.decode, raw)
    return (ok and type(data) == 'table') and data or nil
end

--- Where the RDR menu tones live.
---
--- ★ We duplicate no audio: the set belongs to no single resource -- w_inventory and
---   w_crafting both carry it -- and nui:// reads from any resource that declares its
---   files. So we take the first that is running, exactly as the weapon wheel does, and
---   the list itself lives in shared/wheel.lua rather than being written twice.
---
--- ⚠️ Silence is an acceptable answer. A panel without a tone is a panel; a panel that
---   refuses to open because an unrelated resource is stopped is a fault.
---@return string|nil
local function soundBase()
    local list = (Wheel and Wheel.SoundSources) or {}

    for i = 1, #list do
        local entry = list[i]
        if entry and GetResourceState(entry.resource) == 'started' then return entry.path end
    end
end

--- Whether a feature the admin switched off is off. Absent settings mean everything is
--- on, which is the right answer while they are still on their way.
---@param key string
---@return boolean
local function featureOn(key)
    local features = WHudSrv and WHudSrv.features
    if type(features) ~= 'table' then return true end
    return features[key] ~= false
end

--- Hand the UI what we have. `open` also opens the panel in the same message, so the
--- first open after a login cannot show the defaults for a frame before the real values.
---@param open boolean|nil
local function pushToUi(open)
    SendNUIMessage({
        action = 'hud:settings',
        settings = Settings or {},
        sounds = soundBase(),
        open = open == true,
    })
end

-- ════════════════════════════════════════════════════════════════════════════
-- Loading
-- ════════════════════════════════════════════════════════════════════════════

local function load()
    -- 1. the local copy -- immediate, so the HUD is never assembled in front of the player
    local local_ = decode(GetResourceKvpString(KVP))

    if local_ then
        Settings = local_
        pushToUi(false)
    end

    -- 2. the server's own settings, and whether this player may edit them
    if w and w.callback then
        w.callback.triggerServer('w_hud:server:bootstrap', function(res)
            if type(res) ~= 'table' then return end

            WHudSrv = res.cfg
            WHudIsAdmin = res.isAdmin == true

            SendNUIMessage({ action = 'hud:server', cfg = res.cfg, isAdmin = WHudIsAdmin })
        end)
    end

    -- 3. the character's copy -- authoritative, and it follows them to any machine
    if not (w and w.callback) then return end

    w.callback.triggerServer('w_hud:settings:get', function(data)
        if type(data) ~= 'table' then return end

        Settings = data

        local encoded = json.encode(data)
        if type(encoded) == 'string' then SetResourceKvp(KVP, encoded) end

        pushToUi(false)
    end)
end

-- ★ Three doors into the same room. A player arrives by whichever their framework uses,
--   and load() is safe to run more than once -- the second run is the same two reads.
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(500) end
    Wait(1200)   -- after the UI has mounted and after sendDisplay in client/needs.lua
    load()
end)

--- ⚠️ Through a thread, not straight from the handler: the login events fire while the
--- character is still being assembled, and asking the server for a layout before it has a
--- character identifier to look it up by gets nil back -- with the player's whole layout
--- as the casualty. The delay is the same one client/needs.lua waits on revive, for the
--- same reason. (It is also what keeps a Wait out of an event handler.)
local function loadSoon()
    CreateThread(function()
        Wait(1500)
        load()
    end)
end

RegisterNetEvent('vorp:SelectedCharacter', loadSoon)
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', loadSoon)

--- ★ Pushed to everyone the moment an admin saves, not on the next login. A feature
---   switched off has to leave every screen at once; a player who must reconnect to see
---   the change is a player filing a bug report.
RegisterNetEvent('w_hud:client:serverCfg', function(cfg)
    if type(cfg) ~= 'table' then return end

    WHudSrv = cfg
    SendNUIMessage({ action = 'hud:server', cfg = cfg })
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Opening and closing
-- ════════════════════════════════════════════════════════════════════════════

--- ⚠️ SetNuiFocus(true, true) without SetNuiFocusKeepInput -- unlike the weapon wheel.
---   The wheel keeps game input because it is used mid-fight and the player must still
---   be able to move. This is the opposite: the player is dragging pieces of their
---   interface around with a cursor, and a stray WASD walking them into a river while
---   they do it is not a feature.
local function openMenu()
    if menuOpen then return end

    -- ⚠️ An admin always gets in, even with player editing switched off -- otherwise
    --    turning it off would lock the person who turned it off out of turning it back on.
    if not WHudIsAdmin and not featureOn('playerPanel') then
        WHudLocale.notify('settings.locked', WHudLocale.DIM, 'lock', 4000)
        return
    end

    menuOpen = true
    SetNuiFocus(true, true)
    pushToUi(true)
end

local function closeMenu()
    if not menuOpen then return end

    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hud:menu', open = false })
end

-- ════════════════════════════════════════════════════════════════════════════
-- What the panel sends back
-- ════════════════════════════════════════════════════════════════════════════

--- ★ The blob is stored as it arrives -- Lua never reads inside it.
---
---   Every field in it is validated where it is used: mergeSettings in the UI clamps
---   every number and drops every unknown key before a single widget is drawn. Adding a
---   second validator here would mean two places to change for every new setting, and
---   the one that got forgotten would be the one that silently dropped the field.
---
---   What Lua does check is the one thing the UI cannot: the size. A blob is written to
---   the database on a timer, and an unbounded string on that path is a way to fill a
---   table from a client.
RegisterNUICallback('hud:settings:save', function(data, cb)
    local settings = type(data) == 'table' and data.settings or nil

    if type(settings) == 'table' then
        local encoded = json.encode(settings)

        if type(encoded) == 'string' and #encoded <= 32768 then
            Settings = settings
            SetResourceKvp(KVP, encoded)
            TriggerServerEvent('w_hud:server:saveSettings', encoded)
        else
            w.print.warn('settings not saved: the payload is too large or unencodable')
        end
    end

    cb({ ok = true })
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The minimap -- the one setting the browser cannot apply itself
--
-- ★ Everything else in the panel is pixels, and pixels belong to the UI. The minimap is
--   the engine's, drawn by the game outside our page, so the choice has to come back
--   here to be acted on. It arrives on its own channel rather than being read out of the
--   saved blob, which keeps that blob opaque to Lua and keeps validation in the one
--   place that already does it.
--
-- ⚠️ 'server' is not a value, it is an abstention: it means the player has expressed no
--   preference and Config.OnFootMinimap and its three siblings decide, exactly as they
--   did before this panel existed. A server that turned the map off did so deliberately,
--   and a default that quietly overrode it would undo that for everyone.
-- ════════════════════════════════════════════════════════════════════════════

WHudWorld = { onFoot = 'server', mounted = 'server' }

local MAP_MODES = { server = true, off = true, map = true, compass = true }

RegisterNUICallback('hud:world', function(data, cb)
    if type(data) == 'table' then
        local onFoot = tostring(data.onFoot or '')
        local mounted = tostring(data.mounted or '')

        WHudWorld.onFoot = MAP_MODES[onFoot] and onFoot or 'server'
        WHudWorld.mounted = MAP_MODES[mounted] and mounted or 'server'
    end

    cb({ ok = true })
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The admin channel
--
-- ⚠️ This forwards and nothing more. Whether the sender is an admin, and whether the
--   numbers are sane, are both decided in server/admin.lua -- where a modified client
--   cannot reach. A check here would be a courtesy, not a defence, and writing one
--   invites the belief that it is the defence.
-- ════════════════════════════════════════════════════════════════════════════
RegisterNUICallback('hud:admin:save', function(data, cb)
    local cfg = type(data) == 'table' and data.cfg or nil

    if type(cfg) == 'table' then
        local encoded = json.encode(cfg)
        if type(encoded) == 'string' and #encoded <= 8192 then
            TriggerServerEvent('w_hud:server:saveServerCfg', encoded)
        end
    end

    cb({ ok = true })
end)

RegisterNUICallback('hud:settings:close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

-- ════════════════════════════════════════════════════════════════════════════
-- The key and the command
-- ════════════════════════════════════════════════════════════════════════════

local CMD = 'hudmenu'

RegisterCommand(CMD, function()
    if menuOpen then closeMenu() else openMenu() end
end, false)

-- The name people reach for when the one above does not occur to them.
RegisterCommand('hudsettings', function() ExecuteCommand(CMD) end, false)

do
    local key = tostring(Config.HudMenuKey or ''):upper()

    -- '' leaves it unbound: the command still works, and the player can bind it themselves
    -- from the game's keybinding screen. Which is the right default for a server that has
    -- already spent every key it has.
    --
    -- ⚠️ The label is registered once, in the language active at load: the game cannot
    --    relabel a key mapping afterwards, so a language switch reaches it at the next start.
    if key ~= '' then
        w.addKeybind({
            name        = 'w_hud_menu',
            description = 'Open the HUD control panel', -- English on purpose: the key-binding page cannot draw Arabic
            defaultKey  = key,
            onPressed   = function() ExecuteCommand(CMD) end,
        })
    end
end

-- ★ Releasing the focus on stop is not politeness, it is the difference between a failed
--   restart and a session that has to be ended from the task manager: a resource that
--   stops holding NUI focus leaves the player with a cursor and no game underneath it.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if menuOpen then SetNuiFocus(false, false) end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- For other resources
-- ════════════════════════════════════════════════════════════════════════════

exports('OpenHudSettings', openMenu)
exports('CloseHudSettings', closeMenu)
exports('GetHudSettings', function() return Settings end)
