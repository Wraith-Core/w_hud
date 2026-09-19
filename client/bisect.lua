-- ============================================================
-- w_hud · client/bisect.lua -- /hudbisect: switch w_hud's behaviours off one at a time
--
-- ★ "Stopping w_hud brings SS-Stable's prompts back" names a resource, not a cause. This
--   table lets the player switch off each thing w_hud does to the game, at the wagon,
--   without restarting anything -- so the next report names the behaviour.
--
--     /hudbisect all off        everything below off -> do the prompts come back?
--     /hudbisect keys on        ...then one piece back on at a time, until they vanish
--     /hudbisect                prints the current switches
--
--   keys   the eight controls disabled every frame (Config.KeysDisabled)
--   icons  the stock core icons hidden (thread.lua at start, ammo.lua every 2 s)
--   radar  DISPLAY_HUD(true) + the radar / minimap type / radar config writes
--   ctx    the HUD context that hides the game's ammo counter (HUD_CTX_INFINITE_AMMO)
--   nui    the two messages the interface receives every frame / tick (compass, hudtick)
--
--   What no switch can test: the streamed files in w_hud/stream (rename the folder to
--   stream_off, restart w_hud, reconnect once) and the key mappings (RegisterKeyMapping).
-- ============================================================

WHudBisect = { keys = true, icons = true, radar = true, ctx = true, nui = true }

local ORDER = { 'keys', 'icons', 'radar', 'ctx', 'nui' }

local function apply(name, on)
    WHudBisect[name] = on
    if name == 'icons' then
        if type(WHudSetRpgIconsHidden) == 'function' then WHudSetRpgIconsHidden(on) end
    elseif name == 'ctx' then
        if not on and WHudHideState and type(WHudHideState.ctxOff) == 'function' then WHudHideState.ctxOff() end
    elseif name == 'radar' then
        if not on then pcall(function() w.setRadarVisible(true) end) end
    elseif name == 'nui' then
        if not on then SetNuiFocus(false, false) end
    end
end

function WHudBisectLine()
    local parts = {}
    for _, name in ipairs(ORDER) do parts[#parts + 1] = ('%s=%s'):format(name, WHudBisect[name] and 'on' or 'OFF') end
    return table.concat(parts, '  ')
end

-- ── /hudkeys: one entry of Config.KeysDisabled at a time ─────────────────────
--     /hudkeys            lists the entries with their index and state
--     /hudkeys 4 off      stops disabling entry 4 (this frame on); /hudkeys 4 on re-enables it
WHudKeyOff = {}
local KEY_NAMES = {
    [`INPUT_NEXT_WEAPON`] = 'INPUT_NEXT_WEAPON (scroll down)',
    [`INPUT_SELECT_PREV_WEAPON`] = 'INPUT_SELECT_PREV_WEAPON (scroll up)',
    [`INPUT_PREV_WEAPON`] = 'INPUT_PREV_WEAPON (scroll up)',
    [`INPUT_SPECIAL_ABILITY_SECONDARY`] = 'INPUT_SPECIAL_ABILITY_SECONDARY (right mouse / LT)',
    [`INPUT_QUICK_SHORTCUT_ABILITIES_MENU`] = 'INPUT_QUICK_SHORTCUT_ABILITIES_MENU (space in the wheel)',
    [`INPUT_RADIAL_MENU_SLOT_NAV_NEXT`] = 'INPUT_RADIAL_MENU_SLOT_NAV_NEXT (E in the wheel)',
    [`INPUT_CARRIABLE_SUICIDE`] = 'INPUT_CARRIABLE_SUICIDE (F)',
    [`INPUT_INTERROGATE_RELEASE`] = 'INPUT_INTERROGATE_RELEASE (R)',
}
local function listKeys()
    for i, key in ipairs(Config.KeysDisabled or {}) do
        print(('^7  %d. %-52s %s^0'):format(i, KEY_NAMES[key] or ('0x%08X'):format(key & 0xFFFFFFFF),
            WHudKeyOff[key] and 'not disabled (off)' or 'disabled every frame'))
    end
end
RegisterCommand('hudkeys', function(_, args)
    local index, state = tonumber(args[1]), tostring(args[2] or ''):lower()
    local key = index and Config.KeysDisabled and Config.KeysDisabled[index]
    if not key or (state ~= 'on' and state ~= 'off') then
        print('^3[w_hud]^7 usage: /hudkeys <index> <on|off>   (off = w_hud stops disabling that control)')
        listKeys()
        return
    end
    WHudKeyOff[key] = state == 'off' or nil
    print(('^2[w_hud]^7 key %d -> %s^0'):format(index, state == 'off' and 'NOT disabled' or 'disabled again'))
    listKeys()
end, false)

RegisterCommand('hudbisect', function(_, args)
    local what, state = tostring(args[1] or ''):lower(), tostring(args[2] or ''):lower()
    if (what ~= 'all' and WHudBisect[what] == nil) or (state ~= 'on' and state ~= 'off') then
        print('^3[w_hud]^7 usage: /hudbisect <keys|icons|radar|ctx|nui|all> <on|off>')
        print('^7  ' .. WHudBisectLine() .. '^0')
        return
    end
    local on = state == 'on'
    if what == 'all' then
        for _, name in ipairs(ORDER) do apply(name, on) end
    else
        apply(what, on)
    end
    print(('^2[w_hud]^7 bisect: %s -> %s^0'):format(what, on and 'on' or 'OFF'))
    print('^7  ' .. WHudBisectLine() .. '^0')
    if not on then print('^7  now walk to the wagon: did the prompts come back?^0') end
end, false)
