-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · server/settings.lua
-- One row per character: the HUD they built, so it follows them to any machine.
--
-- ★ Against the character identifier, not the licence.
--   A player with three characters is three people, and a sheriff who wants their
--   wallet where their outlaw wants their ammo should not have to choose. This is the
--   same key server/metabolism.lua stores hunger under, for the same reason.
--
-- ⚠️ The blob is stored opaque -- the server never reads inside it, and neither does
--   the client. It is validated where it is used: mergeSettings in the UI clamps every
--   number and drops every unknown key before anything is drawn from it. What is checked
--   here is what only the server can check: that it parses at all, that it is not large
--   enough to be a weapon, and that it is not arriving faster than a person could
--   produce it.
-- ════════════════════════════════════════════════════════════════════════════

--- Anything above this is not a layout, it is an attempt.
---
--- ⚠️ The number has to clear the worst *realistic* save rather than the typical one.
---   Three saved layouts, each carrying four picture links of up to 400 characters, comes
---   to roughly 14 KB -- and a save that quietly exceeds the cap is a layout the player
---   loses without ever being told why. A plain settings blob is about 2 KB.
local MAX_BYTES = 32768

--- The floor between writes, per player. The UI already debounces its autosave; this is
--- the guard against a client that does not.
local WRITE_EVERY = 1000

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `w_hud_settings` (
            `cid`     VARCHAR(64) NOT NULL,
            `data`    TEXT NOT NULL,
            `updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`cid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])
end)

---@param src number
---@return string|nil
local function cidOf(src)
    local ok, id = pcall(function() return exports.w_lib:FwGetCharacterIdentifier(src) end)
    return ok and id or nil
end

-- ════════════════════════════════════════════════════════════════════════════
-- Reading
-- ════════════════════════════════════════════════════════════════════════════

w.callback.register('w_hud:settings:get', function(source)
    local cid = cidOf(source)
    if not cid then return nil end

    local row = MySQL.single.await('SELECT data FROM w_hud_settings WHERE cid = ?', { cid })
    if not row or type(row.data) ~= 'string' then return nil end

    local ok, data = pcall(json.decode, row.data)
    return (ok and type(data) == 'table') and data or nil
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Writing
--
-- ★ Coalesced, not dropped.
--
--   The obvious throttle -- ignore anything that arrives too soon after the last write --
--   throws away the newest state, which is the one the player is looking at. So a save
--   inside the window is **kept** as pending and written when the window closes, and a
--   second one inside the same window overwrites the first. The result is at most one
--   write a second per player, and the last thing they did is always the thing stored.
-- ════════════════════════════════════════════════════════════════════════════

local pending = {}   -- [src] = the newest payload not yet written
local waiting = {}   -- [src] = true while a flush is already scheduled

---@param src number
---@param payload string
local function write(src, payload)
    local cid = cidOf(src)
    if not cid then return end

    MySQL.update([[
        INSERT INTO w_hud_settings (cid, data) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE data = VALUES(data)
    ]], { cid, payload })
end

RegisterNetEvent('w_hud:server:saveSettings', function(payload)
    local src = source

    if type(payload) ~= 'string' or payload == '' or #payload > MAX_BYTES then return end

    -- It must be readable before it is stored: a row that cannot be decoded is a layout
    -- the player has lost, and they would not find out until their next login.
    local ok, data = pcall(json.decode, payload)
    if not ok or type(data) ~= 'table' then return end

    pending[src] = payload

    if waiting[src] then return end
    waiting[src] = true

    CreateThread(function()
        Wait(WRITE_EVERY)

        waiting[src] = nil

        local latest = pending[src]
        pending[src] = nil

        if latest then write(src, latest) end
    end)
end)

-- ★ Written on the way out rather than dropped: someone who moves a circle and quits in
--   the same second would otherwise lose it to the window above.
AddEventHandler('playerDropped', function()
    local src = source
    local latest = pending[src]

    pending[src] = nil
    waiting[src] = nil

    if latest then write(src, latest) end
end)
