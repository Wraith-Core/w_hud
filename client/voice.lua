-- ════════════════════════════════════════════════════════════════════════════
-- w_hud -- voice level: four steps on the mouse wheel
--
--   Whisper · Normal · Loud · Shouting
--
-- ★ Why do we own the levels instead of pma-voice?
--   pma-voice defines three in Cfg.voiceModes, and its mode variable is local and
--   never exported -- while its cycleproximity command only cycles forward, which is
--   no use for a wheel that goes up and down. So we own the steps in shared/needs.lua
--   and push the distance into it through its declared overrideProximityRange export.
--   Not one line of it is touched.
--
--   And on RedM no key is bound to cycleproximity at all, so there is no input to fight over.
-- ════════════════════════════════════════════════════════════════════════════

local Cfg = Config.Voice or {}
local Levels = Cfg.Levels or {}
local KVP = 'w_hud:voiceLevel' -- remembers the player's choice between sessions

local function levelCount() return #Levels end

--- The level's name in the player's language (`label` is a dictionary key, voice.<name>).
local function labelOf(i)
    local l = Levels[i] and Levels[i].label
    return l and locale(l) or ''
end

--- Apply the level to pma-voice
---
--- ★ No notification on change. There used to be a w.notify printing "Loud" in the
---   middle of the screen on every wheel tick -- and the voice core in the HUD says
---   the same thing permanently and without noise. The notification only repeated what
---   was already on screen, and worst of all it fired two or three times a second while
---   the player scrolled between steps.
local function apply(index)
    local n = levelCount(); if n == 0 then return end

    if index < 1 then index = 1 elseif index > n then index = n end
    voiceLevel = index

    local entry = Levels[index]

    if GetResourceState('pma-voice') == 'started' then
        -- ★ pcall: pma-voice builds differ, and a missing export must not kill the thread
        pcall(function()
            exports['pma-voice']:overrideProximityRange(entry.distance + 0.0)
        end)
    end

    SetResourceKvpInt(KVP, index)

end

local function step(delta)
    local n = levelCount(); if n == 0 then return end

    local next = (voiceLevel or Cfg.Default or 2) + delta

    -- ★ No wrap-around: going from Shouting to Whisper in one tick makes a player
    --   whisper while they believe they are shouting. Stopping at the ends is clearer.
    if next < 1 or next > n then return end

    apply(next)
end

exports('SetVoiceLevel', function(i) apply(tonumber(i) or 1); return voiceLevel end)
exports('GetVoiceLevel', function() return voiceLevel, labelOf(voiceLevel) end)

-- -- startup ----------------------------------------------------------------
CreateThread(function()
    if not Cfg.Enabled then return end

    -- Wait for pma-voice to be ready so it does not overwrite our setting while initialising
    Wait(3000)

    local saved = GetResourceKvpInt(KVP)
    apply((saved and saved > 0) and saved or (Cfg.Default or 2))
end)

-- ════════════════════════════════════════════════════════════════════════════
-- Mouse wheel -- through a named keybind, not by polling controls
--
-- ★ Polling controls (INPUT_CURSOR_SCROLL_* and INPUT_SELECT_*_WEAPON) was guesswork:
--   wheel binding in RDR3 follows the player's own control map, and the "next" control
--   fires in both directions under some maps -- so the voice went up and never down.
--
--   w.addKeybind registers MOUSE_WHEEL with IOM_WHEEL_UP / IOM_WHEEL_DOWN: a declared
--   binding that tells the two directions apart with certainty, does not compete with
--   the game's controls, and shows up in the key list so the player can move it.
-- ════════════════════════════════════════════════════════════════════════════
CreateThread(function()
    if not (Cfg.Enabled and Cfg.ScrollControl) then return end

    -- ⚠️ Labels are registered once, in the language active at load: the game cannot
    --    relabel a key mapping afterwards, so a switch reaches them at the next start.
    w.addKeybind({
        name          = 'w_hud_voice_up',
        description   = 'Raise voice level',   -- English on purpose: the key-binding page cannot draw Arabic
        defaultMapper = 'MOUSE_WHEEL',
        defaultKey    = 'IOM_WHEEL_UP',
        onPressed     = function() step(1) end,
    })

    w.addKeybind({
        name          = 'w_hud_voice_down',
        description   = 'Lower voice level',   -- English on purpose: the key-binding page cannot draw Arabic
        defaultMapper = 'MOUSE_WHEEL',
        defaultKey    = 'IOM_WHEEL_DOWN',
        onPressed     = function() step(-1) end,
    })
end)

-- -- /voice -- a path that depends on no key at all -------------------------
-- ★ Necessary, not spare: the wheel binding follows each player's settings and may not
--   be bound for them at all. If binding fails, the player still has a way to set their
--   voice instead of being stuck on one step.
--     /voice        -> shows the current level and the available ones
--     /voice 2      -> switches to the second level
--     /voice up|down
RegisterCommand('voice', function(_, args)
    local arg = tostring(args[1] or ''):lower()

    if arg == 'up' then return step(1) end
    if arg == 'down' then return step(-1) end

    local n = tonumber(arg)

    if n then
        if n < 1 or n > levelCount() then
            return WHudLocale.notify('voice.help', '#e8c547', 'warning', 4000, { levelCount() })
        end
        return apply(n)
    end

    -- the current level (its name as the title, the counter below) and how to change it
    local current = Levels[voiceLevel] and Levels[voiceLevel].label or 'voice.normal'
    WHudLocale.notify(current, '#34b895', 'tick', 4000, nil,
        ('%s/%s'):format(tostring(voiceLevel), tostring(levelCount())))
    WHudLocale.notify('voice.help', '#ffffff', 'rating_star', 4000, { levelCount() })
end, false)

-- ════════════════════════════════════════════════════════════════════════════
-- /scrolldebug -- which control does your wheel actually fire?
--
-- ★ Wheel binding in RDR3 differs with the control map, and there is no way to know
--   the right control except by measuring it on your own machine. This command prints
--   every control that fires within five seconds, along with your scroll direction.
-- ════════════════════════════════════════════════════════════════════════════
RegisterCommand('scrolldebug', function()
    local WATCH = {
        { 'INPUT_CURSOR_SCROLL_UP', `INPUT_CURSOR_SCROLL_UP` },
        { 'INPUT_CURSOR_SCROLL_DOWN', `INPUT_CURSOR_SCROLL_DOWN` },
        { 'INPUT_SELECT_NEXT_WEAPON', `INPUT_SELECT_NEXT_WEAPON` },
        { 'INPUT_SELECT_PREV_WEAPON', `INPUT_SELECT_PREV_WEAPON` },
        { 'INPUT_NEXT_WEAPON', `INPUT_NEXT_WEAPON` },
        { 'INPUT_PREV_WEAPON', `INPUT_PREV_WEAPON` },
        { 'INPUT_WEAPON_WHEEL_NEXT', `INPUT_WEAPON_WHEEL_NEXT` },
        { 'INPUT_WEAPON_WHEEL_PREV', `INPUT_WEAPON_WHEEL_PREV` },
    }

    print('^3== w_hud - SCROLL PROBE =================================^0')
    print('^7Scroll the wheel UP and DOWN for the next 5 seconds...^0')

    CreateThread(function()
        local deadline = GetGameTimer() + 5000
        local seen = {}

        while GetGameTimer() < deadline do
            for i = 1, #WATCH do
                local name, hash = WATCH[i][1], WATCH[i][2]

                if IsDisabledControlJustPressed(0, hash) or IsControlJustPressed(0, hash) then
                    seen[name] = (seen[name] or 0) + 1
                end
            end
            Wait(0)
        end

        local any = false
        for name, count in pairs(seen) do
            any = true
            print(('^2[fired]^7 %-28s x%d'):format(name, count))
        end

        if not any then
            -- ★ This is the expected outcome, not a fault.
            --   No game control is bound to the wheel under your control map, which is
            --   why polling was abandoned in favour of RegisterKeyMapping -- that reads
            --   raw input before the game interprets it.
            print('^3No game control is bound to the wheel - this is expected.^7')
            print('^7w_hud uses a named keybind (w.addKeybind, MOUSE_WHEEL) instead.^0')
            print('^7Find it in: Settings > Key Bindings > RedM > "Raise/Lower voice level"^0')
        end

        print(('^7current voice level: %s/%s^0'):format(tostring(voiceLevel), tostring(levelCount())))
        print('^3=========================================================^0')
    end)
end, false)
