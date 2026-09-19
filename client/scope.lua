-- ════════════════════════════════════════════════════════════════════════════
-- w_hud · client/scope.lua -- auto scope
--
--   Aiming a rifle that carries a scope enters the scope view by itself. The game
--   waits for the scope key (mouse wheel / R3); this presses it for the player the
--   moment the aim is up and the view is still the third-person one. Letting go of
--   the aim leaves the scope the way the game always does -- nothing to undo here.
--
-- ⚠️ The first version asked 0x5E346D934122613F (IS_FIRST_PERSON_AIM_CAM_ACTIVE)
--    whether the scope was up, without a return-type hint. Its answer was never a
--    boolean, so "not in scope" was true every 600 ms and the key was pressed again
--    and again: in, out, in, out -- the endless zoom loop players reported.
--
-- ★ Two rules replace it:
--   1. One aim = one press. The key is pressed once, shortly after the aim begins,
--      and never again until the aim is released and taken up afresh.
--   2. The only thing that may add a second press is the camera itself: the scope
--      view narrows the field of view to well under 30° (third-person aim sits at
--      ~45-55°). If, half a second after the press, the FOV is still wide, the aim
--      was not ready and the press is repeated -- at most twice per aim, so nothing
--      can fight the player who scrolls out on purpose.
--
-- ⚠️ INPUT_TOGGLE_WEAPON_SCOPE must stay enabled (see Config.KeysDisabled): a
--    disabled control ignores a simulated press as much as a real one.
-- ════════════════════════════════════════════════════════════════════════════

local SCOPE_COMPONENTS = {
    `COMPONENT_RIFLE_SCOPE02`,
    `COMPONENT_RIFLE_SCOPE03`,
    `COMPONENT_RIFLE_SCOPE04`,
}

--- Scoped out of the box, no component to look for.
local SCOPED_BY_DESIGN = {
    [`WEAPON_SNIPERRIFLE_CARCANO`]      = true,
    [`WEAPON_SNIPERRIFLE_ROLLINGBLOCK`] = true,
}

local SET_CONTROL_NORMAL = 0xE8A25867FBA3B05E   -- SET_CONTROL_VALUE_NEXT_FRAME(padIndex, control, value)

local SCOPE_FOV      = 30.0  -- below this the camera is looking through the scope
local FIRST_PRESS_MS = 150   -- the aim pose needs a beat before the key is honoured
local RETRY_AFTER_MS = 500   -- how long a press gets to change the view
local MAX_PRESSES    = 3     -- per aim: the first press and at most two retries

local function hasScope(ped, weapon)
    if SCOPED_BY_DESIGN[weapon] then return true end
    for i = 1, #SCOPE_COMPONENTS do
        if HasPedGotWeaponComponent(ped, SCOPE_COMPONENTS[i], weapon) == 1 then return true end
    end
    return false
end

local function inScope()
    local ok, fov = pcall(GetGameplayCamFov)
    return ok and type(fov) == 'number' and fov > 0.0 and fov < SCOPE_FOV
end

local function pressScopeKey()
    -- one frame of "pressed" = one press of the scope key
    Citizen.InvokeNative(SET_CONTROL_NORMAL, 0, `INPUT_TOGGLE_WEAPON_SCOPE`, 1.0)
end

CreateThread(function()
    local aiming    = false  -- an aim with a scoped weapon is in progress
    local aimedAt   = 0      -- when it began
    local presses   = 0      -- presses spent on this aim
    local pressedAt = 0      -- when the last one was made

    while true do
        local sleep = 250

        local scopedAim = false
        if Config.AutoScope ~= false and LocalPlayer.state.IsInSession then
            local ped, player = PlayerPedId(), PlayerId()
            if not IsEntityDead(ped) and IsPlayerFreeAiming(player) then
                local found, weapon = GetCurrentPedWeapon(ped, true, 0, true)
                scopedAim = found and weapon and weapon ~= 0 and weapon ~= `WEAPON_UNARMED` and hasScope(ped, weapon)
            end
        end

        if scopedAim then
            sleep = 0
            local now = GetGameTimer()

            if not aiming then
                -- the aim has just begun: a fresh budget of presses for it
                aiming, aimedAt, presses, pressedAt = true, now, 0, 0
            end

            if presses < MAX_PRESSES and not inScope() then
                local due = presses == 0 and (now - aimedAt >= FIRST_PRESS_MS)
                    or (presses > 0 and now - pressedAt >= RETRY_AFTER_MS)
                if due then
                    pressScopeKey()
                    presses, pressedAt = presses + 1, now
                end
            end
        else
            -- aim released (or the weapon changed): the game drops the scope by itself
            aiming = false
        end

        Wait(sleep)
    end
end)
