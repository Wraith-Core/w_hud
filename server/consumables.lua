-- ════════════════════════════════════════════════════════════════════════════
-- w_hud -- registering consumables and horse care with the active inventory
--
-- ! Through w_lib's inventory bridge and never exports.w_inventory directly.
--
--   This file used to call w_inventory by name in six places, gated on
--   GetResourceState('w_inventory') == 'started'. On a server running
--   vorp_inventory that gate is simply never open: nothing was registered,
--   nothing was removed, nothing was handed back - every food and drink in the
--   satchel did nothing when used, with no line in the console to say why.
--
--   w_lib already carries an adapter per inventory (w_inventory, vorp_inventory,
--   rsg, qbr) and normalises the use-callback to (source, { metadata, slot, item })
--   for all of them. So the calls below go there, and the bag underneath is
--   whichever one the server actually runs.
--
--   The whole table lives in shared/consumables.lua -- this file only executes it.
--   The effect on needs is applied here (the server is the authority), and whatever
--   touches the ped itself (cores · animation · screen effect) runs on the client in
--   client/consumables.lua.
--
-- ⚠️ This file loads before server/metabolism.lua (alphabetical order), so every call
--    to WNeeds sits **inside** a function invoked at runtime, not at load time.
-- ════════════════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════════════════
-- The inventory, through w_lib
-- ════════════════════════════════════════════════════════════════════════════
local Inv = {}

--- The active inventory's name, or nil while w_lib has not settled on one.
---@return string|nil
function Inv.name()
    local ok, name = pcall(function() return exports.w_lib:InvName() end)
    return ok and name or nil
end

---@return boolean
function Inv.ready()
    return Inv.name() ~= nil
end

---@param src integer
---@param item string
---@param count integer
---@return boolean
function Inv.add(src, item, count)
    local ok, done = pcall(function() return exports.w_lib:InvAddItem(src, item, count or 1) end)
    return ok and done == true
end

--- ★ Boolean only: the bridge does not pass the inventory's failure reason through.
---   Where a reason matters, /useprobe and the debug convar below say what they can.
---@param src integer
---@param item string
---@param count integer
---@param slot? integer|string
---@return boolean
function Inv.remove(src, item, count, slot)
    local ok, done = pcall(function() return exports.w_lib:InvRemoveItem(src, item, count or 1, nil, slot) end)
    return ok and done == true
end

--- The bridge closes the satchel after use and hands the callback (source, data)
--- where data.slot is the piece that was used - the same shape every branch below
--- already expects.
---@param item string
---@param callback fun(source: integer, data: table)
---@return boolean
function Inv.registerUsable(item, callback)
    local ok, done = pcall(function() return exports.w_lib:InvRegisterUsableItem(item, true, callback) end)
    return ok and done == true
end

--- A notice to the player; `key` is a dictionary key the client translates (WNeeds.notify).
local function notify(src, key, color, icon)
    if not key then return end
    WNeeds.notify(src, key, color, icon, 4000)
end

-- ════════════════════════════════════════════════════════════════════════════
-- Consuming an item (food/drink/medicine/tobacco)
-- ════════════════════════════════════════════════════════════════════════════

--- The item's effect after the piece has been removed -- separated from the removal
--- because dual items (sugar/mint) are removed first, then it is decided: does the
--- player eat it, or feed it to the horse?
local function applyEffects(src, item)
    local entry = Config.Consumables[item]
    if not entry then return end

    -- Needs: one broadcast for all the changes
    WNeeds.addMany(src, {
        hunger = entry.hunger or 0,
        thirst = entry.thirst or 0,
    })

    -- The buff
    if entry.buff and Config.Systems.buffs then
        WNeeds.giveBuff(src, entry.buff.type, entry.buff.amount or 50)
    end

    -- What is handed back to the player (an empty bottle, say)
    if entry.giveBack and entry.giveBack.item and entry.giveBack.item ~= '' then
        Inv.add(src, entry.giveBack.item, entry.giveBack.amount or 1)
    end

    -- The client: animation + cores + screen effect + the "consumed" notice in the
    -- player's language (it reads the details from shared/consumables.lua)
    TriggerClientEvent('w_hud:client:consume', src, item)

    WNeeds.save(src)

    -- A console trace while diagnosing:  setr w_lib:printlevel:w_hud debug
    local n = WNeeds.state(src) or {}
    w.print.debug(("player %s consumed '%s' -> hunger=%s thirst=%s")
        :format(tostring(src), item, tostring(n.hunger), tostring(n.thirst)))
end

--- Remove, then apply. ★ Nothing is granted unless the piece really was removed -- a guard against duplication.
local function consume(src, item, data)
    if not Config.Consumables[item] then return false end

    -- ★ A failed removal is printed, never swallowed: without the line, the whole
    --   thing looks like "I ate and nothing happened" with no evidence at all.
    local removed = Inv.remove(src, item, 1, data and data.slot)

    if not removed then
        w.print.error(("could not remove '%s' from player %s's %s (slot=%s) - nothing applied")
            :format(item, tostring(src), tostring(Inv.name() or 'inventory'), tostring(data and data.slot)))
        return false
    end

    applyEffects(src, item)
    return true
end

-- ════════════════════════════════════════════════════════════════════════════
-- Horse care
--
--   The server starts the request, the client performs it and confirms, then the item
--   is removed.
--   ★ We do not remove before confirmation, so the carrot is not lost if the player is
--     far from their horse. And we do not accept a confirmation we did not start:
--     one pending request per player, with a deadline.
-- ════════════════════════════════════════════════════════════════════════════
local pending = {} -- [src] = { item = …, slot = …, expires = … }

local function requestHorseCare(src, item, data)
    local entry = Config.HorseItems[item]
    if not entry then return false end

    pending[src] = {
        item = item,
        slot = data and data.slot,
        expires = os.time() + 30,
    }

    TriggerClientEvent('w_hud:client:horseCare', src, item)
    return true
end

RegisterNetEvent('w_hud:server:horseCareDone', function(item)
    local src = source
    local p = pending[src]

    -- A confirmation we did not start, or for a different item, or past the deadline => rejected
    if not p or p.item ~= item or os.time() > p.expires then return end
    pending[src] = nil

    local entry = Config.HorseItems[item]
    if not entry then return end

    if entry.consume ~= false then
        Inv.remove(src, item, 1, p.slot)
    end

    local key = (entry.kind == 'brush' and 'needs.horseBrushed')
        or (entry.kind == 'stamina' and 'needs.horseStamina')
        or 'needs.horseFed'

    notify(src, key, '#c9a227', 'awards_set_p_003')
end)

-- -- dual items (sugar · horse mint) -----------------------------------------
--   Near their horse => they feed it. Far => they eat it themselves. Never both.
--   The piece is removed first either way, and the client reports which branch it took.
--   ★ There is nothing to cheat here: the piece is gone before the answer, so the worst
--     a forger can do is pick the branch they wanted -- which they are free to do anyway
--     by walking away from the horse.
local dual = {} -- [src] = { item = …, expires = … }

local function requestDual(src, item, data)
    local removed = Inv.remove(src, item, 1, data and data.slot)
    if not removed then return false end

    dual[src] = { item = item, expires = os.time() + 30 }
    TriggerClientEvent('w_hud:client:dualUse', src, item)
    return true
end

RegisterNetEvent('w_hud:server:dualResult', function(item, target)
    local src = source
    local d = dual[src]

    if not d or d.item ~= item or os.time() > d.expires then return end
    dual[src] = nil

    if target == 'horse' then
        local entry = Config.HorseItems[item]
        notify(src, (entry and entry.kind == 'stamina') and 'needs.horseStamina' or 'needs.horseFed',
            '#c9a227', 'awards_set_p_003')
    else
        applyEffects(src, item)
    end
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
    dual[source] = nil
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Registration -- a single pass over the union of the two tables
-- ════════════════════════════════════════════════════════════════════════════
local function handleUse(src, item, data)
    local horse = Config.Systems.horseCare and Config.HorseItems[item] or nil
    local food  = Config.Systems.consumables and Config.Consumables[item] or nil

    -- A horse-only item => always goes to the horse
    if horse and not (food and horse.playerFallback) then
        return requestHorseCare(src, item, data)
    end

    -- A dual item (sugar/mint): to the horse if it is near, otherwise the player eats it
    if horse and food then
        return requestDual(src, item, data)
    end

    if food then return consume(src, item, data) end

    notify(src, 'needs.cantUse', '#ff6b6b', 'cross')
    return false
end

-- ════════════════════════════════════════════════════════════════════════════
-- ★ A guard that surfaces errors instead of letting them be swallowed.
--
--   w_inventory calls our handler like this:  pcall(server.UseItem, source, name, data)
--   so any error in the code here is swallowed by that pcall without a single line in
--   the console, and what the player sees is: they eat and nothing goes up -- with no
--   trace to follow.
--   xpcall + traceback makes the fault visible at the moment it happens.
-- ════════════════════════════════════════════════════════════════════════════
local function guarded(src, item, data)
    local ok, result = xpcall(handleUse, debug.traceback, src, item, data)

    if not ok then
        w.print.error(("ERROR while using '%s' (player %s):\n%s")
            :format(tostring(item), tostring(src), tostring(result)))
        return false
    end

    return result
end

local function registerAll(why)
    -- The bridge, not a resource name: w_lib says which bag is up, and a bag that has
    -- not been detected yet is simply not ready - not a different resource.
    if not Inv.ready() then
        w.print.warn(('no inventory detected by w_lib yet - usable items not registered (%s)'):format(why or 'start'))
        return 0
    end

    local names, count = {}, 0

    if Config.Systems.consumables then
        for item in pairs(Config.Consumables) do names[item] = true end
    end

    if Config.Systems.horseCare then
        for item in pairs(Config.HorseItems) do names[item] = true end
    end

    -- ★ We read the registration's own return value, not whether pcall succeeded.
    --   The count used to rely on `ok` alone, which only means "the call did not throw"
    --   -- so it printed 88 even if the inventory returned false for every one of them.
    local refused = {}

    for item in pairs(names) do
        local accepted = Inv.registerUsable(item, function(source, data)
            return guarded(source, item, data)
        end)

        if accepted then
            count = count + 1
        else
            refused[#refused + 1] = item
        end
    end

    -- ★ The registry check that used to follow here read w_inventory's own table and
    --   has no counterpart on the other bags, so there is nothing honest to print for
    --   it. The bridge keeps every definition and re-applies it when the bag comes
    --   back, which is what that check was guarding against.
    w.print.info(('usable items: %d registered with %s (%s)')
        :format(count, tostring(Inv.name()), why or 'start'))

    if #refused > 0 then
        w.print.error(('%s REFUSED %d item(s), first: %s')
            :format(tostring(Inv.name()), #refused, table.concat(refused, ', ', 1, math.min(5, #refused))))
    end

    return count
end

--- Register once the bridge has found a bag. Detection is asynchronous and the
--- folder may start us before the inventory, so we wait on the bridge (w.waitFor)
--- rather than trust one fixed delay. WNeeds (metabolism.lua loads after this file)
--- is ready long before the wait ends.
local function registerWhenReady(why)
    CreateThread(function()
        local ok = pcall(w.waitFor, function()
            Wait(250) -- keeps the poll at four reads a second
            if Inv.ready() then return true end
        end, 'no inventory detected by w_lib', 30000)

        if ok then Wait(1500) end
        registerAll(why)
    end)
end

registerWhenReady('w_hud start')

-- ════════════════════════════════════════════════════════════════════════════
-- ★ Re-registering after the bag restarts underneath us
--
--   The bag's usable-item registry is an in-memory table wiped every time it restarts
--   (vorp_inventory's USABLE_ITEMS exactly as much as w_inventory's was), and it has no
--   way to restore it, since it does not hold other resources' functions. We do not
--   depend on the bag, so we survive its restart - and must register again, or the food
--   sits in the bag inert afterwards: you eat it and nothing goes up. (The bridge
--   re-applies what it remembers too; registering twice is harmless, last writer wins.)
--
--   A restart of w_lib is a different story: we declare `dependency 'w_lib'`, so
--   FXServer stops us (and every other wraith resource) BEFORE it, and starts none of
--   us again. The 'w_lib' arm below is for the one case where we are still up when it
--   comes back (a manual `start w_lib` after a plain `stop`); after `restart w_lib` the
--   operator must `ensure [wraith]` - or restart the server.
--   ⚠️ Any other resource of yours that registers usable items needs exactly this.
-- ════════════════════════════════════════════════════════════════════════════
AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'w_lib' and resource ~= Inv.name() then return end
    registerWhenReady(('after %s start'):format(resource))
end)
