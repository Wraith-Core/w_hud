-- ============================================================
-- w_wheel · server/rsg.lua
-- Executing the wheel's commands against the RSG inventory
--
-- ═══ Why a server side for an action requested from the client ═══
--
-- RSG's documentation is explicit: 'All inventory functions should be called from the
-- server-side only. Client-side inventory manipulation is not supported for
-- security reasons.' So there is no client export that equips a weapon at all, and the only
-- official route is:
--
--     RSGCore.Functions.UseItem(source, item)
--
-- And it goes through the very same rsg-inventory path the inventory UI goes through, so it
-- reaches rsg-weapons and draws the weapon or holsters it. That is, the wheel does nothing
-- the inventory does not do itself -- which is exactly what we want.
--
-- ═══ What the client is trusted with ═══
--
-- The slot number alone. And the server reads the item from the **sender's own** inventory
-- (GetItemBySlot on GetPlayer(src)), so no client can use an item it does not own even if it
-- forges the request. And we never accept an item name from the client.
--
-- ⚠️ And the file disables itself when our own inventory is the active one, like its sibling server/vorp.lua.
-- ============================================================

--- Is RSG the source of truth right now?
---@return boolean
local function rsgOwnsInventory()
    return exports.w_lib:InvName() == 'rsg-inventory' and exports.w_lib:FwReady() == true
end

--- The core object, through the library's bridge -- fetched on demand, never cached:
--- the core is replaced when rsg-core restarts and a stored copy becomes an empty shell.
---@return table|nil
local function core()
    return w.framework:getCore()
end

-- ════════════════════════════════════════════════════════════════════════════
-- Using a slot -- equip, holster or eat an item, all in one call
--
-- ★ Because RSG draws no distinction: 'using' a holstered weapon draws it, using it while in
--   hand holsters it, and using food eats it. So the decision comes from the item itself and
--   not from the wheel -- which means any weapon the server adds later works in the wheel
--   without a single line here.
-- ════════════════════════════════════════════════════════════════════════════
RegisterNetEvent(('%s:rsg:useSlot'):format(GetCurrentResourceName()), function(slot)
    local source = source

    if not rsgOwnsInventory() then return end

    slot = tonumber(slot)
    if not slot then return end

    local RSGCore = core()
    if not RSGCore then return end

    -- the player object through the bridge (FwGetUser is GetPlayer on the RSG family)
    local okUser, Player = pcall(function() return exports.w_lib:FwGetUser(source) end)
    if not okUser or type(Player) ~= 'table' then return end

    -- ★ The item is read from the sender's inventory, not from their payload: that is the whole
    --   difference between 'use your slot 3' and 'use what I tell you is in my slot'.
    local ok, item = pcall(function() return Player.Functions.GetItemBySlot(slot) end)

    if not ok or type(item) ~= 'table' or not item.name then return end

    pcall(function() RSGCore.Functions.UseItem(source, item) end)
end)
