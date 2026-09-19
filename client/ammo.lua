-- ============================================================
-- w_hud · client/ammo.lua
-- The ammo readout -- it reads the inventory's accounting, not the engine's pool.
--
-- ═══ Why a replacement at all ═══
--
-- RDR3 keeps one pool per ammo **type**, not per weapon, and a weapon's magazine is
-- addressed by hash. So any readout that reads GET_PED_AMMO_BY_TYPE -- the game's own,
-- or bln_hud's -- shows the sum of two weapons' reserves beside each of them, and there
-- is no persuading it otherwise. A player would empty one weapon and watch its number
-- hold steady or even 'rise' -- those were its companion's rounds.
--
-- The inventory alone knows each weapon's reserve separately, and that reserve is items
-- in a bag rather than a pool in the engine. So we read it straight from
-- w_inventory:getHeldAmmoState.
--
-- ============================================================

local POLL_ARMED   = 200   -- ms while a weapon is held
local POLL_IDLE    = 700   -- ms with no weapon -- enough to catch the draw
local UNARMED_HASH = -1569615261

-- ════════════════════════════════════════════════════════════════════════════
-- Policy for the game's own HUD
--
-- ★ What the engine has a dedicated toggle for, and what it does not -- verified
--   against the official native database (VORPCORE/RDR3natives): the entire HUD
--   namespace (188 natives), plus every native carrying RETICLE, WHEEL, RADAR or AMMO
--   in its name across all namespaces.
--
--     minimap            DISPLAY_RADAR            MAP 0x1B3DA717B9AFF828
--     player cores       _SHOW_PLAYER_CORES       HUD 0x50C803A4CD5932C5
--     horse cores        _SHOW_HORSE_CORES        HUD 0xD4EE21B7CC7FD350
--     prompts            _UI_PROMPT_DISABLE_PROMPTS_THIS_FRAME
--
--     crosshair          X no native **by name**
--     weapon wheel       X read-only (_HUD_WEAPON_WHEEL_GET_SELECTED_ITEM_HASH)
--     ammo counter       X no native **by name**
--
-- ★ Correction: this used to say all three sat under DISPLAY_HUD alone and the
--   trade-off was unavoidable. That was wrong: the search had been for a native that
--   **names** each element, and no such thing exists. But 0x4CC5F2FC1332577F hides a
--   component **by its hash** rather than by name -- so it reaches what has no name.
--   See HIDE_HUD_COMPONENTS below.
-- ════════════════════════════════════════════════════════════════════════════

--- ═══ Hiding policy ═══
---
---   'off'        no blanket hide -- the cores alone are hidden by their own natives (default)
---   'persistent' DISPLAY_HUD(false) -- hides the game's whole UI, minimap included
---   'frame'      the per-frame hide native -- ⚠️ **takes the minimap down for good**
---
--- ⚠️ Correction: this used to claim persistent keeps the minimap, on the grounds that
---    DISPLAY_HUD and DisplayRadar are both persistent toggles so there is no race
---    between them. Measurement proved the opposite: the minimap disappears under
---    persistent too. DISPLAY_HUD(false) takes the radar down and keeps it down, and
---    a later DisplayRadar(true) does not bring it back -- the two are not peers, one
---    governs the other.
---
--- ★ So no blanket mode keeps the minimap, and the answer is not to hide in bulk at all.
---    The reference script (F:/Server RedM/hud/hud) knows exactly one line:
---        InvokeNative(0x4CC5F2FC1332577F, 1058184710)  every frame
---    It hides the ammo counter and the crosshair and never touches the minimap --
---    because it targets a component by hash rather than the whole UI. That is what we use.
---
--- ⚠️ Correction: this used to claim 0xBF4F34A85CA2970D was _HIDE_HUD_THIS_FRAME and
---    therefore left the radar alone. The claim was false -- no native database in the
---    project names it, and measurement contradicted it: under 'frame' the minimap goes
---    and under 'off' it returns. DisplayRadar(true) cannot rescue it because the hide
---    is per-frame while the show is a persistent toggle -- so the hide lands after it
---    on every cycle.
---
--- ★ And it is not needed anyway: the cores are hidden one at a time through
---   _UITUTORIAL_SET_RPG_ICON_VISIBILITY, and the ammo counter and crosshair through
---   HIDE_HUD_COMPONENTS. Every element by its own native, and the minimap stays.
local HIDE_MODE = 'off'  -- switchable live with /hudhide (bottom of this file)

--- Restore the minimap explicitly after every hide.
--- ★ Under 'off' this is an assertion, not a rescue: the minimap is visible anyway. But
---   it does bring it back if someone tries /hudhide persistent and then returns, and it
---   does not fight thread.lua -- both write the same value to a persistent toggle.
local KEEP_MINIMAP = true

--- We do not hide while the **game's** wheel is open: a per-frame hide takes it down mid-draw.
---
--- ⚠️ And this exception is meaningless when our own wheel is enabled (client/wheel.lua):
--- the game's wheel is already disabled there, so keeping the HUD up for its sake means
--- showing its ammo counter -- shared between both weapons, and the very lie this whole
--- file was built to avoid. So the condition reads the wheel setting, not a constant.
local KEEP_WEAPON_WHEEL = not (Wheel and Wheel.Enabled)

--- The stock core icons we hide -- w_hud draws its own in their place.
---
--- ★ Per-icon control through _UITUTORIAL_SET_RPG_ICON_VISIBILITY, not the blunt
--- _SHOW_PLAYER_CORES (all or nothing). Delete a line to keep its icon.
---
--- The official enumeration (nativewrappers/rdr3-natives):
---   0 STAMINA · 1 STAMINA_CORE · 2 DEADEYE · 3 DEADEYE_CORE
---   4 HEALTH  · 5 HEALTH_CORE  · 6 HORSE_HEALTH · 7 HORSE_HEALTH_CORE
---   8 HORSE_STAMINA · 9 HORSE_STAMINA_CORE · 10 HORSE_COURAGE · 11 HORSE_COURAGE_CORE
---
--- ⚠️ And it has no entry for ammo -- see the documented search above. The ammo counter
--- sits under DISPLAY_HUD alone, along with the crosshair and the weapon wheel.
local HIDE_RPG_ICONS = {
    0, 1,   -- stamina and its core
    4, 5,   -- health and its core
    6, 7,   -- horse health and its core
    8, 9,   -- horse stamina and its core
    -- 2, 3,   -- dead eye: left visible (w_hud has no replacement for it)
    -- 10, 11, -- horse courage
}

local SET_RPG_ICON_VISIBILITY = 0xC116E6DF68DCE667
local ICON_SHOW, ICON_HIDE = 1, 2

--- Our own counter. Set it false if having two counters bothers you.
local SHOW_OWN_AMMO = true

-- ════════════════════════════════════════════════════════════════════════════
-- Hiding the game's ammo counter: a HUD CONTEXT, not a "component"
--
-- ★ Corrected 2026-09-17 (night) against the RDR3 native database (alloc8or) and RedM's
--   own rdr3_universal.lua. Everything this block used to say was wrong in the one way
--   that mattered:
--
--     0x4CC5F2FC1332577F  HUD::_ENABLE_HUD_CONTEXT(Hash)        PERSISTENT -- stays until
--                                                              _DISABLE_HUD_CONTEXT
--     0xC9CAEAEEC1256E54  HUD::_ENABLE_HUD_CONTEXT_THIS_FRAME   one frame, nothing persists
--     0x8BC7C1F929D07BF3  HUD::_DISABLE_HUD_CONTEXT(Hash)       the off switch
--     1058184710          = 0x3F129E06 = joaat("HUD_CTX_INFINITE_AMMO")
--                         (documented: hides the AMMO slot and the MP ability-card
--                          indicator -- the reticle is hidden by stream/hud_reticle.gfx)
--
--   This file called the PERSISTENT enable every frame and never disabled it, so one aim
--   (or, before the gating, the first frame after connecting) left HUD_CTX_INFINITE_AMMO
--   switched on for the whole session; gating the call to "gun in hand" / "aiming" and
--   /hidecomp off only stopped RE-enabling it. Now: the per-frame variant while aiming,
--   an explicit disable the moment the aim ends, on stop, on start (a stale context from
--   an older build), and /hudctx on|off to prove it at the wagon.
-- ════════════════════════════════════════════════════════════════════════════
local ENABLE_HUD_CONTEXT            = 0x4CC5F2FC1332577F
local ENABLE_HUD_CONTEXT_THIS_FRAME = 0xC9CAEAEEC1256E54
local DISABLE_HUD_CONTEXT           = 0x8BC7C1F929D07BF3
local HUD_CTX_INFINITE_AMMO         = 1058184710

local HIDE_HUD_COMPONENTS = {
    HUD_CTX_INFINITE_AMMO, -- the game's ammo counter (w_hud draws its own)
}

-- what this file did to the context, for /stablediag
local ctxLog = { enables = 0, lastEnabledAt = nil, disables = 0, lastDisabledAt = nil, persistentUsed = false }

local function disableHudContext(hash)
    Citizen.InvokeNative(DISABLE_HUD_CONTEXT, hash)
    ctxLog.disables, ctxLog.lastDisabledAt = ctxLog.disables + 1, GetGameTimer()
end
local function disableAllHudContexts()
    for i = 1, #HIDE_HUD_COMPONENTS do disableHudContext(HIDE_HUD_COMPONENTS[i]) end
end

local DISPLAY_HUD          = 0xD63FE3AF9FB3D53F
local HIDE_HUD_THIS_FRAME  = 0xBF4F34A85CA2970D

local appliedDisplayHud = nil
local function applyNativeHudState()
    -- (/hudbisect radar off | icons off switch these two writes off at runtime)
    if not WHudBisect or WHudBisect.radar ~= false then
        -- ★ DISPLAY_HUD is a persistent toggle: written when the wanted value changes, not
        --   re-asserted every 2 s (2026-09-18 -- one HUD-state write less for other scripts'
        --   UI to survive; a gizmo that hides the HUD for a moment is no longer fought either).
        local wantDisplay = HIDE_MODE ~= 'persistent'
        if wantDisplay ~= appliedDisplayHud then
            Citizen.InvokeNative(DISPLAY_HUD, wantDisplay)
            appliedDisplayHud = wantDisplay
        end

        -- ★ And the radar is switched on **immediately after** the HUD is switched off, in
        --   the same call. Both are persistent toggles, so their order within the call is
        --   all it takes -- no chasing it every frame the way 'frame' mode did.
        if KEEP_MINIMAP then w.setRadarVisible(true) end
    end

    if not WHudBisect or WHudBisect.icons ~= false then
        for i = 1, #HIDE_RPG_ICONS do
            Citizen.InvokeNative(SET_RPG_ICON_VISIBILITY, HIDE_RPG_ICONS[i], ICON_HIDE)
        end
    end
end
--- /hudbisect icons on|off: the stock core icons back (all twelve), or hidden again.
function WHudSetRpgIconsHidden(hidden)
    for icon = 0, 11 do
        Citizen.InvokeNative(SET_RPG_ICON_VISIBILITY, icon, hidden and ICON_HIDE or ICON_SHOW)
    end
end

-- -- the per-frame hide -----------------------------------------------------
--
-- ★ "Hide everything, then restore what I need": the per-frame native takes the ammo
-- counter, the crosshair and their neighbours down, and the minimap is outside its
-- scope. What we need we except explicitly -- the wheel for instance: we do not hide
-- with a finger on TAB, or it goes down mid-draw.
CreateThread(function()
    local wheelKey = `INPUT_OPEN_WHEEL_MENU`

    while true do
        if HIDE_MODE ~= 'frame' then
            Wait(500)
        else
            local wheelOpen = KEEP_WEAPON_WHEEL
                and (IsControlPressed(0, wheelKey) or IsDisabledControlPressed(0, wheelKey))

            if not wheelOpen then
                Citizen.InvokeNative(HIDE_HUD_THIS_FRAME)
                if KEEP_MINIMAP then w.setRadarVisible(true) end
            end

            Wait(0)
        end
    end
end)

CreateThread(function()
    -- The stock HUD comes back with every spawn/load, so we re-assert after the player settles.
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    -- a context an OLDER build of this file left switched on (it used the persistent
    -- enable and never disabled it) survives a resource restart: clear it once here
    disableAllHudContexts()
    applyNativeHudState()

    -- ★ And once is not enough: the engine restores the core icons on every state
    --   transition (mounting · combat · cutscene · entering a building), which is why
    --   they kept reappearing. A light re-assert every two seconds is enough and costs nothing.
    while true do
        Wait(2000)
        applyNativeHudState()
    end
end)

AddEventHandler('playerSpawned', applyNativeHudState)
RegisterNetEvent('vorp:SelectedCharacter', applyNativeHudState)
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', applyNativeHudState)
RegisterNetEvent('qbr-core:client:OnPlayerLoaded', applyNativeHudState)

-- And we restore everything when the resource stops, or the player is left with neither HUD.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    Citizen.InvokeNative(DISPLAY_HUD, true)
    disableAllHudContexts()

    -- all twelve icons, not only the eight of HIDE_RPG_ICONS: thread.lua hides dead eye
    -- and horse courage at start too, and nothing else ever showed them again
    for icon = 0, 11 do
        Citizen.InvokeNative(SET_RPG_ICON_VISIBILITY, icon, ICON_SHOW)
    end
end)

local GET_PED_CURRENT_HELD_WEAPON = 0x8425C5F057012DAB

--- A state fingerprint: we only send to the UI when something actually changes. Sending
--- every 200ms unchanged re-renders React for nothing and burns cycles for nothing.
---@param hands table[]
---@return string
local function signature(hands)
    local parts = {}

    for i = 1, #hands do
        local h = hands[i]
        parts[#parts + 1] = ('%s:%d:%d:%d:%s:%s')
            :format(tostring(h.slot), h.loaded or 0, h.reserve or -1, h.hand or 0,
                h.active and '1' or '0', tostring(h.ammoItem))
    end

    return table.concat(parts, '|')
end

-- ════════════════════════════════════════════════════════════════════════════
-- The readout without w_inventory (VORP and every other inventory): the engine's own numbers
--
-- ★ The game's readout is "rounds in the clip | rounds left", per hand. The engine has
--   both: GET_AMMO_IN_CLIP for the clip and GET_AMMO_IN_PED_WEAPON for everything the ped
--   carries of that weapon's ammo type. The known caveat (one pool per ammo TYPE, so two
--   weapons sharing a type share a reserve) is the game's own behaviour, which is what
--   the player is used to reading.
--
-- * Bows and thrown weapons have no clip: the count is what is in hand, the reserve the rest.
-- * The ammo type's item (for the picture) comes from vorp_inventory's map when it is
--   running; the picture is served from its images folder.
-- ════════════════════════════════════════════════════════════════════════════
local IMAGE_BASE = {
    vorp_inventory = 'nui://vorp_inventory/html/img/items/',
    w_inventory    = 'nui://w_inventory/web/images/',
}

local RANGED_GROUPS = {
    [`GROUP_PISTOL`] = true, [`GROUP_REVOLVER`] = true, [`GROUP_REPEATER`] = true,
    [`GROUP_RIFLE`] = true, [`GROUP_SNIPER`] = true, [`GROUP_SHOTGUN`] = true,
    [`GROUP_BOW`] = true, [`GROUP_THROWN`] = true,
}

local ammoItemOf = {} -- ammo type hash -> item name, filled once vorp_inventory answers
local ammoItemsAsked = false

local function askAmmoItems()
    if ammoItemsAsked or GetResourceState('vorp_inventory') ~= 'started' then return end
    ammoItemsAsked = true
    pcall(function()
        -- SHARED_DATA.AMMO_ITEMS is vorp's; its config is a shared script, so the map is
        -- reachable through a small export if the inventory offers one, else left empty.
        local map = exports.vorp_inventory:getWeaponWheelAmmoItems()
        for ammoType, entry in pairs(type(map) == 'table' and map or {}) do
            if type(entry) == 'table' and entry.item then ammoItemOf[joaat(ammoType) & 0xFFFFFFFF] = entry.item end
        end
    end)
end

--- One hand's reading straight from the engine.
---@param ped number
---@param hand integer 0 right · 1 left
---@param active boolean
---@return table|nil
local function nativeHand(ped, hand, active)
    local ok, weapon = pcall(function()
        local _, hash = GetCurrentPedWeapon(ped, hand == 0, hand, false)
        return hash
    end)
    if not ok or not weapon or weapon == 0 or weapon == UNARMED_HASH then return nil end
    if IsWeaponMeleeWeapon(weapon) == 1 then return nil end
    -- only what fires or is thrown: a lasso, a lantern or a kit has no readout
    local group = GetWeapontypeGroup(weapon)
    if not RANGED_GROUPS[group] then return nil end

    -- ★ The type SHOWN comes first (2026-09-18): the one the player chose in the wheel or the
    --   bag (vorp_inventory remembers it per weapon), else the type the weapon object reports.
    --   Its pool is read per TYPE (GET_PED_AMMO_BY_TYPE): GET_AMMO_IN_PED_WEAPON answers for the
    --   weapon, and a bow kept showing the normal arrow's 9 whichever arrow was selected.
    local object = GetCurrentPedWeaponEntityIndex(ped, hand)
    -- (hashes as unsigned 32-bit throughout: joaat answers signed, the natives may not)
    local objectType = object and object ~= 0 and GetCurrentPedWeaponAmmoType(ped, object) or nil
    if objectType == 0 then objectType = nil end
    if objectType then objectType = objectType & 0xFFFFFFFF end
    local chosenType = nil
    if GetResourceState('vorp_inventory') == 'started' then
        local okSel, sel = pcall(function() return exports.vorp_inventory:getSelectedAmmoTypeForHash(weapon) end)
        if okSel and type(sel) == 'string' then chosenType = joaat(sel) & 0xFFFFFFFF end
    end
    local ammoType = chosenType or objectType
    local total = ammoType and (GetPedAmmoByType(ped, ammoType) or 0) or (GetAmmoInPedWeapon(ped, weapon) or 0)
    local clip, capacity, reserve
    local okClip, _, inClip = pcall(GetAmmoInClip, ped, weapon)
    local okMax, maxClip = pcall(GetMaxAmmoInClip, ped, weapon, true)
    local noClip = group == `GROUP_BOW` or group == `GROUP_THROWN`
    if noClip or not okClip or not tonumber(inClip) then
        -- no clip: the count is what the ped carries of the type shown, and there is no second number
        clip, capacity, reserve = total, total, nil
    else
        clip = math.floor(inClip)
        capacity = okMax and tonumber(maxClip) and math.floor(maxClip) or clip
        -- the clip belongs to the pool only while the weapon fires the type shown
        local clipOfShownType = objectType == nil or ammoType == objectType
        reserve = math.max(0, total - (clipOfShownType and clip or 0))
    end
    local base = GetResourceState('vorp_inventory') == 'started' and IMAGE_BASE.vorp_inventory or nil

    return {
        slot = hand + 1, label = '', hand = hand,
        loaded = clip, capacity = capacity, reserve = reserve,
        active = active,
        ammoItem = ammoType and ammoItemOf[ammoType] or nil,
        imageBase = base,
    }
end

local function nativeHands(ped)
    local hands = {}
    local right = nativeHand(ped, 0, true)
    if right then hands[#hands + 1] = right end
    local left = nativeHand(ped, 1, false)
    if left then hands[#hands + 1] = left end
    return hands
end

CreateThread(function()
    local last = nil
    local inventoryReady = false

    while true do
        local armed = false

        if not inventoryReady then
            inventoryReady = GetResourceState('w_inventory') == 'started'
        end

        if SHOW_OWN_AMMO and showUI ~= false then
            local held = Citizen.InvokeNative(GET_PED_CURRENT_HELD_WEAPON, cache.ped)

            -- We only read with a weapon genuinely in hand: the holster is no business of
            -- this readout, and a call every 200ms for no reason is plain waste.
            if held and held ~= 0 and held ~= UNARMED_HASH then
                local hands
                if inventoryReady then
                    local ok, result = pcall(function() return exports.w_inventory:getHeldAmmoState() end)
                    if ok and type(result) == 'table' then hands = result end
                else
                    askAmmoItems()
                    hands = nativeHands(cache.ped)
                end

                if type(hands) == 'table' and #hands > 0 then
                    armed = true
                    local stamp = signature(hands)

                    if stamp ~= last then
                        last = stamp
                        SendNUIMessage({ action = 'ammo', hands = hands })
                    end
                end
            end
        end

        if not armed and last ~= nil then
            last = nil
            SendNUIMessage({ action = 'ammo', hands = {} })
        end

        Wait(armed and POLL_ARMED or POLL_IDLE)
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- /hudhide -- test the hiding policy live
--
-- ★ The comment at the top of this file claimed 0xBF4F34A85CA2970D hides the HUD but
--   not the radar. That claim is **unverified**: no native database in the project names
--   it, and practical evidence contradicts it (switching w_hud off brings the minimap back).
--
--   So rather than a fifth guess, we make the policy switchable on the spot:
--     /hudhide off         no hiding at all
--     /hudhide frame       the per-frame hide native
--     /hudhide persistent  the permanent DISPLAY_HUD(false)
--
--   If the minimap returns under 'off' then the native is the culprit, and we fall back
--   to the trade-off: keep the game's ammo counter, or hunt for another hash that leaves
--   the radar alone.
-- ════════════════════════════════════════════════════════════════════════════
RegisterCommand('hudhide', function(_, args)
    local mode = tostring(args[1] or ''):lower()

    if mode ~= 'off' and mode ~= 'frame' and mode ~= 'persistent' then
        print('^3[w_hud]^7 usage: /hudhide <off | frame | persistent>')
        print(('^7  current: %s^0'):format(HIDE_MODE))
        return
    end

    HIDE_MODE = mode

    -- 'off' must restore the stock HUD explicitly: the persistent toggle may be off
    Citizen.InvokeNative(DISPLAY_HUD, mode ~= 'persistent')

    if mode == 'off' then
        -- and we restore the core icons we hid
        for i = 1, #HIDE_RPG_ICONS do
            Citizen.InvokeNative(SET_RPG_ICON_VISIBILITY, HIDE_RPG_ICONS[i], ICON_SHOW)
        end
    else
        applyNativeHudState()
    end

    w.setRadarVisible(true)

    print(('^2[w_hud]^7 hide mode = %s  — does the minimap show now?^0'):format(mode))
end, false)

-- ════════════════════════════════════════════════════════════════════════════
-- Hiding the listed components -- every frame
--
-- ★ Every frame because the native is 'for this frame', not a persistent toggle. And
--   the cost is negligible: one call per component, and the list holds one.
-- ════════════════════════════════════════════════════════════════════════════
-- ★ 2026-09-17: this hide used to run EVERY frame, unconditionally. Component 1058184710 is
--   not only the ammo counter and the crosshair: SS-Stable's wagon / stable prompt groups went
--   down with it (stopping w_hud brought them back). The vanilla counter and crosshair only
--   exist while a gun is in hand, so the hide now runs only then; unarmed, every other
--   script's prompts are left alone. Config.HideNativeAmmoCounter = false (or /hidecomp off)
--   switches it off altogether.
--   ★ Second narrowing (same day): the hide ran only while the gun was AIMED. Withdrawn on
--     2026-09-18: the wagon prompts turned out to be hidden by a DISABLED CONTROL (the right
--     mouse button in Config.KeysDisabled), not by this context, and the game's counter was
--     showing again the whole time a gun was merely held. So: while a gun is in hand.
--   ★ Third (same night, see the block above): the native is the PERSISTENT context
--     enable. The loop uses the per-frame variant, and the moment the gun is put away the
--     context is disabled explicitly -- so nothing this file switches on outlives the draw.
local componentHideEnabled = Config.HideNativeAmmoCounter ~= false
local function gunInHand()
    if not cache.ped or cache.ped == 0 then return false end
    local armed = IsPedArmed(cache.ped, 4) -- 4: guns and bows (vorp_inventory relies on the same flag)
    return armed == true or armed == 1
end
local function aiming()
    local ok, free = pcall(IsPlayerFreeAiming, PlayerId())
    if ok and (free == true or free == 1) then return true end
    local okCam, cam = pcall(IsAimCamActive)
    return okCam and (cam == true or cam == 1)
end
local function hidingNow()
    return componentHideEnabled and (not WHudBisect or WHudBisect.ctx ~= false)
        and #HIDE_HUD_COMPONENTS > 0 and gunInHand()
end
local probeHash = nil
WHudHideState = {
    build = '2026-09-18a',
    mode = function() return HIDE_MODE end,
    enabled = function() return componentHideEnabled end,
    armed = gunInHand,
    aiming = aiming,
    hidingNow = hidingNow,
    ctx = ctxLog,
    probe = function() return probeHash end,
    contexts = HIDE_HUD_COMPONENTS,
    -- /hudbisect ctx off: stop hiding and switch the context off right now
    ctxOff = function() probeHash = nil; disableAllHudContexts() end,
}
CreateThread(function()
    if #HIDE_HUD_COMPONENTS == 0 then return end

    local hiding = false
    while true do
        if not hidingNow() then
            if hiding then
                hiding = false
                disableAllHudContexts() -- the gun is away: whatever the engine still holds, off
            end
            Wait(150)
        else
            hiding = true
            for i = 1, #HIDE_HUD_COMPONENTS do
                Citizen.InvokeNative(ENABLE_HUD_CONTEXT_THIS_FRAME, HIDE_HUD_COMPONENTS[i])
            end
            ctxLog.enables, ctxLog.lastEnabledAt = ctxLog.enables + 1, GetGameTimer()
            Wait(0)
        end
    end
end)

-- ════════════════════════════════════════════════════════════════════════════
-- /hudctx on|off [hash] -- the decisive test for a stuck HUD context
--
-- ★ At the wagon, with w_hud running and SS-Stable's prompts missing:
--     /hudctx off      disables HUD_CTX_INFINITE_AMMO (three times, in case it is counted)
--                      -> the prompts appear at once = the persistent context was the cause
--     /hudctx on       enables it persistently -> they must vanish again
-- ════════════════════════════════════════════════════════════════════════════
RegisterCommand('hudctx', function(_, args)
    local word = tostring(args[1] or ''):lower()
    local h = tonumber(args[2]) or HUD_CTX_INFINITE_AMMO
    if word == 'on' then
        Citizen.InvokeNative(ENABLE_HUD_CONTEXT, h)
        ctxLog.persistentUsed = true
        print(('^1[w_hud]^7 HUD context %d ENABLED (persistent) -- /hudctx off to clear it^0'):format(h))
    elseif word == 'off' then
        for _ = 1, 3 do disableHudContext(h) end
        print(('^2[w_hud]^7 HUD context %d DISABLED (x3)^0'):format(h))
    else
        print('^3[w_hud]^7 usage: /hudctx <on|off> [hash]   (default hash 1058184710 = HUD_CTX_INFINITE_AMMO)')
        print(('^7  enables this session: %d (last %s ms ago), disables: %d (last %s ms ago), persistent enable used: %s^0')
            :format(ctxLog.enables, ctxLog.lastEnabledAt and (GetGameTimer() - ctxLog.lastEnabledAt) or '-',
                ctxLog.disables, ctxLog.lastDisabledAt and (GetGameTimer() - ctxLog.lastDisabledAt) or '-', tostring(ctxLog.persistentUsed)))
    end
end, false)

-- ════════════════════════════════════════════════════════════════════════════
-- /hidecomp -- try a HUD context hash live (per frame, nothing persists)
--
-- ★ The context names ARE known: femga's rdr3_discoveries hud_presets list
--   (HUD_CTX_INFINITE_AMMO, HUD_CTX_HIDE_RADAR, ...). This command enables any hash for
--   one frame at a time while it runs; if what you wanted disappears, add the number to
--   HIDE_HUD_COMPONENTS above.
--
--     /hidecomp 1058184710     enables it (per frame) for as long as it is running
--     /hidecomp                turns the probe off, disables the context, prints the list
-- ════════════════════════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        if probeHash then
            Citizen.InvokeNative(ENABLE_HUD_CONTEXT_THIS_FRAME, probeHash)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterCommand('hidecomp', function(_, args)
    local word = tostring(args[1] or ''):lower()
    -- /hidecomp off | on -- the standing hide of HIDE_HUD_COMPONENTS (the ammo counter)
    if word == 'off' or word == 'on' then
        componentHideEnabled = word == 'on'
        if not componentHideEnabled then
            if probeHash then disableHudContext(probeHash) end
            probeHash = nil
            disableAllHudContexts()
        end
        print(('^3[w_hud]^7 native ammo counter hide: %s^0'):format(componentHideEnabled and 'ON (while a gun is in hand)' or 'OFF (contexts disabled)'))
        return
    end
    local h = tonumber(args[1])

    if not h then
        if probeHash then disableHudContext(probeHash) end
        probeHash = nil
        print('^3[w_hud]^7 probe off. usage: /hidecomp <hash> | off | on')
        print(('^7  currently hidden: %s (%s)^0'):format(table.concat(HIDE_HUD_COMPONENTS, ', '), componentHideEnabled and 'while a gun is in hand' or 'disabled'))
        return
    end

    probeHash = h
    print(('^2[w_hud]^7 hiding component %d — did the element disappear?'):format(h))
    print('^7  yes -> add it to HIDE_HUD_COMPONENTS in client/ammo.lua^0')
end, false)
