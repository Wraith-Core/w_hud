-- ============================================================
-- w_hud · client/stablediag.lua -- /stablediag: what the game sees around the player
--
-- SS-Stable's client is closed, so when its wagon / horse prompts do not appear the
-- only way to tell *why* is to look at the same facts it looks at: is the vehicle
-- networked and who owns it, is the player locked on to it, which targeting mode the
-- core forces, are the prompt keys still enabled, is the horse actually the player's.
-- One command, one screenshot of F8, and the guessing stops.
-- ============================================================

local KEYS = {
    { 'WagonOpenStash', 0xFF8109D8 }, { 'WagonSendAway', 0x06052D11 }, { 'WagonGetCargo (G)', 0x760A9C6F },
    { 'WagonDropCargo (N)', 0x4BC9DABB }, { 'HorseOpenStash (R)', 0xE30CD707 }, { 'HorseGetPelts (U)', 0xD8F73058 },
    { 'E', 0xCEFD9220 }, { 'F', 0xB2F377E8 },
}

local function line(label, value) print(('  %-28s %s'):format(label, tostring(value))) end
-- a native answers a BOOL as true/false or as 1/0 depending on how it is invoked: one test for both
local function yes(value) return value == true or value == 1 end

local function nearest(kind)
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    local pool = GetGamePool(kind)
    local best, bestDist
    for _, ent in ipairs(pool) do
        if ent ~= ped and DoesEntityExist(ent) then
            local d = #(GetEntityCoords(ent) - me)
            if d < 12.0 and (not bestDist or d < bestDist) then best, bestDist = ent, d end
        end
    end
    return best, bestDist
end

local function describe(ent, dist)
    line('distance', ('%.1f m'):format(dist))
    -- (GetEntityArchetypeName is a FiveM-only native: RedM has no name for a model, only the hash)
    line('model hash', ('0x%X'):format(GetEntityModel(ent)))
    line('networked', NetworkGetEntityIsNetworked(ent))
    if NetworkGetEntityIsNetworked(ent) then
        line('netId', NetworkGetNetworkIdFromEntity(ent))
        local owner = NetworkGetEntityOwner(ent)
        line('network owner (server id)', owner and owner ~= -1 and GetPlayerServerId(owner) or 'none')
        line('I have control', NetworkHasControlOfEntity(ent))
    end
    line('mission entity', IsEntityAMissionEntity(ent))
    line('health', GetEntityHealth(ent))
    local ok, populationType = pcall(GetEntityPopulationType, ent)
    line('population type', ok and populationType or '?')
end

RegisterCommand('stablediag', function()
    local ped = PlayerPedId()
    print('^3== /stablediag =============================================^0')
    for _, res in ipairs({ 'SS-Core', 'SS-Inputs', 'SS-Stable', 'vorp_core', 'vorp_inventory', 'w_wheel', 'w_hud' }) do
        line('resource ' .. res, GetResourceState(res))
    end
    line('character loaded', LocalPlayer.state.IsInSession == true)
    -- vorp_core forces free aim (SetPlayerTargetingMode 3) every frame when its
    -- config has disableAutoAIM = true; lock-on based prompts never fire then.
    line('free aiming', IsPlayerFreeAiming(PlayerId()))
    local okT, found, target = pcall(GetPlayerTargetEntity, PlayerId())
    line('lock-on target', okT and (found and target or 'none') or '?')
    local okF, aiming, aimedAt = pcall(GetEntityPlayerIsFreeAimingAt, PlayerId())
    line('free-aim target', okF and aiming and aimedAt or 0)
    line('on mount', IsPedOnMount(ped))
    line('in vehicle', IsPedInAnyVehicle(ped, false))

    -- w_hud's own hiding: the one thing in this resource that can take another script's
    -- prompts off the screen (client/ammo.lua). If 'hiding now' is true while the prompts are
    -- missing, that is the cause; if it is false and they are still missing, it is not w_hud's hide.
    print('^3-- w_hud hiding (client/ammo.lua)^0')
    local hide = rawget(_G, 'WHudHideState')
    if type(hide) == 'table' then
        line('ammo.lua build', hide.build)
        line('hide mode (/hudhide)', hide.mode())
        line('component hide (/hidecomp)', hide.enabled() and 'on' or 'off')
        line('gun in hand', hide.armed())
        line('aiming', hide.aiming())
        line('hiding now', hide.hidingNow() and '^1YES^0' or 'no')
        if type(hide.ctx) == 'table' then
            local c, now = hide.ctx, GetGameTimer()
            line('ctx enables (per frame)', ('%d, last %s ms ago'):format(c.enables, c.lastEnabledAt and (now - c.lastEnabledAt) or '-'))
            line('ctx disables', ('%d, last %s ms ago'):format(c.disables, c.lastDisabledAt and (now - c.lastDisabledAt) or '-'))
            line('persistent enable used', c.persistentUsed and '^1YES (/hudctx on)^0' or 'no')
            line('probe hash (/hidecomp)', hide.probe() or 'none')
        end
    else
        line('ammo.lua build', '^1OLD FILE (no WHudHideState)^0')
    end
    line('w_hud interface shown', showUI ~= false)
    line('w_hud hideStement', hideStement == true)
    line('bisect switches', type(WHudBisectLine) == 'function' and WHudBisectLine() or 'n/a')

    print('^3-- the HUD / the prompt system as the game sees it^0')
    -- IS_HUD_HIDDEN 0x71B72B478F8189DC · IS_PAUSE_MENU_ACTIVE 0x535384D6067BA42E
    line('HUD hidden (IS_HUD_HIDDEN)', yes(Citizen.InvokeNative(0x71B72B478F8189DC, Citizen.ResultAsInteger())) and '^1YES^0' or 'no')
    line('pause menu active', yes(IsPauseMenuActive()) and 'YES' or 'no')
    line('NUI focused / keeps input', ('%s / %s'):format(tostring(IsNuiFocused()), tostring(IsNuiFocusKeepingInput())))
    -- _GET_PLAYER_UI_PROMPT_IS_DISABLED(player, promptType, promptMode): a prompt TYPE another
    -- script switched off for this player (only the disabled ones are printed)
    local disabledTypes = {}
    for promptType = 0, 63 do
        local ok, disabled = pcall(Citizen.InvokeNative, 0x6614F9039BD31931, PlayerId(), promptType, 0, Citizen.ResultAsInteger())
        if ok and yes(disabled) then disabledTypes[#disabledTypes + 1] = tostring(promptType) end
    end
    line('disabled prompt types', #disabledTypes > 0 and ('^1' .. table.concat(disabledTypes, ', ') .. '^0') or 'none')
    for _, res in ipairs({ 'w_lib', 'w_map', 'w_pausemenu', 'w_wheel', 'w_crafting' }) do
        line('resource ' .. res, GetResourceState(res))
    end
    print('^7  (note for the report: is ANY prompt group visible bottom-right right now -- the game\'s own or the wagon\'s?)^0')

    print('^3-- prompt keys (disabled = another script blocks them this frame)^0')
    for _, k in ipairs(KEYS) do
        -- UI_PROMPT_IS_CONTROL_ACTION_ACTIVE 0x1BE19185B8AFE299: a prompt on this control is live
        local okA, active = pcall(Citizen.InvokeNative, 0x1BE19185B8AFE299, k[2], Citizen.ResultAsInteger())
        line(k[1], ('%s · prompt on it: %s'):format(IsControlEnabled(0, k[2]) and 'enabled' or '^1DISABLED^0',
            okA and (yes(active) and '^2active^0' or 'none') or '?'))
    end

    local veh, vd = nearest('CVehicle')
    print('^3-- nearest vehicle^0')
    if veh then describe(veh, vd) else print('  none within 12 m') end

    local horse, hd = nearest('CPed')
    -- the nearest ped that is a horse, not a person
    if horse and not IsPedHuman(horse) then
        print('^3-- nearest animal^0')
        describe(horse, hd)
        line('is a horse', Citizen.InvokeNative(0x772A1969F649E902, GetEntityModel(horse)) == 1) -- IS_THIS_MODEL_A_HORSE
        local okL, last = pcall(GetLastMount, ped)
        line('my mount', GetMount(ped) == horse or (okL and last == horse))
        local okOwner, owner = pcall(function() return Entity(horse).state.owner end)
        line('statebag owner', okOwner and owner or 'n/a')
    end
    print('^3============================================================^0')
end, false)

-- ════════════════════════════════════════════════════════════════════════════
-- /promptprobe [seconds] -- a native prompt group of w_hud's own, on the SAME controls
-- SS-Stable uses (R = 0xFF8109D8 INPUT_LOOT_ALIVE_COMPONENT, G = 0x760A9C6F
-- INPUT_INTERACT_OPTION1), shown bottom-right for N seconds.
--
-- ★ The one experiment that splits the question without SS-Stable's code:
--     the probe group DRAWS while the wagon's does not  -> script prompts render fine
--                                                          under w_hud; SS-Stable's own
--                                                          gate is what fails
--     the probe group does NOT draw either              -> w_hud breaks script-prompt
--                                                          rendering: /hudbisect all off,
--                                                          then the pieces back one by one
-- ════════════════════════════════════════════════════════════════════════════
local PROMPT = {
    RegisterBegin = 0x04F97DE45A519419, RegisterEnd = 0xF7AA2696A22AD8B9,
    SetControlAction = 0xB5352B7494A08258, SetText = 0x5DD02A8318420DD7,
    SetEnabled = 0x8A0FB4D03A630D21, SetVisible = 0x71215ACCFDE075EE,
    SetStandardMode = 0xCC6656799977741B, SetGroup = 0x2F11D3A254169EA4,
    SetActiveGroupThisFrame = 0xC65A45D4453C2627, Delete = 0x00EDE88D4D13CF59,
    IsEnabled = 0x0D00EDDFB58B7F28, IsActive = 0x546E342E01DE71CF, IsValid = 0x347469FBDD1589A9,
}
local VAR_STRING = 0xFA925AC00EB830B9
-- the same call w_lib's prompt module makes (CreateVarString is RedM's name for VAR_STRING)
local function literal(text)
    if type(CreateVarString) == 'function' then return CreateVarString(10, 'LITERAL_STRING', text) end
    return Citizen.InvokeNative(VAR_STRING, 10, 'LITERAL_STRING', text, Citizen.ResultAsLong())
end
local probeRunning = false

RegisterCommand('promptprobe', function(_, args)
    if probeRunning then return print('^3[w_hud]^7 promptprobe already running') end
    local seconds = math.max(3, math.min(60, tonumber(args[1]) or 10))
    probeRunning = true
    CreateThread(function()
        local group = GetHashKey('w_hud_probe_group')
        local prompts = {}
        for _, spec in ipairs({ { 'probe R', 0xFF8109D8 }, { 'probe G', 0x760A9C6F } }) do
            local p = Citizen.InvokeNative(PROMPT.RegisterBegin, Citizen.ResultAsInteger())
            Citizen.InvokeNative(PROMPT.SetControlAction, p, spec[2])
            Citizen.InvokeNative(PROMPT.SetText, p, literal(spec[1]))
            Citizen.InvokeNative(PROMPT.SetEnabled, p, true)
            Citizen.InvokeNative(PROMPT.SetVisible, p, true)
            Citizen.InvokeNative(PROMPT.SetStandardMode, p, true)
            Citizen.InvokeNative(PROMPT.SetGroup, p, group, 0)
            Citizen.InvokeNative(PROMPT.RegisterEnd, p)
            prompts[#prompts + 1] = p
        end
        print(('^3[w_hud]^7 promptprobe: showing a prompt group of our own for %d s -- is "w_hud probe" visible bottom-right?^0'):format(seconds))
        local title = literal('w_hud probe')
        local deadline, nextReport = GetGameTimer() + seconds * 1000, 0
        while GetGameTimer() < deadline do
            Citizen.InvokeNative(PROMPT.SetActiveGroupThisFrame, group, title, 1, 0, 0, 0)
            local now = GetGameTimer()
            if now >= nextReport then
                nextReport = now + 1000
                local parts = {}
                for i, p in ipairs(prompts) do
                    parts[#parts + 1] = ('#%d valid=%s enabled=%s active=%s'):format(i,
                        tostring(yes(Citizen.InvokeNative(PROMPT.IsValid, p, Citizen.ResultAsInteger()))),
                        tostring(yes(Citizen.InvokeNative(PROMPT.IsEnabled, p, Citizen.ResultAsInteger()))),
                        tostring(yes(Citizen.InvokeNative(PROMPT.IsActive, p, Citizen.ResultAsInteger()))))
                end
                print('^7  ' .. table.concat(parts, ' | ') .. ('  hudHidden=%s'):format(tostring(yes(Citizen.InvokeNative(0x71B72B478F8189DC, Citizen.ResultAsInteger())))) .. '^0')
            end
            Wait(0)
        end
        for _, p in ipairs(prompts) do Citizen.InvokeNative(PROMPT.Delete, p) end
        probeRunning = false
        print('^3[w_hud]^7 promptprobe: done. visible = script prompts render under w_hud (SS-Stable\'s own gate fails); invisible = run /hudbisect all off and repeat^0')
    end)
end, false)
