-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · server/satchels.lua
-- The satchel upgrade -- stored per character, re-applied on every login
--
-- ═══ Why the bonus is stored and not the total ═══
--
--   Storing maxWeight itself would freeze the base: raise `inventory:weight` in
--   server.cfg and every existing character keeps the old total forever, while new
--   ones get the new one. Storing the bonus keeps them all in step -- the base moves
--   and everyone moves with it.
--
-- ═══ Why re-applied on login ═══
--
--   exports.w_inventory:SetMaxWeight is runtime only: the inventory rebuilds the player
--   at every login from `inventory:weight` and knows nothing of our bonus. So the bonus
--   has to be re-asserted every time, or it lasts exactly one session.
--
-- ⚠️ And it is applied a little **after** the login, not on the event itself: the player
--    inventory does not exist the instant the framework says the character loaded, and
--    SetMaxWeight on a missing inventory silently does nothing. We wait for it to exist.
-- ════════════════════════════════════════════════════════════════════════════

local Bonus = {}   -- src -> { bonus = number, rank = number, cid = the character it was read for }

--- The base capacity, from the same convar the inventory reads.
---@return number
local function baseWeight()
    return GetConvarInt('inventory:weight', 30000)
end

local function cidOf(src)
    local ok, id = pcall(function() return exports.w_lib:FwGetCharacterIdentifier(src) end)
    return ok and id or nil
end

-- ════════════════════════════════════════════════════════════════════════════
-- The table
-- ════════════════════════════════════════════════════════════════════════════
-- ★ Inside a CreateThread like server/metabolism.lua, and not because the manifest
--   order demands it any more: a table created at file scope depends on load order,
--   and load order is exactly the thing that broke twice today.
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `w_hud_satchels` (
            `cid`   VARCHAR(64) NOT NULL,
            `bonus` INT NOT NULL DEFAULT 0,
            `rank`  INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`cid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]])
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Applying
-- ════════════════════════════════════════════════════════════════════════════

--- Push the character's total onto their inventory.
---@param src number
local function apply(src)
    local b = Bonus[src]
    if not b then return end

    -- ⚠️ pcall: the inventory may be restarting, and a HUD must never take a login
    --    down with it.
    pcall(function()
        exports.w_inventory:SetMaxWeight(src, baseWeight() + (b.bonus or 0))
    end)
end

--- Read the character's row and apply it.
---
--- ★ The wait loop is the point: the framework announces the character before the
---   inventory has built the player, and SetMaxWeight on a player that does not exist
---   yet returns quietly. Three seconds of patience beats a bonus that vanishes.
---@param src number
local function load(src)
    local cid = cidOf(src)
    if not cid then return end

    local row = MySQL.single.await(
        'SELECT bonus, `rank` FROM w_hud_satchels WHERE cid = ?', { cid })

    Bonus[src] = { bonus = (row and row.bonus) or 0, rank = (row and row.rank) or 0, cid = cid }

    if Bonus[src].bonus <= 0 then return end

    CreateThread(function()
        -- w.waitFor yields until the inventory has built the player (errors after 15s);
        -- the pause inside the predicate keeps the poll at two reads a second.
        local ok = pcall(w.waitFor, function()
            Wait(500)
            local found, inv = pcall(function() return exports.w_inventory:GetInventory(src) end)
            if found and inv then return true end
        end, 'no player inventory', 15000)

        if ok then return apply(src) end

        -- It never appeared. Say so rather than leave the player quietly under-capacity.
        w.print.warn(('satchel bonus not applied for %s: no player inventory after 15s.')
            :format(tostring(src)))
    end)
end

RegisterNetEvent('w_hud:server:load', function() load(source) end)
AddEventHandler('playerDropped', function() Bonus[source] = nil end)

-- A deleted character's upgrade leaves memory with its row (server/purge.lua): a player still
-- connected at the character selection keeps the entry until the next login otherwise.
WHudPurge = WHudPurge or {}
WHudPurge.satchels = function(cid)
    local n = 0
    for src, b in pairs(Bonus) do
        if b.cid == cid then Bonus[src] = nil; n = n + 1 end
    end
    return n
end

-- A live restart of w_hud: the login event is not replayed, so we walk the connected.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(3000)
        for _, src in ipairs(GetPlayers()) do load(tonumber(src)) end
    end)
end)

-- ★ And when the inventory itself restarts: it rebuilds every player from the convar,
--   wiping our bonus with no event of its own. Nobody tells us -- so we watch for it.
AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'w_inventory' then return end

    CreateThread(function()
        Wait(4000)
        for _, src in ipairs(GetPlayers()) do apply(tonumber(src)) end
    end)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Using a satchel
-- ════════════════════════════════════════════════════════════════════════════

---@param src number
---@param item string
---@return boolean consumed
local function useSatchel(src, item)
    local entry = (Config.Satchels or {})[item]
    if not entry then return false end

    if not Bonus[src] then load(src) end

    local state = Bonus[src]

    if not state then
        WNeeds.notify(src, 'satchel.noChar', '#EDE6D6', 'cross')
        return false
    end

    -- ★ Refused *and not consumed*: losing a satchel to a no-op is the kind of thing
    --   players remember, and rightly.
    if (entry.rank or 0) <= (state.rank or 0) then
        WNeeds.notify(src, 'satchel.already', '#B9AF9C', 'warning')
        return false
    end

    local cid = cidOf(src)
    if not cid then return false end

    -- ★ The satchel leaves the bag here, not through the return value: w_inventory's bridge
    --   only hands the use over and never consumes on `true`, so an upgrade would otherwise
    --   leave the satchel to be passed on for a free upgrade per character.
    local okRemove, removed = pcall(function() return exports.w_lib:InvRemoveItem(src, item, 1) end)
    if not okRemove or removed ~= true then return false end

    state.bonus, state.rank = entry.bonus or 0, entry.rank or 0

    MySQL.update([[
        INSERT INTO w_hud_satchels (cid, bonus, `rank`)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE bonus = VALUES(bonus), `rank` = VALUES(`rank`)
    ]], { cid, state.bonus, state.rank })

    apply(src)

    -- The new capacity travels as a format argument; the client formats the notice in
    -- the player's own language.
    WNeeds.notify(src, 'satchel.upgraded', '#EDE6D6', 'tick', 5000,
        { math.floor((baseWeight() + state.bonus) / 1000) })

    return true
end

-- ════════════════════════════════════════════════════════════════════════════
-- Registration
--
-- ★ The same pattern as server/consumables.lua, and for the same reason: the usable-item
--   registry in w_inventory is an in-memory table wiped on every restart of it, and it
--   has no way to rebuild itself. So we re-register when we see it come up.
-- ════════════════════════════════════════════════════════════════════════════
local function registerAll(why)
    if not Config.Satchels then return end

    local count = 0

    for item in pairs(Config.Satchels) do
        local ok, accepted = pcall(function()
            return exports.w_inventory:RegisterUsableItem(item, function(source)
                -- ★ useSatchel takes the satchel out itself once the upgrade is accepted; a
                --   refused upgrade keeps it. The return value is only a status.
                return useSatchel(source, item)
            end)
        end)

        if ok and accepted == true then count = count + 1 end
    end

    w.print.info(('satchels: %d registered (%s)'):format(count, why or 'start'))
end

CreateThread(function()
    -- w_inventory is the only bag with SetMaxWeight; wait for it without a deadline
    w.waitFor(function()
        Wait(500)
        if GetResourceState('w_inventory') == 'started' then return true end
    end, nil, false)
    Wait(1500)
    registerAll('w_hud start')
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'w_inventory' then return end
    CreateThread(function() Wait(1500); registerAll('after w_inventory start') end)
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Public interface + admin command
-- ════════════════════════════════════════════════════════════════════════════
exports('GetSatchelBonus', function(src) return (Bonus[src] or {}).bonus or 0 end)
exports('GetCarryWeight', function(src) return baseWeight() + ((Bonus[src] or {}).bonus or 0) end)

--- /satchel <citizen id> <tier|reset>  -- grant or clear an upgrade without an item.
---
--- ★ The player is named by his citizen id ('#5' = whoever is on server id 5): a server id
---   changes on every connection and collides with the digits of a citizen id. The row is
---   keyed by that id, so a citizen who is not in the game gets it too: his next login
---   reads it (load). Only the live capacity (apply) waits for him to be online.
RegisterCommand('satchel', function(source, args)
    local src = source

    if src ~= 0 then
        local ok, admin = pcall(function() return exports.w_lib:IsAdmin(src) end)
        if not (ok and admin) then return end
    end

    local tier = tostring(args[2] or '')

    if not args[1] then
        print('[w_hud] usage: /satchel <citizen id | #server id> <' ..
            table.concat((function()
                local t = {}
                for k in pairs(Config.Satchels or {}) do t[#t + 1] = k end
                table.sort(t)
                return t
            end)(), '|') .. '|reset>^0')
        return
    end

    local who, reason = w.citizen.resolve(args[1], { self = src ~= 0 and src or nil })
    if not who then return w.print.warn(('satchel: %s (%s)'):format(w.citizen.reasonText(reason), tostring(args[1]))) end

    local cid, target = who.citizenid, who.online and who.source or nil
    local label = w.citizen.label(who) .. (target and '' or ' [offline]')

    if tier == 'reset' then
        if target then Bonus[target] = { bonus = 0, rank = 0, cid = cid } end
        MySQL.update('DELETE FROM w_hud_satchels WHERE cid = ?', { cid })
        if target then apply(target) end
        return w.print.info(('satchel reset for %s'):format(label))
    end

    local entry = (Config.Satchels or {})[tier]
    if not entry then return w.print.warn('unknown tier') end

    -- ⚠️ The admin path bypasses the rank check deliberately: an admin fixing a mistake
    --    needs to be able to move a player *down* a tier, not only up.
    if target then Bonus[target] = { bonus = entry.bonus or 0, rank = entry.rank or 0, cid = cid } end

    MySQL.update([[
        INSERT INTO w_hud_satchels (cid, bonus, `rank`)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE bonus = VALUES(bonus), `rank` = VALUES(`rank`)
    ]], { cid, entry.bonus or 0, entry.rank or 0 })

    if target then apply(target) end

    w.print.info(('%s -> %s (%d kg total)')
        :format(label, tier, math.floor((baseWeight() + (entry.bonus or 0)) / 1000)))
end, true)

-- ════════════════════════════════════════════════════════════════════════════
-- For the live settings (shared/settings_schema.lua, group 'satchels')
--
-- ★ A tier whose bonus an admin changed reaches everyone who already owns it: the stored
--   bonus of every character of that rank is rewritten, and the ones online get their new
--   capacity now. The admin console asks for a confirmation before it sends the change.
-- ════════════════════════════════════════════════════════════════════════════
WHudSatchels = WHudSatchels or {}

---@param rank number the tier (Config.Satchels[item].rank)
---@param bonus number grams
---@return integer online players whose capacity changed now
function WHudSatchels.setRankBonus(rank, bonus)
    rank, bonus = tonumber(rank), math.floor(tonumber(bonus) or 0)
    if not rank then return 0 end

    local ok, err = pcall(MySQL.update.await, 'UPDATE w_hud_satchels SET bonus = ? WHERE `rank` = ?', { bonus, rank })
    if not ok then w.print.error(('satchels: could not rewrite tier %s: %s'):format(rank, tostring(err))) end

    local n = 0
    for src, b in pairs(Bonus) do
        if b.rank == rank then
            b.bonus = bonus
            apply(src)
            n = n + 1
        end
    end
    return n
end
