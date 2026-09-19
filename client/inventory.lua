-- ============================================================
-- w_wheel · client/inventory.lua
-- The inventory bridge -- where the wheel reads from, and who it sends its orders to
--
-- ═══ Why a bridge at all ═══
--
-- The wheel used to call exports.w_inventory in twelve places in the engine. So anyone
-- running it on the VORP inventory saw nothing but the line 'w_inventory is not started'
-- -- and the wheel is not a part of our inventory; it is a UI fit for any inventory that
-- answers two questions:
--
--     what is the player carrying?   and how do I equip a weapon from it?
--
-- So the file now holds providers that answer those two, and the engine does not know which one answers it.
--
-- ═══ What VORP does not have ═══
--
-- Our inventory stores per weapon **instance**: its own reserve, its condition, and the
-- ammo type chambered in it. VORP stores a weapon with one reserve, no condition and no types.
--
-- So we do not invent what does not exist: caps states what the provider has, and the UI
-- switches off what it does not (the condition bar, the clean button, the ammo switcher)
-- rather than showing a number that is a lie.
-- ============================================================

WheelInv = {}

local provider          -- the active provider (a table from PROVIDERS)
local providerName      -- its name, for diagnostics
local cached            -- the last state we read
local cachedAt = 0

local PROVIDERS = {}

----------------------------------------------------------------
-- Shared helpers
----------------------------------------------------------------

--- A readable label from a raw name, for when the inventory gives us none.
--- WEAPON_REVOLVER_CATTLEMAN → Revolver Cattleman
---@param name string
---@return string
local function prettify(name)
    name = tostring(name or '')

    local stripped = name:gsub('^[Ww][Ee][Aa][Pp][Oo][Nn]_', ''):gsub('_', ' '):lower()
    local out = stripped:gsub('(%a)([%w]*)', function(first, rest)
        return first:upper() .. rest
    end)

    return out ~= '' and out or name
end

WheelInv.prettify = prettify

----------------------------------------------------------------
-- Provider one: w_inventory -- our own
--
-- ★ One call serves the whole wheel (getWeaponWheelState), so nothing is assembled here.
----------------------------------------------------------------

PROVIDERS.w_inventory = {
    resource = 'w_inventory',
    images   = 'w_inventory',

    caps = {
        condition   = true,  -- the condition bar and the clean button
        clean       = true,
        ammoSwitch  = true,  -- per-weapon ammo types
        dual        = true,
        stow        = true,
        slots       = true,  -- real slots the player picks
    },

    ready = function()
        return GetResourceState('w_inventory') == 'started'
    end,

    read = function()
        local ok, state = pcall(function()
            return exports.w_inventory:getWeaponWheelState()
        end)

        if not ok or type(state) ~= 'table' or not state.ready then return nil end
        return state
    end,

    equip = function(weapon)
        local ok, result = pcall(function()
            return exports.w_inventory:selectWeaponSlot(weapon.slot)
        end)

        return ok and result == true
    end,

    --- ═══ Holstering specifically: one hand empties and the other stays as it was ═══
    ---
    --- ★ Deliberately the same call as equipping, not a second path.
    ---
    ---   selectWeaponSlot on a slot that is **already held** hands the job to useSlot,
    ---   which is the full holstering transaction: it suspends the weapon guard for the
    ---   duration, saves the magazine's reserve, releases the GUID, syncs both hands with
    ---   the server, and plays the holster animation.
    ---
    ---   There is a shorter call (w_inventory:disarmSlot) that reaches Weapon.Disarm
    ---   directly -- but it skips suspending the guard and clearing the tracked variables,
    ---   so the guard sees the player 'unarmed' mid-transaction and counts it as an
    ---   external change. The long path is the correct one, and the tested one.
    ---
    --- ★ And where the weapon comes to rest is none of our business: the inventory owns
    ---   the attach-point map and puts the sidearm in its holster and the longarm on the
    ---   back. We ask 'put it away', not 'hang it here'.
    stow = function(weapon)
        -- Already holstered: it is on the body right now (the decorative-copy thread shows
        -- quick-bar slots), and calling selectWeaponSlot on it would **draw** it -- exactly
        -- the opposite of what was asked.
        if not weapon.held then return true end

        local ok, result = pcall(function()
            return exports.w_inventory:selectWeaponSlot(weapon.slot)
        end)

        return ok and result == true
    end,

    useItem = function(item)
        pcall(function() exports.w_inventory:useSlot(item.slot) end)
        return true
    end,

    switchAmmo = function(weapon, ammoItem)
        local ok, result, reason = pcall(function()
            return exports.w_inventory:switchWeaponAmmo(weapon.slot, ammoItem)
        end)

        return ok and result == true, reason
    end,

    clean = function(weapon)
        local response = { ok = false, reason = 'error' }

        pcall(function()
            local begun = exports.w_inventory:beginWeaponInspection(weapon.slot, weapon.name, weapon.serial)

            if type(begun) ~= 'table' or begun.ok ~= true then
                response = type(begun) == 'table' and begun or { ok = false, reason = 'inspect_failed' }
                return
            end

            Wait(250)
            response = exports.w_inventory:cleanInspectedWeapon(weapon.slot, weapon.name, weapon.serial)
                or { ok = false, reason = 'clean_failed' }

            Wait((type(response) == 'table' and response.state and response.state.cleanDuration) or 2800)
            exports.w_inventory:endWeaponInspection()
        end)

        return response
    end,
}

----------------------------------------------------------------
-- Provider two: vorp_inventory
--
-- ═══ Why it goes through the server ═══
--
-- VORP does not expose the player's weapons from the client side at all:
-- getUserInventoryWeapons is a **server** export, and the client has only
-- getInventoryItems (items, no weapons). So a single server call is unavoidable -- and it
-- is the path VORP's own inventory documentation describes.
--
-- ⚠️ But the wheel opens on a keypress and cannot afford to wait for a server reply. So
-- the answer is a cached snapshot: refreshed in the background and on every event that
-- touches the inventory, with the wheel opening on the last thing that arrived and then
-- correcting itself when the reply lands. Worst case: an ammo counter a second stale,
-- rather than a wheel that freezes a whole second on every open.
--
-- ═══ Equipping ═══
--
-- VORP equips through a client export called useWeapon that takes the weapon's row, and
-- it is a toggle: calling it on an equipped weapon holsters it. And if it is missing (an
-- old build) we fall back to the raw event its own UI uses: vorpinventory:setUsedWeapon.
----------------------------------------------------------------

local vorpPending = false

--- Ask the server for a fresh snapshot. Does not block -- it updates `cached` when the reply lands.
local function vorpRefresh()
    if vorpPending then return end
    vorpPending = true

    -- ★ The name follows the resource: w_hud and w_wheel both carry this same file, and a
    --   callback registered under one name in two resources is refused by w_lib
    --   ('Callback already registered') so the second drops silently and never gets a snapshot.
    w.callback.triggerServer(('%s:vorp:state'):format(GetCurrentResourceName()), function(state)
        vorpPending = false

        if type(state) ~= 'table' or not state.ready then return end

        -- What the server does not know is filled in here: engine attributes are readable only on the client.
        for i = 1, #state.weapons do
            local weapon = state.weapons[i]
            local hash   = tonumber(weapon.hash) or joaat(weapon.name)

            local okHanded, oneHanded = pcall(IsWeaponOneHanded, hash)
            local okGun, isGun        = pcall(IsWeaponAGun, hash)

            weapon.hash      = hash
            weapon.oneHanded = okHanded and (oneHanded == true or oneHanded == 1) or false
            weapon.isGun     = okGun and (isGun == true or isGun == 1) or false
            weapon.label     = weapon.label ~= nil and weapon.label ~= '' and weapon.label or prettify(weapon.name)

            -- VORP dual wield: a one-handed firearm, which is the game's own condition.
            weapon.dualCapable = weapon.isGun and weapon.oneHanded
        end

        for i = 1, #state.items do
            local item = state.items[i]
            item.label = item.label ~= nil and item.label ~= '' and item.label or prettify(item.name)
        end

        cached   = state
        cachedAt = GetGameTimer()
    end)
end

PROVIDERS.vorp_inventory = {
    resource = 'vorp_inventory',
    images   = 'vorp_inventory',

    -- ⚠️ Read from VORP's capabilities, not wished for: there is no weapon condition in the
    --   loadout table, no cleaning, and no per-instance ammo type. Switched off, so they vanish from the UI.
    caps = {
        condition   = false,
        clean       = false,
        ammoSwitch  = false,
        dual        = true,
        stow        = true,
        slots       = false, -- no slots: the number is ordinal, computed on every snapshot
    },

    ready = function()
        return GetResourceState('vorp_inventory') == 'started'
    end,

    read = function()
        -- The cached snapshot first, with a background refresh if it has aged.
        if not cached or GetGameTimer() - cachedAt > 1500 then vorpRefresh() end
        return cached
    end,

    equip = function(weapon)
        local sent = pcall(function()
            exports.vorp_inventory:useWeapon({ id = weapon.weaponId, name = weapon.name })
        end)

        if not sent then
            TriggerServerEvent('vorpinventory:setUsedWeapon', weapon.weaponId, true, false)
        end

        vorpRefresh()
        return true
    end,

    --- VORP draws no distinction between 'holster' and 'equip': useWeapon is a toggle.
    --- So holstering is calling it on a held weapon, and nothing on one already holstered.
    stow = function(weapon)
        if not weapon.held then return true end

        local sent = pcall(function()
            exports.vorp_inventory:useWeapon({ id = weapon.weaponId, name = weapon.name })
        end)

        if not sent then
            TriggerServerEvent('vorpinventory:setUsedWeapon', weapon.weaponId, false, false)
        end

        vorpRefresh()
        return true
    end,

    useItem = function(item)
        -- The same payload the inventory UI posts: vorp's server handler reads data.item.
        -- (The old server-side fallback is gone: vorp has no client event to relay a use
        -- through, so it could never have worked.)
        pcall(function()
            exports.vorp_inventory:useItem({ id = item.itemId or item.slot, item = item.name, name = item.name, type = 'item_standard' })
        end)

        vorpRefresh()
        return true
    end,

    switchAmmo = function() return false, 'unsupported' end,
    clean      = function() return { ok = false, reason = 'unsupported' } end,
}

-- Refresh the snapshot on every event that touches the player's loadout -- cheaper than polling.
for _, event in ipairs({
    'vorp_inventory:onWeaponEquipped',
    'vorp_inventory:componentAdded',
    'vorp_inventory:componentRemoved',
    'vorpinventory:loaded',
}) do
    AddEventHandler(event, function()
        if providerName == 'vorp_inventory' then vorpRefresh() end
    end)
end

RegisterNetEvent('vorp_inventory:Client:OnInvStateChange', function(isOpen)
    -- On close only: whatever was swapped inside the inventory must be visible to the wheel afterwards.
    if not isOpen and providerName == 'vorp_inventory' then vorpRefresh() end
end)


----------------------------------------------------------------
-- Provider three: rsg-inventory
--
-- ═══ Why there is no server here ═══
--
-- Unlike VORP, RSG puts the player's inventory in PlayerData on the **client**:
--     RSGCore.Functions.GetPlayerData().items
-- with all its fields (slot, name, amount, info). So reading is local and instant -- no
-- snapshot to wait on and no server call on open.
--
-- ═══ So what does go through the server ═══
--
-- The action alone. RSG's documentation is explicit that all inventory functions are
-- server-side ('server-side only for security reasons'), and the official route is
-- RSGCore.Functions.UseItem(source, item). So we send the slot number and the server reads
-- the item out of the sender's own inventory -- the client is trusted with nothing except
-- 'which slot did you press'.
--
-- ★ And 'using' a weapon in RSG is a toggle: it draws it if holstered and holsters it if
--   in hand -- exactly like VORP. So equipping and holstering are one call.
----------------------------------------------------------------

--- The RSG player data, through the library's bridge (nil on vorp or before the
--- character loads). Read on every call: the core object is replaced on
--- RSGCore:Client:UpdateObject and a cached copy would go stale.
---@return table|nil
local function rsgPlayerData()
    if not w.framework:is('rsg') and not w.framework:is('qbr') then return nil end

    local ok, data = pcall(function() return exports.w_lib:FwGetPlayerData() end)
    return (ok and type(data) == 'table') and data or nil
end

--- The serial of the weapon held right now, from rsg-weapons.
---
--- ★ This is the correct source, not a hash comparison: two weapons of one model share one
---   hash, and 'which of them is in my hand' is never answered by a hash. rsg-weapons
---   tracks the instance by its serial and answers exactly.
---@return string?
local function rsgHeldSerial()
    if GetResourceState('rsg-weapons') ~= 'started' then return nil end

    local ok, serial = pcall(function() return exports['rsg-weapons']:CheckWeaponSerial() end)

    return (ok and type(serial) == 'string' and serial ~= '') and serial or nil
end

--- A fallback for when rsg-weapons is absent: the hash of whatever is in hand.
--- ⚠️ It conflates two identical instances -- which is why it is a fallback, not the basis.
---@return number
local function rsgHeldHash()
    local ok, _, hash = pcall(function() return GetCurrentPedWeapon(cache.ped, true, 0, true) end)

    if ok and hash and hash ~= 0 and hash ~= `WEAPON_UNARMED` then return hash end

    return 0
end

--- An item's image in RSG: the image field carries the filename with its extension, and the UI appends it.
---@param item table
---@return string?
local function rsgImage(item)
    local image = item and item.image

    if type(image) == 'string' and image ~= '' then
        return (image:gsub('%.%a+$', ''))
    end
end

PROVIDERS['rsg-inventory'] = {
    resource = 'rsg-inventory',
    images   = 'rsg-inventory',

    -- ★ Read from RSG's capabilities:
    --   Condition genuinely exists (info.quality, a number from 0 to 100) so it is shown.
    --   Cleaning there is a gunsmith's job (rsg-weapons:server:repairweapon), not a button
    --   in a wheel that consumes oil, so we invent no path for it.
    --   And dual wield is not in rsg-weapons at all.
    caps = {
        condition   = true,
        clean       = false,
        ammoSwitch  = false,
        dual        = false,
        stow        = true,
        slots       = true,  -- real slots (item.slot) the player picks
    },

    ready = function()
        return GetResourceState('rsg-inventory') == 'started' and rsgPlayerData() ~= nil
    end,

    read = function()
        local data = rsgPlayerData()
        if not data or type(data.items) ~= 'table' then return nil end

        local state = {
            ready   = true,
            weapons = {},
            items   = {},
            oil     = { name = 'gunoil', label = locale('wheel.gunOil'), count = 0, required = 1, enabled = false },
            dual    = { enabled = false, count = 0, slots = {} },
        }

        local serial = rsgHeldSerial()
        local hash   = (not serial) and rsgHeldHash() or 0

        for _, item in pairs(data.items) do
            local name = type(item) == 'table' and type(item.name) == 'string' and item.name

            if name then
                local slot   = tonumber(item.slot)
                local info   = type(item.info) == 'table' and item.info or {}
                local amount = math.max(0, math.floor(tonumber(item.amount or item.count) or 0))

                -- A weapon: by type first, by prefix as a fallback -- servers add weapons
                -- without a correct type, and dropping those meant an incomplete wheel.
                local isWeapon = item.type == 'weapon' or name:lower():sub(1, 7) == 'weapon_'

                if isWeapon and slot then
                    local weaponHash = joaat(name)

                    local okHanded, oneHanded = pcall(IsWeaponOneHanded, weaponHash)
                    local okGun, isGun        = pcall(IsWeaponAGun, weaponHash)

                    local loaded = math.max(0, math.floor(tonumber(info.ammo) or 0))

                    state.weapons[#state.weapons + 1] = {
                        slot   = slot,
                        name   = name,
                        label  = item.label or name,
                        image  = rsgImage(item),
                        hash   = weaponHash,
                        serial = info.serie,
                        count  = math.max(1, amount),

                        oneHanded = okHanded and (oneHanded == true or oneHanded == 1) or false,
                        isGun     = okGun and (isGun == true or isGun == 1) or false,
                        throwable = false,

                        loaded   = loaded,
                        capacity = loaded,

                        -- ★ Condition is real here: RSG stores info.quality and lowers it
                        --   with use. We show it as it is and do not round it.
                        condition        = math.max(0, math.min(100, tonumber(info.quality) or 100)),
                        stats            = {},
                        damageMultiplier = 1.0,

                        held = (serial ~= nil and info.serie == serial)
                            or (serial == nil and hash ~= 0 and weaponHash == hash),
                        hand = 0,
                        dualCapable = false, -- rsg-weapons does not carry two weapons
                    }

                elseif slot and amount > 0 then
                    -- ★ Ammo is kept out of the items tab: its place is under its weapon,
                    --   not among the provisions. We mark it with the same field our own
                    --   inventory marks it with (ammoFamily) so the existing filter catches
                    --   it without a new line.
                    local lower = name:lower()
                    local ammo = lower:find('^ammo') ~= nil or lower:find('^bullet') ~= nil

                    state.items[#state.items + 1] = {
                        slot   = slot,
                        name   = name,
                        label  = item.label or name,
                        image  = rsgImage(item),
                        count  = amount,
                        usable = item.useable ~= false,
                        ammoFamily = ammo and lower or nil,
                    }
                end
            end
        end

        table.sort(state.weapons, function(a, b) return a.slot < b.slot end)
        table.sort(state.items, function(a, b) return a.slot < b.slot end)

        local heldSlots = {}
        for i = 1, #state.weapons do
            if state.weapons[i].held then heldSlots[#heldSlots + 1] = state.weapons[i].slot end
        end

        state.dual.count = #heldSlots
        state.dual.slots = heldSlots

        return state
    end,

    --- The server reads the item itself -- we send the slot, not the item.
    equip = function(weapon)
        TriggerServerEvent(('%s:rsg:useSlot'):format(GetCurrentResourceName()), weapon.slot)
        return true
    end,

    --- 'Using' a held weapon in RSG holsters it -- the same call, and the held condition
    --- stops the holster turning into a draw on one already holstered.
    stow = function(weapon)
        if not weapon.held then return true end

        TriggerServerEvent(('%s:rsg:useSlot'):format(GetCurrentResourceName()), weapon.slot)
        return true
    end,

    useItem = function(item)
        TriggerServerEvent(('%s:rsg:useSlot'):format(GetCurrentResourceName()), item.slot)
        return true
    end,

    switchAmmo = function() return false, 'unsupported' end,
    clean      = function() return { ok = false, reason = 'unsupported' } end,
}

----------------------------------------------------------------
-- Detection
----------------------------------------------------------------

local ORDER = { 'w_inventory', 'vorp_inventory', 'rsg-inventory' }

--- Who answers right now? Recomputed on every query, because resources start and stop.
---@return table? provider
local function detect()
    local forced = tostring(Wheel and Wheel.Inventory or 'auto'):lower()

    if forced ~= 'auto' and PROVIDERS[forced] then
        local candidate = PROVIDERS[forced]

        if candidate.ready() then
            providerName = forced
            return candidate
        end

        providerName = nil
        return nil
    end

    for i = 1, #ORDER do
        local name = ORDER[i]

        if PROVIDERS[name].ready() then
            if providerName ~= name then
                providerName = name
                cached, cachedAt = nil, 0
                if name == 'vorp_inventory' then vorpRefresh() end
            end

            return PROVIDERS[name]
        end
    end

    providerName = nil
    return nil
end

----------------------------------------------------------------
-- The interface the engine sees
----------------------------------------------------------------

--- The name of the active inventory (nil if there is none).
function WheelInv.name()
    provider = detect()
    return providerName
end

function WheelInv.ready()
    provider = detect()
    return provider ~= nil
end

-- ════════════════════════════════════════════════════════════════════════════
-- Asset paths -- they follow the active inventory rather than a path written once
--
-- ★ A wheel without icons is not a supported wheel. And every inventory puts its images
--   in its own folder, so a fixed path means eight empty discs on any server not running
--   the inventory whose path was written.
--
--   So images are a candidate list tried in the UI one after another (see ItemImage): the
--   active inventory's folder first, then the rest. And a wrong guess in one folder is
--   skipped without trace -- the image fails and the next is tried.
--
--   Textures and sounds do not belong to any one inventory (the w_crafting set carries them
--   too), so they are taken from the first started resource that has them. And missing all
--   of them breaks nothing: frames without texture and silence instead of a tone.
-- ════════════════════════════════════════════════════════════════════════════

--- The order of fallback candidates after the active inventory's folder.
local IMAGE_FALLBACK_ORDER = { 'w_inventory', 'vorp_inventory', 'rsg-inventory' }

--- The first path in a list whose resource is started.
---@param list table[]
---@return string?
local function firstStarted(list)
    for i = 1, #(list or {}) do
        local entry = list[i]

        if entry and GetResourceState(entry.resource) == 'started' then return entry.path end
    end
end

--- Wheel.Assets, after its paths are resolved against the active inventory.
---@return table
function WheelInv.assets()
    provider = detect()

    local out = {}
    for key, value in pairs(Wheel.Assets or {}) do out[key] = value end

    -- -- images: the active inventory's folder, then the rest as fallbacks --
    local sources = Wheel.ImageSources or {}
    local bases, seen = {}, {}

    --- ⚠️ A stopped resource's folder is not offered: nui:// on it is a guaranteed failed
    --- request, and every failure delays the correct image and fills the console for nothing.
    local function push(name)
        if GetResourceState(name) ~= 'started' then return end

        local list = sources[name] or {}

        for i = 1, #list do
            if not seen[list[i]] then
                seen[list[i]] = true
                bases[#bases + 1] = list[i]
            end
        end
    end

    push(provider and provider.images or '')

    -- ⚠️ From a fixed list, not pairs: the latter guarantees no order, so the fallback
    --    candidates shuffle between one call and the next -- which is what makes an image
    --    fault appear once and vanish the next time.
    for i = 1, #IMAGE_FALLBACK_ORDER do push(IMAGE_FALLBACK_ORDER[i]) end

    if #bases > 0 then out.items = bases end

    out.tex    = firstStarted(Wheel.TexSources) or out.tex
    out.sounds = firstStarted(Wheel.SoundSources) or out.sounds

    return out
end

--- What the current provider has -- the UI switches off what it lacks.
function WheelInv.caps()
    provider = detect()
    return provider and provider.caps
        or { condition = false, clean = false, ammoSwitch = false, dual = false, stow = false, slots = true }
end

--- The full wheel state, or nil if it is not ready.
function WheelInv.state()
    provider = detect()
    if not provider then return nil end

    local state = provider.read()
    if type(state) ~= 'table' or not state.ready then return nil end

    -- Fields a provider may not fill: pinned here so the engine does not test them on every line.
    state.weapons = state.weapons or {}
    state.items   = state.items or {}
    state.dual    = state.dual or { enabled = false, count = 0, slots = {} }

    cached = state
    return state
end

--- The last state read (without a fresh call) -- to turn a slot number into a full row.
function WheelInv.last()
    return cached
end

-- ════════════════════════════════════════════════════════════════════════════
-- A stable weapon key -- what the default is saved against between sessions
--
-- ★ The slot does not work on VORP.
--
--   In our inventory the slot is a real position the player picks and it persists: slot 2
--   today is slot 2 tomorrow. VORP has no weapon slots at all -- only loadout rows with
--   identifiers, and the slot we hand out for display is an ordinal computed per snapshot.
--
--   So saving the default against it would mean buying a new sidearm shifts the whole
--   ordering, and a TAB tap draws a different weapon than the player assigned -- with no
--   message and no reason.
--
--   Hence: on VORP the key is the weapon identifier itself, and with us it stays the slot.
-- ════════════════════════════════════════════════════════════════════════════

---@param weapon table?
---@return string?
function WheelInv.keyOf(weapon)
    if type(weapon) ~= 'table' then return nil end

    if weapon.weaponId ~= nil then return ('id:%s'):format(weapon.weaponId) end
    if weapon.slot ~= nil then return tostring(weapon.slot) end
end

--- The weapon a stored key points at (nil if it is no longer in the inventory).
---@param key any
---@return table? weapon
function WheelInv.weaponByKey(key)
    if not cached or type(key) ~= 'string' then return nil end

    local id = key:match('^id:(.+)$')

    for i = 1, #cached.weapons do
        local weapon = cached.weapons[i]

        if id then
            if tostring(weapon.weaponId) == id then return weapon end
        elseif tostring(weapon.slot) == key then
            return weapon
        end
    end
end

---@param slot any
---@return table? weapon
function WheelInv.weaponBySlot(slot)
    slot = tonumber(slot)
    if not slot or not cached then return nil end

    for i = 1, #cached.weapons do
        if cached.weapons[i].slot == slot then return cached.weapons[i] end
    end
end

---@param slot any
---@return table? item
function WheelInv.itemBySlot(slot)
    slot = tonumber(slot)
    if not slot or not cached then return nil end

    for i = 1, #cached.items do
        if cached.items[i].slot == slot then return cached.items[i] end
    end
end

--- Equip a weapon into the hand.
---@param weapon table a row from state.weapons
---@return boolean
function WheelInv.equip(weapon)
    provider = detect()
    if not provider or type(weapon) ~= 'table' then return false end

    return provider.equip(weapon) == true
end

--- Return a weapon to its holster on the body (without touching the other hand).
---@param weapon table
---@return boolean
function WheelInv.stow(weapon)
    provider = detect()
    if not provider or type(weapon) ~= 'table' then return false end

    return provider.stow(weapon) == true
end

--- Holster everything in both hands.
---
--- ⚠️ Not 'remove all weapons': that drops the weapon off the body entirely. Holstering
--- here is a per-hand transaction, which is why it walks what is held one at a time.
function WheelInv.holsterAll()
    provider = detect()
    if not provider then return end

    local state = WheelInv.state()
    if not state then return end

    for i = 1, #state.weapons do
        if state.weapons[i].held then
            provider.stow(state.weapons[i])
            Wait(60) -- the second hand after the first settles: two transactions, not one
        end
    end
end

---@param item table a row from state.items
function WheelInv.useItem(item)
    provider = detect()
    if not provider or type(item) ~= 'table' then return false end

    return provider.useItem(item) == true
end

---@param weapon table
---@param ammoItem string
---@return boolean ok
---@return string? reason
function WheelInv.switchAmmo(weapon, ammoItem)
    provider = detect()
    if not provider or not provider.caps.ammoSwitch then return false, 'unsupported' end

    return provider.switchAmmo(weapon, ammoItem)
end

---@param weapon table
---@return table response
function WheelInv.clean(weapon)
    provider = detect()
    if not provider or not provider.caps.clean then return { ok = false, reason = 'unsupported' } end

    return provider.clean(weapon)
end

--- Dual wield: two sidearms together.
---
--- ★ The hand order is deliberate: whichever is equipped last lands in the right hand in
---   both inventories, so the left goes first. We ask, we do not execute -- the transaction
---   belongs to the inventory.
---@param right table
---@param left table
function WheelInv.dual(right, left)
    provider = detect()
    if not provider or not provider.caps.dual or not right or not left then return end

    CreateThread(function()
        provider.equip(left)
        Wait(150)
        provider.equip(right)
    end)
end

--- The reason opening failed, in one phrase -- for the line printed to the console.
---@return string
function WheelInv.problem()
    if not WheelInv.ready() then
        return 'no inventory is running (w_inventory, vorp_inventory or rsg-inventory)'
    end

    if providerName == 'vorp_inventory' and not cached then
        return 'vorp_inventory snapshot has not arrived yet -- wait a second and retry'
    end

    return ('%s did not return a ready state -- restart it'):format(tostring(providerName))
end
