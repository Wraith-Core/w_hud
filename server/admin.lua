-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · server/admin.lua
-- The settings that belong to the server rather than to the player.
--
-- ═══ Why any of this exists ═══
--
--   How fast hunger falls, how hard starving hurts, whether it can kill at all: every
--   one of those is a number somebody wants to try, watch for ten minutes, and change
--   again. In shared/config.lua each attempt costs an edit, a `refresh`, a `restart`
--   and a guess -- so in practice nobody ever tunes them, and they sit at whatever they
--   shipped as. Which is precisely how the shipped values came to be what they were:
--
--     hunger fell 1 point every 144 seconds  -> four hours from full to empty
--     damage began below 5                   -> reached after nearly four hours
--     and then removed 1 point of a 0-600 health bar every 15 seconds
--
--   That last line is the one that mattered. One six-hundredth of a life per tick is a
--   quarter of a percent a minute: a starving character took over two hours to die and
--   looked, to everyone watching, exactly like nothing was happening. Reported as
--   "hunger does not do anything", and it was right.
--
--   These live in the database now, an admin moves a slider, and everyone has it.
--
-- ═══ What is trusted, and what is not ═══
--
--   ⚠️ The values are clamped **here**, on arrival, and not only in the UI that sent
--     them. Not because the admin is suspected -- but `interval = 0` is a loop with no
--     wait in it, in this process, for every player at once. A settings screen must not
--     be able to hang the server, whoever is holding it.
--
--   ⚠️ And the admin check is server-side only. The client is told whether to draw the
--     section, which is a convenience; whether a save is honoured is decided again
--     here, where a modified client cannot reach.
-- ════════════════════════════════════════════════════════════════════════════

--- Kept in the same order as FEATURES in web/src/settings/types.ts.
--- ★ A feature missing from this list is a feature the admin can switch off in the UI
---   and find switched back on after a restart -- so the two lists move together.
local FEATURE_KEYS = {
    'health', 'stamina', 'hunger', 'thirst', 'voice', 'horse', 'buffs',
    'ammo', 'money', 'identity', 'compass', 'location',
    'playerImages', 'playerPanel',
}

-- ════════════════════════════════════════════════════════════════════════════
-- Validation
-- ════════════════════════════════════════════════════════════════════════════

local function clampNum(v, lo, hi, fallback)
    v = tonumber(v)
    if not v or v ~= v then return fallback end
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

--- ⚠️ Only http, https and nui. A logo URL is written into an <img src> on every
--- player's screen, and `javascript:` in that position is a script they all run.
local function safeUrl(v)
    local url = tostring(v or '')
    if not (url:match('^https://') or url:match('^http://') or url:match('^nui://')) then return '' end
    return url:sub(1, 400)
end

--- Anything shaped wrongly becomes the default rather than an error: this runs on a
--- blob from the database, from a client, and from a build that may predate this file.
---
--- ⚠️ This rebuilds the table field by field, which means a field it does not name is a
---   field it **silently deletes**. That is the intended behaviour for junk -- and it is
---   a trap for us: `identity` was added to the UI's model and not to this list, so an
---   admin could drag the logo, watch it publish, and watch the echo put it back in the
---   corner a second later. Nothing errored; the field simply evaporated in transit.
---
---   So anything present on the way in and absent on the way out is now reported. The
---   next time the two lists drift apart it says so in the console instead of showing up
---   as a widget that refuses to stay where it is put.
---@param raw any
---@return table
local function sanitise(raw)
    local c      = type(raw) == 'table' and raw or {}
    local needs  = type(c.needs) == 'table' and c.needs or {}
    local dmg    = type(c.damage) == 'table' and c.damage or {}
    local logo   = type(c.logo) == 'table' and c.logo or {}
    local ident  = type(c.identity) == 'table' and c.identity or {}
    local feats  = type(c.features) == 'table' and c.features or {}

    local out = {
        name = tostring(c.name or ''):sub(1, 48),

        logo = {
            url    = safeUrl(logo.url),
            width  = clampNum(logo.width, 2, 160, 30),
            height = clampNum(logo.height, 0, 160, 0),
        },

        -- Where the name-or-logo block sits, for everyone. Same units and the same
        -- limits as IdentityCfg in web/src/settings/types.ts.
        identity = {
            x       = clampNum(ident.x, -20, 120, 98.2),
            y       = clampNum(ident.y, -20, 120, 2.0),
            scale   = clampNum(ident.scale, 0.4, 3, 1),
            opacity = clampNum(ident.opacity, 0.15, 1, 1),
        },

        needs = {
            hungerRate = clampNum(needs.hungerRate, 0, 25, 1),
            thirstRate = clampNum(needs.thirstRate, 0, 25, 1.4),
            -- ⚠️ Five seconds is the floor, and it is the important one on this page.
            interval   = clampNum(needs.interval, 5, 1800, 90),
        },

        damage = {
            enabled  = dmg.enabled ~= false,
            hungerAt = clampNum(dmg.hungerAt, 0, 99, 15),
            thirstAt = clampNum(dmg.thirstAt, 0, 99, 15),
            -- On the 0-100 scale the player sees. The client multiplies by 6.
            amount   = clampNum(dmg.amount, 0.5, 25, 2),
            interval = clampNum(dmg.interval, 3, 600, 20),
            canKill  = dmg.canKill ~= false,
        },

        features = {},
    }

    for i = 1, #FEATURE_KEYS do
        local key = FEATURE_KEYS[i]
        out.features[key] = feats[key] ~= false
    end

    -- The drift alarm described above. Costs one pass over a handful of keys.
    for key in pairs(c) do
        if out[key] == nil then
            w.print.warn(('server settings: dropping unknown field ~orange~%s~ - if the UI '
                .. 'sends it on purpose, add it to sanitise() in server/admin.lua'):format(tostring(key)))
        end
    end

    return out
end

--- ★ A global, read by server/metabolism.lua's decay loop. That file loads before this
---   one, which is fine: it reads the table inside its loop, at runtime, and falls back
---   to Config for as long as this is still nil.
WHudSrv = sanitise(nil)

-- ════════════════════════════════════════════════════════════════════════════
-- Who may change it
-- ════════════════════════════════════════════════════════════════════════════

--- The library answers: the console always passes, framework admins pass
--- (exports.w_lib:IsAdmin), and so does the exact ACE Config.AdminAce or a wildcard
--- parent of it (w_hud.*, *). Same test the rest of this resource uses.
---@param src number
---@return boolean
local function isAdmin(src)
    local ok, allowed = pcall(function()
        return exports.w_lib:HasPermissionNode(src, Config.AdminAce or 'w_hud.admin')
    end)

    return ok and allowed == true
end

exports('IsHudAdmin', function(src) return isAdmin(src) end)

-- ════════════════════════════════════════════════════════════════════════════
-- Storage -- one row, because there is one server
-- ════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `w_hud_server` (
            `id`      TINYINT NOT NULL DEFAULT 1,
            `data`    TEXT NOT NULL,
            `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    local row = MySQL.single.await('SELECT data FROM w_hud_server WHERE id = 1')

    if row and type(row.data) == 'string' then
        local ok, data = pcall(json.decode, row.data)
        if ok and type(data) == 'table' then WHudSrv = sanitise(data) end
    end

    w.print.info(('server settings loaded - hunger -%s every %ss, damage %s')
        :format(WHudSrv.needs.hungerRate, WHudSrv.needs.interval,
            WHudSrv.damage.enabled and ('-' .. WHudSrv.damage.amount .. '% every ' .. WHudSrv.damage.interval .. 's') or 'off'))

    -- ⚠️ Said once, at boot, because the alternative is an admin opening the panel,
    --    finding no Admin section, and having no way to learn why.
    local ace = Config.AdminAce or 'w_hud.admin'
    if not IsPrincipalAceAllowed('group.admin', ace) then
        w.print.info(('to let someone edit these in game: ~orange~add_ace group.admin %s allow~ in server.cfg'):format(ace))
    end
end)

local function store(cfg)
    local ok, result = pcall(MySQL.update.await, [[
        INSERT INTO w_hud_server (id, data) VALUES (1, ?)
        ON DUPLICATE KEY UPDATE data = VALUES(data)
    ]], { json.encode(cfg) })
    return ok and result ~= nil
end

--- The one save path every writer shares (the panel's event, the export, and the admin
--- console's live settings through shared/settings_schema.lua): clamp, store, publish,
--- broadcast to everyone. Who is asking is the caller's check, made before this.
---@param cfg table
---@return boolean ok, table|string result  the stored cfg | 'db_error'
local function save(cfg)
    local saved = sanitise(cfg)
    if not store(saved) then return false, 'db_error' end
    WHudSrv = saved
    TriggerClientEvent('w_hud:client:serverCfg', -1, WHudSrv)
    return true, WHudSrv
end

--- For shared/settings_schema.lua (the 'own' groups of the live settings: needs, damage,
--- features, identity). sanitise(nil) is the real set of defaults.
WHudAdmin = {
    sanitise = sanitise,
    defaults = function() return sanitise(nil) end,
    isAdmin = function(src) return isAdmin(src) end,
    save = save,
}

-- ════════════════════════════════════════════════════════════════════════════
-- Reading and writing from the panel
-- ════════════════════════════════════════════════════════════════════════════

--- What a client needs on login: the settings, and whether to offer the admin section.
w.callback.register('w_hud:server:bootstrap', function(source)
    return { cfg = WHudSrv, isAdmin = isAdmin(source) }
end)

--- The floor between writes, per player -- a settings screen is not a firehose.
local lastWrite = {}

RegisterNetEvent('w_hud:server:saveServerCfg', function(payload)
    local src = source

    if not isAdmin(src) then
        w.print.warn(('%s tried to change the server HUD settings and is not an admin')
            :format(GetPlayerName(src) or src))
        return
    end

    if type(payload) ~= 'string' or #payload > 8192 then return end

    local now = GetGameTimer()
    if (now - (lastWrite[src] or 0)) < 500 then return end
    lastWrite[src] = now

    local ok, data = pcall(json.decode, payload)
    if not ok or type(data) ~= 'table' then return end

    -- ★ save() sends it to everyone, not only to whoever saved. These settings are the
    --   server's: a feature switched off has to disappear from every screen at once, and a
    --   player who has to reconnect to see it is a player reporting a bug.
    if not save(data) then return end

    w.print.info(('server settings saved by %s'):format(GetPlayerName(src) or src))
end)

AddEventHandler('playerDropped', function() lastWrite[source] = nil end)

-- ════════════════════════════════════════════════════════════════════════════
-- For the rest of the resource
-- ════════════════════════════════════════════════════════════════════════════

exports('GetServerHudCfg', function() return WHudSrv end)

--- Save the server HUD settings from another resource (the w_admin console).
--- Mirrors 'w_hud:server:saveServerCfg' exactly: the same admin check (IsHudAdmin), the
--- same sanitise() clamping, the same store + broadcast to every client. `cfg` may be
--- the decoded table or its JSON string. Console (adminSrc 0) is allowed, like the event
--- path's HasPermissionNode. The throttle is skipped here: the caller is a resource.
---@param cfg table|string
---@param adminSrc number  the admin doing it (re-checked here, not trusted)
---@return boolean ok, string|table result  'not_admin' | 'invalid_cfg' | the stored cfg
exports('SaveServerHudCfg', function(cfg, adminSrc)
    local src = tonumber(adminSrc) or -1
    if src ~= 0 and not isAdmin(src) then
        w.print.warn(('%s tried to change the server HUD settings (export) and is not an admin')
            :format(GetPlayerName(src) or src))
        return false, 'not_admin'
    end

    if type(cfg) == 'string' then
        if #cfg > 8192 then return false, 'invalid_cfg' end
        local ok, data = pcall(json.decode, cfg)
        if not ok or type(data) ~= 'table' then return false, 'invalid_cfg' end
        cfg = data
    end
    if type(cfg) ~= 'table' then return false, 'invalid_cfg' end

    local saved, result = save(cfg)
    if not saved then return false, result end

    w.print.info(('server settings saved by %s (export)'):format(GetPlayerName(src) or src))
    return true, WHudSrv
end)
