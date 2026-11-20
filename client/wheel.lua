-- ============================================================
-- w_hud · client/wheel.lua
-- The weapon wheel -- the engine
--
-- ═══ Why a replacement wheel at all ═══
--
-- RDR3's own wheel reads from the engine's ped: an ammo pool per **type**, not per weapon,
-- with no knowledge of the inventory slot, the weapon's condition, or the ammo types the
-- player owns. So it shows a number shared between two weapons, and cannot tell 'this
-- Cattleman' from 'that Cattleman' -- only the inventory can. (Full explanation in client/ammo.lua.)
--
-- So this wheel reads from w_inventory rather than the engine, in one call:
--     exports.w_inventory:getWeaponWheelState()
--
-- ═══ Why not use the game's wheel and merely dress it up ═══
--
-- No native writes into RDR3's wheel: the official database exposes exactly one reader
-- (_HUD_WEAPON_WHEEL_GET_SELECTED_ITEM_HASH) and no writer beside it. So it is either their
-- wheel as it is, or a wheel of our own. We chose the second, because the first lies to the player.
--
-- ═══ Why SetNuiFocusKeepInput ═══
--
-- The wheel needs a real cursor (mouse selection, as in the game on PC), and full focus
-- freezes the player in place. So we take the cursor and leave the input:
--     SetNuiFocus(true, true) + SetNuiFocusKeepInput(true)
-- then we disable the two look axes every frame, or the camera turns with the mouse.
-- ============================================================

-- ⚠️ The guard is on the table existing, not on it being enabled.
--
-- `not Wheel.Enabled` used to bail out of the whole file, taking /wheeldebug with it --
-- meaning the diagnostic tool existed only while the system worked, and it is never asked
-- for except when it does not. So disabling now silences the behaviour and keeps the
-- diagnostic, which is the first thing the command reports.
if not Wheel then return end

----------------------------------------------------------------
-- State
----------------------------------------------------------------

local isOpen        = false
local pressedAt     = 0
local lastTapAt     = 0
local wasPressed    = false
local pendingTap    = false
local quickSlots    = {}    -- the default weapons, in order
local previousSlot  = nil   -- what was in hand before the quick draw
local busy          = false -- a transaction in flight (cleaning/ammo swap) -- we do not close over it
local lookLockUntil = 0     -- محورا النظر معطَّلان حتّى هذه اللحظة (انظر closeWheel)

--- ★ The default is stored per **character**, not per account: a player with two characters,
--- one with a sidearm and one with a rifle, and a single key would have the second inherit
--- the first's assignment and draw a weapon it does not own.
local characterId = 'default'

local function quickKey()
    return ('wheel:defaults:%s'):format(characterId)
end

--- ★ The target is not always a slot.
---
--- 'Dual wield' and 'fists' are sectors with no inventory slot -- there is no weapon behind
--- them to address by number. Assigning them used to be refused for that reason, even though
--- the most useful thing to assign quickly is drawing both sidearms. So the target is text:
--- a slot number, or 'dual', or 'unarmed'.
---
--- ═══ And why a list rather than a single target ═══
---
--- A going-out kit is not one weapon but a set: a sidearm and a sidearm, or a sidearm and a
--- rifle. The assignment used to be single, so the second cancelled the first. Now right
--- click adds to the list and removes from it, and the quick tap draws them in order.
local function loadQuickSlots()
    quickSlots = {}

    local raw = GetResourceKvpString(quickKey())

    -- A silent upgrade from the old format (a single target as text): whoever played before
    -- this update finds their assignment as they left it, not an empty list for no reason.
    if raw == nil or raw == '' then
        local legacy = GetResourceKvpString(('w_hud:wheel:quick:%s'):format(characterId))
        if legacy ~= nil and legacy ~= '' then quickSlots = { legacy } end
        return
    end

    if raw:sub(1, 1) ~= '[' then
        quickSlots = { raw }
        return
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return end

    for i = 1, #decoded do
        if type(decoded[i]) == 'string' and decoded[i] ~= '' then
            quickSlots[#quickSlots + 1] = decoded[i]
        end
    end
end

local function saveQuickSlots()
    if #quickSlots == 0 then
        DeleteResourceKvp(quickKey())
        return
    end

    SetResourceKvp(quickKey(), json.encode(quickSlots))
end

--- A target's position in the list (0 = not in it).
---@param target string
---@return number
local function quickIndex(target)
    for i = 1, #quickSlots do
        if quickSlots[i] == target then return i end
    end

    return 0
end

--- Right click on an assigned weapon removes it, on any other adds it -- one button for both.
---@param target string
---@return boolean added
local function quickToggle(target)
    local at = quickIndex(target)

    if at > 0 then
        table.remove(quickSlots, at)
        saveQuickSlots()
        return false
    end

    quickSlots[#quickSlots + 1] = target

    -- The cap displaces the oldest rather than refusing the new: a player assigning a third
    -- means it to replace something, and a silent refusal looks like a fault.
    local limit = math.floor(tonumber(Wheel.QuickMax) or 0)

    while limit > 0 and #quickSlots > limit do
        table.remove(quickSlots, 1)
    end

    saveQuickSlots()
    return true
end

-- ⚠️ After the functions are defined, not before: a local referenced above its definition
-- line reads as a global, i.e. nil, and the handler collapses on the first character switch.
local function setCharacter(id)
    characterId  = tostring(id or 'default')
    previousSlot = nil
    loadQuickSlots()
end

exports.w_lib:FwOnCharacterLoaded(function(id)
    if id ~= nil then
        setCharacter(id)
    else
        local ok, pd = pcall(function() return exports.w_lib:FwGetPlayerData() end)
        setCharacter(ok and pd and pd.citizenid or nil)
    end
end)

----------------------------------------------------------------
-- Reading the inventory and building the sectors
----------------------------------------------------------------

--- Is there an inventory answering? (ours or VORP's -- the bridge detects on its own)
local function inventoryReady()
    return WheelInv.ready()
end

local function readInventory()
    return WheelInv.state()
end

--- Is this slot inside the wheel's range (the quick bar)?
---@param slot any
---@return boolean
local function inSlotRange(slot)
    local range = Wheel.SlotRange
    if not range then return true end

    -- ★ An inventory with no real slots (VORP): the number you see here is not a position
    --   the player chose, but an ordering computed per snapshot from loadout row identifiers.
    --   So cutting it at 'the first five' hides weapons for a reason the player cannot
    --   understand and has no way to change -- there is no quick bar for them to reorder.
    --
    --   So the range applies to whoever has slots, and is bypassed for whoever has not.
    if WheelInv.caps().slots == false then return true end

    slot = tonumber(slot)
    if not slot then return false end

    return slot >= (range.min or 1) and slot <= (range.max or 5)
end

local function matchesAny(name, list)
    if not list then return false end
    name = tostring(name or ''):lower()

    for i = 1, #list do
        if name:find(tostring(list[i]):lower(), 1, true) then return true end
    end

    return false
end

--- The weapons that enter the wheel, ordered by slot, with their class and stats.
---
--- ★ The quick bar alone: what is not placed in a slot within Wheel.SlotRange is not equipped
---   gear and has no place in the wheel -- as in RDR2.
---@param state table
---@return table[] weapons
local function wheelWeapons(state)
    local out = {}

    for i = 1, #state.weapons do
        local weapon = state.weapons[i]

        if inSlotRange(weapon.slot) then
            weapon.class  = Wheel.ClassOf(weapon)
            weapon.stats0 = Wheel.StatsOf(weapon)
            weapon.stowed = nil

            -- ★ Its position in the default list (0 = not in it) is computed here, not in the
            --   UI: the stored key may be a slot or a weapon identifier depending on the
            --   inventory, and the UI must neither know the difference nor parse text.
            weapon.quick = quickIndex(WheelInv.keyOf(weapon))

            out[#out + 1] = weapon
        end
    end

    -- The slot is the ordering, and it alone: any other key makes the wheel re-arrange its
    -- icons between one opening and the next for a reason the player cannot see.
    table.sort(out, function(a, b) return a.slot < b.slot end)

    return out
end

--- The carry cap per class: whatever exceeds it is marked 'on the horse' and shown dimmed --
--- never removed. Removing it meant a weapon in your bag that you never see in the wheel.
---@param weapons table[]
local function markStowed(weapons)
    local seen = {}

    for i = 1, #weapons do
        local weapon = weapons[i]
        local limit  = Wheel.CarryLimits[weapon.class]

        seen[weapon.class] = (seen[weapon.class] or 0) + 1

        if limit and limit > 0 and seen[weapon.class] > limit then
            weapon.stowed = true
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════
-- Layout one: by slot -- the first sector for the first weapon
--
-- ★ Why this became the default:
--   Distribution by class knows where each weapon 'should' sit (right holster, back,
--   shoulder), but the player does not: they put their sidearm in the first slot and find it
--   at the bottom right of the wheel, then add a second and the first jumps position. So they
--   had to scan every sector.
--
--   By slot: what is on the quick bar is what is in the wheel, in the same sequence. They
--   learn it once and then stop looking -- which is the entire point of a wheel opened for
--   the space of a second in a firefight.
--
-- ★ And interleaved items shift nothing: the count is over weapons, not over slot numbers. A
--   slot holding bread between two sidearms => the two sidearms are adjacent in the wheel.
--   (Which is what wheelWeapons already does: filter, then sort.)
--
-- ⚠️ The extras (fists and dual wield) go **after** the last weapon, not at a fixed angle: a
--   fixed angle means a hole in the sequence that the count jumps over, which is exactly what
--   we came to remove. Whoever wants a wheel without extras empties Wheel.OrderExtras.
-- ════════════════════════════════════════════════════════════════════════════

---@param weapons table[]
---@return string[] roles  each sector's role, in wheel order
---@return table byRole
local function layoutBySlot(weapons)
    local roles, byRole = {}, {}
    local total = #Wheel.Sectors
    local at = 0
    local last

    for i = 1, #weapons do
        if at < total then
            at = at + 1
            local role = ('slot%d'):format(at)

            roles[at]    = role
            byRole[role] = { role = role, options = { weapons[i] }, cursor = 1 }
            last         = byRole[role]
        elseif last then
            -- ★ More weapons than the wheel has sectors (a slot range widened past eight):
            --   they stack on the last sector and are cycled with the mouse wheel, showing a
            --   '3/5' counter. Which is less bad than the alternative: vanishing without trace
            --   and without a line saying they vanished -- a weapon in your bag you never see.
            last.options[#last.options + 1] = weapons[i]
        end
    end

    -- The cursor lands on the held weapon if it is in the stack: what is in your hand must show first.
    if last then
        for i = 1, #last.options do
            if last.options[i].held then last.cursor = i break end
        end
    end

    -- ★ An extra the inventory does not support is not drawn: rsg-weapons does not carry two
    --   weapons, so the 'dual wield' sector on it is an **always** empty slot -- it never
    --   fills and does nothing when pressed. Removing it frees a place for a real weapon.
    local caps = WheelInv.caps()

    for i = 1, #(Wheel.OrderExtras or {}) do
        local extra = tostring(Wheel.OrderExtras[i])

        if at >= total then break end

        if extra ~= 'dual' or caps.dual then
            at = at + 1
            roles[at] = extra
        end
    end

    -- The rest are empty slots. A unique name for each so two empties do not share a cursor.
    for i = at + 1, total do
        roles[i] = ('empty%d'):format(i)
    end

    return roles, byRole
end

-- ════════════════════════════════════════════════════════════════════════════
-- Layout two: by class -- fixed roles as in RDR2
--
-- ★ Kept exactly as it was for whoever wants it (Wheel.Order = 'class'). Nothing of it was
--   removed; it simply became an option after having been the only road.
--
--   Every weapon takes its class's sector, and the overflow drops to the first **free** sector
--   in wheel order. Nothing stacks unless the whole wheel is full.
-- ════════════════════════════════════════════════════════════════════════════

---@param weapons table[]
---@return string[] roles
---@return table byRole
local function layoutByClass(weapons)
    local buckets = {}

    for i = 1, #weapons do
        local weapon = weapons[i]
        local bucket = buckets[weapon.class]

        if not bucket then bucket = {}; buckets[weapon.class] = bucket end
        bucket[#bucket + 1] = weapon
    end

    -- Held first, then hand, then slot -- an ordering stable between openings.
    for _, bucket in pairs(buckets) do
        table.sort(bucket, function(a, b)
            if a.held ~= b.held then return a.held end
            if a.hand ~= b.hand then return a.hand < b.hand end
            return a.slot < b.slot
        end)
    end

    local byRole    = {}
    local leftovers = {}

    local function place(role, option)
        byRole[role] = { role = role, options = { option }, cursor = 1 }
    end

    -- 1) the class sector: the first for its first sector, the second for the second... no cycling
    --
    -- ⚠️ In Wheel.ClassOrder order, not pairs: the latter guarantees no order, and two sectors
    --    are shared by two classes -- so a weapon's position shifts between openings for no reason.
    for c = 1, #Wheel.ClassOrder do
        local class   = Wheel.ClassOrder[c]
        local targets = Wheel.ClassSectors[class]
        local bucket  = buckets[class]

        if bucket and targets then
            for i = 1, #bucket do
                local option = bucket[i]
                local role   = targets[i]

                -- A sector shared by two classes (lasso and throwables): if another got there
                -- first, this is overflow looking for another place.
                if role and not byRole[role] then
                    place(role, option)
                else
                    leftovers[#leftovers + 1] = option
                end
            end
        end
    end

    -- 2) overflow -> the first free sector in wheel order
    --
    -- ⚠️ Except 'dual' and 'unarmed': they are not weapon slots but commands, and putting a
    --    sidearm where the fists were means deleting 'unarmed' from the wheel.
    local free = {}

    for i = 1, #Wheel.Sectors do
        local role = Wheel.Sectors[i].role

        if role ~= 'dual' and role ~= 'unarmed' and not byRole[role] then
            free[#free + 1] = role
        end
    end

    local next_free = 1

    for i = 1, #leftovers do
        local option = leftovers[i]
        local role   = free[next_free]

        if role then
            place(role, option)
            next_free = next_free + 1
        else
            -- 3) the wheel is full: only then does it stack in its class's sector
            local home = Wheel.ClassSectors[option.class]
            local list = home and home[1] and byRole[home[1]]

            if list then list.options[#list.options + 1] = option end
        end
    end

    -- The cursor inside each sector starts on the held weapon if there is one.
    for _, list in pairs(byRole) do
        for i = 1, #list.options do
            if list.options[i].held then list.cursor = i break end
        end
    end

    local roles = {}

    for i = 1, #Wheel.Sectors do
        roles[i] = Wheel.Sectors[i].role
    end

    return roles, byRole
end

--- Distributing the weapons over the eight sectors.
---@param state table
---@return table sectors
---@return table byRole
local function buildSectors(state)
    local weapons = wheelWeapons(state)
    local ordered = tostring(Wheel.Order or 'slot'):lower() ~= 'class'

    markStowed(weapons)

    local roles, byRole

    if ordered then
        roles, byRole = layoutBySlot(weapons)
    else
        roles, byRole = layoutByClass(weapons)
    end

    local sectors = {}

    for i = 1, #Wheel.Sectors do
        local def  = Wheel.Sectors[i]
        local role = roles[i] or def.role
        local list = byRole[role]

        sectors[i] = {
            index   = i,
            role    = role,
            angle   = def.angle,
            sweep   = def.sweep,
            -- ★ The card symbol and the attach point belong to the class roles (right/left
            --   holster, back/shoulder). Under slot ordering they mean nothing so they are not
            --   sent: a badge saying 'left holster' over a weapon that was never put in a left
            --   holster is a small lie that costs you trust in every other badge.
            suit    = (not ordered) and def.suit or nil,
            mount   = (not ordered) and def.mount or nil,
            cursor  = list and list.cursor or 1,
            options = list and list.options or {},
        }
    end

    return sectors, byRole
end

--- The payload the UI sees.
local function payload(state, sectors, tab, items)
    return {
        action  = 'wheel:open',
        tab     = tab,
        sectors = sectors,
        items   = items,
        oil     = state.oil,
        dual    = state.dual,
        quick   = quickSlots,
        assets  = WheelInv.assets(),
        text    = Wheel.Text(), -- from locales/{ar,en}.json, in the player's language
        order   = Wheel.StatOrder,
        ability = Wheel.AbilityLoadout.enabled or false,
        rtl     = WHudLocale.rtl(),

        -- ★ What the active inventory supports. The UI hides what it lacks (the condition bar,
        --   the clean button, the ammo switcher) rather than drawing a button that does nothing.
        caps    = WheelInv.caps(),
        bag     = WheelInv.name() or 'none',
        stows   = tostring(Wheel.LeftClick or 'stow'):lower() == 'stow',
        stowShut = Wheel.LeftClickCloses == true,
    }
end

----------------------------------------------------------------
-- Opening and closing
----------------------------------------------------------------

local currentTab = 'weapons'

--- A horse **registered to you with a satchel**?
---
--- ★ horseUUID in the entity's statebag is the marker, and not a judgement call of ours: the
---   inventory itself requires it before opening a horse satchel and bails without it ('the
---   horse is not part of our system'). So what the inventory will not open a satchel for does
---   not deserve a tab in the wheel.
---@param horse number
---@return boolean
local function horseHasStorage(horse)
    if not Wheel.HorseRequiresStorage then return true end
    if not horse or horse == 0 or not DoesEntityExist(horse) or not NetworkGetEntityIsNetworked(horse) then return false end

    local ok, uuid = pcall(function() return w.entity.getState(horse, 'horseUUID') end)

    return ok and uuid ~= nil and uuid ~= false
end

--- 'Near the horse' in the game's sense: riding it, or standing beside the last one you rode.
--- ⚠️ GetLastMount may return a deleted entity (swapped/dismissed), so an existence check is required.
local function nearHorse()
    if not Wheel.HorseTab then return false end

    local horse = GetMount(cache.ped)
    local mounted = IsPedOnMount(cache.ped)

    if not horse or horse == 0 or not DoesEntityExist(horse) then
        horse = GetLastMount(cache.ped)
        mounted = false
    end

    if not horse or horse == 0 or not DoesEntityExist(horse) then return false end
    if not horseHasStorage(horse) then return false end

    if mounted then return true end

    return #(GetEntityCoords(cache.ped) - GetEntityCoords(horse)) <= Wheel.HorseDistance
end

--- The items of a given tab -- eight in order: those named explicitly, then those matching by
--- pattern, then the most numerous if the config allows.
---@param state table
---@param tab string
---@return table[]
local function collectItems(state, tab)
    local rules = tab == 'horse' and Wheel.HorseWheel or Wheel.ItemWheel
    local slots = #Wheel.Sectors

    -- ═══ Slot ordering ═══
    --
    -- ★ Same principle as the weapons: the first slot in the first sector. The list used to be
    --   built by rules (explicitly named, then pattern-matched, then most numerous) -- an order
    --   the player does not see in their bag, so it looks random, and it shifts whenever the
    --   count of what they carry changes. So the default became what they understand unexplained.
    --
    -- ⚠️ And ammo is out of the tab either way: its place is under its weapon in the ammo switcher.
    if tab ~= 'horse' and tostring(Wheel.ItemsOrder or 'slot'):lower() == 'slot' then
        local ordered = {}

        for i = 1, #state.items do
            local item = state.items[i]

            if inSlotRange(item.slot) and not item.ammoFamily
                and not matchesAny(item.name, rules.exclude) then
                ordered[#ordered + 1] = item
            end
        end

        table.sort(ordered, function(a, b) return a.slot < b.slot end)

        while #ordered > slots do table.remove(ordered) end

        return ordered
    end

    local byName, taken, out = {}, {}, {}

    for i = 1, #state.items do
        local item = state.items[i]

        -- The quick bar alone here too, and ammo out of the tab: its place is under its weapon
        -- in the ammo switcher, not in the items wheel.
        if inSlotRange(item.slot) and not item.ammoFamily
            and not matchesAny(item.name, rules.exclude) then
            byName[item.name] = byName[item.name] or item
        end
    end

    local function push(item)
        if not item or taken[item.slot] or #out >= slots then return end
        taken[item.slot] = true
        out[#out + 1] = item
    end

    for i = 1, #(rules.include or {}) do push(byName[rules.include[i]]) end

    for i = 1, #state.items do
        local item = state.items[i]
        if byName[item.name] == item and matchesAny(item.name, rules.prefixes) then push(item) end
    end

    if rules.fallback and #out < slots then
        local rest = {}

        for i = 1, #state.items do
            local item = state.items[i]
            if byName[item.name] == item and not taken[item.slot] then rest[#rest + 1] = item end
        end

        table.sort(rest, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.slot < b.slot
        end)

        for i = 1, #rest do push(rest[i]) end
    end

    return out
end

local function refresh()
    local state = readInventory()
    if not state then return false end

    local sectors = buildSectors(state)
    local items   = collectItems(state, currentTab)

    SendNUIMessage(payload(state, sectors, currentTab, items))
    return true
end

--- ⚠️ Failure here used to be silent: you hold the key, nothing happens, and not a line in the
--- console -- so the server owner has nothing to diagnose with. Now it says why.
-- ════════════════════════════════════════════════════════════════════════════
-- The screen effect when the wheel opens
--
-- ★ From the game, not from the UI. wheel.css used to lay two black sheets over the scene, a
--   pale imitation of what the engine does: saturation, blur and depth of field alongside the
--   time dilation. And the difference is that the engine's effect sits **behind** our UI so it
--   does not darken it too, whereas the CSS layer was dimming the wheel itself.
--
-- ⚠️ The name differs between RDR3 builds, so we try a list and settle on the first accepted.
--   And if none is accepted, the time dilation remains alone -- nothing breaks.
-- ════════════════════════════════════════════════════════════════════════════
local WHEEL_FX_CANDIDATES = { 'WheelHUDIn', 'PlayerAbilityDeadEye', 'MP_Downed' }
local wheelFx = nil

local function startWheelFx()
    if wheelFx then return end

    for i = 1, #WHEEL_FX_CANDIDATES do
        local name = WHEEL_FX_CANDIDATES[i]
        local ok = pcall(function() AnimpostfxPlay(name) end)

        if ok and Citizen.InvokeNative(0x4A123E85D7C4CA0B, name) then
            wheelFx = name
            return
        end

        pcall(function() AnimpostfxStop(name) end)
    end
end

local function stopWheelFx()
    if not wheelFx then return end
    pcall(function() AnimpostfxStop(wheelFx) end)
    wheelFx = nil
end

----------------------------------------------------------------
-- The wheel's prompts -- drawn by the library, not by the wheel's own UI
--
-- ★ One look for every prompt on the server: the group below is a w.prompt group (the
--   library's NUI prompt cards), shown while the wheel is open and hidden with it. The keys
--   are read by the library itself and arrive through w_lib:promptCompleted; the wheel never
--   polls a key for them. The UI owns the selection (which weapon is under the cursor), so
--   the keyboard actions are handed to it as one message (`wheel:key`), and it answers with
--   what the group should show (`wheel:prompts`) whenever the selection changes.
--
--   LBUTTON / RBUTTON are shown for what a click on a sector does (holster / set default);
--   the click itself is handled by the UI because it needs the sector under the cursor.
----------------------------------------------------------------

--- key -> dictionary key of its label, in display order
local WHEEL_PROMPTS = {
    { key = 'R',       label = 'wheel.tabSwitch' },
    { key = 'LEFT',    label = 'wheel.ammoPrev' },
    { key = 'RIGHT',   label = 'wheel.ammoNext' },
    { key = 'SPACE',   label = 'wheel.ability' },
    { key = 'LBUTTON', label = 'wheel.stow' },
    { key = 'RBUTTON', label = 'wheel.quickAdd' },
    { key = 'ESCAPE',  label = 'wheel.close' },
}

local promptGroup = nil

local function wheelPrompts()
    if promptGroup then return promptGroup end

    promptGroup = w.prompt.createGroup(false, 'bottom-right')

    for i = 1, #WHEEL_PROMPTS do
        promptGroup.addPrompt(WHEEL_PROMPTS[i].key, locale(WHEEL_PROMPTS[i].label), false)
    end

    return promptGroup
end

--- Which rows are shown. What the UI cannot do right now is not drawn -- as before, when the
--- wheel drew its own hints.
---@param state { ammo?: boolean, ability?: boolean, stow?: boolean }
local function setWheelPrompts(state)
    local group = wheelPrompts()

    if state.ammo ~= nil then
        group.setVisible('LEFT', state.ammo == true)
        group.setVisible('RIGHT', state.ammo == true)
    end

    if state.ability ~= nil then group.setVisible('SPACE', state.ability == true) end
    if state.stow ~= nil then group.setVisible('LBUTTON', state.stow == true) end
end

local function showWheelPrompts()
    local caps = WheelInv.caps() or {}

    -- the ammo rows wait for the UI: nothing is under the cursor at the moment of opening
    setWheelPrompts({
        ammo    = false,
        ability = Wheel.AbilityLoadout.enabled == true,
        stow    = currentTab == 'weapons'
            and tostring(Wheel.LeftClick or 'stow'):lower() == 'stow'
            and caps.stow == true,
    })

    wheelPrompts().display()
end

local function hideWheelPrompts()
    if promptGroup then promptGroup.hide() end
end

local function openWheel()
    if isOpen then return end

    local state = readInventory()

    if not state then
        w.print.warn(('wheel could not open: %s'):format(WheelInv.problem()))
        return
    end

    isOpen = true
    startWheelFx()
    if currentTab == 'horse' and not nearHorse() then currentTab = 'weapons' end

    local sectors = buildSectors(state)
    SendNUIMessage(payload(state, sectors, currentTab, collectItems(state, currentTab)))

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    showWheelPrompts()

    -- Time dilation -- local, touching nobody else. And we skip it in combat so it is not an advantage.
    local scale = Wheel.TimeScale

    if IsPedInCombat(cache.ped, 0) or IsPedShooting(cache.ped) then
        scale = Wheel.TimeScaleInCombat
    end

    if scale and scale < 1.0 then SetTimeScale(scale + 0.0) end
end

local function closeWheel(commit)
    if not isOpen then return end

    isOpen = false
    stopWheelFx()

    -- ★ قبل تحرير التركيز لا بعده: فرقُ الماوس المتراكم يصل إلى المحرّك في
    --   أوّل إطارٍ بعد التحرير، فلا بدّ أن يكون القفل قائماً قبله. وضعُه بعد
    --   السطر التالي يترك إطاراً واحداً مكشوفاً — وهو الإطار الذي تقفز فيه
    --   الكاميرا.
    lookLockUntil = GetGameTimer() + math.max(0, math.floor(tonumber(Wheel.LookLockAfterClose) or 0))

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SetTimeScale(1.0)
    hideWheelPrompts()
    SendNUIMessage({ action = 'wheel:close', commit = commit and true or false })
end

-- ── the group's handlers (after closeWheel: ESCAPE closes the wheel) ──────────────────

-- the UI reports what the selection allows (ammo switching, holstering)
RegisterNUICallback('wheel:prompts', function(data, cb)
    if isOpen and type(data) == 'table' then setWheelPrompts(data) end
    cb({ ok = true })
end)

-- a key of the group completed: ESCAPE closes here, the rest go to the UI (it owns the selection)
AddEventHandler('w_lib:promptCompleted', function(id, key)
    if not isOpen or not promptGroup or id ~= promptGroup.id then return end

    if key == 'ESCAPE' then return closeWheel(false) end

    if key == 'R' or key == 'LEFT' or key == 'RIGHT' or key == 'SPACE' then
        SendNUIMessage({ action = 'wheel:key', key = key })
    end
end)

-- a language switch from /w_lib relabels the group (the dictionary is reloaded by
-- client/metabolism.lua, whose handler runs before this one)
AddEventHandler('w_lib:setLocale', function()
    if not promptGroup then return end

    for i = 1, #WHEEL_PROMPTS do
        promptGroup.setLabel(WHEEL_PROMPTS[i].key, locale(WHEEL_PROMPTS[i].label))
    end
end)

----------------------------------------------------------------
-- Execution -- every action goes through the inventory; nothing is done to the ped directly here
----------------------------------------------------------------

--- Equip a slot into the hand. The slot is a number, and the bridge translates it to an inventory row.
local function equipSlot(slot)
    local weapon = WheelInv.weaponBySlot(slot)
    if not weapon then return false end

    return WheelInv.equip(weapon)
end

--- ═══ Single holster -- left click ═══
---
--- ★ The difference from holsterAll: this returns **one weapon** to its holster and leaves the
---   other hand as it is. So someone carrying two sidearms who wants to put one away is not
---   forced to put both away and draw one again.
---
--- ★ And where the weapon comes to rest is none of our business: the inventory hangs each
---   weapon in its place (the sidearm in its belt holster, the longarm on the back) -- it owns
---   the attach-point map. We ask 'put it away', not 'hang it here'.
---@param slot any
---@return boolean
local function stowSlot(slot)
    local weapon = WheelInv.weaponBySlot(slot)
    if not weapon then return false end

    return WheelInv.stow(weapon)
end

--- Holster what is in hand.
---
--- ⚠️ Not clearWeapons: that is a full wipe (RemoveAllPedWeapons) built for death and character
--- cleanup, not for putting a weapon in its holster. It passes noAnim so there is no holster
--- animation, and it drops every weapon off the body at once.
---
--- The correct route is the inventory's own: 'using' an already-equipped weapon un-equips it
--- (w_inventory/client.lua:870) -- a full holster transaction with its animation and its slot
--- ammo accounting, and per hand.
local function holsterAll()
    WheelInv.holsterAll()
    previousSlot = nil
end

--- Dual wield: we equip both holster sidearms together.
--- The inventory owns the transaction (a GUID per instance) -- we ask, we do not execute.
local function equipDual(rightSlot, leftSlot)
    local right = WheelInv.weaponBySlot(rightSlot)
    local left  = WheelInv.weaponBySlot(leftSlot)

    if not right or not left then return end

    -- The bridge opens its own thread: there is a Wait between the hands, and an NUI call cannot be held.
    WheelInv.dual(right, left)
end

----------------------------------------------------------------
-- UI callbacks
----------------------------------------------------------------

-- ⚠️ Every command touching a weapon runs in its own thread and replies at once: inventory
-- transactions contain Waits and server calls, and holding the NUI call for their duration
-- freezes the UI under the player's hand -- and the wheel closes at that very moment, so the
-- freeze looks like a fault.
RegisterNUICallback('wheel:equip', function(data, cb)
    local slot = data and data.slot
    CreateThread(function() equipSlot(slot) end)
    cb({ ok = true })
end)

--- Left click: the weapon to its holster on the body, and the other hand is untouched.
RegisterNUICallback('wheel:stow', function(data, cb)
    local slot = data and data.slot
    CreateThread(function() stowSlot(slot) end)
    cb({ ok = true })
end)

RegisterNUICallback('wheel:unarmed', function(_, cb)
    CreateThread(holsterAll)
    cb({ ok = true })
end)

RegisterNUICallback('wheel:dual', function(data, cb)
    equipDual(data and tonumber(data.right), data and tonumber(data.left))
    cb({ ok = true })
end)

RegisterNUICallback('wheel:ammo', function(data, cb)
    local slot, item = data and tonumber(data.slot), data and data.item
    local weapon = slot and WheelInv.weaponBySlot(slot)

    if not weapon or type(item) ~= 'string' then
        return cb({ ok = false })
    end

    busy = true

    CreateThread(function()
        local ok, reason = WheelInv.switchAmmo(weapon, item)

        busy = false

        -- The wheel is open during the swap, so it is re-read rather than left as a stale picture.
        if ok and isOpen then refresh() end

        cb({ ok = ok, reason = reason })
    end)
end)

RegisterNUICallback('wheel:quick', function(data, cb)
    -- role for sectors with no slot ('dual' / 'unarmed'), and otherwise the stable weapon key
    -- the bridge computes (a slot with us, a loadout identifier on VORP).
    local target = data and (data.role or WheelInv.keyOf(WheelInv.weaponBySlot(data.slot)))

    if not target then return cb({ ok = false, quick = quickSlots }) end

    local added = quickToggle(target)

    -- ★ 'Default' means: this is my going-out weapon -- so let it be on my body, not at the
    --   bottom of the bag. So assigning it lowers it into its holster if it was in hand, and
    --   there the player sees it on their belt or their back. Which is what the intended
    --   behaviour describes: you assign it, you see it on you, then one TAB tap draws it.
    if added and Wheel.QuickStowsOnAssign and data.slot then
        CreateThread(function() stowSlot(data.slot) end)
    end

    -- ★ The redraw is required: the default badge is read from weapon.quick in the payload, so
    --   without a fresh snapshot the weapon stays unbadged until the next opening -- and the
    --   player reads that as 'right click did not work' and presses again, unassigning it.
    if isOpen and not busy then refresh() end

    cb({ ok = true, quick = quickSlots, added = added })
end)

RegisterNUICallback('wheel:tab', function(data, cb)
    local tab = data and tostring(data.tab or 'weapons')

    if tab == 'horse' and not nearHorse() then tab = 'weapons' end
    currentTab = tab

    refresh()
    cb({ ok = true, tab = currentTab })
end)

RegisterNUICallback('wheel:useItem', function(data, cb)
    local item = data and WheelInv.itemBySlot(data.slot)

    closeWheel(true)

    if item then
        CreateThread(function() WheelInv.useItem(item) end)
    end

    cb({ ok = true })
end)

--- Cleaning -- inspect, then clean, then finish, and the server decides at every step.
RegisterNUICallback('wheel:clean', function(data, cb)
    local slot   = data and tonumber(data.slot)
    local weapon = slot and WheelInv.weaponBySlot(slot)

    if not Wheel.AllowCleaning or not weapon or not WheelInv.caps().clean then
        return cb({ ok = false, reason = 'disabled' })
    end

    busy = true

    -- The wheel closes first: inspection in RDR3 is a full motion task on the player, and is
    -- not run with a screen over it.
    closeWheel(true)

    -- ⚠️ In its own thread: the transaction contains waits measured in seconds (two server calls
    -- and the cleaning animation), and holding the NUI call that long freezes the UI.
    CreateThread(function()
        local response = WheelInv.clean(weapon)

        busy = false
        cb(type(response) == 'table' and response or { ok = false, reason = 'error' })
    end)
end)

RegisterNUICallback('wheel:close', function(_, cb)
    closeWheel(false)
    cb({ ok = true })
end)

RegisterNUICallback('wheel:ability', function(_, cb)
    if Wheel.AbilityLoadout.enabled and Wheel.AbilityLoadout.event then
        closeWheel(true)
        TriggerEvent(Wheel.AbilityLoadout.event)
    end

    cb({ ok = true })
end)

----------------------------------------------------------------
-- Quick select
----------------------------------------------------------------

--- The first two sidearms eligible for dual wield -- for the 'dual' target.
---@param state table
---@return number? right
---@return number? left
local function dualPair(state)
    local found = {}

    for i = 1, #state.weapons do
        local weapon = state.weapons[i]

        if weapon.dualCapable and Wheel.ClassOf(weapon) == 'sidearm' then
            found[#found + 1] = weapon.slot
            if #found == 2 then break end
        end
    end

    return found[1], found[2]
end

-- ════════════════════════════════════════════════════════════════════════════
-- Quick draw -- a single TAB tap
--
-- ═══ What changed ═══
--
-- The target used to be single: a tap drew it, a second tap went back to what preceded it. Now
-- it is a list: one tap draws the whole default in order -- a sidearm and a sidearm, or a
-- sidearm and a rifle -- and a second tap while it is in your hand puts it back.
--
-- ★ And why 'is it already in my hand' is a condition and not decoration: without it the second
--   tap re-equips what is already equipped -- a full holster-and-draw animation to no effect,
--   which reads as 'the weapon dances in my hand every time I press'.
-- ════════════════════════════════════════════════════════════════════════════

--- The slots held right now.
---@param state table
---@return table<number, boolean>
local function heldSet(state)
    local held = {}

    for i = 1, #state.weapons do
        if state.weapons[i].held then held[state.weapons[i].slot] = true end
    end

    return held
end

--- The default slots still pointing at a weapon in the bag, in order and without duplicates.
---@return number[]
local function quickTargets()
    local out, seen = {}, {}

    for i = 1, #quickSlots do
        local weapon = WheelInv.weaponByKey(quickSlots[i])

        -- ★ A weapon assigned then sold or moved to a stash: skipped silently and kept in the
        --   list. Removing it here meant depositing a weapon and withdrawing it lost its assignment.
        if weapon and not seen[weapon.slot] then
            seen[weapon.slot] = true
            out[#out + 1] = weapon.slot
        end
    end

    return out
end

local function quickSelect()
    if not Wheel.QuickSelect or #quickSlots == 0 then return end

    local state = readInventory()
    if not state then return end

    local held = heldSet(state)

    local heldSlot
    for i = 1, #state.weapons do
        if state.weapons[i].held then heldSlot = state.weapons[i].slot break end
    end

    -- ═══ The two slotless targets ═══
    --
    -- ★ 'Fists' and 'dual wield' are commands, not weapons, so they are exclusive: either one
    --   in the list decides the whole tap and is not combined with slots. And 'empty your hands'
    --   together with 'draw your sidearm' are contradictory requests that cannot both run.
    --
    -- ⚠️ And they are searched for across the whole list, not just its head: a player may assign
    --    a sidearm and then the fists, putting the command second -- and checking only the first ignored it.
    local role

    for i = 1, #quickSlots do
        if quickSlots[i] == 'unarmed' or quickSlots[i] == 'dual' then
            role = quickSlots[i]
            break
        end
    end

    if role == 'unarmed' then
        return heldSlot and holsterAll() or nil
    end

    if role == 'dual' then
        local right, left = dualPair(state)

        -- Both sidearms already in hand -> the tap holsters them (same logic as 'go back to the previous')
        if right and left and #state.dual.slots >= 2 then return holsterAll() end

        return equipDual(right, left)
    end

    -- ═══ Slots ═══
    local targets = quickTargets()
    if #targets == 0 then return end

    -- The whole default is in your hand now -> the tap puts it away. Which is what pressing twice implies.
    local allHeld = true

    for i = 1, #targets do
        if not held[targets[i]] then allHeld = false break end
    end

    if allHeld then
        if previousSlot and not held[previousSlot] then
            local back = previousSlot
            previousSlot = nil
            return equipSlot(back)
        end

        previousSlot = nil
        return holsterAll()
    end

    previousSlot = heldSlot

    -- ═══ How many weapons actually come out ═══
    --
    -- ★ There are two hands, and the engine combines only two one-handed sidearms in them. So a
    --   rifle and a sidearm never come out together however they are assigned -- the second puts
    --   the first away.
    --
    --   Hence: two eligible sidearms => one dual-wield transaction. Anything else => the first
    --   alone in hand, and the rest where they already were -- on the body, in their holsters.
    --
    -- ⚠️ And we do not equip them in sequence: equipping the second holsters the first, so the
    --    player sees a draw, a holster and a draw ending in one weapon -- the same result in
    --    three animations and a third of a second wasted, at the moment they do not have a third to spare.
    if #targets >= 2 then
        local first  = WheelInv.weaponBySlot(targets[1])
        local second = WheelInv.weaponBySlot(targets[2])

        if first and second and first.dualCapable and second.dualCapable then
            return equipDual(targets[1], targets[2])
        end
    end

    equipSlot(targets[1])
end

----------------------------------------------------------------
-- The main thread -- press cadence
--
-- ★ We disable the wheel key every frame and read it disabled: that alone is what stops the
--   game's own wheel appearing under ours. Leaving it enabled showed both at once.
----------------------------------------------------------------

-- ════════════════════════════════════════════════════════════════════════════
-- The two press sources
--
-- ★ Why two and not one:
--   INPUT_OPEN_WHEEL_MENU is the game's wheel key, and reading it is required because we disable
--   it (or their wheel appears under ours). But it depends on the player's control map: whoever
--   rebound it in the game settings, or plays on a pad with a different map, receives nothing --
--   and the wheel does not open for no visible reason.
--
--   So the second source is RegisterKeyMapping: an explicit binding under the resource's name
--   that appears in Settings -> Key Bindings so the player can change it themselves, and works
--   whatever the control map. Both feed the same edge detector, so there is no double fire.
-- ════════════════════════════════════════════════════════════════════════════

local keyHeld = false
local bindMethod = 'none' -- for diagnostics: by which route the key was actually bound

-- ★ The wheel key is a named keybind: w.addKeybind -> RegisterKeyMapping. RegisterRawKeymap
--   is not used here and must not come back.
--
--   Two faults died with it, and both were live in this file:
--
--   1. Raw keymaps were named `w_lib:rawKeys:<vk>` -- one name for every resource on the
--      server. The first resource to claim TAB owned it; the engine told the next
--      «already has a keymap bound by another resource», and listen() swallowed that and
--      returned an id anyway. Keymapping names are prefixed with this resource, so it is over.
--
--   2. This function used to ask the raw-keys module for a VK code and got nil on every
--      start, so the wheel key was never bound and INPUT_OPEN_WHEEL_MENU did the whole job
--      alone. No VK lookup is needed now: RegisterKeyMapping takes the key name directly.
--
--   Wheel.OpenKey is now only the DEFAULT -- the player rebinds it in Settings > Key Bindings.
local function bindOpenKey()
    -- the wheel is switched off on this server (w_wheel owns TAB): no key mapping of our own
    if not Wheel.Enabled then bindMethod = 'disabled' return end
    local key = tostring(Wheel.OpenKey or 'TAB'):upper()

    local ok, keybind = pcall(w.addKeybind, {
        name        = ('%s_wheel_open'):format(GetCurrentResourceName()),
        description = 'Open weapon wheel', -- English on purpose: the key-binding page cannot draw Arabic
        defaultKey  = key,
        onPressed   = function() keyHeld = true end,
        onReleased  = function() keyHeld = false end,
    })

    if not ok or not keybind then
        bindMethod = 'none'
        w.print.warn(('wheel: could not bind "%s" -- INPUT_OPEN_WHEEL_MENU remains alone.'):format(key))
        return
    end

    bindMethod = 'keymapping:' .. key
end

CreateThread(bindOpenKey)

local function inputPressed()
    return keyHeld
        or IsDisabledControlPressed(0, Wheel.OpenControl)
        or IsControlPressed(0, Wheel.OpenControl)
end

CreateThread(function()
    loadQuickSlots()

    local look = Wheel.LookControls or { `INPUT_LOOK_LR`, `INPUT_LOOK_UD` }

    while true do
        local sleep = 0

        -- Disabled: we do not touch the wheel key at all, so the game's wheel works as it did.
        if not Wheel.Enabled then
            sleep = 1000
            if isOpen then closeWheel(false) end

        elseif not inventoryReady() or showUI == false then
            sleep = 500
            if isOpen then closeWheel(false) end
        else
            DisableControlAction(0, Wheel.OpenControl, true)

            -- The emote wheel and its sibling are on TAB too -- silenced, or the 'Emote Wheel'
            -- prompt appears over ours and their wheel opens with it.
            for i = 1, #(Wheel.BlockControls or {}) do
                DisableControlAction(0, Wheel.BlockControls[i], true)
            end

            local pressed = inputPressed()

            if pressed and not wasPressed then
                pressedAt = GetGameTimer()
                pendingTap = true

            elseif pressed and wasPressed then
                if pendingTap and not isOpen
                    and GetGameTimer() - pressedAt >= Wheel.HoldThreshold then
                    pendingTap = false
                    openWheel()
                end

            elseif not pressed and wasPressed then
                if isOpen then
                    -- Releasing confirms the selection -- the UI sends the command and then we close.
                    SendNUIMessage({ action = 'wheel:commit' })
                    SetTimeout(60, function() if isOpen and not busy then closeWheel(true) end end)

                elseif pendingTap then
                    pendingTap = false

                    -- No double tap wanted? Act at once: the delay below is the price of telling
                    -- the two taps apart, and it is not paid when there is nothing to tell apart.
                    if not Wheel.DoubleTapHolster then
                        CreateThread(quickSelect)
                    else
                        local now = GetGameTimer()

                        if now - lastTapAt <= Wheel.DoubleTapWindow then
                            lastTapAt = 0
                            CreateThread(holsterAll)
                        else
                            lastTapAt = now
                            -- We wait out the double-tap window before running the single, or the
                            -- first would act and the second undo it in front of the player.
                            SetTimeout(Wheel.DoubleTapWindow + 20, function()
                                if lastTapAt == now then quickSelect() end
                            end)
                        end
                    end
                end
            end

            wasPressed = pressed

            if isOpen then
                -- ★ The minimap stays -- as in the game.
                --
                -- client/ammo.lua hides game HUD components every frame to drop the lying ammo
                -- counter, and the minimap sometimes goes with it. Resource order within a single
                -- frame is not guaranteed, so we write it from here as well: whichever runs last
                -- pins it visible.
                if showUI ~= false then w.setRadarVisible(true) end

                -- The camera does not turn with the mouse while the wheel is open.
                for i = 1, #look do DisableControlAction(0, look[i], true) end

                DisableControlAction(0, `INPUT_ATTACK`, true)
                DisableControlAction(0, `INPUT_AIM`, true)
                DisableControlAction(0, `INPUT_RELOAD`, true)
                DisableControlAction(0, `INPUT_JUMP`, true)
                DisableControlAction(0, `INPUT_SELECT_NEXT_WEAPON`, true)
                DisableControlAction(0, `INPUT_SELECT_PREV_WEAPON`, true)

                -- A safety belt: closed on death or on entering another menu.
                if IsEntityDead(cache.ped) or IsPauseMenuActive() then closeWheel(false) end
            else
                -- ★ العجلة أُغلقت للتوّ: المحوران يبقيان معطَّلين مهلةً قصيرة.
                --
                --   تحريرُ التركيز يُعيد الماوس إلى المحرّك، فيصله فرقُ ما
                --   تحرّك عليه المؤشّر دفعةً واحدة. وكاميرا الحصان **تابعة**
                --   ذات عطالة، فتأخذ الدفعة وتُكملها — وهي «الكاميرا تتحرّك
                --   بعد فكّ العجلة». إطاراتٌ قليلةٌ معطَّلةٌ تبتلع الفرق.
                if lookLockUntil > 0 then
                    if GetGameTimer() < lookLockUntil then
                        for i = 1, #look do DisableControlAction(0, look[i], true) end
                    else
                        lookLockUntil = 0
                    end
                end

                sleep = 0
            end
        end

        Wait(sleep)
    end
end)

-- The magazine changes while the wheel is open (reload/purchase/swap) -- we re-read rather than
-- freeze a picture.
--- The event sometimes precedes the inventory writing its data by a frame -- one frame of waiting
--- is cheaper than a read of the old state.
local function refreshSoon()
    if not isOpen or busy then return end

    SetTimeout(50, function() if isOpen and not busy then refresh() end end)
end

exports.w_lib:InvOnWheelRefresh(function(ev)
    if not isOpen or busy then return end
    local okInv, invName = pcall(function() return exports.w_lib:InvName() end)
    local delay = (okInv and invName == 'w_inventory') and 50 or 250
    SetTimeout(delay, function() if isOpen and not busy then refresh() end end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SetTimeScale(1.0)
    hideWheelPrompts()
    -- ★ And the screen effect: animpostfx effects keep running after the resource dies, leaving
    --   the player stuck with a blurred screen and no way to stop it.
    stopWheelFx()
end)

--- For other resources: is the wheel open right now? (ammo.lua reads it to keep the HUD hidden)
exports('isWheelOpen', function() return isOpen end)

--- Is our wheel enabled? w_wheel asks this to disable itself so two wheels never open together.
exports('isWheelEnabled', function() return Wheel and Wheel.Enabled == true end)

-- ════════════════════════════════════════════════════════════════════════════
-- /wheeldebug -- why does it not open?
--
-- ★ The opening chain has five links, and a break in any of them gives exactly the same result:
--   you press TAB and nothing happens. So without this command diagnosis stays a guess among
--   five possibilities -- and this command names them one by one.
-- ════════════════════════════════════════════════════════════════════════════
-- ★ The name follows the resource: w_hud and w_wheel carry this same file verbatim, and one
--   command name registered in two resources makes the diagnosis itself ambiguous: which one
--   answered? So each resource gets its own name, and the two files stay identical so the fix
--   copies across as-is.
local DEBUG_CMD = GetCurrentResourceName() == 'w_wheel' and 'wwheeldebug' or 'wheeldebug'

RegisterCommand(DEBUG_CMD, function()
    local function line(label, ok, detail)
        print(('%s %-34s %s'):format(ok and '^2[✓]^7' or '^1[✗]^7', label, detail or ''))
    end

    print(('^3== %s . WEAPON WHEEL DIAGNOSTIC ======================^0'):format(GetCurrentResourceName()))

    line('wheel enabled', Wheel.Enabled == true,
        Wheel.Enabled and 'Wheel.Enabled'
        or '^1shared/wheel.lua -> Wheel.Enabled = true^7 (the game wheel runs in its place)')

    line('HUD visible', showUI ~= false, 'showUI')

    -- ★ The most commonly broken link: no inventory answering -- either because the resource is
    --   stopped, or because Wheel.Inventory is pinned to one that is not running.
    local bag = WheelInv.name()

    line('active inventory', bag ~= nil,
        bag and ('%s (Wheel.Inventory = %s)'):format(bag, tostring(Wheel.Inventory))
        or '^1neither w_inventory nor vorp_inventory is running^7')

    if bag then
        local caps = WheelInv.caps()
        print(('^7   capabilities:^0 condition=%s · cleaning=%s · ammo swap=%s · dual=%s')
            :format(tostring(caps.condition), tostring(caps.clean),
                tostring(caps.ammoSwitch), tostring(caps.dual)))
    end

    local state = readInventory()
    line('inventory returns a ready state', state ~= nil,
        state and ('weapons=%d · items=%d'):format(#state.weapons, #state.items)
        or ('^1%s^7'):format(WheelInv.problem()))

    if state and #state.weapons == 0 then
        print('^3   note:^7 no weapon in your bag -- the wheel will open empty except for the fists.')
    end

    print(('^7   ordering:^0 %s · items=%s · left click=%s')
        :format(tostring(Wheel.Order), tostring(Wheel.ItemsOrder), tostring(Wheel.LeftClick)))

    print(('^7   defaults:^0 %s')
        :format(#quickSlots > 0 and table.concat(quickSlots, ', ') or 'none'))

    print('^3-- the key ----------------------------------------^0')
    print('^7Press TAB within the next five seconds...^0')

    CreateThread(function()
        local deadline, sawControl, sawMapping = GetGameTimer() + 5000, false, false

        while GetGameTimer() < deadline do
            if IsDisabledControlPressed(0, Wheel.OpenControl)
                or IsControlPressed(0, Wheel.OpenControl) then sawControl = true end

            if keyHeld then sawMapping = true end
            Wait(0)
        end

        line(('keybind "%s"'):format(tostring(Wheel.OpenKey)), sawMapping,
            sawMapping and bindMethod
            or ('^1did not arrive^7 (bind method: %s)'):format(bindMethod))

        line('INPUT_OPEN_WHEEL_MENU', sawControl,
            sawControl and '' or 'your control map does not bind it to this key (harmless)')

        if not sawControl and not sawMapping then
            print(('^1   no key press arrived at all -- make sure you pressed %s and the game window is focused.^7')
                :format(tostring(Wheel.OpenKey)))
        elseif Wheel.Enabled and bag and state then
            print('^2   every link is sound -- the wheel should open.^7')
        end

        print('^3════════════════════════════════════════════════════^0')
    end)
end, false)
