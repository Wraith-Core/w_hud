-- HUD owns food/drink use. Animation completes before a single validated charge.
local pending, sequence = {}, 0
local Inv = {}
function Inv.name()
    local ok, name = pcall(function() return exports.w_lib:InvName() end)
    return ok and name or nil
end
function Inv.ready() return Inv.name() ~= nil end
function Inv.registerUsable(item, callback)
    return exports.w_lib:InvRegisterUsableItem(item, true, callback) == true
end
local function count(src, item)
    return exports.w_lib:InvGetItemCount(src, item) or 0
end
local function notify(src, reason)
    WNeeds.notify(src, reason or 'needs.useFailed', '#F2F2F2', 'cross', 4000)
end
local function finish(src, p, effects, reason)
    if pending[src] ~= p then return end
    pending[src] = nil
    TriggerClientEvent('w_hud:client:useFinished', src, p.token, effects and p.item or false, p.target)
    if reason then notify(src, reason) end
end
--- The reset for a token the server does not hold (any more): the client drops that use and its
--- hudConsuming. It acts only while it still waits on this very token, so an extra one is harmless.
local function reset(src, token)
    if type(token) == 'number' then TriggerClientEvent('w_hud:client:useFinished', src, token, false) end
end
-- ! Not GetEntityHealth: this RedM build answers 0 for a live player's ped on the server
--   (w_pets logged "hp=0" for a player buying a pet), so this gate refused every use before
--   it began, with no notice -- food and drink simply did nothing. The downed state the server
--   does keep is the core's: metadata.isdead / inlaststand on the RSG family (w_ambulancejob
--   keeps them), the character's isdead on VORP. The client refuses a dead ped by itself.
local function downed(flag) return flag == true or flag == 1 end
local function alive(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    local ok, char = pcall(function() return exports.w_lib:FwGetCharacter(src) end)
    if not ok or type(char) ~= 'table' then return true end
    local flags = type(char.metadata) == 'table' and char.metadata or char
    return not downed(flags.isdead) and not downed(flags.inlaststand)
end
local function sameSlot(src, p)
    if Inv.name() ~= 'w_inventory' then return count(src, p.item) > 0 end
    local slot = exports.w_inventory:GetSlot(src, p.slot)
    return slot and slot.name == p.item and slot.count > 0 and
        (not p.metadata or json.encode(slot.metadata or {}) == p.metadata)
end
local function horseTarget(src, netId)
    if GetResourceState('w_stables') ~= 'started' then return nil end
    local ok, horse = pcall(function() return exports.w_stables:ConsumableTarget(src, netId) end)
    return ok and horse or nil
end
local function validateTarget(src, p)
    if p.target == 'player' then return Config.Consumables[p.item] ~= nil end
    if p.target == 'horse' then
        return Config.HorseItems[p.item] and horseTarget(src, p.netId) ~= nil
    end
    return p.target == 'animal' and WHudAnimalUse.validate(src, p.netId, p.item) ~= nil
end
local function beginUse(src, item, data)
    if pending[src] then notify(src, 'needs.useBusy'); return false end
    if not alive(src) then return false end
    local entry = Config.Consumables[item]
    if not entry then return false end
    if entry.blocked then notify(src, entry.blocked); return false end
    if entry.focus and not entry.focusOptional and not Config.Focus.Enabled then notify(src, 'needs.focusUnavailable'); return false end
    if count(src, item) < 1 then return false end
    if entry.pack and exports.w_lib:InvCanCarry(src, entry.pack.item, entry.pack.count) ~= true then
        notify(src, 'needs.packNoSpace'); return false
    end
    if entry.requirement and count(src, entry.requirement.item) < entry.requirement.count then
        notify(src, 'needs.tobaccoRequired'); return false
    end
    sequence = sequence + 1
    local p = { item = item, slot = data and data.slot, token = sequence,
        forcedAnimal = data and data.targetNetId,
        character = exports.w_lib:FwGetCharacterIdentifier(src),
        expires = GetGameTimer() + Config.Use.Timeout, stage = 'select' }
    if Inv.name() == 'w_inventory' then
        local slot = p.slot and exports.w_inventory:GetSlot(src, p.slot)
        if not slot or slot.name ~= item then return false end
        p.metadata = json.encode(slot.metadata or {})
    end
    pending[src] = p
    TriggerClientEvent('w_hud:client:prepareUse', src, item, p.token, p.forcedAnimal)
    return true
end
local function guarded(src, item, data)
    local ok, result = xpcall(beginUse, debug.traceback, src, item, data)
    if not ok then
        if pending[src] then finish(src, pending[src], false, 'needs.useFailed') end
        w.print.error(tostring(result))
        return false
    end
    return result
end
local function current(src, token, stage)
    local p = pending[src]
    -- ! A token the server no longer holds (finished, timed out, never ours) used to return nil
    --   here with no answer, and a client still waiting on it kept hudConsuming up for good:
    --   w_stables' E-mount and care rows and w_pets' follow refuse while it is up. It gets the reset.
    if not p or p.token ~= token then reset(src, token); return nil end
    -- the live use's own token at another stage is a replay: that use ends through its own path
    -- (its next stage, the timeout thread below, or the commit's finish)
    if p.stage ~= stage then return nil end
    if GetGameTimer() > p.expires or not alive(src) or
        p.character ~= exports.w_lib:FwGetCharacterIdentifier(src) then
        finish(src, p, false, 'needs.useCancelled'); return nil
    end
    return p
end
local function onUseEvent(name, callback)
    RegisterNetEvent(name, function(...)
        local src, token = source, ...
        local ok, reason = xpcall(callback, debug.traceback, src, ...)
        if not ok then
            local p = pending[src]
            if p then finish(src, p, false, 'needs.useFailed') end
            -- this event's own token is answered too when the error left another use (or none)
            if not p or p.token ~= token then reset(src, token) end
            w.print.error(('consumable event %s failed for %s: %s'):format(name, src, reason))
        end
    end)
end

exports('GetAnimalFoods', function(src, netId)
    local food = {}
    for item in pairs(Config.AnimalFood or {}) do
        if Config.Consumables[item] and count(src,item)>0 and WHudAnimalUse.validate(src,netId,item) then
            food[#food+1] = {item=item,count=count(src,item),water=Config.AnimalFood[item]=='water'}
        end
    end
    table.sort(food,function(a,b)return a.item<b.item end)
    return food
end)
exports('FeedAnimal', function(src,netId,item)
    if type(item)~='string' or not WHudAnimalUse.validate(src,netId,item) then return false end
    local slot = Inv.name()=='w_inventory' and exports.w_inventory:GetSlotIdWithItem(src,item) or nil
    return guarded(src,item,{slot=slot,targetNetId=netId})
end)
onUseEvent('w_hud:server:selectUse', function(src, token, target, netId)
    local p = current(src, token, 'select')
    if not p then return end
    if target ~= 'player' and target ~= 'horse' and target ~= 'animal' then
        return finish(src, p, false)
    end
    if p.forcedAnimal and (target~='animal' or tonumber(netId)~=p.forcedAnimal) then
        return finish(src,p,false,'needs.targetUnavailable')
    end
    p.target, p.netId = target, tonumber(netId)
    if not validateTarget(src, p) or not sameSlot(src, p) then
        return finish(src, p, false, 'needs.targetUnavailable')
    end
    p.stage, p.started = 'animate', GetGameTimer()
    p.expires = p.started + Config.Use.Timeout
    TriggerClientEvent('w_hud:client:playUse', src, p.item, token, target, p.netId)
end)
onUseEvent('w_hud:server:completeUse', function(src, token, success)
    local p = current(src, token, 'animate')
    if not p then return end
    if success ~= true then return finish(src, p, false, 'needs.useCancelled') end
    if GetGameTimer() - p.started < 700 or not sameSlot(src, p) or not validateTarget(src, p) then
        return finish(src, p, false, 'needs.targetUnavailable')
    end
    -- Close the replay window before exports that might yield.
    p.stage, p.committed = 'commit', GetGameTimer()
    local entry = Config.Consumables[p.item]
    if entry.pack and exports.w_lib:InvCanCarry(src, entry.pack.item, entry.pack.count) ~= true then
        return finish(src, p, false, 'needs.packNoSpace')
    end
    if p.forcedAnimal and (p.target~='animal' or p.netId~=p.forcedAnimal) then return finish(src,p,false) end
    local charge = entry.requirement or (entry.consume ~= false and { item = p.item, count = 1 })
    local removed = not charge or exports.w_lib:InvRemoveItem(src, charge.item, charge.count,
        nil, charge.item == p.item and p.slot or nil) == true
    if not removed then return finish(src, p, false, 'needs.useFailed') end
    local applied = true
    if entry.pack then
        applied = exports.w_lib:InvAddItem(src, entry.pack.item, entry.pack.count) == true
    elseif p.target == 'horse' then
        applied = exports.w_stables:ApplyConsumable(src, p.netId, Config.HorseItems[p.item].effect) == true
    elseif p.target == 'animal' then
        applied = WHudAnimalUse.apply(src, p.netId, p.item) == true
    else
        WNeeds.addMany(src, { hunger = entry.hunger or 0, thirst = entry.thirst or 0 })
        if entry.buff and Config.Systems.buffs then
            WNeeds.giveBuff(src, entry.buff.type, entry.buff.amount or 50)
        end
        WNeeds.save(src)
    end
    if not applied and charge then
        -- A target can disappear during an inventory adapter call. Compensate once.
        local restored = exports.w_lib:InvAddItem(src, charge.item, charge.count,
            charge.item == p.item and p.metadata and json.decode(p.metadata) or nil)
        if restored ~= true then w.print.error(('consumable refund failed: player %s item %s'):format(src, charge.item)) end
    end
    finish(src, p, applied, not applied and 'needs.targetUnavailable' or nil)
end)
AddEventHandler('playerDropped', function() pending[source] = nil end)
CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for src, p in pairs(pending) do
            -- ★ A commit waits on inventory / stables exports and used to be exempt for good: one that
            --   never returned held the use (every later one answered 'busy') and the client's
            --   hudConsuming. Past Config.Use.CommitTimeout it is ended; a late finish finds it gone.
            local hung = p.stage == 'commit' and now - (p.committed or now) > (Config.Use.CommitTimeout or 60000)
            if hung or (p.stage ~= 'commit' and now > p.expires) then
                if hung then w.print.error(('consumable commit hung: player %s item %s'):format(src, p.item)) end
                -- ! pcall: one notice that threw used to end this thread, and every timeout after it
                local ok, problem = pcall(finish, src, p, false, hung and 'needs.useFailed' or 'needs.useCancelled')
                if not ok then w.print.error(('consumable timeout for %s: %s'):format(src, tostring(problem))) end
            end
        end
    end
end)
-- the clients' half stops with us and releases by itself; this answers any use still waiting
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src, p in pairs(pending) do pending[src] = nil; reset(src, p.token) end
end)

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
