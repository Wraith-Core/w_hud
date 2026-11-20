-- ============================================================
-- w_wheel · server/vorp.lua
-- A snapshot of the player's loadout from the VORP inventory
--
-- ═══ Why here and not on the client ═══
--
-- VORP exposes the player's items to the client (getInventoryItems) but never their
-- weapons: getUserInventoryWeapons, getUserAmmo and getWeaponBullets are all **server**
-- exports. So anyone wanting a wheel on VORP has exactly one route -- a call from here.
--
-- And the reference is VORP's documented inventory API, not what is read out of the
-- source. What is not stated there, we do not build on.
--
-- ═══ Why this file goes quiet when our own inventory is running ═══
--
-- w_inventory declares provide 'vorp_inventory', taking over every VORP export. So
-- calling them while running on it would send the snapshot on a full round trip
-- (client -> server -> impersonation -> our inventory) only to come back with less
-- than a single local call gives. The guard below prevents that: this file answers
-- only when VORP really is the inventory.
-- ============================================================

--- Is VORP the source of truth right now?
---@return boolean
local function vorpOwnsInventory()
    return exports.w_lib:InvName() == 'vorp_inventory'
end

--- Turn a callback-style call into a synchronous value, with a time limit.
---
--- ⚠️ The limit is required, not decorative: a callback that is never invoked (an old
--- build, or a player who disconnects mid-call) hangs this thread forever, and with
--- it everyone waiting on its answer.
---@param caller fun(cb: function)
---@return any
local function await1(caller)
    local p = promise.new()
    local done = false

    local function resolve(value)
        if done then return end
        done = true
        p:resolve(value)
    end

    local ok = pcall(caller, resolve)
    if not ok then resolve(nil) end

    SetTimeout(4000, function() resolve(nil) end)

    return Citizen.Await(p)
end

local function flag(value)
    return value == true or value == 1 or value == '1'
end

--- A weapon's ammo in VORP: the ammo table is keyed by type, so the sum is what it carries.
---@param weapon table
---@return number
local function bulletsOf(weapon)
    local ammo = weapon and weapon.ammo

    if type(ammo) == 'table' then
        local total = 0
        for _, amount in pairs(ammo) do total = total + (tonumber(amount) or 0) end
        return math.max(0, math.floor(total))
    end

    return math.max(0, math.floor(tonumber(ammo) or 0))
end

--- Display label: the custom one first, then whatever the item database has, then
--- nothing (the client prettifies the raw name in that case).
---@param weapon table
---@return string?
local function weaponLabel(weapon)
    if type(weapon.custom_label) == 'string' and weapon.custom_label ~= '' then
        return weapon.custom_label
    end

    if type(weapon.label) == 'string' and weapon.label ~= '' then
        return weapon.label
    end
end

-- ════════════════════════════════════════════════════════════════════════════
-- The snapshot
--
-- ★ The slot here is **synthetic**: VORP has no weapon slots, only loadout rows with
--   identifiers. The wheel needs a number to order and address them by, so each weapon
--   gets its number in identifier order -- the same order VORP's own UI shows, so the
--   player never sees two different orderings of one loadout.
--
--   And weaponId travels with it: that is what commands execute against; the slot is
--   for display alone.
-- ════════════════════════════════════════════════════════════════════════════
-- ⚠️ The name follows the resource: w_hud and w_wheel both carry this same file, and
-- registering a callback twice under one name is refused by w_lib, dropping the second silently.
w.callback.register(('%s:vorp:state'):format(GetCurrentResourceName()), function(source)
    local state = { ready = false, weapons = {}, items = {}, oil = nil, dual = { enabled = true, count = 0, slots = {} } }

    if not vorpOwnsInventory() then return state end

    local weapons = await1(function(cb) exports.w_lib:InvNativeCall('getUserInventoryWeapons', source, cb) end)
    local items   = await1(function(cb) exports.w_lib:InvNativeCall('getUserInventoryItems', source, cb) end)

    -- Either may come back nil (a player whose character has not loaded yet) -- a
    -- not-ready snapshot beats an empty one that reads as "owns nothing".
    if type(weapons) ~= 'table' and type(items) ~= 'table' then return state end

    state.ready = true

    local rows = {}

    for _, weapon in pairs(type(weapons) == 'table' and weapons or {}) do
        if type(weapon) == 'table' and type(weapon.name) == 'string' then
            rows[#rows + 1] = weapon
        end
    end

    table.sort(rows, function(a, b)
        return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
    end)

    local dualSlots = {}

    for index = 1, #rows do
        local weapon = rows[index]
        local used   = flag(weapon.used) or flag(weapon.used2)
        local loaded = bulletsOf(weapon)

        state.weapons[index] = {
            slot     = index,                     -- for display and ordering
            weaponId = tonumber(weapon.id),       -- for execution
            name     = tostring(weapon.name):upper(),
            label    = weaponLabel(weapon),
            serial   = weapon.serial_number,
            count    = 1,

            -- filled in on the client: engine natives cannot be read from the server.
            oneHanded = false,
            isGun     = true,
            throwable = false,

            loaded   = loaded,
            capacity = loaded,

            -- What VORP does not have: neutral values rather than invented ones, and
            -- the UI switches them off anyway because caps.condition = false.
            condition        = 100,
            stats            = {},
            damageMultiplier = 1.0,

            held = used,
            -- ⚠️ The hand is decided after the loop: a lone weapon goes in the right
            --    regardless of used2, and you cannot know it is alone until everything
            --    held has been counted.
            hand = flag(weapon.used2) and 0 or 1,
            dualCapable = false, -- the client decides this with IsWeaponOneHanded
        }

        if used then dualSlots[#dualSlots + 1] = index end
    end

    -- ★ VORP marks the right hand with used2, so a held weapon without used2 means
    --   "the second one". But a lone weapon is nobody's second: left on hand 1, the
    --   panel would say "left hand" over a weapon the player sees in their right.
    --   (Same thing the w_gunsmith converter does.)
    if #dualSlots < 2 then
        for i = 1, #state.weapons do
            if state.weapons[i].held then state.weapons[i].hand = 0 end
        end
    end

    state.dual.count = #dualSlots
    state.dual.slots = dualSlots

    -- -- items ------------------------------------------------
    -- ★ Ammo is kept out of the list: its place is under its weapon, not in the items
    --   tab. And VORP names ammo items to a fixed pattern (ammo.../bullet...), so the
    --   name alone is enough.
    local slot = 0

    for _, item in pairs(type(items) == 'table' and items or {}) do
        local name = type(item) == 'table' and item.name

        if type(name) == 'string' and name ~= '' then
            local lower = name:lower()
            local isAmmo = lower:find('^ammo') ~= nil or lower:find('^bullet') ~= nil

            if not isAmmo then
                slot = slot + 1

                state.items[slot] = {
                    slot   = slot,
                    itemId = tonumber(item.id) or tonumber(item.item_crafted_id),
                    name   = name,
                    label  = type(item.label) == 'string' and item.label ~= '' and item.label or nil,
                    count  = math.max(0, math.floor(tonumber(item.count or item.amount) or 0)),
                    usable = true,
                }
            end
        end
    end

    -- Gun oil does not exist in VORP: we say so outright rather than leave it nil and be misread.
    state.oil = { name = 'kit_gun_oil', label = 'Gun Oil', count = 0, required = 1, enabled = false }

    return state
end)

-- (The wheel's server-side "use" fallback used to live here. It relayed the request as
--  a CLIENT event named vorp_inventory:useItem, which vorp never registers - that name
--  is its SERVER event - so it could not work and is gone. The client export is the
--  one route, see client/inventory.lua.)
